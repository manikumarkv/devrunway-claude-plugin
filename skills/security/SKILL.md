---
name: security
description: Security standards for the full stack — OWASP top 10 applied to React, Express, Cognito, Prisma, DynamoDB, S3, and CDK. Load when writing auth, API endpoints, file uploads, or reviewing any code before PR.
user-invocable: false
---

Full standards in [security.md](security.md). Always-on summary:

**Authentication & authorization:**
- Verify Cognito JWT on every protected route via `aws-jwt-verify` — never decode without verifying
- Group-based authorization via `requireGroup('admin')` middleware — never trust client-sent roles
- Check resource ownership in the service layer on every read/write — not just auth

**Input:**
- Zod `.parse()` on all request body, params, and query — never `req.body.field` directly
- Never use `req.body` values in raw SQL or shell commands
- Prisma parameterized queries only — never string-concatenate into queries

**Output:**
- Never send `err.message` or stack traces to clients — use `AppError.code` only
- React escapes by default — never use `dangerouslySetInnerHTML` with user content

**Infrastructure:**
- helmet on every Express app — never disable defaults
- Rate limiting on auth routes (5 req/15 min) and API routes (100 req/min)
- S3: presigned URLs only — never expose bucket directly, set 15-min expiry
- Secrets in SSM/Secrets Manager only — never in env files committed to git

**Never:**
- `jwt.decode()` without `jwt.verify()`
- Trusting `req.user.role` from the token claims for authorization — use Cognito groups
- Wildcard CORS (`*`) in production
- `eval()`, `Function()`, or `child_process.exec()` with user input
