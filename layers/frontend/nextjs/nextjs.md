# Next.js standards (v15, App Router)

Short rules for Next.js apps. When the project is on the Pages Router, see section 9.

## 1. Server and Client Components

- Every component in `app/` is a Server Component unless the file starts with `'use client'`.
- Server Components can be `async`, read the database and use secrets. They send no JS to the browser.
- Add `'use client'` only when a component needs state, effects, event handlers or browser APIs. Put it on the smallest leaf (a button, not the page).
- Props passed from a Server to a Client Component must be serialisable, and must never contain secrets.
- A Client Component can render Server Components passed in as `children`.

## 2. Request APIs are async (Next.js 15)

`params`, `searchParams`, `cookies()`, `headers()` and `draftMode()` return promises. Await them:

```tsx
// app/products/[id]/page.tsx
type Props = { params: Promise<{ id: string }>; searchParams: Promise<{ tab?: string }> };

export default async function ProductPage({ params, searchParams }: Props) {
  const { id } = await params;
  const { tab = 'details' } = await searchParams;
  const product = await getProduct(id);
  if (!product) notFound();
  return <Product product={product} tab={tab} />;
}
```

In a Client Component, unwrap them with `use(params)`, or use `useParams()` / `useSearchParams()`.

## 3. Data fetching and caching

- Fetch in the Server Component that needs the data: the page, not the layout.
- Run independent requests in parallel: `const [a, b] = await Promise.all([getA(), getB()])`.
- Nothing is cached by default in Next.js 15. Choose per request:

| Need | Write |
|---|---|
| Always fresh | Default (or `cache: 'no-store'`) |
| Static until redeploy | `fetch(url, { cache: 'force-cache' })` |
| Refresh every N seconds | `fetch(url, { next: { revalidate: N } })` or `export const revalidate = N` |
| Invalidate on demand | `fetch(url, { next: { tags: ['products'] } })` + `revalidateTag('products')` |
| Cache a DB query | `unstable_cache(fn, keys, { tags, revalidate })` |

- Wrap slow parts in `<Suspense>` (or add `loading.tsx`) so the rest of the page streams first.
- Use `after(() => ...)` for work that shouldn't delay the response (logging, analytics).

## 4. Server Actions

- Use them for form submissions and mutations from your own UI.
- They are public HTTP endpoints. Always, at the top: check auth, then validate input (Zod).
- After a write, call `revalidatePath()` or `revalidateTag()`, or `redirect()`.
- Use `useActionState` (React 19) for pending state and errors.

```ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';

const Input = z.object({ name: z.string().min(1), price: z.coerce.number().positive() });

export async function createProduct(_prev: unknown, formData: FormData) {
  const session = await auth();
  if (!session) return { error: 'Not signed in' };
  const parsed = Input.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: parsed.error.flatten().fieldErrors };
  await db.product.create({ data: parsed.data });
  revalidatePath('/products');
  return { error: null };
}
```

## 5. Route handlers

- `app/api/**/route.ts`, exporting `GET`, `POST`, etc. Return `Response` / `NextResponse`.
- Use them for webhooks, external clients and streaming. Your own pages call Server Actions or fetch data directly.
- GET handlers are not cached by default. Add `export const dynamic = 'force-static'` to cache one.

## 6. Layouts and special files

| File | Purpose |
|---|---|
| `layout.tsx` | Shared UI that persists across navigations. Server Component. |
| `loading.tsx` | Suspense fallback for the segment |
| `error.tsx` | Error boundary. Must be `'use client'`. |
| `not-found.tsx` | Rendered by `notFound()` |
| `route.ts` | API endpoint (no `page.tsx` in the same folder) |

## 7. Metadata and SEO

- Export `metadata` or `async generateMetadata({ params })` from `layout.tsx` / `page.tsx`.
- Never write `<head>` tags by hand. Add `sitemap.ts` and `robots.ts` in `app/`.
- Use `next/image` for images (with `alt`), `next/font` for fonts, `next/link` for internal links.

## 8. Middleware and config

- `middleware.ts` runs on every matched request: keep it to redirects, rewrites and auth gating. Set `config.matcher` so it skips static files.
- Middleware is not the only auth check. Check again where the data is read.
- Keep `next.config.ts` typed (`NextConfig`). Set security headers there.
- Env vars: only `NEXT_PUBLIC_*` reaches the browser.

## 9. Pages Router (`pages/`)

- Sections 2–5 do not apply. Use `getServerSideProps` / `getStaticProps` (with `revalidate`) and `pages/api/*` handlers.
- Never mix the two data models in one route: no `getServerSideProps` in `app/`, no Server Actions in `pages/`.
- For new routes in a mixed project, prefer `app/`.

## Never

- `'use client'` on pages or layouts to make one button work.
- Reading `params.id` without awaiting `params` (Next.js 15).
- Assuming `fetch` is cached; say what you want.
- A Server Action without auth and input validation.
- Secrets in Client Components or `NEXT_PUBLIC_*` variables.
- Fetching page data in `layout.tsx`.
