# REST API Design Conventions

Universal principles — applies to any backend language or framework. For implementation helpers (response builders, validation middleware), see your backend layer skill.

---

## Response Envelope

Every response uses a single consistent shape. Never return a bare array or bare object at the root. Always include a `meta` block for traceability.

### Success response
```json
{
  "success": true,
  "data": {
    "id": "usr_123",
    "name": "Alice"
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "v1"
  }
}
```

### Success response with pagination
```json
{
  "success": true,
  "data": [
    { "id": "ord_1", "total": 99.99 },
    { "id": "ord_2", "total": 45.00 }
  ],
  "pagination": {
    "nextCursor": "ord_2",
    "total": 47,
    "limit": 20,
    "hasMore": true
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### Error response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      { "field": "email", "message": "Must be a valid email address" },
      { "field": "age", "message": "Must be a positive integer" }
    ]
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

**Rules:**
- `success: true/false` on every response — makes client-side handling predictable
- `data` is always an object or array of objects — never a scalar at the root
- `error.code` is a machine-readable constant (SCREAMING_SNAKE_CASE)
- `error.details` lists every invalid field — not just the first one
- Never include stack traces, query text, or file paths in error responses

---

## Route Design

### URL structure
```
/api/v1/{resource}                 GET list, POST create
/api/v1/{resource}/{id}            GET one, PUT/PATCH update, DELETE
/api/v1/{resource}/{id}/{sub}      GET nested list, POST nested create
```

### Rules
- **Plural nouns** — `/users`, `/orders`, `/products` (not `/user`, `/getOrders`)
- **Version from day one** — `/api/v1/` prefix, even if only one version exists
- **Nested for ownership** — `/users/:userId/orders` when a resource belongs to another (max 2 levels)
- **kebab-case** — `/order-items`, `/shipping-addresses` (not camelCase)
- **No verbs in URLs** — the HTTP method is the verb. `/orders/:id/cancel` → `POST /orders/:id/cancellations` or `PATCH /orders/:id` with `{ status: "cancelled" }`

### Examples
```
GET    /api/v1/users              → list users
POST   /api/v1/users              → create user
GET    /api/v1/users/:id          → get user
PATCH  /api/v1/users/:id          → update user
DELETE /api/v1/users/:id          → delete user
GET    /api/v1/users/:id/orders   → list orders for user
POST   /api/v1/users/:id/orders   → create order for user
```

---

## HTTP Status Codes

| Code | When to use |
|---|---|
| `200 OK` | Successful GET, PATCH, PUT |
| `201 Created` | Successful POST that created a resource |
| `204 No Content` | Successful DELETE (no response body) |
| `400 Bad Request` | Input validation failed — malformed or missing fields |
| `401 Unauthorized` | Not authenticated — no valid token |
| `403 Forbidden` | Authenticated but not authorised for this resource |
| `404 Not Found` | Resource does not exist |
| `409 Conflict` | Duplicate creation or state conflict |
| `422 Unprocessable Entity` | Input is valid but violates a business rule |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Unexpected server-side failure |

**Never return `200` for errors.** Clients check the status code first — an error body inside a 200 response breaks every HTTP client and monitoring tool.

---

## Pagination

Prefer **cursor-based** pagination over offset-based.

| | Cursor-based | Offset-based |
|---|---|---|
| Consistent under writes | ✅ | ❌ (items skip/duplicate) |
| Works on large datasets | ✅ | ❌ (OFFSET N is slow) |
| Can jump to page N | ❌ | ✅ |

### Cursor request
```
GET /api/v1/orders?limit=20&cursor=ord_abc123
```

### Cursor response
```json
{
  "pagination": {
    "nextCursor": "ord_xyz789",
    "limit": 20,
    "hasMore": true,
    "total": 147
  }
}
```

When cursor is absent, return the first page. When `hasMore` is `false`, there are no more pages.

Use offset (`?page=N&pageSize=M`) only when the UI genuinely needs random page access (e.g. a numbered page list).

---

## Query Parameters

| Parameter | Convention | Example |
|---|---|---|
| Filtering | `?status=active` | `GET /orders?status=shipped` |
| Sorting | `?sort=createdAt&order=desc` | `GET /users?sort=name&order=asc` |
| Pagination | `?limit=20&cursor=<id>` | `GET /orders?limit=10&cursor=abc` |
| Search | `?q=<term>` | `GET /products?q=keyboard` |
| Field selection | `?fields=id,name,email` | `GET /users?fields=id,name` |

**Rules:**
- camelCase for multi-word params: `?createdAfter=` not `?created_after=`
- Date params in ISO 8601: `?createdAfter=2024-01-01T00:00:00Z`
- Boolean params as strings: `?includeDeleted=true`
- Array params repeated: `?status=active&status=pending` or `?status=active,pending`

---

## Versioning Strategy

Version in the URL path — not in headers or query params (headers and query params are invisible in browser address bars and most logs).

```
/api/v1/users   ← current
/api/v2/users   ← new version when breaking changes required
```

**Breaking changes** that require a new version:
- Removing a field from the response
- Changing a field's type
- Changing the semantics of a status code
- Removing an endpoint

**Non-breaking changes** — no new version needed:
- Adding new optional fields to responses
- Adding new optional query parameters
- Adding new endpoints

---

## Idempotency

Mutating operations that could be retried (due to network failures) should support idempotency keys:

```
POST /api/v1/payments
Idempotency-Key: <client-generated UUID>
```

If the same key is received twice, return the original response without re-processing. Store idempotency keys with a TTL (24 hours is typical).

---

*For backend-specific implementation (response helper functions, validation middleware, error handler middleware), see your backend layer skill (e.g., `layers/backend/node-express/`).*
