---
name: api-docs
description: API documentation standards — OpenAPI 3.1 spec, JSDoc annotations, Zod-to-schema generation, Swagger UI setup. Load when documenting API endpoints or reviewing API contracts.
user-invocable: false
---

Full standards in [api-docs.md](api-docs.md). Always-on summary:

**Approach:** Generate OpenAPI from code, not write YAML by hand.
- Zod schemas → OpenAPI components via `zod-to-openapi`
- Express routes → documented via route registration (no separate YAML)
- Swagger UI served at `/api/docs` in non-production environments

**Every endpoint must document:**
- Summary + description
- Request body schema (Zod-derived)
- All response shapes: 200/201, 400 (validation), 401, 403, 404, 500
- Auth requirement (`bearerAuth`)

**Never:**
- Write OpenAPI YAML by hand — schema and code drift
- Document responses that don't match actual Zod types
- Expose `/api/docs` in production without auth


**Related skills — apply together:**
- `api-conventions` — OpenAPI paths must match the route naming and envelope conventions
- `error-handling` — document all AppError-derived response codes (400/401/403/404/409/422/500)
- `typescript-patterns` — Zod schemas registered in OpenAPI are the same types used for validation