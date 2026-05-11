# API Design Conventions

---

## Response envelope

Every response — success or error — is wrapped. Never return a bare array or object at the root.

```ts
// ✅ Single resource
{ "success": true, "data": { "id": "...", "status": "pending" } }

// ✅ Collection
{ "success": true, "data": [...], "meta": { "nextCursor": "abc123", "total": 84 } }

// ✅ Mutation with no meaningful return
{ "success": true }

// ✅ Error (from errorHandler — see error-handling skill)
{ "error": { "message": "Order not found", "code": "NOT_FOUND" } }

// ❌ Bare array — client can't add metadata later without breaking change
[{ "id": "..." }, { "id": "..." }]

// ❌ Bare object — no room to add "success" or pagination
{ "id": "...", "status": "pending" }

// ❌ 200 with error in body
{ "status": "error", "message": "Not found" }
```

**TypeScript helper:**

```ts
// src/utils/response.ts
import { type Response } from 'express'

export function ok<T>(res: Response, data: T, status = 200) {
  res.status(status).json({ success: true, data })
}

export function created<T>(res: Response, data: T) {
  res.status(201).json({ success: true, data })
}

export function noContent(res: Response) {
  res.status(204).end()
}

export function paginated<T>(
  res: Response,
  data: T[],
  meta: { nextCursor: string | null; total: number },
) {
  res.json({ success: true, data, meta })
}
```

```ts
// In controllers — always use helpers, never res.json() directly
export const getOrder = asyncHandler(async (req, res) => {
  const order = await orderService.get(req.params.id, req.user)
  ok(res, order)
})

export const createOrder = asyncHandler(async (req, res) => {
  const order = await orderService.create(req.body, req.user)
  created(res, order)
})

export const deleteOrder = asyncHandler(async (req, res) => {
  await orderService.delete(req.params.id, req.user)
  noContent(res)
})
```

---

## Route naming

```
Base prefix:  /api/v1/

Collection:   GET    /api/v1/orders
Single:       GET    /api/v1/orders/:id
Create:       POST   /api/v1/orders
Update:       PUT    /api/v1/orders/:id    (full replace)
Patch:        PATCH  /api/v1/orders/:id   (partial update)
Delete:       DELETE /api/v1/orders/:id

Nested (ownership):
              GET    /api/v1/users/:userId/orders
              POST   /api/v1/users/:userId/orders
```

**Rules:**
- Plural nouns — `/orders`, `/products`, `/order-items`
- kebab-case — `/order-items` not `/orderItems` or `/order_items`
- Max 2 nesting levels — `/users/:userId/orders` is fine, deeper is a smell
- No verbs in path — `/orders/:id/cancel` (bad) → `PATCH /orders/:id` with `{ "status": "cancelled" }` in body
- Exception: actions with no resource equivalent — `POST /api/v1/auth/sign-in`, `POST /api/v1/orders/:id/duplicate`

```ts
// ❌ Verb in path
POST /api/v1/cancelOrder
GET  /api/v1/getOrders
POST /api/v1/orders/create

// ✅ Noun + HTTP method carries the verb
DELETE /api/v1/orders/:id
GET    /api/v1/orders
POST   /api/v1/orders

// ✅ State change via PATCH
PATCH /api/v1/orders/:id   body: { "status": "cancelled" }

// ✅ Actions that don't map cleanly to CRUD
POST /api/v1/orders/:id/duplicate
POST /api/v1/invoices/:id/send
```

---

## Versioning

All routes are versioned from day one. Version in the URL — not headers.

```
/api/v1/orders     ← current
/api/v2/orders     ← when breaking changes are needed
```

```ts
// src/routes/index.ts
import { Router } from 'express'
import { ordersRouter } from './orders'
import { usersRouter } from './users'

const v1 = Router()
v1.use('/orders', ordersRouter)
v1.use('/users', usersRouter)

export function mountRoutes(app: Express) {
  app.use('/api/v1', v1)
}
```

**When to bump the version:**
- Removing a field from the response
- Changing a field type or name
- Changing required/optional on a request field
- Removing an endpoint

**Not a breaking change (no version bump needed):**
- Adding a new optional response field
- Adding a new optional request field
- Adding a new endpoint

---

## HTTP status codes

| Code | When to use |
|---|---|
| `200` | Successful GET, PUT, PATCH |
| `201` | Successful POST that created a resource |
| `204` | Successful DELETE (no body) |
| `400` | Request validation failed (Zod parse error) |
| `401` | Not authenticated — no token or invalid token |
| `403` | Authenticated but not authorized — wrong role/group/owner |
| `404` | Resource does not exist |
| `409` | Conflict — duplicate unique key, version mismatch |
| `422` | Business rule violated — insufficient stock, invalid state transition |
| `429` | Rate limit exceeded |
| `500` | Unexpected server error |

```ts
// ❌ 200 for not found
res.status(200).json({ found: false })

// ❌ 400 for business rule violations (not a validation error)
throw new ValidationError('Insufficient stock')   // use UnprocessableError

// ✅ Correct mapping
throw new NotFoundError('Order', id)              // → 404
throw new ForbiddenError()                        // → 403
throw new ConflictError('Email already in use')  // → 409
throw new UnprocessableError('Insufficient stock', { available: 2, requested: 10 })  // → 422
```

---

## Pagination

Always cursor-based. Never offset (`?page=2&pageSize=20`) — it breaks under concurrent inserts and doesn't scale.

**Request:**
```
GET /api/v1/orders?limit=20&cursor=<encodedCursor>
```

**Response:**
```json
{
  "success": true,
  "data": [...],
  "meta": {
    "nextCursor": "eyJpZCI6ImFiYzEyMyJ9",
    "total": 84
  }
}
```

`nextCursor` is `null` when no more pages exist. `total` is the count of all matching records (for UI display — "Showing 20 of 84").

**Implementation:**

```ts
// src/utils/pagination.ts
const DEFAULT_LIMIT = 20
const MAX_LIMIT = 100

export function parsePaginationParams(query: Record<string, unknown>) {
  const limit = Math.min(
    Number(query.limit) || DEFAULT_LIMIT,
    MAX_LIMIT,
  )
  const cursor = typeof query.cursor === 'string' ? query.cursor : undefined
  return { limit, cursor }
}

export function encodeCursor(id: string): string {
  return Buffer.from(JSON.stringify({ id })).toString('base64url')
}

export function decodeCursor(cursor: string): { id: string } {
  return JSON.parse(Buffer.from(cursor, 'base64url').toString())
}

export function buildNextCursor(items: { id: string }[], limit: number): string | null {
  if (items.length < limit) return null
  return encodeCursor(items[items.length - 1].id)
}
```

```ts
// src/repositories/orders.repository.ts
export async function findMany(params: {
  userId: string
  limit: number
  cursor?: string
}): Promise<{ items: Order[]; total: number }> {
  const cursorWhere = params.cursor
    ? { id: { lt: decodeCursor(params.cursor).id } }
    : {}

  const [items, total] = await prisma.$transaction([
    prisma.order.findMany({
      where: { userId: params.userId, deletedAt: null, ...cursorWhere },
      orderBy: { createdAt: 'desc' },
      take: params.limit,
    }),
    prisma.order.count({ where: { userId: params.userId, deletedAt: null } }),
  ])

  return { items, total }
}
```

```ts
// src/controllers/orders.controller.ts
export const listOrders = asyncHandler(async (req, res) => {
  const { limit, cursor } = parsePaginationParams(req.query)
  const { items, total } = await orderService.list(req.user.sub, { limit, cursor })
  const nextCursor = buildNextCursor(items, limit)
  paginated(res, items, { nextCursor, total })
})
```

**Frontend — React Query infinite query:**

```ts
// src/features/orders/api/orders.api.ts
export function useOrders() {
  return useInfiniteQuery({
    queryKey: ['orders'],
    queryFn: ({ pageParam }) =>
      apiClient.get<PaginatedResponse<Order>>(
        `/api/v1/orders?limit=20${pageParam ? `&cursor=${pageParam}` : ''}`
      ),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.meta.nextCursor ?? undefined,
  })
}
```

---

## Query parameters

```
Filtering:   GET /api/v1/orders?status=pending&status=confirmed
Sorting:     GET /api/v1/orders?sort=createdAt&order=desc
Search:      GET /api/v1/orders?q=widget
Pagination:  GET /api/v1/orders?limit=20&cursor=abc123
```

**Validation with Zod:**

```ts
// src/types/orders.types.ts
export const listOrdersQuerySchema = z.object({
  status: z.union([orderStatusSchema, z.array(orderStatusSchema)]).optional(),
  sort: z.enum(['createdAt', 'updatedAt', 'total']).default('createdAt'),
  order: z.enum(['asc', 'desc']).default('desc'),
  q: z.string().max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().optional(),
})

export type ListOrdersQuery = z.infer<typeof listOrdersQuerySchema>
```

```ts
// In controller — parse query params the same way as body
export const listOrders = asyncHandler(async (req, res) => {
  const query = listOrdersQuerySchema.parse(req.query)  // throws ValidationError → 400
  // ...
})
```

---

## Headers

```
Request:
  Authorization: Bearer <cognito-jwt>
  Content-Type: application/json

Response:
  Content-Type: application/json
  X-Request-Id: <uuid>          ← set by requestLogger middleware, trace across logs
```

```ts
// src/middleware/requestId.ts
import { randomUUID } from 'crypto'

export function requestId(req: Request, res: Response, next: NextFunction) {
  const id = randomUUID()
  req.headers['x-request-id'] = id
  res.setHeader('X-Request-Id', id)
  next()
}
```

Mount before `requestLogger` so every log line includes the same ID.

---

## Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Route path segments | kebab-case | `/order-items` |
| Query parameters | camelCase | `?nextCursor=`, `?sortBy=` |
| JSON body fields | camelCase | `{ "productId": "...", "createdAt": "..." }` |
| JSON response fields | camelCase | `{ "success": true, "data": { "orderId": "..." } }` |
| Route params | camelCase | `/:orderId`, `/:userId` |

---

## Route file structure

```ts
// src/routes/orders.ts
import { Router } from 'express'
import { requireAuth } from '../middleware/auth'
import { requireGroup } from '../middleware/requireGroup'
import * as ordersController from '../controllers/orders.controller'

export const ordersRouter = Router()

ordersRouter.use(requireAuth)                                          // all routes require auth

ordersRouter.get('/', ordersController.listOrders)
ordersRouter.post('/', ordersController.createOrder)
ordersRouter.get('/:id', ordersController.getOrder)
ordersRouter.patch('/:id', ordersController.updateOrder)
ordersRouter.delete('/:id', ordersController.deleteOrder)

// Admin-only sub-routes
ordersRouter.post('/:id/refund', requireGroup('admin'), ordersController.refundOrder)
```

---

## Never

```ts
// ❌ No version prefix
GET /api/orders

// ❌ Verb in path
POST /api/v1/createOrder
GET  /api/v1/getOrderById/:id

// ❌ Bare array response
res.json([...orders])

// ❌ 200 for errors
res.status(200).json({ error: 'Not found' })

// ❌ Offset pagination
GET /api/v1/orders?page=3&pageSize=20

// ❌ snake_case fields in JSON
{ "order_id": "...", "created_at": "..." }

// ❌ Inconsistent envelope — some routes wrap, some don't
res.json(order)           // sometimes bare
res.json({ data: order }) // sometimes wrapped
```
