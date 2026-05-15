---
name: vault
description: HashiCorp Vault — static/dynamic secrets, AppRole auth, KV v2, Node.js SDK, lease renewal
user-invocable: false
stack: secrets/vault
paths:
  - "**/*.ts"
  - "**/*.js"
  - "**/*.py"
  - "**/*.hcl"
  - "**/vault*"
  - "**/*secrets*"
---

Full standards in [vault.md](vault.md). Always-on summary:

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

**Lease Renewal:**
- Check the `renewable` field; if true, renew the `lease_id` before TTL expires (at 75% elapsed)
- Renew with Vault Agent or the SDK's `auth.token.renewSelf()`
- On failure to renew, re-authenticate and get fresh credentials — never cache expired leases

**Policies:**
- Write explicit HCL policies — never use `*` capabilities
- Scope policies to specific paths: `path "secret/data/myapp/*" { capabilities = ["read"] }`
- Attach the least-privilege policy to each AppRole

**Never:**
- Use the root token outside of initial Vault setup
- Log the `secret_id` or any Vault token — it is a secret
- Store tokens in environment variables that are visible in `ps aux` output
- Set a static token via environment variable in production — use the SDK AppRole or Kubernetes auth flow instead

**Related skills:** `security-principles`, `cdk`, `nodejs-standards`
