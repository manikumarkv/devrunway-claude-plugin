# REST API Standards

---

## URL design

```
# Collections
GET    /v1/orders                    list orders (paginated)
POST   /v1/orders                    create order → 201

# Resources
GET    /v1/orders/:id                get one order
PATCH  /v1/orders/:id                partial update → 200
PUT    /v1/orders/:id                full replace → 200
DELETE /v1/orders/:id                delete → 204

# Nested resources (one level only)
GET    /v1/users/:userId/orders      orders for a specific user
POST   /v1/users/:userId/orders      create order for user

# Actions (when CRUD doesn't fit)
POST   /v1/orders/:id/cancel         action verb as sub-resource
POST   /v1/orders/:id/ship
POST   /v1/invoices/:id/send

# Filtering, sorting, pagination via query params
GET    /v1/orders?status=pending&limit=20&cursor=abc
GET    /v1/products?category=electronics&sort=price&order=asc
```

---

## HTTP status codes

| Code | When to use |
|------|-------------|
| `200 OK` | Successful GET, PATCH, PUT |
| `201 Created` | Successful POST — include `Location` header |
| `204 No Content` | Successful DELETE with no body |
| `400 Bad Request` | Malformed request (invalid JSON, missing required header) |
| `401 Unauthorized` | Not authenticated — include `WWW-Authenticate` header |
| `403 Forbidden` | Authenticated but not authorised |
| `404 Not Found` | Resource does not exist |
| `409 Conflict` | State conflict (duplicate email, concurrent edit) |
| `422 Unprocessable Entity` | Request is well-formed but fails validation |
| `429 Too Many Requests` | Rate limited — include `Retry-After` header |
| `500 Internal Server Error` | Unexpected server error — log but do not expose details |

---

## Response envelope

```typescript
// Success — single resource
{
  "data": {
    "id":        "ord_abc123",
    "status":    "pending",
    "total":     49.99,
    "createdAt": "2025-01-15T10:30:00Z"
  }
}

// Success — collection
{
  "data": [
    { "id": "ord_abc123", "status": "pending", "total": 49.99 },
    { "id": "ord_def456", "status": "shipped", "total": 99.00 }
  ],
  "meta": {
    "total":      42,
    "cursor":     "eyJpZCI6Im9yZF9kZWY0NTYifQ",
    "hasMore":    true,
    "limit":      20
  }
}

// Error
{
  "error": {
    "code":    "VALIDATION_ERROR",
    "message": "The request contains invalid data",
    "details": {
      "email":   ["Must be a valid email address"],
      "total":   ["Must be a positive number"]
    }
  }
}

// Error — not found
{
  "error": {
    "code":    "ORDER_NOT_FOUND",
    "message": "Order ord_abc123 was not found"
  }
}
```

---

## Pagination

### Cursor-based (preferred for large datasets)

```
GET /v1/orders?limit=20
→ { data: [...], meta: { cursor: "abc", hasMore: true } }

GET /v1/orders?limit=20&cursor=abc
→ next page
```

```typescript
// Implementation
async function listOrders(userId: string, limit: number, cursor?: string) {
  const cursorId = cursor ? decodeCursor(cursor) : undefined

  const orders = await db.orders.findMany({
    where:   { userId, ...(cursorId && { id: { gt: cursorId } }) },
    take:    limit + 1,     // fetch one extra to check hasMore
    orderBy: { id: 'asc' },
  })

  const hasMore = orders.length > limit
  const items   = hasMore ? orders.slice(0, limit) : orders

  return {
    data: items,
    meta: {
      hasMore,
      cursor:  hasMore ? encodeCursor(items.at(-1)!.id) : null,
      limit,
    },
  }
}
```

### Offset-based (for small, static datasets)

```
GET /v1/categories?page=2&pageSize=10
→ { data: [...], meta: { page: 2, pageSize: 10, total: 45, totalPages: 5 } }
```

---

## Headers

```typescript
// Required on all responses
'Content-Type': 'application/json'

// On 201 Created — where to find the new resource
'Location': `/v1/orders/${newOrder.id}`

// On 401 Unauthorized
'WWW-Authenticate': 'Bearer realm="api"'

// On 429 Too Many Requests
'Retry-After': '60'   // seconds
'X-RateLimit-Limit':     '100'
'X-RateLimit-Remaining': '0'
'X-RateLimit-Reset':     '1705312260'  // Unix timestamp

// CORS (set in middleware)
'Access-Control-Allow-Origin':  'https://yourapp.com'
'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
'Access-Control-Allow-Headers': 'Content-Type, Authorization'
```

---

## Express implementation pattern

```typescript
// src/features/orders/orders.router.ts
import { Router } from 'express'
import { authenticate } from '../middleware/auth'
import { validate }     from '../middleware/validate'
import { createOrderSchema, updateOrderSchema } from './order.schema'
import * as ordersHandler from './orders.handler'

const router = Router()

// Auth on all routes in this router
router.use(authenticate)

router.get('/',      ordersHandler.list)
router.post('/',     validate(createOrderSchema), ordersHandler.create)
router.get('/:id',   ordersHandler.getById)
router.patch('/:id', validate(updateOrderSchema), ordersHandler.update)
router.delete('/:id', ordersHandler.remove)

// Actions
router.post('/:id/cancel', ordersHandler.cancel)
router.post('/:id/ship',   ordersHandler.ship)

export { router as ordersRouter }
```

```typescript
// src/features/orders/orders.handler.ts
import type { Request, Response } from 'express'
import { ordersService } from './orders.service'
import { HttpError } from '../lib/errors'

export async function list(req: Request, res: Response) {
  const { limit = 20, cursor, status } = req.query

  const result = await ordersService.list({
    userId: req.user.id,
    limit:  Number(limit),
    cursor: cursor as string | undefined,
    status: status as string | undefined,
  })

  res.json(result)
}

export async function create(req: Request, res: Response) {
  const order = await ordersService.create({ ...req.body, userId: req.user.id })

  res.status(201)
    .header('Location', `/v1/orders/${order.id}`)
    .json({ data: order })
}

export async function getById(req: Request, res: Response) {
  const order = await ordersService.getById(req.params.id, req.user.id)
  if (!order) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found')
  res.json({ data: order })
}

export async function remove(req: Request, res: Response) {
  await ordersService.delete(req.params.id, req.user.id)
  res.status(204).send()
}

export async function cancel(req: Request, res: Response) {
  const order = await ordersService.cancel(req.params.id, req.user.id)
  res.json({ data: order })
}
```

---

## Error middleware

```typescript
// src/middleware/error-handler.ts
import type { Request, Response, NextFunction } from 'express'
import { HttpError } from '../lib/errors'

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof HttpError) {
    return res.status(err.statusCode).json({
      error: {
        code:    err.code,
        message: err.message,
        ...(err.details && { details: err.details }),
      },
    })
  }

  // Log unexpected errors
  console.error(err)

  // Never expose internal details in production
  res.status(500).json({
    error: {
      code:    'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
    },
  })
}
```

---

## OpenAPI (documentation)

```yaml
# openapi.yaml
openapi: "3.1.0"
info:
  title:   "MyApp API"
  version: "1.0.0"

paths:
  /v1/orders:
    get:
      summary:     "List orders"
      operationId: "listOrders"
      parameters:
        - name:     limit
          in:       query
          schema:   { type: integer, minimum: 1, maximum: 100, default: 20 }
        - name:     cursor
          in:       query
          schema:   { type: string }
        - name:     status
          in:       query
          schema:   { type: string, enum: [pending, shipped, delivered] }
      responses:
        "200":
          description: "Paginated list of orders"
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/OrderListResponse"
        "401":
          $ref: "#/components/responses/Unauthorized"

    post:
      summary:     "Create order"
      operationId: "createOrder"
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateOrderInput"
      responses:
        "201":
          description: "Order created"
          headers:
            Location:
              schema: { type: string, example: "/v1/orders/ord_abc123" }
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/OrderResponse"
        "422":
          $ref: "#/components/responses/ValidationError"

components:
  schemas:
    Order:
      type: object
      required: [id, status, total, createdAt]
      properties:
        id:        { type: string, example: "ord_abc123" }
        status:    { type: string, enum: [pending, shipped, delivered, cancelled] }
        total:     { type: number, format: float, minimum: 0 }
        createdAt: { type: string, format: date-time }

  responses:
    Unauthorized:
      description: "Not authenticated"
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorResponse"

  securitySchemes:
    bearerAuth:
      type:   http
      scheme: bearer

security:
  - bearerAuth: []
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `GET /orders/search?q=foo` with a body | Use query params: `GET /orders?q=foo` — GET has no body |
| `200 OK` with `{ success: false }` in the body | Use the correct 4xx/5xx status code |
| `POST /cancelOrder` (verb in URL) | `POST /orders/:id/cancel` — actions as sub-resource nouns/verbs |
| Deeply nested URLs (`/users/:uid/orders/:oid/items/:iid`) | Max one level of nesting — flatten with filters instead |
| No `Location` header on `201 Created` | Always include where the new resource can be found |
| Inconsistent envelope — sometimes `{ data }`, sometimes flat | Uniform envelope across all endpoints |
| Breaking existing API in place | Add `/v2/` — never change `/v1/` responses in a breaking way |
