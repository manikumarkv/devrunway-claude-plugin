---
name: packages
description: Approved packages for frontend and backend — use these, not alternatives. Load when adding a dependency, reviewing a package.json, or choosing between libraries.
user-invocable: false
stack: frontend/react
---

Full list in [packages.md](packages.md). Always-on summary:

**Frontend — use these:**
- Styling: `tailwindcss` + `clsx` + `tailwind-merge`
- Data fetching: `@tanstack/react-query` v5
- Routing: `react-router-dom` v6
- Forms: `react-hook-form` + `@hookform/resolvers`
- Validation: `zod`
- Auth: `aws-amplify`
- HTTP: native `fetch` via project API client — not `axios`
- Dates: `date-fns` — not `moment`
- Icons: `lucide-react`
- Tables: `@tanstack/react-table`
- Animations: `framer-motion`
- Testing: `vitest` + `@testing-library/react` + `msw` + `@playwright/test`

**Backend — use these:**
- Framework: `express` + `@types/express`
- Validation: `zod`
- Logging: `pino` + `pino-http`
- Auth: `aws-jwt-verify`
- ORM (SQL): `prisma`
- DB client (NoSQL): `@aws-sdk/client-dynamodb` + `@aws-sdk/lib-dynamodb`
- Security: `helmet` + `express-rate-limit`
- Testing: `vitest`

**Never use:** `moment`, `lodash` (use native JS), `axios` (use fetch), `passport` (use aws-jwt-verify), `jsonwebtoken` (use aws-jwt-verify), `sequelize`/`typeorm` (use prisma), `jest` (use vitest)


**Related skills — apply together:**
- `project-structure` — approved packages are placed in specific layers (lib/, utils/, features/)
- `security` — helmet, express-rate-limit, and aws-jwt-verify are mandatory, not optional