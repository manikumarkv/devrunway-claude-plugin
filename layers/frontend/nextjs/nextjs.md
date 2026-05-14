# Next.js App Router Standards

---

## Project structure

```
src/
  app/
    layout.tsx           ← root layout — ThemeProvider, auth context, fonts
    page.tsx             ← homepage
    loading.tsx          ← root loading UI (optional)
    error.tsx            ← root error boundary (must be 'use client')
    not-found.tsx        ← 404 page
    globals.css

    (marketing)/         ← route group (no URL segment)
      about/page.tsx
      pricing/page.tsx

    (app)/               ← authenticated app shell
      layout.tsx         ← auth check, sidebar, header
      dashboard/
        page.tsx
        loading.tsx
      orders/
        page.tsx
        [id]/
          page.tsx
          edit/page.tsx

    api/
      webhooks/
        stripe/route.ts  ← webhook handler (external)
      auth/[...nextauth]/route.ts

  components/            ← shared Client Components
  lib/                   ← utilities, DB client, auth helpers
  actions/               ← Server Actions
  types/
```

---

## Server Components (default)

```tsx
// app/orders/page.tsx — Server Component (no 'use client')
import { getOrders } from '@/lib/orders'
import { OrderList } from '@/components/OrderList'
import { getCurrentUser } from '@/lib/auth'
import { redirect } from 'next/navigation'

// generateMetadata — SEO
export const metadata = {
  title:       'Orders | MyApp',
  description: 'View and manage your orders',
}

export default async function OrdersPage({
  searchParams,
}: {
  searchParams: { status?: string; page?: string }
}) {
  const user = await getCurrentUser()
  if (!user) redirect('/login')

  const orders = await getOrders({
    userId: user.id,
    status: searchParams.status,
    page:   Number(searchParams.page ?? 1),
  })

  return (
    <main>
      <h1>Your Orders</h1>
      {/* OrderList is a Client Component if it needs interactivity */}
      <OrderList initialOrders={orders} />
    </main>
  )
}
```

---

## Client Components

```tsx
// src/components/OrderList.tsx
'use client'

import { useState } from 'react'
import type { Order } from '@/types'

interface Props {
  initialOrders: Order[]
}

// Keep 'use client' boundary as far down the tree as possible
export function OrderList({ initialOrders }: Props) {
  const [orders, setOrders] = useState(initialOrders)
  const [selectedId, setSelectedId] = useState<string | null>(null)

  return (
    <ul>
      {orders.map((order) => (
        <li
          key={order.id}
          onClick={() => setSelectedId(order.id)}
          aria-selected={selectedId === order.id}
        >
          Order #{order.id} — {order.status}
        </li>
      ))}
    </ul>
  )
}
```

---

## Data fetching patterns

```tsx
// Real-time data (no cache)
async function getOrder(id: string) {
  const res = await fetch(`/api/orders/${id}`, { cache: 'no-store' })
  if (!res.ok) throw new Error('Failed to fetch order')
  return res.json()
}

// Revalidated data (ISR — fresh every 60 seconds)
async function getProducts() {
  const res = await fetch('/api/products', { next: { revalidate: 60 } })
  return res.json()
}

// Static data (build-time, never stale)
async function getConfig() {
  const res = await fetch('/api/config', { cache: 'force-cache' })
  return res.json()
}

// Tag-based revalidation (invalidate on demand)
async function getOrderById(id: string) {
  const res = await fetch(`/api/orders/${id}`, {
    next: { tags: [`order-${id}`] },
  })
  return res.json()
}

// Deduplication: same URL fetched multiple times in one render = one HTTP request
async function UserAvatar() {
  const user = await getUser()  // safe to call in multiple components
  return <img src={user.avatar} alt={user.name} />
}
```

---

## Parallel data fetching

```tsx
// ❌ Sequential — each awaits the previous
const user    = await getUser(id)
const orders  = await getOrders(user.id)

// ✅ Parallel — start both simultaneously
const [user, orders] = await Promise.all([
  getUser(id),
  getOrders(id),
])
```

---

## Server Actions

```typescript
// src/actions/orders.ts
'use server'

import { revalidatePath, revalidateTag } from 'next/cache'
import { redirect } from 'next/navigation'
import { getCurrentUser } from '@/lib/auth'
import { createOrderSchema } from '@/lib/schemas'
import { db } from '@/lib/db'

export async function createOrder(formData: FormData) {
  // 1. Auth check — Server Actions are API endpoints
  const user = await getCurrentUser()
  if (!user) throw new Error('Unauthorised')

  // 2. Validate input — never trust FormData
  const raw = Object.fromEntries(formData)
  const parsed = createOrderSchema.safeParse(raw)
  if (!parsed.success) {
    return { error: parsed.error.flatten().fieldErrors }
  }

  // 3. Perform mutation
  const order = await db.orders.create({
    data: { ...parsed.data, userId: user.id },
  })

  // 4. Invalidate cache
  revalidatePath('/orders')
  revalidateTag(`user-${user.id}-orders`)

  // 5. Redirect to new resource
  redirect(`/orders/${order.id}`)
}
```

```tsx
// Using a Server Action in a form (no JS needed for basic submit)
import { createOrder } from '@/actions/orders'

export function CreateOrderForm() {
  return (
    <form action={createOrder}>
      <input name="customerId" required />
      <input name="total" type="number" required />
      <button type="submit">Create Order</button>
    </form>
  )
}

// Using with useActionState for error display (React 19 / Next.js 14.3+)
'use client'
import { useActionState } from 'react'
import { createOrder } from '@/actions/orders'

export function CreateOrderForm() {
  const [state, action, isPending] = useActionState(createOrder, null)

  return (
    <form action={action}>
      <input name="customerId" required />
      {state?.error?.customerId && <p>{state.error.customerId[0]}</p>}
      <button type="submit" disabled={isPending}>
        {isPending ? 'Creating…' : 'Create Order'}
      </button>
    </form>
  )
}
```

---

## Route Handlers

```typescript
// src/app/api/orders/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { getCurrentUser } from '@/lib/auth'
import { db } from '@/lib/db'

export async function GET(request: NextRequest) {
  const user = await getCurrentUser()
  if (!user) return NextResponse.json({ error: 'Unauthorised' }, { status: 401 })

  const { searchParams } = new URL(request.url)
  const status = searchParams.get('status')

  const orders = await db.orders.findMany({
    where: { userId: user.id, ...(status && { status }) },
    orderBy: { createdAt: 'desc' },
  })

  return NextResponse.json({ data: orders })
}

// src/app/api/orders/[id]/route.ts
export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const user = await getCurrentUser()
  if (!user) return NextResponse.json({ error: 'Unauthorised' }, { status: 401 })

  const body = await request.json()

  const order = await db.orders.update({
    where: { id: params.id, userId: user.id },
    data:  body,
  })

  return NextResponse.json({ data: order })
}
```

---

## Layouts and loading states

```tsx
// src/app/(app)/layout.tsx — authenticated layout
import { getCurrentUser } from '@/lib/auth'
import { redirect } from 'next/navigation'
import { Sidebar } from '@/components/Sidebar'

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser()
  if (!user) redirect('/login')

  return (
    <div className="flex h-screen">
      <Sidebar user={user} />
      <main className="flex-1 overflow-auto p-6">{children}</main>
    </div>
  )
}
```

```tsx
// src/app/(app)/orders/loading.tsx — automatic Suspense boundary
export default function Loading() {
  return (
    <div>
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="skeleton h-16 mb-2 rounded" />
      ))}
    </div>
  )
}
```

```tsx
// src/app/(app)/orders/error.tsx — must be a Client Component
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <p>{error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

---

## Metadata API

```typescript
// Static metadata
export const metadata = {
  title:       'Orders',
  description: 'View and manage your orders',
  openGraph: {
    title:       'Orders | MyApp',
    description: 'View and manage your orders',
    images:      ['/og-image.png'],
  },
}

// Dynamic metadata (e.g., for a product page)
export async function generateMetadata(
  { params }: { params: { id: string } }
): Promise<Metadata> {
  const order = await getOrder(params.id)

  return {
    title:       `Order #${order.id}`,
    description: `View order details for #${order.id}`,
  }
}
```

---

## Middleware

```typescript
// src/middleware.ts — runs on the Edge before every request
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { verifyToken } from './lib/auth'

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Public routes — no auth needed
  if (pathname.startsWith('/login') || pathname.startsWith('/api/webhooks')) {
    return NextResponse.next()
  }

  const token = request.cookies.get('auth-token')?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  try {
    const payload = await verifyToken(token)
    // Pass user info to headers for Server Components
    const response = NextResponse.next()
    response.headers.set('x-user-id', payload.sub)
    return response
  } catch {
    return NextResponse.redirect(new URL('/login', request.url))
  }
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
```

---

## next.config.ts

```typescript
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'your-cdn.com' },
    ],
  },
  experimental: {
    serverActions: { allowedOrigins: ['localhost:3000'] },
  },
  // Security headers
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options',  value: 'nosniff' },
          { key: 'X-Frame-Options',          value: 'DENY' },
          { key: 'Referrer-Policy',          value: 'strict-origin-when-cross-origin' },
        ],
      },
    ]
  },
}

export default nextConfig
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `'use client'` on every component | Default is Server Component — only add `'use client'` when you need hooks/events |
| Fetching data in `layout.tsx` for a specific page | Fetch in `page.tsx` — layouts don't know which page will render |
| `useEffect` + `fetch` in a Server Component | Server Components are async — `await fetch()` directly |
| `getServerSideProps` in the App Router | Not supported — fetch in Server Components instead |
| Passing secrets as props to Client Components | Secrets stay in Server Components — never cross the server/client boundary |
| `<head>` tags in JSX | Use the Metadata API — `export const metadata = { ... }` |
| Sequential awaits for independent data | Use `Promise.all()` for parallel fetching |
| Not checking auth in Server Actions | Server Actions are API endpoints — always auth-check at the top |
