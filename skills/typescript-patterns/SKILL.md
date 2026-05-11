---
name: typescript-patterns
description: TypeScript patterns for React and Node.js — discriminated unions, type narrowing, generics, utility types, branded IDs, exhaustive checks. Load when writing or reviewing any TypeScript code.
user-invocable: false
---

Full patterns in [typescript.md](typescript.md). Always-on summary:

**Never:**
- `any` — use `unknown` with narrowing
- `as SomeType` without a comment explaining why it's safe
- Optional chaining as a substitute for proper typing (`foo?.bar?.baz` everywhere means the types are wrong)
- Parallel boolean flags for state — use discriminated unions

**Always:**
- Discriminated unions for state that has multiple exclusive modes
- Type guards (`is`) and `satisfies` over type assertions
- Exhaustive `never` checks in switch statements
- Branded types for IDs (never pass a `userId` where `postId` is expected)
- Explicit return types on all exported functions
- `const` assertions for static lookup objects
