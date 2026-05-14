---
name: yup
description: Yup validation standards — schema chaining, TypeScript inference, custom validators, and form integration. Load when working with Yup.
user-invocable: false
stack: validation/yup
paths:
  - "**/*.schema.ts"
  - "**/*.schema.js"
  - "**/schemas/**"
  - "**/yup*"
---

Full standards in [yup.md](yup.md). Always-on summary:

**Schema structure:**
- Define schemas in dedicated `*.schema.ts` files, co-located with the feature
- Use `yup.InferType<typeof schema>` for TypeScript types — never hand-write the type separately
- Always define the schema as `const` outside of the component so it isn't recreated on each render

**Validation settings:**
- Always use `abortEarly: false` so all errors surface at once (not just the first)
- Use `stripUnknown: true` in `schema.validate()` when accepting external input — removes extra fields silently

**Chaining:**
- Chain validators in specificity order: `string().email().required().max(255)`
- Put `.required()` last in the chain so the error message is clear
- Use `.nullable()` when `null` is a valid value (distinct from `undefined`)

**Custom validators:**
- Use `.test('name', 'message', fn)` for custom rules; return `true` to pass, `false` or `this.createError()` to fail
- Async validators: `.test('name', 'message', async (value) => ...)` — Yup handles the Promise
- For cross-field validation (password confirm), use `.test()` on the object schema with `this.parent`

**Error messages:**
- Override default messages via `yup.setLocale()` once at app startup — not per-schema
- Use `createError({ message, path })` in `.test()` for precise error placement

**Never:**
- Define schemas inside React components — unnecessary recreation on every render
- Use `.required()` and `.nullable()` together without understanding the distinction: `.nullable().required()` means "must be non-null but not necessarily non-empty string"
- Skip `abortEarly: false` in form validation — users need all errors at once

**Related skills:** `validation/joi` (server-side alternative), `layers/frontend/react` (react-hook-form integration)
