---
name: type-safety
description: Universal type safety principles — validate at boundaries, make invalid states unrepresentable, prefer explicit types over implicit. Applies to any typed language (TypeScript, Python type hints, Java, C#, Go). Load when writing or reviewing any code.
user-invocable: false
paths:
  - "**/*"
---

Always-on type safety principles:

**Validate at the boundary, trust inside**
- Data from external sources (API requests, file input, user input, environment variables) must be validated at the entry point before it enters the system
- Once validated, pass typed values — never re-validate the same data deep inside the system
- A function that accepts typed parameters should be able to trust those types

**Make invalid states unrepresentable**
- Model state with variants, not boolean flags — parallel flags create impossible combinations
- A loading state should not also carry data; a success state should not also carry an error
- If two values are always changed together, model them as a single value

**Prefer explicit over implicit**
- Explicit type annotations on all public/exported functions
- Infer private/internal types from implementation only when the type is obvious
- Never use a "catch-all" type (`any`, `object`, untyped `dict`) without a comment explaining why

**Fail safely at the boundary, never silently inside**
- When validation fails at the boundary, fail loudly (throw, return error) — never proceed with invalid data
- Avoid silent coercions (e.g. `"42" → 42`, `null → 0`) — they hide bugs
- Prefer returning explicit error values over null/undefined for expected failure cases

**Make the language's type checker work for you**
- Exhaustive checks: when you handle variants, ensure the language catches unhandled new cases at compile time
- Branded/nominal types for domain IDs: a `UserId` and a `PostId` should not be interchangeable even if both are strings
- Favour composition of small, precise types over large generic ones

**For language-specific implementation, consult your language layer:**
- TypeScript → `layers/language/typescript/`
- Python → `layers/language/python/` *(stub)*
- Java / Kotlin → `layers/language/java/` *(stub)*
