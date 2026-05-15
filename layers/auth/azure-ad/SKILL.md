---
name: azure-ad
description: Azure Active Directory (Entra ID) auth with MSAL, JWT validation, and React provider
user-invocable: false
stack: auth/azure-ad
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.py"
  - "**/auth/**"
  - "**/msal*"
  - "**/*azure-ad*"
---

Full standards in [azure-ad.md](azure-ad.md). Always-on summary:

**MSAL Setup:**
- Use `@azure/msal-browser` for SPAs, `@azure/msal-node` for confidential clients
- Store `clientId` and `tenantId` in env vars — never in source
- Use `PublicClientApplication` with `loginPopup` or `loginRedirect` — never roll your own OAuth flow

**B2C vs Workforce:**
- Workforce (Entra ID): `https://login.microsoftonline.com/{tenantId}` — for employees
- B2C: `https://{tenant}.b2clogin.com/{tenant}.onmicrosoft.com/{policy}` — for customers
- B2C requires `knownAuthorities` set in MSAL config

**React MSAL Provider:**
- Wrap the app in `<MsalProvider instance={msalInstance}>` at the root
- Use `useMsal()` and `useIsAuthenticated()` hooks — never store tokens in component state
- Protect routes with `<AuthenticatedTemplate>` / `<UnauthenticatedTemplate>`

**API Protection (JWT):**
- Validate token on every request: issuer, audience, signature, expiry
- Use `microsoft-identity-web` (.NET) or `python-jose` / `msal` for backend validation
- Never trust claims from the frontend — always re-validate server-side

**Token Handling:**
- Acquire tokens silently first (`acquireTokenSilent`) — fall back to interactive only on `InteractionRequiredAuthError`
- Pass the Bearer token in `Authorization` header — never in query params
- Tokens expire; always handle `401` by refreshing, not by logging out

**Never:**
- Store access tokens in `localStorage` — use `sessionStorage` or in-memory
- Skip audience validation on the API — any Entra-issued token would pass issuer check alone
- Mix B2C and workforce tenants in a single MSAL instance

**Related skills:** `security-principles`, `api-conventions`, `error-handling`
