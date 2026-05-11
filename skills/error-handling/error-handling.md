# Error Handling Standards

---

## Backend

### Custom error classes

One base class, purpose-built subclasses. Never throw raw `new Error()` in business logic.

```ts
// src/utils/errors.ts

export class AppError extends Error {
  constructor(
    public readonly message: string,
    public readonly statusCode: number,
    public readonly code: string,         // machine-readable, sent to client
    public readonly details?: unknown,    // field errors, extra context
  ) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor)
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: unknown) {
    super(message, 400, 'VALIDATION_ERROR', details)
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id?: string) {
    super(
      id ? `${resource} with id "${id}" not found` : `${resource} not found`,
      404,
      'NOT_FOUND',
    )
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'UNAUTHORIZED')
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'You do not have permission to perform this action') {
    super(message, 403, 'FORBIDDEN')
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, 'CONFLICT')
  }
}

export class UnprocessableError extends AppError {
  constructor(message: string, details?: unknown) {
    super(message, 422, 'UNPROCESSABLE', details)
  }
}
```

---

### asyncHandler — no try/catch in controllers

```ts
// src/utils/asyncHandler.ts
import { type Request, type Response, type NextFunction, type RequestHandler } from 'express'

type AsyncFn = (req: Request, res: Response, next: NextFunction) => Promise<unknown>

export const asyncHandler = (fn: AsyncFn): RequestHandler =>
  (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next)
  }
```

```ts
// src/controllers/orders.controller.ts
import { asyncHandler } from '../utils/asyncHandler'
import { createOrderSchema } from '../types/orders.types'
import { orderService } from '../services/orders.service'

// ✅ No try/catch — asyncHandler forwards errors to errorHandler middleware
export const createOrder = asyncHandler(async (req, res) => {
  const body = createOrderSchema.parse(req.body)
  const order = await orderService.create(body, req.user)
  res.status(201).json({ success: true, data: order })
})

// ❌ Never — manual try/catch leaks internals and duplicates error formatting
export const createOrderBad = async (req: Request, res: Response) => {
  try {
    const order = await orderService.create(req.body, req.user)
    res.json(order)
  } catch (e) {
    res.status(500).json({ error: e.message })  // leaks stack/internals
  }
}
```

---

### Centralized error handler

```ts
// src/middleware/errorHandler.ts
import { type Request, type Response, type NextFunction } from 'express'
import { ZodError } from 'zod'
import { Prisma } from '@prisma/client'
import { AppError } from '../utils/errors'
import { logger } from '../lib/logger'

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
) {
  // Zod validation error — parse and return field-level messages
  if (err instanceof ZodError) {
    const details = err.errors.reduce<Record<string, string>>((acc, issue) => {
      acc[issue.path.join('.')] = issue.message
      return acc
    }, {})

    return res.status(400).json({
      error: {
        message: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details,
      },
    })
  }

  // Prisma known errors
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      return res.status(409).json({
        error: { message: 'A record with this value already exists', code: 'CONFLICT' },
      })
    }
    if (err.code === 'P2025') {
      return res.status(404).json({
        error: { message: 'Record not found', code: 'NOT_FOUND' },
      })
    }
  }

  // Our own AppError subclasses
  if (err instanceof AppError) {
    // Log 5xx as errors, 4xx as warnings
    const logFn = err.statusCode >= 500 ? logger.error.bind(logger) : logger.warn.bind(logger)
    logFn({ err, req: { method: req.method, url: req.url } }, err.message)

    return res.status(err.statusCode).json({
      error: {
        message: err.message,
        code: err.code,
        ...(err.details ? { details: err.details } : {}),
      },
    })
  }

  // Unknown/unexpected error — log and return generic message
  logger.error({ err, req: { method: req.method, url: req.url } }, 'Unhandled error')

  return res.status(500).json({
    error: {
      message: 'An unexpected error occurred',
      code: 'INTERNAL_ERROR',
    },
  })
}
```

```ts
// src/app.ts — error handler must be last
import { errorHandler } from './middleware/errorHandler'

app.use('/api/v1', routes)
app.use(errorHandler)          // after all routes
```

---

### Throwing errors in services

```ts
// src/services/orders.service.ts
import { NotFoundError, UnprocessableError, ForbiddenError } from '../utils/errors'

async function getOrder(id: string, userId: string): Promise<Order> {
  const order = await orderRepository.findById(id)

  if (!order) {
    throw new NotFoundError('Order', id)
  }

  if (order.userId !== userId) {
    throw new ForbiddenError('You do not own this order')
  }

  return order
}

async function create(input: CreateOrderInput, user: AuthUser): Promise<Order> {
  const product = await productRepository.findById(input.productId)

  if (!product) {
    throw new NotFoundError('Product', input.productId)
  }

  if (product.stock < input.quantity) {
    throw new UnprocessableError('Insufficient stock', {
      available: product.stock,
      requested: input.quantity,
    })
  }

  return orderRepository.create({ ...input, userId: user.sub })
}
```

---

### Response envelope — consistent shape

Every response follows this shape. Never deviate.

```ts
// Success
{ "success": true, "data": { ... } }

// Success with pagination
{ "success": true, "data": [...], "meta": { "nextCursor": "...", "total": 42 } }

// Error (from errorHandler)
{ "error": { "message": "...", "code": "NOT_FOUND", "details": { ... } } }
```

---

## Frontend

### ApiError class

```ts
// src/utils/errors.ts
export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly message: string,
    public readonly code: string,
    public readonly details?: Record<string, string>,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}
```

```ts
// src/lib/apiClient.ts
async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const session = await fetchAuthSession()
  const token = session.tokens?.accessToken.toString()

  const res = await fetch(`${import.meta.env.VITE_API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...options?.headers,
    },
  })

  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new ApiError(
      res.status,
      body.error?.message ?? 'Request failed',
      body.error?.code ?? 'UNKNOWN',
      body.error?.details,
    )
  }

  return res.json()
}
```

---

### React Query — default error handling

Set a global `onError` on the QueryClient. Every query and mutation gets it automatically.

```ts
// src/lib/queryClient.ts
import { QueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import * as Sentry from '@sentry/react'
import { ApiError } from '../utils/errors'

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error) => {
        // Don't retry 4xx errors — they won't fix themselves
        if (error instanceof ApiError && error.status < 500) return false
        return failureCount < 2
      },
      staleTime: 1000 * 60,        // 1 minute
    },
    mutations: {
      onError: (error) => {
        if (error instanceof ApiError) {
          // 401 — session expired, redirect to login
          if (error.status === 401) {
            window.location.href = '/login'
            return
          }
          // 4xx — user-facing message (they can fix it)
          if (error.status < 500) {
            toast.error(error.message)
            return
          }
        }
        // 5xx or network error — unexpected, report to Sentry
        Sentry.captureException(error)
        toast.error('Something went wrong. Please try again.')
      },
    },
  },
})
```

---

### Per-mutation error handling

Override global defaults when you need field-level feedback.

```ts
// src/features/orders/api/orders.api.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ApiError } from '@/utils/errors'

export function useCreateOrder() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (input: CreateOrderInput) =>
      apiClient.post<Order>('/api/v1/orders', input),

    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['orders'] })
    },

    // Override global onError — field-level errors handled in the form, not toast
    onError: undefined,
  })
}
```

```tsx
// src/features/orders/components/OrderForm/OrderForm.tsx
export function OrderForm() {
  const { register, handleSubmit, setError, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(createOrderSchema),
  })

  const { mutate, isPending } = useCreateOrder()

  function onSubmit(data: FormData) {
    mutate(data, {
      onError: (error) => {
        if (error instanceof ApiError && error.details) {
          // Map server field errors to form fields
          Object.entries(error.details).forEach(([field, message]) => {
            setError(field as keyof FormData, { message })
          })
          return
        }
        // Fallback for non-field errors
        toast.error(error.message)
      },
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label htmlFor="quantity">Quantity</label>
        <input id="quantity" type="number" {...register('quantity')} />
        {errors.quantity && (
          <p role="alert" className="text-red-600 text-sm">
            {errors.quantity.message}
          </p>
        )}
      </div>
      <button type="submit" disabled={isPending}>
        {isPending ? 'Creating...' : 'Create Order'}
      </button>
    </form>
  )
}
```

---

### Query errors — show in UI, not toast

```tsx
// src/features/orders/components/OrderList/OrderList.tsx
import { useOrders } from '../api/orders.api'
import { ApiError } from '@/utils/errors'

export function OrderList() {
  const { data, isLoading, error } = useOrders()

  if (isLoading) return <OrderListSkeleton />

  if (error) {
    // 404 is a normal state — not an error
    if (error instanceof ApiError && error.status === 404) {
      return <EmptyState message="No orders found." />
    }
    return (
      <div role="alert" className="text-red-600 p-4">
        Failed to load orders. <RetryButton />
      </div>
    )
  }

  return <ul>{data.map(order => <OrderRow key={order.id} order={order} />)}</ul>
}
```

---

### Error boundaries — granular, not one global

```tsx
// src/pages/OrdersPage.tsx
import { ErrorBoundary } from '@/components/ErrorBoundary'

export function OrdersPage() {
  return (
    <div>
      <PageHeader title="Orders" />

      {/* Each section has its own boundary — one failure doesn't blank the page */}
      <ErrorBoundary fallback={<p className="text-red-600">Failed to load orders.</p>}>
        <OrderList />
      </ErrorBoundary>

      <ErrorBoundary fallback={<p className="text-red-600">Failed to load summary.</p>}>
        <OrderSummaryWidget />
      </ErrorBoundary>
    </div>
  )
}
```

---

### When to use what

| Situation | Pattern |
|---|---|
| Form field validation failure (server) | `setError` via react-hook-form |
| Form field validation failure (client) | Zod + react-hook-form inline |
| Mutation failed (non-field, user can retry) | `toast.error` |
| Mutation failed (5xx / unexpected) | `toast.error` + `Sentry.captureException` |
| Query failed (render error) | Inline error UI with retry, NOT toast |
| Session expired (401) | Redirect to `/login` |
| Permission denied (403) | Inline message, NOT redirect |
| Resource not found (404) | Empty state or not-found page |

---

### Never

```ts
// ❌ Swallow errors silently
try {
  await doSomething()
} catch (_e) {}

// ❌ Expose internal error message to client (backend)
res.status(500).json({ error: err.message })

// ❌ Generic toast for everything including field errors
onError: (e) => toast.error('Something went wrong')

// ❌ try/catch in every Express controller
export const handler = async (req, res) => {
  try { ... } catch (e) { res.status(500)... }
}

// ❌ throw raw Error in service layer
throw new Error('Not found')  // use NotFoundError

// ❌ 404 treated as error in query UI
if (error) return <div>Error!</div>   // 404 should be empty state
```
