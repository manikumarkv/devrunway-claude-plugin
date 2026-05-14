# Auth0 Standards

---

## Environment variables

```bash
# .env.example

# Web application (SPA / Next.js)
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret       # server-side only
AUTH0_AUDIENCE=https://api.example.com       # your API identifier
AUTH0_BASE_URL=http://localhost:3000

# API (for token verification)
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_AUDIENCE=https://api.example.com

# Machine-to-machine
AUTH0_M2M_CLIENT_ID=m2m_client_id
AUTH0_M2M_CLIENT_SECRET=m2m_client_secret    # NEVER expose client-side
```

---

## Next.js setup (@auth0/nextjs-auth0)

```bash
npm install @auth0/nextjs-auth0
```

```typescript
// src/app/api/auth/[auth0]/route.ts — handles all Auth0 routes
import { handleAuth } from '@auth0/nextjs-auth0'
export const GET = handleAuth()

// This creates:
// GET /api/auth/login      → redirects to Auth0 Universal Login
// GET /api/auth/callback   → exchanges code for tokens
// GET /api/auth/logout     → clears session and redirects to Auth0 logout
// GET /api/auth/me         → returns current user profile
```

```typescript
// src/middleware.ts — protect routes
import { withMiddlewareAuthRequired } from '@auth0/nextjs-auth0/edge'

export default withMiddlewareAuthRequired()

export const config = {
  matcher: ['/dashboard/:path*', '/api/protected/:path*'],
}
```

```typescript
// Server Component — get session
import { getSession } from '@auth0/nextjs-auth0'

export default async function Dashboard() {
  const session = await getSession()
  const user = session?.user
  return <div>Welcome {user?.name}</div>
}
```

```typescript
// Client Component — use session hook
'use client'
import { useUser } from '@auth0/nextjs-auth0/client'

export function UserProfile() {
  const { user, isLoading } = useUser()
  if (isLoading) return <Spinner />
  if (!user) return <a href="/api/auth/login">Log in</a>
  return <div>{user.email}</div>
}
```

---

## Express API — token verification

```bash
npm install express-oauth2-jwt-bearer
```

```typescript
// src/middleware/auth.ts
import { auth } from 'express-oauth2-jwt-bearer'

export const requireAuth = auth({
  audience: process.env.AUTH0_AUDIENCE,
  issuerBaseURL: `https://${process.env.AUTH0_DOMAIN}`,
  tokenSigningAlg: 'RS256',
})
```

```typescript
// src/routes/orders.ts
import express from 'express'
import { requireAuth } from '../middleware/auth'
import { requireScope } from '../middleware/scope'

const router = express.Router()

router.get('/', requireAuth, async (req, res) => {
  // req.auth.payload.sub — verified user ID
  const userId = req.auth?.payload.sub
  const orders = await orderService.getByUser(userId)
  res.json({ success: true, data: orders })
})

router.delete('/:id', requireAuth, requireScope('delete:orders'), async (req, res) => {
  // Only users with delete:orders scope can reach here
  await orderService.delete(req.params.id)
  res.status(204).send()
})
```

```typescript
// src/middleware/scope.ts
import { Request, Response, NextFunction } from 'express'

export function requireScope(scope: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    const tokenScopes = (req.auth?.payload.scope as string ?? '').split(' ')
    if (!tokenScopes.includes(scope)) {
      return res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: `Required scope: ${scope}` },
      })
    }
    next()
  }
}
```

---

## Roles and permissions

Auth0 roles and permissions are managed in the dashboard or via the Management API.

**To include permissions in the access token:**
1. Go to APIs → your API → Settings → enable "RBAC" and "Add Permissions in the Access Token"
2. Assign roles to users in Users & Roles
3. Permissions appear as `scope` in the access token

**Add custom claims via an Auth0 Action:**

```javascript
// Auth0 Action — "Add custom claims to token"
// Trigger: Login / Post Login

exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://api.example.com'

  // Add user roles to access token
  if (event.authorization) {
    api.accessToken.setCustomClaim(`${namespace}/roles`, event.authorization.roles)
    api.idToken.setCustomClaim(`${namespace}/roles`, event.authorization.roles)
  }

  // Add org ID or other metadata
  api.accessToken.setCustomClaim(`${namespace}/orgId`, event.user.app_metadata?.orgId)
}
```

```typescript
// Server-side: read custom claims
const roles = decoded[`https://api.example.com/roles`] as string[]
if (!roles.includes('admin')) {
  throw new ForbiddenError('Admin role required')
}
```

---

## Machine-to-machine (M2M) tokens

For service-to-service communication (no user involved):

```typescript
// src/lib/auth0-m2m.ts
let cachedToken: { token: string; expiresAt: number } | null = null

export async function getM2MToken(): Promise<string> {
  // Return cached token if still valid (with 30s buffer)
  if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
    return cachedToken.token
  }

  const response = await fetch(`https://${process.env.AUTH0_DOMAIN}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type:    'client_credentials',
      client_id:     process.env.AUTH0_M2M_CLIENT_ID,
      client_secret: process.env.AUTH0_M2M_CLIENT_SECRET,
      audience:      process.env.AUTH0_AUDIENCE,
    }),
  })

  const data = await response.json()
  cachedToken = {
    token: data.access_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  }

  return cachedToken.token
}
```

---

## Management API — user management

```bash
npm install auth0
```

```typescript
// src/lib/auth0-management.ts
import { ManagementClient } from 'auth0'

const management = new ManagementClient({
  domain: process.env.AUTH0_DOMAIN!,
  clientId: process.env.AUTH0_MGMT_CLIENT_ID!,
  clientSecret: process.env.AUTH0_MGMT_CLIENT_SECRET!,
})

// Assign a role to a user
export async function assignRole(userId: string, roleId: string) {
  await management.users.assignRoles({ id: userId }, { roles: [roleId] })
}

// Get user profile
export async function getUser(userId: string) {
  return management.users.get({ id: userId })
}

// Update user metadata
export async function updateUserMetadata(userId: string, metadata: object) {
  await management.users.update({ id: userId }, { app_metadata: metadata })
}
```

---

## Silent refresh (SPAs)

```typescript
// For SPAs — refresh the access token silently before it expires
import { useAuth0 } from '@auth0/auth0-react'

function ApiClient() {
  const { getAccessTokenSilently } = useAuth0()

  async function callApi() {
    try {
      const token = await getAccessTokenSilently({
        authorizationParams: {
          audience: process.env.REACT_APP_AUTH0_AUDIENCE,
        },
      })
      const res = await fetch('/api/v1/orders', {
        headers: { Authorization: `Bearer ${token}` },
      })
      return res.json()
    } catch (err) {
      // Token refresh failed — user needs to log in again
      loginWithRedirect()
    }
  }
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Sending the ID token to your API | Use the access token — the ID token is for the client only |
| Not checking `aud` claim | Verify `audience === process.env.AUTH0_AUDIENCE` |
| Not caching M2M tokens | Cache until near-expiry — each token request costs time |
| Storing tokens in localStorage | Use in-memory; Auth0 SDK handles token storage via cookies |
| Roles not appearing in the token | Add an Auth0 Action to include roles in the token claims |
| Management API client exposed client-side | Management API credentials are server-only — never in browser code |
