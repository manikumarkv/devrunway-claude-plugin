---
name: zod-validation
description: Zod schema patterns — .parse() vs .safeParse(), infer types, schema reuse, zod-to-openapi, form validation integration. Load when working with Zod schemas.
user-invocable: false
stack: validation/zod
paths:
  - "**/*.schema.ts"
  - "src/validation/**"
  - "src/schemas/**"
---

Full standards in [zod-validation.md](zod-validation.md). Always-on summary:

**Types:**
- `z.infer<typeof Schema>` for all TypeScript types — never write them manually
- `.brand()` for nominal types: `UserId`, `OrderId` etc.

**Parsing:**
- `.parse()` throws — use at API entry points where a 400 response is correct
- `.safeParse()` returns `{ success, data, error }` — use in forms and optional parsing

**Schema design:**
- Co-locate schemas with the data they validate — not in a mega `schemas/` file
- Reusable primitives: `emailSchema = z.string().email()`, `uuidSchema = z.string().uuid()`
- `z.discriminatedUnion()` over `z.union()` when shapes differ by a key
- `.transform()` after `.parse()`, not before

**OpenAPI:**
- Add `.openapi()` metadata to all schemas for free Swagger docs via `zod-to-openapi`

**Error handling:**
- `ZodError.flatten()` for form field errors
- `ZodError.format()` for nested object errors

**Never:**
- `z.any()` or `z.unknown()` without a comment explaining why
- Manually-written TypeScript types that duplicate a Zod schema

**Related skills:** `api-conventions` (Zod at route entry), `error-handling` (400 response shape)
