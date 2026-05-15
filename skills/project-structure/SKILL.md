---
name: project-structure
description: Universal project structure principles — feature-based organisation, separation of concerns, test proximity, module boundaries. Applies to any language or framework. Load when scaffolding or deciding where a file belongs.
user-invocable: false
paths:
  - "**/*"
---

Full structure principles in [structure.md](structure.md). Always-on summary:

**Group by feature, not by file type**
- `src/features/payments/` containing model + service + controller + tests is better than `controllers/payments.ts` + `services/payments.ts` in separate trees
- Related code that changes together should live together

**Separate concerns by layer**
- Entry point (controller/handler): validates input, calls service, formats response — no business logic
- Service: business logic only — no HTTP objects, no direct DB calls
- Repository/data layer: data access only — no business logic
- Infrastructure (logger, DB client, config): injected, not imported directly into services

**Tests next to source**
- `payment.service.test.ts` lives beside `payment.service.ts`
- Integration tests in `__tests__/integration/` if you need to distinguish

**Configuration in one place**
- Environment config at the root or `src/config/` — never scattered
- Secrets via environment variables, never hardcoded in source

**For technology-specific folder layouts, consult your installed layer skills:**
- React/frontend → `layers/frontend/react/scaffold`
- Node.js/Express → `layers/backend/node-express/nodejs-standards`