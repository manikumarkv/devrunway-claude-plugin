---
name: swagger-docs
description: OpenAPI 3.1 / Swagger documentation standards. Load when writing, reviewing, or generating API documentation for any Express/Node.js route.
user-invocable: false
stack: api-docs/swagger-express
---

Full rules in [swagger-docs.md](swagger-docs.md). Always-on summary:

**Tooling (locked):**
- `@asteasolutions/zod-to-openapi` — derive OpenAPI schemas from existing Zod validators; no duplication
- `swagger-ui-express` — serves interactive Swagger UI at `/api-docs` (dev/staging only): `app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(spec))`
- `swagger-jsdoc` — NOT used; schema is code-generated from Zod, not JSDoc comments

**When swagger-jsdoc IS used (legacy projects):**
- Annotate each route handler with a `@swagger` JSDoc block — keeps docs co-located with the route
- All reusable types defined once under `components:` and referenced via `$ref:` — never inline `type: object`

**Single source of truth:**
- Zod schemas define validation AND generate OpenAPI schemas — never write them twice
- All schemas registered in `src/docs/openapi-registry.ts`
- `src/docs/openapi.ts` assembles the final spec from the registry
- Spec is served as JSON at `GET /api-docs/spec.json` for tooling integration

**Every route must document:**
- Summary + description
- All path/query parameters with type and whether required
- Request body schema (reference to Zod-derived schema)
- All response codes: 200/201/204 success + 400/401/403/404/409/422/500 errors
- Auth requirement (`bearerAuth` security scheme)

**Never:**
- Duplicate type definitions — if a Zod schema exists, derive the OpenAPI schema from it
- Expose `/api-docs` in production — gate behind `NODE_ENV !== 'production'`
- Use `type: object` inline in route docs — always `$ref` a named schema
- Leave a route undocumented — every public endpoint has a full spec entry

**Related skills — apply together:**
- `api-conventions` — response envelope shapes must match the documented schemas
- `error-handling` — all error codes listed in error-handling must appear in response docs
- `typescript-patterns` — Zod schemas are the shared source for TS types + OpenAPI
