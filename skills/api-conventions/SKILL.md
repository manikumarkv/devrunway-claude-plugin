---
name: api-conventions
description: REST API design conventions — response envelope, route naming, versioning, pagination, status codes, query parameters. Load when designing or implementing any API endpoint.
user-invocable: false
---

Full standards in [api-conventions.md](api-conventions.md). Always-on summary:

**Response envelope — always:**
- Success: `{ "success": true, "data": <T> }`
- Success + pagination: `{ "success": true, "data": <T[]>, "meta": { "nextCursor": "...", "total": 42 } }`
- Error: `{ "error": { "message": "...", "code": "NOT_FOUND", "details": { ... } } }`

**Routes:**
- Prefix: `/api/v1/`
- Plural nouns: `/orders` not `/order` or `/getOrders`
- Nested for ownership: `/users/:userId/orders` (max 2 levels)
- kebab-case: `/order-items` not `/orderItems`

**Status codes:**
- `200` GET/PUT/PATCH success, `201` POST created, `204` DELETE (no body)
- `400` validation, `401` no auth, `403` no permission, `404` not found, `409` conflict, `422` business rule, `500` unexpected

**Pagination:** cursor-based always. `?limit=20&cursor=<id>`. Never offset.

**Never:** `/getOrders`, `/api/orders` (no version), returning arrays at root, 200 for errors.


**Related skills — apply together:**
- `error-handling` — AppError subclasses map to status codes; centralized errorHandler
- `typescript-patterns` — Zod inferred types for all request/response shapes
- `api-docs` — register every route in OpenAPI using the same Zod schemas
- `security` — every route needs requireAuth, ownership check, and rate limiting