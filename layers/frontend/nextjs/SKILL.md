---
name: nextjs
description: Next.js 15 standards — App Router, Server Components, async request APIs, caching, Server Actions, route handlers, metadata. Load when working with Next.js.
user-invocable: false
stack: frontend/nextjs
paths:
  - "app/**"
  - "src/app/**"
  - "pages/**"
  - "src/pages/**"
  - "next.config*"
  - "middleware.{ts,js}"
  - "src/middleware.{ts,js}"
  - "**/layout.tsx"
  - "**/page.tsx"
---

Full standards in [nextjs.md](nextjs.md). Always-on summary (Next.js 15, App Router):

- **Server Components by default.** Add `'use client'` only for hooks, events or browser APIs, and push it to the smallest component.
- **Await request APIs.** `params`, `searchParams`, `cookies()`, `headers()` and `draftMode()` are promises: `const { id } = await params`.
- **Caching is opt-in.** `fetch` and GET route handlers are not cached by default. Opt in with `cache: 'force-cache'`, `next: { revalidate: N }` or `export const revalidate = N`.
- **Fetch in the page's Server Component**, in parallel with `Promise.all`. No `useEffect` + `fetch` for server data.
- **Server Actions are public endpoints.** Validate input and check auth at the top, then `revalidatePath()` / `revalidateTag()`. Use `useActionState` for form state.
- **Route handlers** (`app/api/**/route.ts`) are for webhooks and external callers, not for your own pages.
- **Metadata API** (`metadata` / `generateMetadata`), never manual `<head>` tags.
- **Never** pass secrets to Client Components, or use `getServerSideProps` / `getStaticProps` inside `app/`.
