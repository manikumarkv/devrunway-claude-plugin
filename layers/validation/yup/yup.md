# Yup Standards

---

## Setup

```bash
npm install yup
```

---

## Schema definitions and TypeScript inference

```typescript
// src/features/orders/order.schema.ts
import * as yup from 'yup'

export const orderSchema = yup.object({
  customerId: yup.string().uuid('Must be a valid UUID').required('Customer is required'),
  status:     yup.string()
                 .oneOf(['pending', 'shipped', 'delivered'] as const, 'Invalid status')
                 .required('Status is required'),
  total:      yup.number()
                 .min(0, 'Total must be non-negative')
                 .required('Total is required'),
  notes:      yup.string().max(500, 'Notes cannot exceed 500 characters').optional(),
  tags:       yup.array(yup.string().required()).default([]),
  address: yup.object({
    line1:    yup.string().required('Address line 1 is required'),
    line2:    yup.string().optional(),
    city:     yup.string().required('City is required'),
    postcode: yup.string().matches(/^\d{5}(-\d{4})?$/, 'Invalid postcode').required(),
    country:  yup.string().length(2, 'Use ISO 3166-1 alpha-2 code').required(),
  }).required(),
})

// Infer the type — NEVER hand-write this separately
export type OrderInput = yup.InferType<typeof orderSchema>
```

---

## Validation — always abortEarly: false

```typescript
// Validate and collect ALL errors (not just the first)
async function validateOrder(data: unknown): Promise<OrderInput> {
  try {
    return await orderSchema.validate(data, {
      abortEarly:    false,   // collect ALL errors
      stripUnknown: true,     // remove extra fields
    })
  } catch (err) {
    if (err instanceof yup.ValidationError) {
      // err.inner contains one error per failing field
      const fieldErrors = err.inner.reduce<Record<string, string>>(
        (acc, e) => ({ ...acc, [e.path!]: e.message }),
        {}
      )
      throw new ValidationError(fieldErrors)
    }
    throw err
  }
}
```

---

## Common field schemas

```typescript
import * as yup from 'yup'

// Email
const email = yup.string().email('Invalid email').lowercase().required('Email is required')

// Password
const password = yup
  .string()
  .min(8, 'Password must be at least 8 characters')
  .matches(/[A-Z]/, 'Must contain an uppercase letter')
  .matches(/[0-9]/, 'Must contain a number')
  .required('Password is required')

// URL
const url = yup.string().url('Must be a valid URL').required()

// Phone
const phone = yup
  .string()
  .matches(/^\+?[1-9]\d{1,14}$/, 'Must be a valid E.164 phone number')
  .required()

// Date (as ISO string)
const isoDate = yup.string().datetime({ allowOffset: true }).required()

// Enum
const status = yup
  .mixed<'active' | 'inactive'>()
  .oneOf(['active', 'inactive'] as const)
  .required()

// File upload
const file = yup
  .mixed<File>()
  .test('fileSize', 'File must be under 5 MB', (val) =>
    !val || (val instanceof File && val.size <= 5 * 1024 * 1024)
  )
  .test('fileType', 'Only PNG, JPG, WEBP allowed', (val) =>
    !val || ['image/png', 'image/jpeg', 'image/webp'].includes((val as File).type)
  )
```

---

## Custom validators with .test()

```typescript
// Simple synchronous test
const username = yup
  .string()
  .required()
  .test('no-spaces', 'Username cannot contain spaces', (value) => {
    return !value?.includes(' ')
  })

// Async test (e.g., server-side uniqueness check)
const uniqueEmail = yup
  .string()
  .email()
  .required()
  .test('is-unique', 'Email is already registered', async (value) => {
    if (!value) return true   // let required() handle empty
    const exists = await checkEmailExists(value)
    return !exists
  })

// Cross-field validation on the object schema
const passwordConfirmSchema = yup.object({
  password:        yup.string().min(8).required(),
  confirmPassword: yup.string()
    .required('Please confirm your password')
    .test('passwords-match', 'Passwords must match', function (value) {
      return this.parent.password === value
      // Use function() not arrow fn so `this` is available
    }),
})

// createError for precise error placement
const conditionalSchema = yup.object({
  paymentMethod: yup.string().oneOf(['card', 'bank']).required(),
  cardNumber:    yup.string().test('card-required', 'Card number is required', function (value) {
    if (this.parent.paymentMethod === 'card' && !value) {
      return this.createError({ message: 'Card number is required', path: 'cardNumber' })
    }
    return true
  }),
})
```

---

## Global locale / error messages

```typescript
// src/lib/yup.ts — run once at app startup
import { setLocale } from 'yup'

setLocale({
  mixed: {
    required:  'This field is required',
    oneOf:     '${path} must be one of: ${values}',
    notType:   '${path} must be a ${type}',
  },
  string: {
    email:  'Must be a valid email address',
    min:    '${path} must be at least ${min} characters',
    max:    '${path} cannot exceed ${max} characters',
    url:    'Must be a valid URL',
  },
  number: {
    min:      '${path} must be at least ${min}',
    max:      '${path} cannot exceed ${max}',
    positive: '${path} must be positive',
    integer:  '${path} must be a whole number',
  },
  array: {
    min: 'Select at least ${min} item(s)',
    max: 'Cannot select more than ${max} item(s)',
  },
})
```

---

## React Hook Form integration

```tsx
import { useForm } from 'react-hook-form'
import { yupResolver } from '@hookform/resolvers/yup'
import { orderSchema, type OrderInput } from './order.schema'

export function OrderForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<OrderInput>({
    resolver: yupResolver(orderSchema),
    defaultValues: {
      status: 'pending',
      tags:   [],
    },
  })

  async function onSubmit(data: OrderInput) {
    // data is fully typed and validated
    await createOrder(data)
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('customerId')} />
      {errors.customerId && <p>{errors.customerId.message}</p>}

      <input {...register('total', { valueAsNumber: true })} type="number" />
      {errors.total && <p>{errors.total.message}</p>}

      <button type="submit" disabled={isSubmitting}>Save</button>
    </form>
  )
}
```

---

## Schema composition — reuse and extend

```typescript
// Base schema shared across create and update
const baseProductSchema = yup.object({
  name:        yup.string().max(100).required(),
  description: yup.string().max(2000).optional(),
  price:       yup.number().positive().required(),
})

// Create: price is required
export const createProductSchema = baseProductSchema

// Update: all fields are optional (partial)
export const updateProductSchema = baseProductSchema.partial()
// .partial() makes all fields optional while preserving validation rules

export type CreateProductInput = yup.InferType<typeof createProductSchema>
export type UpdateProductInput = yup.InferType<typeof updateProductSchema>

// Extend a schema with extra fields
export const adminProductSchema = baseProductSchema.shape({
  internalCode: yup.string().matches(/^[A-Z]{2}-\d{4}$/).required(),
  costPrice:    yup.number().positive().required(),
})
```

---

## Lazy schemas (conditional schema selection)

```typescript
// Different schema based on runtime value
const paymentSchema = yup.lazy((value: { method: string }) =>
  value.method === 'card'
    ? yup.object({
        method:     yup.string().oneOf(['card']).required(),
        cardNumber: yup.string().matches(/^\d{16}$/).required(),
        cvv:        yup.string().matches(/^\d{3,4}$/).required(),
        expiry:     yup.string().matches(/^\d{2}\/\d{2}$/).required(),
      })
    : yup.object({
        method:    yup.string().oneOf(['bank']).required(),
        accountNo: yup.string().matches(/^\d{8}$/).required(),
        sortCode:  yup.string().matches(/^\d{2}-\d{2}-\d{2}$/).required(),
      })
)
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `abortEarly: true` (default) | Always pass `abortEarly: false` — users need all errors at once |
| Schema defined inside a component | Define schemas at module level — not recreated on render |
| Hand-writing the TypeScript type alongside the schema | `type T = yup.InferType<typeof schema>` — the schema IS the type |
| `.required().nullable()` confusion | `.nullable()` = null is valid; `.required()` = must not be undefined/empty string; order matters |
| Using arrow function in `.test()` that references `this` | Use `function` keyword when you need `this.parent` or `this.createError()` |
| No locale override — cryptic default messages | Call `setLocale()` once at app startup |
| Validating on every keypress with async `.test()` | Debounce or trigger validation only on blur |
