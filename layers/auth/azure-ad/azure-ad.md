# Azure Active Directory (Entra ID) Standards

## MSAL Config (SPA)

```typescript
// src/auth/msalConfig.ts
import { Configuration, LogLevel } from "@azure/msal-browser";

export const msalConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_AZURE_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${import.meta.env.VITE_AZURE_TENANT_ID}`,
    redirectUri: window.location.origin,
    postLogoutRedirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: "sessionStorage", // never localStorage
    storeAuthStateInCookie: false,
  },
  system: {
    loggerOptions: {
      loggerCallback: (level, message, containsPii) => {
        if (containsPii) return;
        if (level === LogLevel.Error) console.error(message);
      },
    },
  },
};

// Scopes for your API
export const apiScopes = [`api://${import.meta.env.VITE_API_CLIENT_ID}/access_as_user`];
```

## B2C Config

```typescript
// B2C — note knownAuthorities is required
const b2cConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_B2C_CLIENT_ID,
    authority: `https://${import.meta.env.VITE_B2C_TENANT}.b2clogin.com/${import.meta.env.VITE_B2C_TENANT}.onmicrosoft.com/B2C_1_signupsignin`,
    knownAuthorities: [`${import.meta.env.VITE_B2C_TENANT}.b2clogin.com`],
    redirectUri: window.location.origin,
  },
  cache: { cacheLocation: "sessionStorage" },
};
```

## React Provider and Hooks

```tsx
// src/main.tsx
import { PublicClientApplication } from "@azure/msal-browser";
import { MsalProvider } from "@azure/msal-react";
import { msalConfig } from "./auth/msalConfig";

const msalInstance = new PublicClientApplication(msalConfig);
await msalInstance.initialize();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <MsalProvider instance={msalInstance}>
    <App />
  </MsalProvider>,
);
```

```tsx
// src/components/LoginButton.tsx
import { useMsal } from "@azure/msal-react";
import { apiScopes } from "../auth/msalConfig";

export function LoginButton() {
  const { instance } = useMsal();
  const login = () => instance.loginPopup({ scopes: apiScopes });
  return <button onClick={login}>Sign in</button>;
}
```

```tsx
// Protecting a route
import { AuthenticatedTemplate, UnauthenticatedTemplate } from "@azure/msal-react";

export function ProtectedPage() {
  return (
    <>
      <AuthenticatedTemplate>
        <Dashboard />
      </AuthenticatedTemplate>
      <UnauthenticatedTemplate>
        <LoginButton />
      </UnauthenticatedTemplate>
    </>
  );
}
```

## Acquiring Tokens for API Calls

```typescript
// src/auth/useApiClient.ts
import { useMsal } from "@azure/msal-react";
import { InteractionRequiredAuthError } from "@azure/msal-browser";
import { apiScopes } from "./msalConfig";

export function useApiClient() {
  const { instance, accounts } = useMsal();

  const getToken = async (): Promise<string> => {
    try {
      const result = await instance.acquireTokenSilent({
        scopes: apiScopes,
        account: accounts[0],
      });
      return result.accessToken;
    } catch (err) {
      if (err instanceof InteractionRequiredAuthError) {
        const result = await instance.acquireTokenPopup({ scopes: apiScopes });
        return result.accessToken;
      }
      throw err;
    }
  };

  const apiFetch = async (url: string, options: RequestInit = {}) => {
    const token = await getToken();
    return fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
    });
  };

  return { apiFetch };
}
```

## API JWT Validation (Node.js)

```typescript
// src/middleware/auth.ts
import jwksRsa from "jwks-rsa";
import jwt from "jsonwebtoken";
import { Request, Response, NextFunction } from "express";

const TENANT_ID = process.env.AZURE_TENANT_ID!;
const AUDIENCE = process.env.API_CLIENT_ID!;

const jwksClient = jwksRsa({
  jwksUri: `https://login.microsoftonline.com/${TENANT_ID}/discovery/v2.0/keys`,
  cache: true,
  rateLimit: true,
});

function getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
  jwksClient.getSigningKey(header.kid!, (err, key) => {
    callback(err, key?.getPublicKey());
  });
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace("Bearer ", "");
  if (!token) return res.status(401).json({ error: "Missing token" });

  jwt.verify(
    token,
    getKey,
    {
      issuer: `https://login.microsoftonline.com/${TENANT_ID}/v2.0`,
      audience: `api://${AUDIENCE}`,
      algorithms: ["RS256"],
    },
    (err, payload) => {
      if (err) return res.status(401).json({ error: "Invalid token" });
      (req as any).user = payload;
      next();
    },
  );
}
```

## API JWT Validation (Python)

```python
# app/auth.py
import os
import httpx
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer

TENANT_ID = os.environ["AZURE_TENANT_ID"]
AUDIENCE = f"api://{os.environ['API_CLIENT_ID']}"
ISSUER = f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"

bearer = HTTPBearer()

async def get_jwks():
    url = f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys"
    async with httpx.AsyncClient() as client:
        resp = await client.get(url)
        return resp.json()

async def require_auth(credentials = Depends(bearer)):
    token = credentials.credentials
    try:
        jwks = await get_jwks()
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],
            audience=AUDIENCE,
            issuer=ISSUER,
        )
        return payload
    except JWTError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
```

## Checklist

- [ ] `clientId` and `tenantId` loaded from environment, not hardcoded
- [ ] Token cache uses `sessionStorage`, not `localStorage`
- [ ] `acquireTokenSilent` attempted before any interactive flow
- [ ] API validates `issuer`, `audience`, `algorithms`, and expiry
- [ ] B2C configs include `knownAuthorities`
- [ ] `Authorization: Bearer` header used — no tokens in query params

## Common mistakes

| Mistake | Fix |
|---|---|
| Using `localStorage` for token cache | Use `sessionStorage` (`cacheLocation: "sessionStorage"`) — localStorage is accessible to XSS scripts across tabs |
| Calling interactive login flows before trying silent token acquisition | Always call `acquireTokenSilent` first; only fall back to `loginPopup` / `loginRedirect` on `InteractionRequiredAuthError` |
| Not initializing `PublicClientApplication` with `await msalInstance.initialize()` | MSAL v3+ requires async initialization; skipping it causes race conditions and auth failures |
| Hardcoding `clientId` or `tenantId` in source code | Load from environment variables (`VITE_AZURE_CLIENT_ID`, etc.) — committed IDs expose your app registration |
| Omitting `knownAuthorities` for B2C configs | Without `knownAuthorities`, MSAL rejects tokens from custom B2C domains as untrusted issuers |
| Validating JWTs without checking `issuer` and `audience` | Verify both `iss` and `aud` claims; accepting tokens from any issuer allows cross-tenant token reuse attacks |
| Passing the access token in a query parameter | Always use `Authorization: Bearer <token>` header — query params are logged in server access logs and browser history |
| Using the v1 JWKS endpoint for v2 tokens | Entra ID v2 tokens must be validated against the v2 JWKS URI: `…/v2.0/keys` |
