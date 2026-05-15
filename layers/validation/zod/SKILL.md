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
- `interface User { ... }` or `type User = { ... }` — use `z.infer<typeof UserSchema>` instead
- `email: z.string().email()` inline inside a schema — import `emailSchema` from the primitives module
- `id: z.string().uuid()` inline — import `uuidSchema`
- `z.union([...])` when shapes differ by a discriminant field — use `z.discriminatedUnion()`

**Code examples:**

```ts
// ✅ API route — .parse() at the entry point, never access req.body fields directly
const createUserSchema = z.object({ name: z.string(), email: emailSchema });
router.post('/users', (req, res) => {
  const body = createUserSchema.parse(req.body);   // throws → 400 via errorHandler
  res.json({ success: true, data: body });
});

// ✅ Form handler — .safeParse(), always check result.success
function handleLogin(input: unknown) {
  const result = loginSchema.safeParse(input);
  if (!result.success) return { errors: result.error.flatten().fieldErrors };
  return { success: true, data: result.data };
}

// ✅ Types always inferred — never duplicated manually
const UserSchema = z.object({ id: uuidSchema, name: z.string(), email: emailSchema });
type User = z.infer<typeof UserSchema>;  // ✅
// ❌ Never: type User = { id: string; name: string; email: string }
// ❌ Never: interface User { ... }

// ✅ discriminatedUnion for tagged response shapes
const ResponseSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('success'), data: z.unknown() }),
  z.object({ type: z.literal('error'), message: z.string() }),
]);
// ❌ Never: z.union([ z.object({...}), z.object({...}) ]) when shapes have a discriminant
```

**Related skills:** `api-conventions` (Zod at route entry), `error-handling` (400 response shape)
