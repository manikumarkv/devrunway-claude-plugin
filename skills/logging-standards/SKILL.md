---
name: logging-standards
description: Comprehensive logging standards — what to log, when to log, log format/schema, what never to log (PII/secrets), Pino setup, request correlation, frontend error logging, CloudWatch config, Sentry integration. Load whenever writing any code that logs, instruments, or debugs.
user-invocable: false
---

Full standards in [logging.md](logging.md). Always-on summary:

**Library (locked):**
- Backend: **Pino** — structured JSON, never `console.*`
- Frontend: **Sentry** for errors + thin `logger` wrapper for critical client events — never `console.*` in production builds

**Every log line must include:**
```
requestId · level · timestamp · action · service
```
Add `userId` on authenticated requests. Add domain context (`orderId`, `productId`, etc.) for the operation.

**Log levels — pick the right one:**
| Level | When |
|---|---|
| `error` | Unhandled exception, operation failed and requires human action |
| `warn` | Expected-but-notable: auth failure, retry attempt, deprecated path, rate limit hit |
| `info` | Significant business event: order created, payment processed, user signed in |
| `debug` | Dev-only detail: query params, branch taken, intermediate values — disabled in prod |

**What to log — by action type:**
- **API request/response** — method, path, statusCode, durationMs, requestId (pinoHttp handles this automatically)
- **Auth events** — sign-in success/failure, token refresh, sign-out (always — security audit trail)
- **Mutations** — resource type, resourceId, actor userId (never the full payload)
- **External calls** — serviceName, endpoint, durationMs, status code or error code
- **Background jobs** — jobName, start, complete, itemCount, durationMs, error if failed
- **Errors** — pass error as `err` key; include all relevant IDs for traceability

**What NEVER to log — no exceptions:**
- Passwords, tokens, API keys, secrets of any kind
- Full JWT value, Authorization header, session/refresh cookie
- Credit card, CVV, bank account/routing numbers
- SSN, national ID, passport number
- Email addresses in INFO/DEBUG — only in ERROR with documented justification
- Full name + address combined (PII aggregation)
- Health, biometric, or children's data
- Full request/response bodies on `/auth`, `/payments`, `/users`

**Never:**
- `console.log/error/warn` anywhere in production code — always Pino
- Template-string messages: `logger.info(\`Order ${id} created\`)` — values in context object
- Full objects: `logger.info({ user })` — pick IDs only: `logger.info({ userId: user.id })`
- Log inside a tight loop — log once before/after with a count
- Same event at multiple levels

**Related skills — apply together:**
- `error-handling` — errorHandler logs via Pino; Sentry captures 5xx
- `checklists` — logging checklist enforces level, structure, requestId, no-PII
- `data-governance` — defines which fields are classified PII
- `security-standards` — logging is the primary accidental PII/secret leak vector
