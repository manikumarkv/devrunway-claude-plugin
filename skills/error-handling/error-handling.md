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

### Centralized error handler — handles every exception type

The error handler is the single place all errors are converted to the standard API response envelope. It must handle every known error type explicitly. Unknown errors must never leak internals.

```ts
// src/middleware/errorHandler.ts
import { type Request, type Response, type NextFunction } from 'express'
import { ZodError } from 'zod'
import { Prisma } from '@prisma/client'
import { TokenExpiredError, JsonWebTokenError } from 'jsonwebtoken'
import { MulterError } from 'multer'
import * as Sentry from '@sentry/node'
import { AppError } from '../errors'
import { logger } from '../lib/logger'
import { errorResponse } from '../lib/response'

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {

  // ─── 1. Zod validation error ────────────────────────────────────────────────
  // Thrown by schema.parse() in controllers or validate middleware
  if (err instanceof ZodError) {
    const details = err.errors.reduce<Record<string, string>>((acc, issue) => {
      acc[issue.path.join('.')] = issue.message
      return acc
    }, {})
    logger.warn({ path: req.path, details }, 'Validation failed')
    return errorResponse(req, res, 400, 'VALIDATION_ERROR', 'Validation failed', details)
  }

  // ─── 2. Malformed JSON body ──────────────────────────────────────────────────
  // express.json() throws SyntaxError when the body is not valid JSON
  if (err instanceof SyntaxError && 'body' in err) {
    return errorResponse(req, res, 400, 'MALFORMED_JSON', 'Request body is not valid JSON')
  }

  // ─── 3. JWT errors ───────────────────────────────────────────────────────────
  // jsonwebtoken throws these when verifying tokens manually
  if (err instanceof TokenExpiredError) {
    return errorResponse(req, res, 401, 'TOKEN_EXPIRED', 'Your session has expired. Please sign in again.')
  }
  if (err instanceof JsonWebTokenError) {
    return errorResponse(req, res, 401, 'INVALID_TOKEN', 'Invalid authentication token.')
  }

  // ─── 4. Prisma known request errors ─────────────────────────────────────────
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002':   // Unique constraint violation
        return errorResponse(req, res, 409, 'CONFLICT',
          'A record with this value already exists.')

      case 'P2025':   // Record not found (update/delete on non-existent row)
        return errorResponse(req, res, 404, 'NOT_FOUND', 'Record not found.')

      case 'P2003':   // Foreign key constraint violation
        return errorResponse(req, res, 409, 'FOREIGN_KEY_VIOLATION',
          'This record is referenced by another record and cannot be deleted.')

      case 'P2014':   // Required relation violation
        return errorResponse(req, res, 400, 'RELATION_VIOLATION',
          'The change violates a required relation.')

      case 'P2021':   // Table not found — migration not applied
        logger.error({ err }, 'Prisma: table not found — run prisma migrate deploy')
        Sentry.captureException(err)
        return errorResponse(req, res, 500, 'INTERNAL_ERROR', 'A database error occurred.')

      default:
        logger.error({ err, code: err.code }, 'Prisma known error (unmapped)')
        Sentry.captureException(err)
        return errorResponse(req, res, 500, 'INTERNAL_ERROR', 'A database error occurred.')
    }
  }

  // ─── 5. Prisma validation error (schema mismatch) ────────────────────────────
  if (err instanceof Prisma.PrismaClientValidationError) {
    logger.error({ err }, 'Prisma validation error — likely a bug in query construction')
    Sentry.captureException(err)
    return errorResponse(req, res, 500, 'INTERNAL_ERROR', 'A database error occurred.')
  }

  // ─── 6. Prisma connection / timeout errors ───────────────────────────────────
  if (err instanceof Prisma.PrismaClientInitializationError ||
      err instanceof Prisma.PrismaClientRustPanicError) {
    logger.error({ err }, 'Prisma connection/panic error')
    Sentry.captureException(err)
    return errorResponse(req, res, 503, 'SERVICE_UNAVAILABLE', 'Database is temporarily unavailable.')
  }

  // ─── 7. Multer file upload errors ────────────────────────────────────────────
  if (err instanceof MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return errorResponse(req, res, 413, 'FILE_TOO_LARGE',
        `File size exceeds the ${process.env.MAX_UPLOAD_MB ?? 10} MB limit.`)
    }
    if (err.code === 'LIMIT_UNEXPECTED_FILE') {
      return errorResponse(req, res, 400, 'UNEXPECTED_FILE', `Unexpected file field: ${err.field}`)
    }
    return errorResponse(req, res, 400, 'UPLOAD_ERROR', err.message)
  }

  // ─── 8. Rate limit error (express-rate-limit) ────────────────────────────────
  // express-rate-limit sets err.status = 429 when limit is exceeded
  if (typeof err === 'object' && err !== null && (err as any).status === 429) {
    return errorResponse(req, res, 429, 'RATE_LIMITED',
      'Too many requests. Please wait before trying again.')
  }

  // ─── 9. Our own AppError subclasses ──────────────────────────────────────────
  if (err instanceof AppError) {
    const logFn = err.statusCode >= 500 ? logger.error : logger.warn
    logFn.call(logger,
      { err, requestId: req.headers['x-request-id'], path: req.path },
      err.message,
    )
    if (err.statusCode >= 500) Sentry.captureException(err)

    return errorResponse(
      req, res,
      err.statusCode,
      err.code,
      err.message,
      err.details as Record<string, string> | undefined,
    )
  }

  // ─── 10. Unknown / unexpected errors ─────────────────────────────────────────
  // Never leak internals. Log fully, return generic message.
  logger.error(
    { err, requestId: req.headers['x-request-id'], path: req.path, method: req.method },
    'Unhandled error',
  )
  Sentry.captureException(err)

  return errorResponse(req, res, 500, 'INTERNAL_ERROR',
    'An unexpected error occurred. Our team has been notified.')
}
```

### 404 route not found handler

Mount this BEFORE `errorHandler` and AFTER all routes. Catches requests to unknown paths.

```ts
// src/app.ts
import { notFoundHandler } from './middleware/notFoundHandler'
import { errorHandler } from './middleware/errorHandler'

app.use('/api/v1', routes)

// Must be after all routes — catches anything that didn't match
app.use(notFoundHandler)
app.use(errorHandler)
```

```ts
// src/middleware/notFoundHandler.ts
import { type Request, type Response, type NextFunction } from 'express'

export function notFoundHandler(req: Request, res: Response, _next: NextFunction): void {
  res.status(404).json({
    success: false,
    error: {
      code:    'ROUTE_NOT_FOUND',
      message: `Cannot ${req.method} ${req.path}`,
      path:    req.path,
    },
    meta: {
      requestId: req.headers['x-request-id'] as string,
      timestamp: new Date().toISOString(),
      version:   'v1',
    },
  })
}
```

### Process-level handlers — unhandled rejections and exceptions

Register these in `handler.ts` (Lambda entry point). They are the last safety net.

```ts
// src/handler.ts
import { logger } from './lib/logger'
import * as Sentry from '@sentry/node'

// Catch promises that rejected without a .catch() handler
process.on('unhandledRejection', (reason, promise) => {
  logger.error({ reason, promise }, 'Unhandled promise rejection')
  Sentry.captureException(reason)
  // Do NOT process.exit() in Lambda — let the invocation fail, Lambda will retry
})

// Catch synchronous throws that were never caught
process.on('uncaughtException', (err) => {
  logger.error({ err }, 'Uncaught exception')
  Sentry.captureException(err)
  // In Lambda context this is fatal — let it surface
})
```

### All Prisma error codes — reference

| Code | Cause | HTTP |
|---|---|---|
| `P2002` | Unique constraint violation | 409 Conflict |
| `P2003` | Foreign key constraint violation | 409 Conflict |
| `P2014` | Required relation violation | 400 Bad Request |
| `P2025` | Record not found (update/delete) | 404 Not Found |
| `P2021` | Table does not exist — migration missing | 500 Internal |
| `P2034` | Transaction conflict / deadlock | 503 Retry |
| `P1001` | DB unreachable | 503 Service Unavailable |
| `P1008` | Operation timed out | 503 Service Unavailable |

```ts
// src/app.ts — full correct order
import express from 'express'
import { json } from 'express'
import { requestId } from './middleware/requestId'
import { pinoHttp } from 'pino-http'
import { logger } from './lib/logger'
import { mountRoutes } from './routes'
import { notFoundHandler } from './middleware/notFoundHandler'
import { errorHandler } from './middleware/errorHandler'

const app = express()

app.use(requestId)                // 1. attach x-request-id
app.use(pinoHttp({ logger }))     // 2. structured request logging
app.use(json({ limit: '10mb' }))  // 3. parse JSON body (throws SyntaxError on malform)
mountRoutes(app)                  // 4. all API routes
app.use(notFoundHandler)          // 5. catch unknown routes — BEFORE errorHandler
app.use(errorHandler)             // 6. convert all errors to standard envelope — LAST

export default app
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
