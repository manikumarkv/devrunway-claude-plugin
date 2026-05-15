---
name: joi
description: Joi validation standards — schema definition, error messages, abortEarly, stripUnknown, and TypeScript types. Load when working with Joi.
user-invocable: false
stack: validation/joi
paths:
  - "**/*.schema.ts"
  - "**/*.schema.js"
  - "**/schemas/**"
  - "**/joi*"
---

Full standards in [joi.md](joi.md). Always-on summary:

**Schema structure:**
- Define schemas in dedicated `*.schema.ts` files, co-located with the feature or route
- Export both the schema and the inferred TypeScript type using `ExtractJoiSchema` or manual `type T = { ... }` derived from the schema
- Keep schemas at module level — never define inside a function or request handler

**Validation options (always set these):**
- `abortEarly: false` — collect all errors, not just the first
- `stripUnknown: true` — silently remove fields not in the schema (prevents mass-assignment)
- `allowUnknown: false` (default) — reject payloads with extra fields before stripping

**Error handling:**
- Always check `if (error)` before using `value` from `.validate()`
- Use `error.details` array — each item has `message`, `path`, and `type`
- Return ALL validation errors to the client, not just the first

**Message customisation:**
- Use `.messages({ 'string.email': 'Must be a valid email' })` per field, or
- Use `Joi.defaults()` at startup for global message overrides

**Never:**
- Use the catch-all `any` validator as a shortcut — always use specific type validators (`Joi.string()`, `Joi.number()`, etc.) instead
- Skip `stripUnknown` when validating request bodies — unknown fields may indicate injection
- Call `.required()` on nested object schemas without also calling it on the object itself

**Related skills:** `validation/yup` (browser/form alternative), `backend/node-express` (middleware integration)
