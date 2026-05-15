# AWS Secrets Manager Standards

## Installing

```bash
# Python
pip install boto3

# Node.js
npm install @aws-sdk/client-secrets-manager
```

## Typed secret loader with in-process cache (Python)

```python
# secrets/loader.py
import json
import time
import logging
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

_cache: dict[str, tuple[Any, float]] = {}
_DEFAULT_TTL = 300  # 5 minutes


def get_secret(secret_id: str, ttl: float = _DEFAULT_TTL) -> dict:
    """Retrieve and cache a JSON secret from AWS Secrets Manager."""
    now = time.monotonic()
    if secret_id in _cache:
        value, expires_at = _cache[secret_id]
        if now < expires_at:
            return value

    client = _get_client()
    try:
        response = client.get_secret_value(SecretId=secret_id)
    except ClientError as exc:
        code = exc.response["Error"]["Code"]
        if code == "ResourceNotFoundException":
            raise KeyError(f"Secret not found: {secret_id}") from exc
        if code == "AccessDeniedException":
            raise PermissionError(f"Access denied to secret: {secret_id}") from exc
        raise

    raw = response.get("SecretString") or response.get("SecretBinary", b"").decode()
    value = json.loads(raw)
    _cache[secret_id] = (value, now + ttl)
    logger.info("secret_loaded", extra={"secret_id": secret_id})
    return value


@lru_cache(maxsize=1)
def _get_client():
    return boto3.client("secretsmanager")
```

## Typed config object

```python
# config.py
import os
from dataclasses import dataclass
from secrets.loader import get_secret


@dataclass(frozen=True)
class DatabaseConfig:
    host: str
    port: int
    name: str
    username: str
    password: str

    @property
    def url(self) -> str:
        return f"postgresql+asyncpg://{self.username}:{self.password}@{self.host}:{self.port}/{self.name}"


@dataclass(frozen=True)
class AppSecrets:
    database: DatabaseConfig
    jwt_secret: str
    stripe_secret_key: str


def load_secrets() -> AppSecrets:
    secret_id = os.environ["APP_SECRET_ID"]  # e.g. "myapp/production/secrets"
    raw = get_secret(secret_id)
    return AppSecrets(
        database=DatabaseConfig(
            host=raw["db_host"],
            port=int(raw["db_port"]),
            name=raw["db_name"],
            username=raw["db_username"],
            password=raw["db_password"],
        ),
        jwt_secret=raw["jwt_secret"],
        stripe_secret_key=raw["stripe_secret_key"],
    )


# Singleton — load once at startup
_secrets: AppSecrets | None = None

def get_app_secrets() -> AppSecrets:
    global _secrets
    if _secrets is None:
        _secrets = load_secrets()
    return _secrets
```

## Node.js / TypeScript loader with cache

```typescript
// src/secrets/loader.ts
import {
  SecretsManagerClient,
  GetSecretValueCommand,
  ResourceNotFoundException,
} from "@aws-sdk/client-secrets-manager";

const client = new SecretsManagerClient({ region: process.env.AWS_REGION ?? "us-east-1" });
const cache = new Map<string, { value: Record<string, string>; expiresAt: number }>();
const DEFAULT_TTL_MS = 5 * 60 * 1000;

export async function getSecret(
  secretId: string,
  ttlMs = DEFAULT_TTL_MS
): Promise<Record<string, string>> {
  const now = Date.now();
  const cached = cache.get(secretId);
  if (cached && now < cached.expiresAt) return cached.value;

  const command = new GetSecretValueCommand({ SecretId: secretId });
  const response = await client.send(command);

  if (!response.SecretString) {
    throw new Error(`Secret ${secretId} has no SecretString`);
  }

  const value = JSON.parse(response.SecretString) as Record<string, string>;
  cache.set(secretId, { value, expiresAt: now + ttlMs });
  return value;
}
```

## Creating a secret (CDK)

```typescript
// lib/secrets-stack.ts
import * as cdk from "aws-cdk-lib";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";

export class SecretsStack extends cdk.Stack {
  public readonly appSecret: secretsmanager.Secret;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    this.appSecret = new secretsmanager.Secret(this, "AppSecret", {
      secretName: "myapp/production/secrets",
      description: "Application secrets for production",
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ db_username: "admin" }),
        generateStringKey: "db_password",
        excludeCharacters: " %+~`#$&*()|[]{}:;<>?!'/@\"\\",
        passwordLength: 32,
      },
    });
  }
}
```

## IAM least-privilege policy (CDK)

```typescript
// Grant read-only to a specific Lambda
const readPolicy = new iam.PolicyStatement({
  sid: "AllowSecretRead",
  effect: iam.Effect.ALLOW,
  actions: ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
  resources: [appSecret.secretArn],
});

lambdaFunction.addToRolePolicy(readPolicy);

// Rotation Lambda — more permissions on a single secret
const rotationPolicy = new iam.PolicyStatement({
  sid: "AllowSecretRotation",
  effect: iam.Effect.ALLOW,
  actions: [
    "secretsmanager:DescribeSecret",
    "secretsmanager:GetSecretValue",
    "secretsmanager:PutSecretValue",
    "secretsmanager:UpdateSecretVersionStage",
  ],
  resources: [appSecret.secretArn],
});
```

## Rotation Lambda (Python)

```python
# rotation/handler.py
import boto3
import json
import logging
import os

logger = logging.getLogger(__name__)
client = boto3.client("secretsmanager")


def lambda_handler(event: dict, context) -> None:
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]

    metadata = client.describe_secret(SecretId=arn)
    if not metadata.get("RotationEnabled"):
        raise ValueError(f"Rotation not enabled for {arn}")

    versions = metadata.get("VersionIdsToStages", {})
    if token not in versions:
        raise ValueError(f"Token {token} not found in secret versions")
    if "AWSCURRENT" in versions[token]:
        logger.info("Token is already current; skipping rotation")
        return
    if "AWSPENDING" not in versions[token]:
        raise ValueError(f"Token {token} is not AWSPENDING")

    dispatch = {
        "createSecret": create_secret,
        "setSecret": set_secret,
        "testSecret": test_secret,
        "finishSecret": finish_secret,
    }
    dispatch[step](client, arn, token)


def create_secret(client, arn: str, token: str) -> None:
    try:
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info("Pending secret already exists; skipping createSecret")
    except client.exceptions.ResourceNotFoundException:
        current = json.loads(client.get_secret_value(SecretId=arn)["SecretString"])
        current["password"] = _generate_password()
        client.put_secret_value(
            SecretId=arn,
            ClientRequestToken=token,
            SecretString=json.dumps(current),
            VersionStages=["AWSPENDING"],
        )


def set_secret(client, arn: str, token: str) -> None:
    pending = json.loads(
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")["SecretString"]
    )
    # Apply the new password to the actual database / service here
    # e.g. _update_db_password(pending["username"], pending["password"])
    logger.info("set_secret: credentials applied to service")


def test_secret(client, arn: str, token: str) -> None:
    pending = json.loads(
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")["SecretString"]
    )
    # Verify the new credentials work
    # e.g. _test_db_connection(pending)
    logger.info("test_secret: connection verified")


def finish_secret(client, arn: str, token: str) -> None:
    metadata = client.describe_secret(SecretId=arn)
    current_version = next(
        v for v, stages in metadata["VersionIdsToStages"].items() if "AWSCURRENT" in stages
    )
    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )
    logger.info("finish_secret: rotation complete", extra={"new_version": token})


def _generate_password(length: int = 32) -> str:
    import secrets
    import string
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))
```

## Enable rotation (CDK)

```typescript
import * as lambda from "aws-cdk-lib/aws-lambda";

const rotationLambda = new lambda.Function(this, "RotationLambda", {
  runtime: lambda.Runtime.PYTHON_3_12,
  handler: "handler.lambda_handler",
  code: lambda.Code.fromAsset("rotation"),
  environment: { SECRETS_MANAGER_ENDPOINT: `https://secretsmanager.${this.region}.amazonaws.com` },
});

appSecret.addRotationSchedule("RotationSchedule", {
  rotationLambda,
  automaticallyAfter: cdk.Duration.days(30),
});
```

## SSM Parameter Store vs Secrets Manager

| Factor | Secrets Manager | SSM Parameter Store |
|---|---|---|
| Cost | ~$0.40/secret/month + API calls | Free tier (4000 params); $0.05/10k API calls |
| Rotation | Built-in Lambda rotation | Manual |
| Versioning | Multiple versions with stages | Version history |
| Cross-account | Resource-based policies | Limited |
| Use for | DB passwords, API keys, certs | App config, non-rotating values |

```python
# SSM for non-rotating config
def get_parameter(name: str, decrypt: bool = True) -> str:
    ssm = boto3.client("ssm")
    response = ssm.get_parameter(Name=name, WithDecryption=decrypt)
    return response["Parameter"]["Value"]

# Use Secrets Manager for rotating credentials
db_password = get_secret("myapp/prod/db")["password"]
# Use SSM for static config
log_level = get_parameter("/myapp/prod/log-level")
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Calling `GetSecretValue` on every request | Cache in memory with TTL; reload on rotation event |
| Logging `SecretString` value | Log only `SecretId` / ARN; never log raw secret |
| IAM `Resource: "*"` for secrets | Scope to specific ARN: `arn:aws:secretsmanager:*:*:secret:myapp/*` |
| Hardcoding secret ARN in code | Store ARN in env var or CDK cross-stack reference |
| Rotation Lambda missing `testSecret` | All four steps required; missing one causes rotation failure |
| Storing secrets in container env vars at build time | Fetch at runtime using IAM role; never bake into image |
| Not handling `AWSPREVIOUS` during rotation | Keep `AWSPREVIOUS` available until `finishSecret` completes |
