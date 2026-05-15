# HashiCorp Vault Standards

## Vault Policy (HCL)

```hcl
# policies/myapp-api.hcl
# Read static secrets for the API service
path "secret/data/myapp/database" {
  capabilities = ["read"]
}

path "secret/data/myapp/api-keys" {
  capabilities = ["read"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Look up own token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

```bash
# Apply the policy
vault policy write myapp-api policies/myapp-api.hcl
```

## AppRole Setup

```bash
# Enable AppRole auth
vault auth enable approle

# Create an AppRole with the policy
vault write auth/approle/role/myapp-api \
  token_policies="myapp-api" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=24h \
  secret_id_num_uses=0   # unlimited uses (for long-running services)

# Get role_id (not secret — can be stored in config)
vault read auth/approle/role/myapp-api/role-id

# Generate secret_id (treat as a secret — bootstrap securely)
vault write -f auth/approle/role/myapp-api/secret-id
```

## KV v2 Operations

```bash
# Enable KV v2
vault secrets enable -path=secret kv-v2

# Write a secret
vault kv put secret/myapp/database \
  host="db.internal" \
  port="5432" \
  username="myapp_api" \
  password="$(openssl rand -hex 32)"

# Read
vault kv get -format=json secret/myapp/database

# Update (creates a new version)
vault kv patch secret/myapp/database password="newpassword"

# List versions
vault kv metadata get secret/myapp/database
```

## Node.js SDK — AppRole Auth + KV v2

```typescript
// src/lib/vault.ts
import * as vault from "node-vault";
import fs from "fs";

interface VaultClient {
  getSecret: (path: string) => Promise<Record<string, string>>;
  renewToken: () => Promise<void>;
}

async function authenticate(): Promise<vault.client> {
  const client = vault({
    apiVersion: "v1",
    endpoint: process.env.VAULT_ADDR!,
  });

  // AppRole auth — role_id from config, secret_id from secure bootstrap
  const roleId = process.env.VAULT_ROLE_ID!;
  const secretId = process.env.VAULT_SECRET_ID!;  // injected at startup, then cleared

  const result = await client.approleLogin({ role_id: roleId, secret_id: secretId });
  client.token = result.auth.client_token;

  // Schedule token renewal
  scheduleRenewal(client, result.auth.lease_duration);

  return client;
}

function scheduleRenewal(client: vault.client, leaseDuration: number): void {
  // Renew at 75% of TTL
  const renewAt = leaseDuration * 0.75 * 1000;

  setTimeout(async () => {
    try {
      const renewed = await client.tokenRenewSelf();
      scheduleRenewal(client, renewed.auth.lease_duration);
    } catch (err) {
      console.error("Vault token renewal failed — re-authenticating", { err });
      // Re-authenticate (requires secret_id re-fetch — implement bootstrap)
      process.exit(1);  // or trigger restart via process manager
    }
  }, renewAt);
}

let vaultClient: vault.client | null = null;

export async function getVaultClient(): Promise<vault.client> {
  if (!vaultClient) {
    vaultClient = await authenticate();
  }
  return vaultClient;
}

export async function getSecret(path: string): Promise<Record<string, string>> {
  const client = await getVaultClient();
  // KV v2 path: secret/data/{path}
  const result = await client.read(`secret/data/${path}`);
  return result.data.data as Record<string, string>;
}
```

## Usage in Application

```typescript
// src/database.ts
import { getSecret } from "./lib/vault";
import { Pool } from "pg";

let pool: Pool | null = null;

export async function getPool(): Promise<Pool> {
  if (pool) return pool;

  const creds = await getSecret("myapp/database");

  pool = new Pool({
    host: creds.host,
    port: parseInt(creds.port),
    user: creds.username,
    password: creds.password,
    database: "myapp",
    ssl: { rejectUnauthorized: true },
  });

  return pool;
}
```

## Dynamic Database Secrets

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection (Vault manages credentials)
vault write database/config/myapp-db \
  plugin_name=postgresql-database-plugin \
  allowed_roles="myapp-api" \
  connection_url="postgresql://{{username}}:{{password}}@db.internal:5432/myapp" \
  username="vault_root" \
  password="vault_root_password"

# Create a role that generates short-lived credentials
vault write database/roles/myapp-api \
  db_name=myapp-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="4h"

# Generate credentials
vault read database/creds/myapp-api
```

```typescript
// Dynamic credentials — fetch on startup and renew before expiry
async function getDynamicDbCreds(): Promise<{ username: string; password: string; leaseId: string; leaseDuration: number }> {
  const client = await getVaultClient();
  const result = await client.read("database/creds/myapp-api");
  return {
    username: result.data.username,
    password: result.data.password,
    leaseId: result.lease_id,
    leaseDuration: result.lease_duration,
  };
}
```

## Python SDK

```python
# app/lib/vault.py
import hvac
import os
import threading
import time

_client: hvac.Client | None = None

def _authenticate() -> hvac.Client:
    client = hvac.Client(url=os.environ["VAULT_ADDR"])
    result = client.auth.approle.login(
        role_id=os.environ["VAULT_ROLE_ID"],
        secret_id=os.environ["VAULT_SECRET_ID"],
    )
    client.token = result["auth"]["client_token"]
    ttl = result["auth"]["lease_duration"]
    _schedule_renewal(client, ttl)
    return client

def _schedule_renewal(client: hvac.Client, ttl: int):
    def renew():
        time.sleep(ttl * 0.75)
        result = client.auth.token.renew_self()
        _schedule_renewal(client, result["auth"]["lease_duration"])

    t = threading.Thread(target=renew, daemon=True)
    t.start()

def get_client() -> hvac.Client:
    global _client
    if _client is None:
        _client = _authenticate()
    return _client

def get_secret(path: str) -> dict:
    client = get_client()
    result = client.secrets.kv.v2.read_secret_version(path=path)
    return result["data"]["data"]
```

## Vault Agent (Sidecar — Kubernetes)

```hcl
# vault-agent-config.hcl
auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "myapp-api"
    }
  }
  sink "file" {
    config = {
      path = "/vault/token"
    }
  }
}

template {
  source      = "/vault/templates/database.tpl"
  destination = "/app/secrets/database.env"
}
```

## Checklist

- [ ] AppRole `role_id` in config; `secret_id` injected at startup via secure bootstrap
- [ ] Token renewal loop scheduled at 75% of TTL
- [ ] KV v2 enabled (not v1) — supports versioning
- [ ] Secrets namespaced by service: `secret/data/{service}/{category}`
- [ ] Explicit HCL policies — no wildcard capabilities
- [ ] Dynamic secrets used for database credentials where possible
- [ ] No Vault tokens or secret_ids in logs or environment variable dumps
