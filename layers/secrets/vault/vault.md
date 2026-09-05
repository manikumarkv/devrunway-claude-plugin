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

## Node.js SDK — Kubernetes Auth (pods)

```typescript
// src/lib/vaultKubernetes.ts
import fs from "fs";

const SA_TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token";

async function authenticateWithKubernetes(): Promise<vault.client> {
  const client = vault({ apiVersion: "v1", endpoint: process.env.VAULT_ADDR! });

  // The pod's projected service account token is the credential. Nothing static
  // is injected, nothing is rotated by hand, and nothing shows up in `ps aux`.
  const jwt = fs.readFileSync(SA_TOKEN_PATH, "utf8");

  const result = await client.write("auth/kubernetes/login", {
    role: "myapp-api",
    jwt,
  });

  client.token = result.auth.client_token;
  scheduleRenewal(client, result.auth.lease_duration);
  return client;
}
```

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
// Dynamic credentials — fetch on startup, then renew the LEASE before expiry
async function getDynamicDbCreds(): Promise<DbLease> {
  const client = await getVaultClient();
  const result = await client.read("database/creds/myapp-api");
  return {
    username: result.data.username,
    password: result.data.password,
    leaseId: result.lease_id,
    leaseDuration: result.lease_duration,
    renewable: result.renewable,
  };
}
```

## Renewing a dynamic credential lease

**A token lease and a secret lease are two different objects.** Renewing the token
keeps the *client* authenticated. It does nothing for the Postgres role Vault
created for you: that role has its own `lease_id`, and when its lease ends Vault
drops the role. The connection pool then fails with an authentication error on a
service whose Vault token is perfectly healthy — which is why this failure is
usually diagnosed as anything but a lease.

Renew the credential's own lease against `sys/leases/renew`, using the `lease_id`
that came back with it. A long-running service runs both loops.

```typescript
// src/lib/dbCredentials.ts
import { Pool } from "pg";
import { getVaultClient } from "./vault";

export interface DbLease {
  username: string;
  password: string;
  leaseId: string;
  leaseDuration: number;
  renewable: boolean;
}

let pool: Pool | null = null;

export async function startDbCredentials(): Promise<Pool> {
  const lease = await getDynamicDbCreds();
  pool = buildPool(lease);
  scheduleLeaseRenewal(lease);
  return pool;
}

function scheduleLeaseRenewal(lease: DbLease): void {
  // 75% of the TTL. Scheduling at the full TTL is scheduling at the moment of
  // expiry: the renewal request races Vault's revocation, and the loser is the
  // database role.
  const renewAt = lease.leaseDuration * 0.75 * 1000;

  setTimeout(async () => {
    if (!lease.renewable) {
      // A non-renewable lease can only be replaced.
      await rotateCredentials(lease);
      return;
    }
    try {
      const client = await getVaultClient();
      const renewed = await client.write("sys/leases/renew", {
        lease_id: lease.leaseId,
        increment: lease.leaseDuration,
      });
      // Vault clamps the increment to max_ttl. Getting back less than you asked
      // for is the warning that this lease is near the end of its life.
      scheduleLeaseRenewal({
        ...lease,
        leaseDuration: renewed.lease_duration,
        renewable: renewed.renewable,
      });
    } catch (err) {
      // Log the lease id, never the credentials it stands for.
      console.warn("Lease renewal failed — issuing fresh credentials", { leaseId: lease.leaseId });
      await rotateCredentials(lease);
    }
  }, renewAt);
}

// max_ttl is a ceiling no amount of renewal crosses, so every dynamic credential
// is eventually replaced. The swap is normal operation, not an error path — build
// it on day one or the service dies at max_ttl on its first long run.
async function rotateCredentials(old: DbLease): Promise<void> {
  const next = await getDynamicDbCreds();
  const previous = pool;
  pool = buildPool(next);
  await previous?.end();

  const client = await getVaultClient();
  await client.write("sys/leases/revoke", { lease_id: old.leaseId });

  scheduleLeaseRenewal(next);
}

function buildPool(lease: DbLease): Pool {
  return new Pool({
    host: process.env.DB_HOST,
    port: 5432,
    user: lease.username,
    password: lease.password,
    database: "myapp",
    ssl: { rejectUnauthorized: true },
  });
}
```

```python
# hvac — same two loops, same distinction
client.auth.token.renew_self()                     # keeps the CLIENT authenticated
client.sys.renew_lease(lease_id=lease_id, increment=3600)   # keeps the DB ROLE alive
client.sys.revoke_lease(lease_id=old_lease_id)     # hand the old role back early
```

Never write a dynamic credential anywhere it outlives its lease: not to a file, not
to a `.env`, not into a log line. The whole point is that it expires.

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
- [ ] Separate lease renewal loop for every dynamic credential, against `sys/leases/renew`
- [ ] Credential swap path implemented and exercised — `max_ttl` ends every lease
- [ ] KV v2 enabled (not v1) — supports versioning
- [ ] Secrets namespaced by service: `secret/data/{service}/{category}`
- [ ] Explicit HCL policies — no wildcard capabilities
- [ ] Dynamic secrets used for database credentials where possible
- [ ] No Vault tokens or secret_ids in logs or environment variable dumps

## Common mistakes

| Mistake | Fix |
|---|---|
| Using KV v1 instead of KV v2 | Enable `kv-v2` (`vault secrets enable -path=secret kv-v2`); v2 supports versioning and soft delete |
| Storing the `secret_id` long-term in an environment variable | `secret_id` is a bootstrap credential — inject it at startup, then clear the env var; rotate `secret_id` regularly |
| Not scheduling token renewal | Vault tokens expire; renew at 75% of `lease_duration` with a `setTimeout`/thread loop — let expiry happen and the app silently fails |
| Using wildcard capabilities in policies (`capabilities = ["*"]`) | List only the capabilities needed (`["read"]`); wildcard grants update, delete, and create to any path matching the pattern |
| Reading secrets on every request instead of caching | Cache secrets in memory for the duration of the lease; re-fetch only on renewal or startup |
| Committing Vault tokens or `role_id` / `secret_id` to source control | `role_id` is non-secret (store in config); `secret_id` is secret — inject via CI/CD secret store only |
| Using the root token in production | The root token is for bootstrapping only; revoke it after setup and use AppRole or Kubernetes auth for all services |
| Renewing the token and calling it lease renewal | `auth/token/renew-self` keeps the client authenticated; the Postgres role has its own `lease_id` and is renewed against `sys/leases/renew`. Renewing only the token loses the database role at `max_ttl` |
| No swap path for when a lease can no longer be renewed | `max_ttl` is a hard ceiling; fetch fresh credentials, rebuild the pool, then revoke the old lease |
| Scheduling renewal at the full `lease_duration` | Renew at 75%; at 100% the renewal races the revocation |
| Logging the Vault response for dynamic credentials | Log the `lease_id` only — the response body contains a live database password |
| Not using dynamic database secrets | Static database credentials are long-lived; use the Vault database secrets engine to issue short-lived, per-service credentials |
