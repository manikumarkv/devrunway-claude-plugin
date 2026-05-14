---
name: auth0
description: Auth0 conventions — SDK setup, token verification, roles via Management API, Actions, and machine-to-machine tokens. Load when working with Auth0 authentication.
user-invocable: false
stack: auth/auth0
paths:
  - "**/auth0*"
  - "**/auth/**"
---

Full standards in [auth0.md](auth0.md). Always-on summary:

**Server-side verification:**
- Always verify JWTs server-side using `jwks-rsa` + `jsonwebtoken` or the Auth0 SDK
- Check `aud` (audience) claim — must match your API identifier, not just any Auth0 token
- Check `iss` (issuer) — must match `https://<your-domain>.auth0.com/`

**Roles and permissions:**
- Roles are managed in Auth0 dashboard or Management API
- Permissions flow into the JWT as `scope` claims (for APIs) or custom namespace claims
- Add permissions to the token via an Auth0 Action — they don't appear automatically

**Tokens:**
- Access tokens are for API calls — short-lived (24h default), scope-based
- ID tokens are for user profile info — never send to your API
- Refresh tokens enable silent renewal — require `offline_access` scope

**Machine-to-machine (M2M):**
- Service-to-service calls use Client Credentials flow — no user involved
- M2M tokens are cached and reused until near-expiry

**Never:**
- Send ID tokens to your API — use access tokens
- Trust the `sub` claim without verifying the token signature
- Store tokens in `localStorage` for SPAs — use in-memory + silent refresh

**Related skills:** `security-principles` (JWT verification, OWASP auth), `api-conventions` (401/403 response codes)
