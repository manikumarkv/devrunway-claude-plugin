---
name: security-standards
description: Security rules and checklist for frontend and backend code. Load when writing auth logic, API endpoints, input handling, secrets management, AWS IAM, or any security-sensitive code.
user-invocable: false
stack: auth/cognito---

## Authentication & Authorization
- All protected routes use `authMiddleware` (Cognito JWT verified with `aws-jwt-verify` — never decoded-only)
- Authorization by Cognito group via `requireGroup('Admin')` — never by username or email
- Frontend tokens stored in memory or `HttpOnly` cookies — never `localStorage`
- Token refresh-and-retry on 401: attempt one refresh, redirect to login on failure
- Full `signOut()` on logout — never just deleting the cookie

## Input Validation
- ALL inputs validated with Zod at system boundaries (API controllers, form submissions)
- Never use raw `req.body`, `req.params`, or `req.query` without Zod parse
- Validate type, format, length, and range — not just presence
- Return 400 with field-level error details on validation failure

## Secrets & Config
- Secrets in AWS Secrets Manager or SSM Parameter Store — never in source code
- `.env` only for local dev; always in `.gitignore`; never committed
- No API keys, tokens, or credentials in frontend bundles (`VITE_` vars are public)
- Environment variables validated with Zod at startup — fail fast if missing

## API Security
- `helmet()` on every Express app (sets secure HTTP headers)
- `express-rate-limit` on all public and auth endpoints
- No sensitive data in error responses returned to clients
- CORS configured explicitly — never `origin: '*'` in production
- HTTPS only — no HTTP in staging or production

## Logging (what NOT to log)
- No `Authorization` headers or JWT tokens
- No passwords, secret keys, or credentials
- No PII unless required and explicitly scrubbed in the log pipeline
- No full request/response bodies on auth endpoints

## AWS IAM
- Least-privilege always — no `"Action": "*"` or `"Resource": "*"` in production policies
- Use IAM roles for service-to-service — never long-lived access keys for services
- Rotate any long-lived access keys (CI/CD) every 90 days
- Enable CloudTrail for all AWS accounts

## Dependency Security
- `npm audit` must pass with no high/critical vulnerabilities before any release
- Pin major dependency versions in `package.json`
- Review new dependencies before adding — check download count, maintainers, last publish

## Review checklist (every PR)
- [ ] No hardcoded secrets, tokens, or credentials
- [ ] All endpoints that need auth have `authMiddleware`
- [ ] Admin operations have `requireGroup('Admin')`
- [ ] All user inputs validated with Zod
- [ ] No sensitive data logged
- [ ] CORS configured correctly
- [ ] `npm audit` passes
