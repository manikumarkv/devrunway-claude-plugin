---
name: nextjs
description: Next.js App Router standards — Server Components, Server Actions, route handlers, metadata API, and performance patterns. Load when working with Next.js.
user-invocable: false
stack: frontend/nextjs
paths:
  - "app/**"
  - "src/app/**"
  - "next.config*"
  - "**/layout.tsx"
  - "**/page.tsx"
---

Full standards in [nextjs.md](nextjs.md). Always-on summary:

**Component model:**
- Server Components (default) — no `'use client'`, render on the server, can `async`, can access DB/secrets
- Client Components — `'use client'` directive required; used for interactivity, browser APIs, hooks
- Push `'use client'` boundary as far down the tree as possible — keep data-fetching Server Components

**Data fetching:**
- Fetch in Server Components directly — no `useEffect` + `fetch` for server data
- Use `cache: 'no-store'` for real-time data; `revalidate: N` for ISR; `cache: 'force-cache'` for static
- Deduplicate: Next.js `fetch` is memoised per request — the same URL within a render pass is fetched once

**Server Actions:**
- Use for form submissions and mutations — `'use server'` directive, called like async functions from the client
- Always validate input in Server Actions — they are API endpoints, even if they look like functions
- Use `revalidatePath()` or `revalidateTag()` to invalidate the cache after mutations

**Route Handlers:**
- `/app/api/*/route.ts` — for external consumers, webhooks, and streaming responses
- Export named functions: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`
- Always return `NextResponse` or `Response` — never `res.json()` (that's Pages Router)

**Layouts:**
- `layout.tsx` — shared UI that persists across navigations; no access to route-specific data
- `loading.tsx` — automatic Suspense boundary; shows while page.tsx is loading
- `error.tsx` — must be a Client Component; catches render errors in the segment

**Metadata:**
- Export `metadata` object or `generateMetadata()` from `page.tsx` and `layout.tsx`
- Never set `<head>` tags manually — use the Metadata API

**Never:**
- Fetch data in a `layout.tsx` that is needed by a specific `page.tsx` — fetch in the page
- Use legacy Pages Router data fetching functions in the App Router — App Router uses `async` Server Components for data fetching instead
- Put secrets in Client Components or pass them as props from Server to Client Components

**Related skills:** `state/redux-toolkit` (client state), `ui-components/mui` or `css/tailwind` (styling), `validation/zod`
