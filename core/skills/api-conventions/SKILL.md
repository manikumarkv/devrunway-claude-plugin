---
name: api-conventions
description: Universal REST API design principles — response envelope, route naming, versioning, pagination, status codes. Applies to any backend language or framework. Load when designing or implementing any API endpoint.
user-invocable: false
paths:
  - "src/**/*.controller.*"
  - "src/**/*.route.*"
  - "src/**/*.handler.*"
  - "src/**/routes/**"
  - "src/**/api/**"
---

Full standards in [api-conventions.md](api-conventions.md). Always-on summary:

**Response envelope — always consistent:**
- Success: `{ "success": true, "data": <resource>, "meta": { "requestId": "...", "timestamp": "..." } }`
- Success + pagination: add `"pagination": { "nextCursor": "...", "total": N, "limit": 20, "hasMore": true }`
- Error: `{ "success": false, "error": { "code": "NOT_FOUND", "message": "...", "details": [...] }, "meta": { ... } }`

**Routes:**
- Prefix and version from day one: `/api/v1/`
- Plural nouns: `/orders` not `/order` or `/getOrders`
- Nested for ownership: `/users/:userId/orders` (max 2 levels deep)
- kebab-case path segments: `/order-items` not `/orderItems`

**HTTP status codes:**
- `200` success · `201` created · `204` deleted (no body)
- `400` invalid input · `401` not authenticated · `403` not authorised
- `404` not found · `409` conflict · `422` business rule violated · `500` unexpected

**Pagination:** prefer cursor-based (`?limit=20&cursor=<id>`) over offset — offset is inconsistent under concurrent writes

**Never:** verb routes (`/getOrders`), unversioned paths (`/api/orders`), bare arrays at root, `200` for errors

**For implementation helpers** (response builder functions, validation middleware, framework-specific wiring), see your backend layer skill.