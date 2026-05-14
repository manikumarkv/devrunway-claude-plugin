---
name: rest
description: REST API implementation standards — resource naming, HTTP methods, status codes, versioning, and OpenAPI. Load when building or consuming REST APIs.
user-invocable: false
stack: api-style/rest
paths:
  - "**/routes/**"
  - "**/controllers/**"
  - "**/handlers/**"
  - "openapi.yaml"
  - "openapi.json"
---

Full standards in [rest.md](rest.md). Always-on summary:

**Resource naming:**
- Plural nouns for collections: `/orders`, `/users`, `/products`
- Nested for ownership: `/users/:userId/orders` — only one level deep
- Actions that don't map to CRUD: use a sub-resource verb: `POST /orders/:id/cancel`
- URL path: `kebab-case`; query params: `camelCase`

**HTTP methods:**
- `GET` — read, idempotent, no body
- `POST` — create; returns `201 Created` with the new resource
- `PUT` — full replacement, idempotent
- `PATCH` — partial update; only send fields that change
- `DELETE` — delete; returns `204 No Content` or `200` with deletion metadata

**Status codes:**
- `200` OK, `201` Created, `204` No Content
- `400` Bad Request (malformed), `401` Unauthenticated, `403` Forbidden, `404` Not Found, `409` Conflict, `422` Unprocessable (validation errors)
- `500` Internal Server Error — never expose stack traces

**Response envelope:**
- Success: `{ data: T }` or `{ data: T[], meta: { total, cursor } }`
- Error: `{ error: { code: string, message: string, details?: Record<string, string[]> } }`
- Never mix envelope and flat responses in the same API

**Versioning:**
- URL prefix: `/v1/`, `/v2/` — visible, cache-friendly, simple
- Never break existing v1 clients — add v2 for breaking changes

**Pagination:**
- Cursor-based for large/real-time datasets (use `cursor` + `limit`)
- Offset-based (`page` + `pageSize`) only for small, static datasets

**Never:**
- Use `GET` with a body for filtering — use query params
- Return `200` with `{ success: false }` — use the appropriate 4xx code
- Expose internal IDs or implementation details in responses

**Related skills:** `core/api-conventions` (universal principles), `api-style/graphql`, `api-style/trpc`
