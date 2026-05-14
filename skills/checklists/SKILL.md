---
name: checklists
description: Quality checklists for every development action — API creation/modification, component creation, page creation/update, API integration, logging, DB queries, DB schema changes. Auto-apply the relevant checklist whenever one of these actions is taken.
user-invocable: false
---

Full checklists in [checklists.md](checklists.md).

**When to apply each checklist — trigger automatically:**

| Action | Checklist to apply |
|---|---|
| Creating or modifying a route / controller | **API Creation / Modification** |
| Creating a new React component | **Component Creation** |
| Creating or updating a page/view/route | **Page Creation / Update** |
| Calling a backend API from the frontend | **API Integration** |
| Adding any log statement | **Logging** |
| Writing a Prisma query / raw SQL | **DB Query** |
| Adding or altering a Prisma model / migration | **DB Schema Change** |

Apply the checklist **before marking work as done**. Every unchecked item is a gap that needs addressing or an explicit decision to skip with a reason.

**Related skills:**
- `api-conventions` — response envelope, status codes, route naming
- `error-handling` — centralized handler, AppError subclasses
- `swagger-docs` — OpenAPI registration for every route
- `react-standards` — shadcn/ui, useSearchParams, toast patterns
- `linting` — ESLint rules enforced on every file touched
- `database-sql` — Prisma patterns, safe migrations, seeders
- `logging-standards` — pino structured logging, log levels, PII rules
- `testing-standards` — unit + integration + E2E coverage expectations
