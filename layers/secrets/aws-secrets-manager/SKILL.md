---
name: aws-secrets-manager
description: AWS Secrets Manager standards for boto3 client, in-process caching, rotation, IAM least-privilege, and SSM cross-reference
user-invocable: false
stack: secrets/aws-secrets-manager
paths:
  - "**/*.py"
  - "**/*.ts"
  - "**/*.js"
  - "**/cdk/**"
  - "**/*secrets*"
---

Full standards in [aws-secrets-manager.md](aws-secrets-manager.md). Always-on summary:

**Retrieval:**
- Always cache secret values in memory with a TTL (default 5 min) — never call `GetSecretValue` on every request
- Parse JSON secrets once at startup; surface typed config objects, not raw strings
- Use `SecretString` for credentials; `SecretBinary` only for binary key material

**IAM least-privilege:**
- Grant `secretsmanager:GetSecretValue` only on the specific ARN — never `*`
- Rotation lambdas need `DescribeSecret`, `PutSecretValue`, `UpdateSecretVersionStage` on the single secret
- Use resource-based policies to restrict cross-account access

**Rotation:**
- Enable automatic rotation via `RotationSchedule` — set `RotationLambdaARN`
- Implement the four lifecycle steps: `createSecret`, `setSecret`, `testSecret`, `finishSecret`
- Keep old version (`AWSPREVIOUS`) alive until rotation completes

**SSM vs Secrets Manager:**
- Use Secrets Manager for credentials, API keys, DB passwords (supports rotation, versioning)
- Use SSM Parameter Store (`SecureString`) for non-rotating config values (cheaper)

**Never:**
- Never log secret values — log only the secret ARN or name
- Never hardcode ARNs — use CDK resource refs or environment variables
- Never store secrets in environment variables baked into container images

**Related skills:** cdk, security-principles, logging-standards
