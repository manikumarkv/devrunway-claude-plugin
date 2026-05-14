# Joi Standards

---

## Setup

```bash
npm install joi
npm install --save-dev @types/joi   # if using older Joi; v17+ ships own types
```

---

## Schema definition

```typescript
// src/features/orders/order.schema.ts
import Joi from 'joi'

export const createOrderSchema = Joi.object({
  customerId: Joi.string().uuid().required(),
  status:     Joi.string().valid('pending', 'shipped', 'delivered').required(),
  total:      Joi.number().min(0).required(),
  notes:      Joi.string().max(500).optional().allow(''),
  tags:       Joi.array().items(Joi.string().max(50)).default([]),
  address: Joi.object({
    line1:    Joi.string().max(200).required(),
    line2:    Joi.string().max(200).optional().allow(''),
    city:     Joi.string().max(100).required(),
    postcode: Joi.string().pattern(/^\d{5}(-\d{4})?$/).required()
               .messages({ 'string.pattern.base': 'Postcode must be in XXXXX or XXXXX-XXXX format' }),
    country:  Joi.string().length(2).uppercase().required()
               .messages({ 'string.length': 'Country must be a 2-letter ISO code' }),
  }).required(),
})

// TypeScript type — derive from Joi description
// Joi v17 does not have built-in InferType; write the type from the schema
export interface CreateOrderInput {
  customerId: string
  status:     'pending' | 'shipped' | 'delivered'
  total:      number
  notes?:     string
  tags:       string[]
  address: {
    line1:    string
    line2?:   string
    city:     string
    postcode: string
    country:  string
  }
}
```

---

## Validation — always abortEarly: false

```typescript
interface ValidationResult<T> {
  data:   T | null
  errors: Record<string, string> | null
}

function validate<T>(schema: Joi.Schema, input: unknown): ValidationResult<T> {
  const { error, value } = schema.validate(input, {
    abortEarly:    false,   // collect ALL errors
    stripUnknown:  true,    // remove extra fields
    convert:       true,    // type coercions (string → number etc.)
  })

  if (error) {
    const errors = error.details.reduce<Record<string, string>>((acc, detail) => {
      const key = detail.path.join('.')   // e.g. 'address.postcode'
      acc[key] = detail.message
      return acc
    }, {})
    return { data: null, errors }
  }

  return { data: value as T, errors: null }
}

// Usage
const { data, errors } = validate<CreateOrderInput>(createOrderSchema, req.body)
if (errors) {
  return res.status(422).json({ error: { code: 'VALIDATION_ERROR', details: errors } })
}
// data is now typed and stripped
```

---

## Express middleware

```typescript
// src/middleware/validate.ts
import Joi from 'joi'
import { Request, Response, NextFunction } from 'express'

type Target = 'body' | 'query' | 'params'

export function validate(schema: Joi.Schema, target: Target = 'body') {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req[target], {
      abortEarly:   false,
      stripUnknown: true,
      convert:      true,
    })

    if (error) {
      const details = error.details.reduce<Record<string, string>>((acc, d) => {
        acc[d.path.join('.')] = d.message
        return acc
      }, {})
      return res.status(422).json({ error: { code: 'VALIDATION_ERROR', details } })
    }

    req[target] = value   // replace with stripped + converted value
    next()
  }
}

// Usage in routes
import { validate } from '../middleware/validate'
import { createOrderSchema } from './order.schema'

router.post('/orders', validate(createOrderSchema, 'body'), createOrderHandler)
```

---

## Common field schemas

```typescript
import Joi from 'joi'

// Email
const email = Joi.string().email({ tlds: { allow: false } }).lowercase().max(254).required()

// Password
const password = Joi.string()
  .min(8)
  .pattern(/[A-Z]/, 'uppercase letter')
  .pattern(/[0-9]/, 'digit')
  .required()
  .messages({
    'string.pattern.name': 'Password must contain at least one {#name}',
  })

// UUID
const id = Joi.string().uuid({ version: 'uuidv4' }).required()

// ISO date string
const isoDate = Joi.string().isoDate().required()

// URL
const url = Joi.string().uri({ scheme: ['http', 'https'] }).required()

// Enum
const status = Joi.string().valid('active', 'inactive', 'pending').required()

// Pagination query params
const paginationSchema = Joi.object({
  limit:  Joi.number().integer().min(1).max(100).default(20),
  cursor: Joi.string().optional(),
})
```

---

## Conditional and cross-field validation

```typescript
// when() — conditional schema
const paymentSchema = Joi.object({
  method:     Joi.string().valid('card', 'bank').required(),
  cardNumber: Joi.when('method', {
    is:        'card',
    then:      Joi.string().creditCard().required(),
    otherwise: Joi.forbidden(),
  }),
  accountNo:  Joi.when('method', {
    is:        'bank',
    then:      Joi.string().pattern(/^\d{8}$/).required(),
    otherwise: Joi.forbidden(),
  }),
})

// Password confirmation
const signupSchema = Joi.object({
  email:           Joi.string().email().required(),
  password:        Joi.string().min(8).required(),
  confirmPassword: Joi.any().valid(Joi.ref('password')).required()
    .messages({ 'any.only': 'Passwords must match' }),
})

// Custom validator
const positiveEvenSchema = Joi.number().custom((value, helpers) => {
  if (value % 2 !== 0) {
    return helpers.error('number.even')   // custom error type
  }
  return value
}).messages({
  'number.even': '{{#label}} must be an even number',
})
```

---

## Global defaults

```typescript
// src/lib/joi.ts — run once at app startup
import Joi from 'joi'

// Override default messages globally
const customJoi = Joi.defaults((schema) =>
  schema.options({
    abortEarly:   false,
    stripUnknown: true,
  })
)

// Or set global language
// Joi uses a messages object per rule type
// To fully replace, pass messages per schema or use a validation wrapper
export { customJoi as Joi }
```

---

## Schema composition

```typescript
// Shared base schema
const timestampsMixin = {
  createdAt: Joi.string().isoDate(),
  updatedAt: Joi.string().isoDate(),
}

// Extend with .append()
const productSchema = Joi.object({
  name:  Joi.string().max(100).required(),
  price: Joi.number().positive().required(),
})

const adminProductSchema = productSchema.append({
  internalCode: Joi.string().pattern(/^[A-Z]{2}-\d{4}$/).required(),
  costPrice:    Joi.number().positive().required(),
})

// Partial schema (all keys optional) — useful for PATCH endpoints
const updateProductSchema = productSchema.fork(
  Object.keys(productSchema.describe().keys),
  (field) => field.optional()
)
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `abortEarly: true` (default) | Always pass `abortEarly: false` — collect all errors |
| Skipping `stripUnknown: true` on request bodies | Unknown fields can be used for mass-assignment attacks |
| Using `Joi.any()` for unknown shapes | Be explicit — define the expected shape even if partial |
| `.optional()` and `.required()` together on nested objects | Declare the nesting object itself as required if its contents are required |
| Not checking `if (error)` before using `value` | The `value` is `undefined` when validation fails |
| Defining schema inside a request handler | Module-level only — schemas are stateless and safe to reuse |
| Returning only the first error to the client | Use `error.details` array — map all errors to a `Record<string, string>` |
