# Zod Validation Standards

## Types — always infer, never duplicate

Always derive TypeScript types from the schema. Writing types by hand that duplicate a Zod schema creates two sources of truth that will drift.

```ts
// Good
const UserSchema = z.object({ id: z.string().uuid(), email: z.string().email() })
type User = z.infer<typeof UserSchema>

// Bad — manual type that duplicates the schema
type User = { id: string; email: string }
```

## `.parse()` vs `.safeParse()`

| Method | Behaviour | Use when |
|---|---|---|
| `.parse(data)` | Throws `ZodError` on failure | API entry points — a 400 is the right response |
| `.safeParse(data)` | Returns `{ success, data, error }` | Forms, optional parsing, non-throwing paths |

```ts
// API route — throw is fine, global handler converts to 400
const body = CreateUserSchema.parse(req.body)

// Form handler — check result before proceeding
const result = LoginSchema.safeParse(formData)
if (!result.success) {
  setErrors(result.error.flatten().fieldErrors)
  return
}
```

## Schema co-location

Define a schema next to the data it validates. Avoid a single mega `schemas/` barrel file — it becomes impossible to navigate and creates circular imports.

```
src/
  features/
    users/
      user.schema.ts      ← UserSchema lives here, next to UserService
      user.service.ts
    orders/
      order.schema.ts
      order.service.ts
```

Exception: shared primitive schemas (`emailSchema`, `uuidSchema`, `isoDateSchema`) belong in `src/lib/schemas.ts`.

## Reusable primitives

Define once in `src/lib/schemas.ts`, import everywhere:

```ts
export const emailSchema = z.string().email()
export const uuidSchema = z.string().uuid()
export const isoDateSchema = z.string().datetime()
export const positiveIntSchema = z.number().int().positive()
export const paginationSchema = z.object({
  cursor: z.string().optional(),
  limit: positiveIntSchema.max(100).default(20),
})
```

## Nominal types with `.brand()`

Use `.brand()` to prevent accidental mixing of structurally identical types.

```ts
const UserIdSchema = z.string().uuid().brand<'UserId'>()
type UserId = z.infer<typeof UserIdSchema>

const OrderIdSchema = z.string().uuid().brand<'OrderId'>()
type OrderId = z.infer<typeof OrderIdSchema>

// TypeScript now rejects passing an OrderId where a UserId is expected
function getUser(id: UserId) { ... }
getUser(orderId) // TS error ✓
```

## Discriminated unions

Use `z.discriminatedUnion()` when shapes differ by a known key — it gives better error messages and faster runtime validation than `z.union()`.

```ts
// Good
const EventSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('created'), userId: z.string() }),
  z.object({ type: z.literal('deleted'), userId: z.string(), reason: z.string() }),
])

// Worse — z.union() tries each branch sequentially
const EventSchema = z.union([...])
```

## Transformations

Apply `.transform()` after parsing, not before. Transforms run after validation — they receive the already-validated, correctly-typed value.

```ts
// Good — transform after validation
const TrimmedNameSchema = z.string().min(1).transform(s => s.trim())

// Also fine — chain in the schema, order matters
const NormalisedEmailSchema = z
  .string()
  .email()
  .transform(s => s.toLowerCase().trim())
```

Do not use `.preprocess()` to coerce types when Zod's built-in coercion (`z.coerce.string()`, `z.coerce.number()`) will do.

## zod-to-openapi integration

Add `.openapi()` metadata to schemas used in API routes. This generates Swagger/OpenAPI docs automatically.

```ts
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi'
extendZodWithOpenApi(z) // call once at app startup

const UserSchema = z.object({
  id: uuidSchema.openapi({ example: '123e4567-e89b-12d3-a456-426614174000' }),
  email: emailSchema.openapi({ example: 'user@example.com' }),
  role: z.enum(['admin', 'member']).openapi({ example: 'member' }),
}).openapi('User')
```

Register schemas in the OpenAPI registry and generate the spec in `src/lib/openapi.ts`.

## Error handling

```ts
// Form errors — flat structure per field
const result = FormSchema.safeParse(data)
if (!result.success) {
  const { fieldErrors, formErrors } = result.error.flatten()
  // fieldErrors: { email: ['Invalid email'], name: ['Required'] }
  // formErrors: string[]  (errors not tied to a field)
}

// Nested object errors — preserves structure
const formatted = result.error.format()
// formatted.address._errors, formatted.address.city._errors etc.

// Custom error messages
const Schema = z.object({
  age: z.number({ required_error: 'Age is required' }).min(18, 'Must be 18 or older'),
})
```

## `z.any()` and `z.unknown()`

Never use without a comment. These opt out of type safety.

```ts
// Bad — silent escape hatch
const Schema = z.object({ metadata: z.any() })

// Good — explicit escape with reasoning
const Schema = z.object({
  // metadata is an opaque JSON blob from an external system; validated at point of use
  metadata: z.record(z.unknown()),
})
```

Prefer `z.record(z.unknown())` over `z.any()` — it at least asserts the top-level shape is an object.

## Common patterns

### Optional vs nullable

```ts
z.string().optional()   // string | undefined — field may be absent
z.string().nullable()   // string | null — field is present but null
z.string().nullish()    // string | null | undefined — either
```

### Default values

```ts
const QuerySchema = z.object({
  limit: z.number().int().min(1).max(100).default(20),
  sortDir: z.enum(['asc', 'desc']).default('desc'),
})
```

### Refinements

```ts
const PasswordSchema = z
  .string()
  .min(8)
  .refine(pw => /[A-Z]/.test(pw), { message: 'Must contain an uppercase letter' })
  .refine(pw => /[0-9]/.test(pw), { message: 'Must contain a number' })

// Cross-field validation
const SignUpSchema = z
  .object({ password: z.string(), confirmPassword: z.string() })
  .refine(data => data.password === data.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  })
```

### Partial and pick for update schemas

```ts
const CreateUserSchema = z.object({ name: z.string(), email: emailSchema, role: RoleSchema })
const UpdateUserSchema = CreateUserSchema.partial()              // all fields optional
const UserPreviewSchema = CreateUserSchema.pick({ name: true }) // subset
```
