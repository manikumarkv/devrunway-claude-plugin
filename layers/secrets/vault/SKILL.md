---
name: vault
description: HashiCorp Vault — static/dynamic secrets, AppRole auth, KV v2, Node.js SDK, lease renewal
user-invocable: false
stack: secrets/vault
paths:
  - "**/vault*"
  - "**/*secrets*"
  - "**/vault/**"
  - "**/secrets/**"
  - "**/policies/*.hcl"
---

Full standards in [vault.md](vault.md). Always-on summary:

> **Scope — applies only if this project uses vault.** This layer shares `**/*secrets*` with `aws-secrets-manager` in `layers/secrets/`, so more than one may load at once and their rules conflict. If the project is not using vault, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Authentication:**
- Use AppRole for machine-to-machine auth (CI, services) — never use root token or dev tokens in production
- Use Kubernetes auth method for pods in Kubernetes — call `kubernetes/login` with the pod's service account token to obtain a short-lived Vault token
- Store `role_id` in config; fetch `secret_id` from a secure bootstrap mechanism — never commit either

**KV v2 (Static Secrets):**
- Enable KV v2 at `secret/` path — KV v2 supports versioning and soft-delete
- Namespace secrets by service: `secret/data/myapp/database`, `secret/data/myapp/api-keys`
- Access via `vault kv get secret/myapp/database` or SDK `client.secrets.kv.v2.read()`

**Dynamic Secrets:**
- Use dynamic secrets for databases — fetch from `database/creds/<role>` to get short-lived credentials
- The response includes `lease_id`, `lease_duration`, and `renewable` fields — store `lease_id` for renewal
- Dynamic credentials expire automatically — configure `default_ttl` and `max_ttl` appropriately

**Lease renewal — a token lease and a secret lease are different objects:**
- Renewing the **token** (`auth/token/renew-self`, `tokenRenewSelf()`) keeps the *client* authenticated. It does nothing for a dynamic database credential
- Renew the **credential** against `sys/leases/renew`, passing the `lease_id` that came back from `database/creds/<role>`. Skip this and the Postgres role disappears at `max_ttl` while the Vault token is still perfectly valid — a failure that reads like a database problem
- Check `renewable` first; a non-renewable lease can only be replaced
- Renew at 75% of `lease_duration`. At 100% the renewal request races Vault's revocation
- `max_ttl` is a ceiling no renewal crosses, so every dynamic credential is eventually replaced: fetch fresh credentials, swap the connection pool, then `sys/leases/revoke` the old lease. This is normal operation, not an error path
- A long-running service runs **both** loops — token renewal to stay authenticated, lease renewal to keep its database role

**Policies:**
- Write explicit HCL policies — never use `*` capabilities
- Scope policies to specific paths: `path "secret/data/myapp/*" { capabilities = ["read"] }`
- Attach the least-privilege policy to each AppRole

**Never:**
- Use the root token outside of initial Vault setup
- Log the `secret_id` or any Vault token — it is a secret
- Log or persist the response from `database/creds/<role>` — it carries a live database password; log the `lease_id` only
- Write a dynamic credential to a file, a `.env`, or any store that outlives its lease
- Store tokens in environment variables that are visible in `ps aux` output
- Set a static token via environment variable in production — use the SDK AppRole or Kubernetes auth flow instead

**Related skills:** `security-principles` (no credential in source or logs; redact before logging, not after), `cdk`, `nodejs-standards`
