---
name: nodejs-standards
description: Node.js and backend coding standards, patterns, approved libraries, and anti-patterns. Load when writing, reviewing, or discussing any Node.js/Express backend code, APIs, services, or controllers.
user-invocable: false
stack: backend/node-express---

For the full reference see [nodejs.md](nodejs.md). Summary of rules that always apply:

**Libraries (use these, no alternatives):**
- Runtime: Node.js 20 LTS + TypeScript (strict)
- Framework: Express 4
- Validation: Zod (runtime + compile-time types from same schema)
- Logging: Pino (structured JSON — never `console.log`)
- Auth: `aws-jwt-verify` for Cognito JWT verification
- Security: `helmet` + `express-rate-limit`
- ORM: Prisma (SQL) or AWS DynamoDB DocumentClient v3 (NoSQL)
- Testing: Vitest + Supertest + MSW for external APIs
- API testing: Bruno collections

**Architecture layers (strict separation):**
```
Route → Controller → Service → Repository → DB
```
- Controller: validate input (Zod), call service, return response — nothing else
- Service: business logic only — no HTTP objects (`req`/`res`)
- Repository: DB access only — no business logic
- Middleware: auth, logging, rate limiting, error handling

**Non-negotiable patterns:**
- All async handlers: `asyncHandler(fn)` wrapper — never bare `async (req, res) => {}`
- All input: Zod schema at controller boundary before any use
- All responses: `{ success: true, data }` or `{ success: false, error: { code, message, details } }`
- All logging: Pino with `requestId`, `userId`, `action` fields — never `console.*`
- Centralized error middleware — never `res.status(500)` inline

**Anti-patterns (never do):**
- `console.log` / `console.error` anywhere
- `any` type
- Raw `req.body` without Zod validation
- DB calls in controllers
- Business logic in repositories
- Missing `asyncHandler` on route handlers
- Inline try/catch that swallows errors silently
- Hardcoded secrets or config values
