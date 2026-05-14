---
name: project-structure
description: Frontend and backend folder structure standards — where every file type lives, naming conventions, module boundaries. Load when scaffolding a new project, adding a feature, or deciding where a file belongs.
user-invocable: false
---

Full structure in [structure.md](structure.md). Always-on summary:

**Frontend (React + Vite):**
- Features in `src/features/<name>/` — types, api, hooks, components all co-located
- Shared UI in `src/components/` — no business logic
- Shared hooks in `src/hooks/` — no API calls (those live in features)
- Global state in `src/stores/` — only truly global, non-server state
- Route pages in `src/pages/` — thin wrappers, no logic
- Named exports everywhere — no default exports in feature folders

**Backend (Node.js + Express):**
- `src/controllers/` — validate input (Zod), call service, format response
- `src/services/` — business logic only, no HTTP objects, no DB calls
- `src/repositories/` — DB access only, no business logic
- `src/middleware/` — auth, logging, rate limiting, error handling
- `src/types/` — Zod schemas + inferred TypeScript types
- `src/utils/` — pure utility functions (no side effects)
- `src/lib/` — third-party client setup (prisma, dynamo, logger)


**Related skills — apply together:**
- `packages` — use only approved packages; structure determines where each goes
- `typescript-patterns` — naming conventions and file boundaries enforce TypeScript module isolation
- `scaffold` — use `/scaffold` to generate the folder structure automatically