# Valibot Standards

> Valibot is a modular, tree-shakeable alternative to Zod with a smaller bundle footprint. The API uses composable functions (pipelines) rather than method chaining.

---

## Setup

```bash
npm install valibot
```

---

## Schema definition and type inference

```typescript
// src/features/orders/order.schema.ts
import * as v from 'valibot'

export const orderSchema = v.object({
  customerId: v.pipe(v.string(), v.uuid('Must be a valid UUID')),
  status:     v.picklist(['pending', 'shipped', 'delivered'], 'Invalid status'),
  total:      v.pipe(v.number(), v.minValue(0, 'Total must be non-negative')),
  notes:      v.optional(v.pipe(v.string(), v.maxLength(500))),
  tags:       v.array(v.string()),
  address: v.object({
    line1:    v.pipe(v.string(), v.minLength(1), v.maxLength(200)),
    line2:    v.optional(v.string()),
    city:     v.pipe(v.string(), v.minLength(1)),
    postcode: v.pipe(
      v.string(),
      v.regex(/^\d{5}(-\d{4})?$/, 'Invalid postcode format')
    ),
    country:  v.pipe(v.string(), v.length(2, 'Use ISO 3166-1 alpha-2 code')),
  }),
})

// Infer TypeScript type from schema — NEVER hand-write it separately
export type OrderInput = v.InferOutput<typeof orderSchema>
```

---

## Parsing — parse vs safeParse

```typescript
import * as v from 'valibot'
import { orderSchema, type OrderInput } from './order.schema'

// ── parse — throws ValiError on failure ───────────────────────────────────────
function validateOrderStrict(data: unknown): OrderInput {
  try {
    return v.parse(orderSchema, data)
  } catch (err) {
    if (v.isValiError(err)) {
      const flat = v.flatten<typeof orderSchema>(err.issues)
      throw new ValidationError(flat.nested ?? {})
    }
    throw err
  }
}

// ── safeParse — returns result object, no try/catch needed ────────────────────
function validateOrderSafe(data: unknown): { data: OrderInput | null; errors: Record<string, string[]> | null } {
  const result = v.safeParse(orderSchema, data)

  if (result.success) {
    return { data: result.output, errors: null }
  }

  const flat = v.flatten<typeof orderSchema>(result.issues)
  return { data: null, errors: flat.nested ?? {} }
}

// Usage in a handler
const { data, errors } = validateOrderSafe(req.body)
if (errors) {
  return res.status(422).json({ error: { code: 'VALIDATION_ERROR', details: errors } })
}
// data: OrderInput — fully typed and validated
```

---

## Common field schemas

```typescript
import * as v from 'valibot'

// Email
const email = v.pipe(
  v.string(),
  v.email('Must be a valid email address'),
  v.toLowerCase(),                          // transform: lowercase
  v.maxLength(254)
)

// Password
const password = v.pipe(
  v.string(),
  v.minLength(8, 'At least 8 characters required'),
  v.regex(/[A-Z]/, 'Must contain an uppercase letter'),
  v.regex(/[0-9]/, 'Must contain a number')
)

// URL
const url = v.pipe(v.string(), v.url('Must be a valid URL'))

// UUID
const uuid = v.pipe(v.string(), v.uuid())

// ISO date string
const isoDate = v.pipe(v.string(), v.isoDateTime())

// Positive integer
const positiveInt = v.pipe(v.number(), v.integer(), v.minValue(1))

// Enum (TypeScript enum)
enum Status { Active = 'active', Inactive = 'inactive' }
const status = v.enum(Status)

// Literal union
const theme = v.union([v.literal('light'), v.literal('dark')])
```

---

## Pipelines — validation and transformation

```typescript
// Validation pipeline
const username = v.pipe(
  v.string(),
  v.minLength(3, 'At least 3 characters'),
  v.maxLength(20, 'At most 20 characters'),
  v.regex(/^[a-z0-9_]+$/, 'Only lowercase letters, numbers, and underscores'),
  v.check((val) => !val.startsWith('_'), 'Cannot start with underscore')
)

// Transformation pipeline — output type changes
const normalizedEmail = v.pipe(
  v.string(),
  v.email(),
  v.transform((val) => val.toLowerCase().trim())
)
// v.InferOutput<typeof normalizedEmail> = string (after transformation)

// Parsing + transformation
const csvToArray = v.pipe(
  v.string(),
  v.transform((val) => val.split(',').map((s) => s.trim())),
  v.array(v.string())
)

// Coerce from string (useful for query params)
const queryLimit = v.pipe(
  v.unknown(),
  v.transform(Number),
  v.number(),
  v.integer(),
  v.minValue(1),
  v.maxValue(100)
)
```

---

## Custom validators

```typescript
import * as v from 'valibot'

// Simple check
const noSpaces = v.check<string>(
  (val) => !val.includes(' '),
  'Must not contain spaces'
)
const noSpacesSchema = v.pipe(v.string(), noSpaces)

// Async custom validator
const uniqueEmail = v.checkAsync<string>(
  async (email) => {
    const exists = await checkEmailInDb(email)
    return !exists
  },
  'Email is already registered'
)
const uniqueEmailSchema = v.pipe(v.string(), v.email(), uniqueEmail)

// Cross-field validation (use v.forward to target specific field in errors)
const passwordConfirmSchema = v.pipe(
  v.object({
    password:        v.pipe(v.string(), v.minLength(8)),
    confirmPassword: v.string(),
  }),
  v.forward(
    v.check(
      (val) => val.password === val.confirmPassword,
      'Passwords do not match'
    ),
    ['confirmPassword']   // error targets this field
  )
)
```

---

## Nested schemas and composition

```typescript
// Reusable nested schemas
const addressSchema = v.object({
  line1:    v.pipe(v.string(), v.minLength(1)),
  city:     v.pipe(v.string(), v.minLength(1)),
  postcode: v.pipe(v.string(), v.regex(/^\d{5}$/)),
  country:  v.pipe(v.string(), v.length(2)),
})
export type Address = v.InferOutput<typeof addressSchema>

// Extend with intersect
const billingAddressSchema = v.intersect([
  addressSchema,
  v.object({
    vatNumber: v.optional(v.pipe(v.string(), v.minLength(5))),
  }),
])

// Partial — all fields optional (for PATCH endpoints)
const updateOrderSchema = v.partial(orderSchema)
export type UpdateOrderInput = v.InferOutput<typeof updateOrderSchema>

// Pick specific fields
const orderSummarySchema = v.pick(orderSchema, ['customerId', 'status', 'total'])

// Omit fields
const orderWithoutNotesSchema = v.omit(orderSchema, ['notes'])
```

---

## Form integration (Vue + VeeValidate)

```typescript
// @vee-validate/valibot adapter
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/valibot'
import { orderSchema } from './order.schema'

const { handleSubmit, errors, defineField } = useForm({
  validationSchema: toTypedSchema(orderSchema),
})

const [customerId, customerIdProps] = defineField('customerId')

const onSubmit = handleSubmit(async (values) => {
  // values is fully typed as OrderInput
  await createOrder(values)
})
```

---

## Error flattening for forms

```typescript
import * as v from 'valibot'

// Raw issues array (hard to use directly)
// result.issues = [{ message: 'Invalid email', path: [{ key: 'email' }] }, ...]

// Flatten to { nested: { email: ['Invalid email'], 'address.city': ['Required'] } }
const flat = v.flatten<typeof orderSchema>(result.issues)

// Access field errors
const emailErrors    = flat.nested?.email         ?? []
const cityErrors     = flat.nested?.['address.city'] ?? []
const formLevelError = flat.root                   // errors not attached to a field
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Hand-writing TypeScript type alongside schema | `type T = v.InferOutput<typeof schema>` — schema IS the type |
| `v.parse()` without catching `ValiError` | Use `v.safeParse()` or wrap in try/catch and check `v.isValiError(err)` |
| Using raw `result.issues` for UI | Use `v.flatten()` to get a field-keyed error map |
| Defining schemas inside components or functions | Module-level only — schemas are pure configuration |
| `v.any()` for unknown shapes | Define the shape explicitly — `v.unknown()` at worst |
| Forgetting `v.optional()` wraps the whole schema | `v.optional(v.string())` allows undefined; the string rules still apply when present |
