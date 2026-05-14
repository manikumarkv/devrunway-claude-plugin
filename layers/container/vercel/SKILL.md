---
name: vercel
description: Vercel deployment conventions — vercel.json, environment variables, rewrites, ISR, Edge functions, and preview deployments. Load when working with vercel.json or deploying to Vercel.
user-invocable: false
stack: container/vercel
paths:
  - "vercel.json"
  - ".vercel/**"
---

Full standards in [vercel.md](vercel.md). Always-on summary:

**vercel.json:**
- `rewrites` for API proxying and SPA fallbacks — not `redirects` unless you intend a browser redirect
- `headers` for security headers (CSP, HSTS, X-Frame-Options) — set these, they are not defaults
- `functions` to configure max duration and memory per route
- `regions` to pin to a specific Vercel edge region (default is `iad1`)

**Environment variables:**
- Set via Vercel dashboard or `vercel env add` — never in `vercel.json`
- `NEXT_PUBLIC_` prefix exposes a var to the browser bundle in Next.js
- Separate variable sets for `development`, `preview`, and `production` environments

**Performance:**
- ISR (Incremental Static Regeneration) via `revalidate` — prefer over SSR for pages that don't need real-time data
- Edge functions run at the CDN edge — use for auth middleware, A/B testing, geolocation; not for DB queries
- Serverless functions have a 10s default timeout (`maxDuration` up to 300s on Pro)

**Preview deployments:**
- Every PR gets a unique preview URL — use `VERCEL_ENV === 'preview'` to scope behaviour
- Add preview deployment URL to PR description via GitHub integration

**Never:**
- Commit `.vercel/` directory
- Put secrets in `vercel.json` `env` block — use the dashboard or `vercel env add`
- Use Edge Runtime for operations requiring Node.js built-ins (fs, crypto, net)

**Related skills:** Your frontend layer (Next.js / React), `secrets/env-only`
