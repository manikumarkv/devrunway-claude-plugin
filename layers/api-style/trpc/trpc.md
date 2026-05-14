# tRPC Standards

---

## Setup (Next.js App Router)

```bash
npm install @trpc/server @trpc/client @trpc/react-query @tanstack/react-query zod
```

---

## tRPC instance and context

```typescript
// src/server/api/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server'
import { ZodError } from 'zod'
import superjson from 'superjson'
import { getCurrentUser } from '@/lib/auth'

// Context — created per request
export async function createTRPCContext(opts: { headers: Headers }) {
  const user = await getCurrentUser()
  return { user, headers: opts.headers }
}

type Context = Awaited<ReturnType<typeof createTRPCContext>>

// tRPC instance
const t = initTRPC.context<Context>().create({
  transformer: superjson,   // supports Date, Map, Set etc.
  errorFormatter: ({ shape, error }) => ({
    ...shape,
    data: {
      ...shape.data,
      // Include Zod validation details
      zodError: error.cause instanceof ZodError ? error.cause.flatten() : null,
    },
  }),
})

export const createTRPCRouter    = t.router
export const createCallerFactory = t.createCallerFactory

// ── Procedures ─────────────────────────────────────────────────────────────

export const publicProcedure = t.procedure

// Auth middleware
const enforceAuth = t.middleware(({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' })
  }
  return next({ ctx: { ...ctx, user: ctx.user } })
})

export const protectedProcedure = t.procedure.use(enforceAuth)

// Admin-only middleware
const enforceAdmin = enforceAuth.unstable_pipe(({ ctx, next }) => {
  if (ctx.user.role !== 'admin') {
    throw new TRPCError({ code: 'FORBIDDEN' })
  }
  return next({ ctx })
})

export const adminProcedure = t.procedure.use(enforceAdmin)
```

---

## Feature routers

```typescript
// src/server/api/routers/orders.ts
import { z } from 'zod'
import { createTRPCRouter, protectedProcedure } from '../trpc'
import { TRPCError } from '@trpc/server'
import { orderService } from '@/services/orders'

export const ordersRouter = createTRPCRouter({
  // Query — GET equivalent
  list: protectedProcedure
    .input(z.object({
      status:   z.enum(['pending', 'shipped', 'delivered']).optional(),
      cursor:   z.string().optional(),
      limit:    z.number().min(1).max(100).default(20),
    }))
    .query(async ({ input, ctx }) => {
      return orderService.list({
        userId: ctx.user.id,
        ...input,
      })
    }),

  byId: protectedProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const order = await orderService.getById(input.id)
      if (!order) throw new TRPCError({ code: 'NOT_FOUND', message: 'Order not found' })
      if (order.userId !== ctx.user.id && ctx.user.role !== 'admin') {
        throw new TRPCError({ code: 'FORBIDDEN' })
      }
      return order
    }),

  // Mutation — POST/PUT/DELETE equivalent
  create: protectedProcedure
    .input(z.object({
      items:    z.array(z.object({
        productId: z.string().uuid(),
        quantity:  z.number().int().min(1),
      })).min(1),
      notes:    z.string().max(500).optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      return orderService.create({ ...input, userId: ctx.user.id })
    }),

  cancel: protectedProcedure
    .input(z.object({ id: z.string().uuid(), reason: z.string().max(200) }))
    .mutation(async ({ input, ctx }) => {
      const order = await orderService.getById(input.id)
      if (!order) throw new TRPCError({ code: 'NOT_FOUND' })
      if (order.userId !== ctx.user.id) throw new TRPCError({ code: 'FORBIDDEN' })
      if (order.status !== 'pending') {
        throw new TRPCError({
          code:    'BAD_REQUEST',
          message: 'Only pending orders can be cancelled',
        })
      }
      return orderService.cancel(input.id, input.reason)
    }),
})
```

---

## Root router

```typescript
// src/server/api/root.ts
import { createTRPCRouter } from './trpc'
import { ordersRouter }   from './routers/orders'
import { usersRouter }    from './routers/users'
import { productsRouter } from './routers/products'

export const appRouter = createTRPCRouter({
  orders:   ordersRouter,
  users:    usersRouter,
  products: productsRouter,
})

// Export TYPE only — never the router instance
export type AppRouter = typeof appRouter
```

---

## Next.js handler

```typescript
// src/app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from '@trpc/server/adapters/fetch'
import { appRouter } from '@/server/api/root'
import { createTRPCContext } from '@/server/api/trpc'

function handler(req: Request) {
  return fetchRequestHandler({
    endpoint:    '/api/trpc',
    req,
    router:      appRouter,
    createContext: () => createTRPCContext({ headers: req.headers }),
    onError: process.env.NODE_ENV === 'development'
      ? ({ path, error }) => {
          console.error(`tRPC error on ${path}: ${error.message}`)
        }
      : undefined,
  })
}

export { handler as GET, handler as POST }
```

---

## Client setup (React Query)

```typescript
// src/trpc/react.tsx
'use client'

import { createTRPCReact } from '@trpc/react-query'
import type { AppRouter } from '@/server/api/root'

export const trpc = createTRPCReact<AppRouter>()
```

```tsx
// src/app/providers.tsx
'use client'

import { useState } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { httpBatchLink, loggerLink } from '@trpc/client'
import superjson from 'superjson'
import { trpc } from '@/trpc/react'
import { getAccessToken } from '@/lib/auth'

export function TRPCProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime:            60 * 1000,    // 1 minute
        refetchOnWindowFocus: false,
        retry:                1,
      },
    },
  }))

  const [trpcClient] = useState(() =>
    trpc.createClient({
      links: [
        loggerLink({ enabled: (opts) => process.env.NODE_ENV === 'development' }),
        httpBatchLink({
          url:         '/api/trpc',
          transformer: superjson,
          headers:     () => ({ authorization: `Bearer ${getAccessToken()}` }),
        }),
      ],
    })
  )

  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  )
}
```

---

## Using tRPC in components

```tsx
// Queries
import { trpc } from '@/trpc/react'

export function OrderList() {
  const { data, isLoading, error } = trpc.orders.list.useQuery({
    status: 'pending',
    limit:  20,
  })

  if (isLoading) return <Skeleton />
  if (error)     return <ErrorMessage message={error.message} />
  if (!data?.items.length) return <EmptyState />

  return <ul>{data.items.map((o) => <OrderCard key={o.id} order={o} />)}</ul>
}

// Mutations
export function CancelOrderButton({ orderId }: { orderId: string }) {
  const utils   = trpc.useUtils()
  const { mutate, isPending, error } = trpc.orders.cancel.useMutation({
    onSuccess: () => {
      // Invalidate related queries
      utils.orders.list.invalidate()
      utils.orders.byId.invalidate({ id: orderId })
    },
  })

  return (
    <button
      onClick={() => mutate({ id: orderId, reason: 'Customer request' })}
      disabled={isPending}
    >
      {isPending ? 'Cancelling…' : 'Cancel Order'}
    </button>
  )
}
```

---

## Server-side calls (Server Components)

```typescript
// src/app/orders/page.tsx — Server Component
import { createCaller } from '@/server/api/root'
import { createTRPCContext } from '@/server/api/trpc'
import { headers } from 'next/headers'

export default async function OrdersPage() {
  const context = await createTRPCContext({ headers: await headers() })
  const caller  = createCaller(context)

  // Type-safe server-side call — no HTTP round-trip
  const orders = await caller.orders.list({ limit: 20 })

  return <OrderList initialData={orders} />
}
```

---

## Error handling on the client

```typescript
import { TRPCClientError } from '@trpc/client'
import type { AppRouter } from '@/server/api/root'

function handleTRPCError(error: unknown) {
  if (error instanceof TRPCClientError<AppRouter>) {
    const code = error.data?.code

    switch (code) {
      case 'UNAUTHORIZED': return redirectToLogin()
      case 'FORBIDDEN':    return showAccessDenied()
      case 'NOT_FOUND':    return showNotFound()
      case 'BAD_REQUEST': {
        // Zod errors are available in error.data.zodError
        const fieldErrors = error.data?.zodError?.fieldErrors
        return showValidationErrors(fieldErrors)
      }
    }
  }
  throw error
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Exporting the router instance to the client | Export `type AppRouter = typeof appRouter` — not the instance |
| Procedures without `.input()` | All inputs require Zod validation — no untyped procedures |
| DB queries directly in procedures | Delegate to service functions — keeps procedures testable |
| Not using `utils.invalidate()` after mutations | Stale UI — always invalidate related queries after writes |
| Using `publicProcedure` for authenticated routes | Create `protectedProcedure` with auth middleware |
| `refetchOnWindowFocus: true` for server data | Can cause excessive requests — disable unless needed |
