# Vercel Standards

---

## vercel.json

```json
{
  "version": 2,
  "$schema": "https://openapi.vercel.sh/vercel.json",

  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "devCommand": "npm run dev",
  "installCommand": "npm ci",

  "regions": ["iad1"],

  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options",    "value": "nosniff" },
        { "key": "X-Frame-Options",            "value": "DENY" },
        { "key": "X-XSS-Protection",           "value": "1; mode=block" },
        { "key": "Referrer-Policy",            "value": "strict-origin-when-cross-origin" },
        { "key": "Permissions-Policy",         "value": "camera=(), microphone=(), geolocation=()" }
      ]
    },
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "no-store" }
      ]
    }
  ],

  "rewrites": [
    {
      "source": "/api/:path*",
      "destination": "https://api.example.com/:path*"
    }
  ],

  "functions": {
    "api/**/*.ts": {
      "maxDuration": 30,
      "memory": 512
    }
  }
}
```

---

## Environment variables

```bash
# Add via CLI (preferred for scripting / CI setup)
vercel env add DATABASE_URL production
vercel env add DATABASE_URL preview
vercel env add DATABASE_URL development

# Pull env vars to local .env.local (for development)
vercel env pull .env.local

# List all env vars
vercel env ls
```

**Environment scopes:**
| Scope | When used | Where to set |
|---|---|---|
| `production` | Main branch deploys | Dashboard: Settings → Environment Variables |
| `preview` | PR and branch deploys | Dashboard: Settings → Environment Variables |
| `development` | `vercel dev` local | Dashboard or `vercel env add ... development` |

**In code:**
```typescript
// All environments
const apiUrl = process.env.API_URL

// Next.js — expose to browser (bundled at build time)
const publicKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY

// Check which environment
const isPreview = process.env.VERCEL_ENV === 'preview'
const isProduction = process.env.VERCEL_ENV === 'production'
```

**Vercel-provided variables (always available):**
```
VERCEL                 = "1"
VERCEL_ENV             = "development" | "preview" | "production"
VERCEL_URL             = auto-generated deployment URL (no protocol)
VERCEL_BRANCH_URL      = branch-specific URL
VERCEL_GIT_COMMIT_SHA  = commit SHA that triggered the deploy
```

---

## Rewrites vs Redirects

```json
{
  "rewrites": [
    {
      "source": "/api/:path*",
      "destination": "https://backend.example.com/:path*"
    },
    {
      "source": "/((?!api).*)",
      "destination": "/index.html"
    }
  ],
  "redirects": [
    {
      "source": "/old-page",
      "destination": "/new-page",
      "permanent": true
    }
  ]
}
```

| Feature | `rewrites` | `redirects` |
|---|---|---|
| Browser URL changes | ❌ No | ✅ Yes |
| Use for | API proxy, SPA fallback | SEO redirects, URL changes |
| HTTP status | 200 (proxied) | 301 (permanent) or 302 (temporary) |

---

## Serverless functions

```typescript
// api/hello.ts — Vercel Serverless Function
import type { VercelRequest, VercelResponse } from '@vercel/node'

export default function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }
  res.status(200).json({ message: 'Hello world' })
}
```

**Limitations:**
- Default timeout: 10s (Pro: up to 300s, set via `maxDuration`)
- Cold starts: ~100-300ms for Node.js functions
- Max payload: 4.5MB request/response
- No persistent connections — open and close DB connections per invocation (use connection pooling: PgBouncer, Prisma Accelerate)

---

## Edge functions

```typescript
// middleware.ts (Next.js) — runs at the edge before every request
import { NextRequest, NextResponse } from 'next/server'

export function middleware(request: NextRequest) {
  // Auth check at the edge — no latency from DB calls
  const token = request.cookies.get('auth_token')

  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*', '/api/protected/:path*'],
}
```

**Edge Runtime is NOT for:**
- Database queries (no persistent TCP connections)
- File system access
- Node.js built-ins (`crypto`, `net`, `fs`) — use Web Crypto API instead

**Edge Runtime IS for:**
- Auth middleware (JWT verification)
- A/B testing (cookie-based splits)
- Geolocation-based routing
- Rate limiting (use Vercel KV for state)

---

## ISR — Incremental Static Regeneration

```typescript
// Next.js App Router — ISR with revalidation
export const revalidate = 60  // revalidate every 60 seconds

export default async function Page() {
  const data = await fetchData()
  return <Component data={data} />
}
```

```typescript
// On-demand revalidation
import { revalidatePath, revalidateTag } from 'next/cache'

// Call from an API route or Server Action when data changes
export async function updateProduct(id: string) {
  await db.update(id)
  revalidatePath(`/products/${id}`)  // clears ISR cache for this path
  revalidateTag('products')          // clears all pages tagged 'products'
}
```

| Strategy | Use when |
|---|---|
| `revalidate = 0` | Real-time data (SSR every request) |
| `revalidate = 60` | Data changes occasionally (product pages) |
| `revalidate = 3600` | Data rarely changes (blog posts) |
| `export const dynamic = 'force-static'` | Data never changes (marketing pages) |

---

## Preview deployments

Every push to a branch gets a unique preview URL: `https://myapp-<hash>-org.vercel.app`

```typescript
// Scope behaviour to preview deployments
if (process.env.VERCEL_ENV === 'preview') {
  // Use staging API, not production
  // Enable debug logging
  // Disable analytics
}
```

**Set up GitHub integration:**
- Vercel app automatically comments preview URL on PRs
- Add preview URL to PR template so reviewers can test

```
# Pull Request

## Preview
[Open preview deployment](https://vercel.com/project/deployments)
```

---

## Deployment commands

```bash
# Deploy to preview (current branch)
vercel

# Deploy to production
vercel --prod

# Check deployment status
vercel ls

# Inspect a deployment
vercel inspect <deployment-url>

# Roll back to previous deployment
vercel rollback

# View logs
vercel logs <deployment-url>
```
