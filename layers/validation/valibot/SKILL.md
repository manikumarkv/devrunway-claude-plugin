---
name: valibot
description: Valibot validation standards — schema definition, TypeScript inference, parse vs safeParse, custom validators. Load when working with Valibot.
user-invocable: false
stack: validation/valibot
paths:
  - "**/*.schema.ts"
  - "**/schemas/**"
  - "**/valibot*"
---

Full standards in [valibot.md](valibot.md). Always-on summary:

**Schema definition:**
- Use `v.object({ ... })` for objects, `v.string()`, `v.number()`, `v.boolean()` for primitives
- Infer TypeScript types with `v.InferOutput<typeof schema>` — never hand-write the type separately
- Define schemas at module level — never inside functions or components

**Parsing:**
- Use `v.parse(schema, data)` when you want to throw on invalid data (safe inside try/catch)
- Use `v.safeParse(schema, data)` when you want to check `.success` without try/catch
- `v.safeParse` returns `{ success: true, output }` or `{ success: false, issues }`
- Always use `v.flatten(issues)` to get a flat `{ nested: { field: ['error'] } }` map

**Pipelines:**
- Use `v.pipe(v.string(), v.email(), v.minLength(1), v.maxLength(254))` for chained validation
- Transformation: `v.pipe(v.string(), v.transform(s => s.toLowerCase()))` — transforms in the pipeline
- Custom rules: `v.check(value => condition, 'Error message')` inside a pipe

**Optional and nullable:**
- `v.optional(schema)` — value can be `undefined`
- `v.nullable(schema)` — value can be `null`
- `v.nullish(schema)` — value can be `null` or `undefined`
- `v.optional` and `v.required` at the object level control which keys are required

**Never:**
- Use `v.any()` — be explicit about the shape
- Skip error flattening — raw `issues` array is hard to map to UI field errors
- Define schemas inside React/Vue components — unnecessary recreation on render

**Related skills:** `validation/zod` (more mature, larger ecosystem), `frontend/vue` (often paired with Valibot for bundle size)
