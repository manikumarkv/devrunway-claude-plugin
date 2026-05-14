---
name: logging-standards
description: Comprehensive logging standards — what to log, when to log, log format/schema, what never to log (PII/secrets), Pino setup, request correlation, frontend error logging, CloudWatch config, Sentry integration. Load whenever writing any code that logs, instruments, or debugs.
user-invocable: false
stack: logging/framework/pino---

Full standards in [logging.md](logging.md). Always-on summary:

---

## Applies to both frontend and backend

### Libraries (locked)
- Backend: **Pino** — structured JSON, never `console.*`
- Frontend: **Sentry** for errors + thin `logger` wrapper — never `console.*` in production builds

### Log levels — same rules everywhere
| Level | When |
|---|---|
| `error` | Unhandled exception, operation failed and requires human action |
| `warn` | Expected-but-notable: auth failure, retry, deprecated path, rate limit hit |
| `info` | Significant business event: order created, payment processed, user signed in |
| `debug` | Dev-only detail: query params, intermediate values — disabled in prod |

### What NEVER to log — no exceptions, frontend or backend
- Passwords, tokens, API keys, secrets of any kind
- Full JWT, Authorization header value, session/refresh cookie
- Credit card numbers, CVV, bank account/routing numbers
- SSN, national ID, passport number
- Email addresses in INFO/DEBUG — only in ERROR with documented justification
- Full name + address combined (PII aggregation)
- Health, biometric, or children's data
- Full request/response bodies on `/auth`, `/payments`, `/users`
- `console.log/error/warn` in production — use the logger
- Template-string messages — values go in the context object, not the string
- Full objects: `logger.info({ user })` → `logger.info({ userId: user.id })`
- Log inside a tight loop — log once before/after with a count

---

## Backend (Node.js / Express) — see [logging.md § Backend](logging.md)

**Every log line must include (auto-set by logger bindings + pino-http):**
```
timestamp · level · service · version · env · host · region · requestId · correlationId
```
Add `userId` on authenticated requests. Add `action` on every line. Add `orderId`, `productId`, etc. for domain context.

**What to log:**
- **HTTP in/out** — `pino-http` handles this automatically; no manual call needed
- **Auth events** — sign-in success/failure, token refresh, sign-out, account lock (security audit trail)
- **Mutations** — resource type + ID + actor userId; never the full payload
- **External calls** — `serviceName`, `endpoint`, `durationMs`, status on every success and failure
- **Background jobs** — start, complete with `itemCount` + `durationMs`, per-item warn, job-level error
- **Errors** — pass as `err` key (Pino serialises the stack); include all relevant IDs

**Quick patterns:**
```ts
// Business event
logger.info({ action: 'order.created', orderId, userId, total }, 'Order created')

// External call failure
logger.error({ action: 'stripe.charge', orderId, durationMs, err }, 'Stripe charge failed')

// Auth failure (warn — not error; user may have mistyped)
logger.warn({ action: 'auth.signIn', maskedEmail, reason: 'invalid_password', attempt }, 'Sign-in failed')
```

**Key setup:**
- `src/lib/logger.ts` — Pino singleton with `redact` for all sensitive paths
- `pino-http` middleware — auto request/response logs; mount before all other middleware
- Child logger — `req.log.child({ userId, action })` in controller; pass into services

---

## Frontend (React) — see [logging.md § Frontend](logging.md)

**What to use:**
- `Sentry.captureException(err)` — for caught errors in critical paths (`checkout`, `payment`)
- `Sentry.withErrorBoundary` — wrap every async page/feature
- `logger.error(message, context)` — goes to Sentry; dev console in non-prod
- `logger.warn/debug` — dev console only; stripped from production build

**After sign-in:** `Sentry.setUser({ id: user.sub })` — ID only, never email or name  
**After sign-out:** `Sentry.setUser(null)`

**Quick patterns:**
```ts
// Caught error in critical path
try {
  await processCheckout()
} catch (err) {
  Sentry.captureException(err, { extra: { orderId, step: 'checkout' } })
  toast.error(t('errors.checkoutFailed'))
}

// Non-fatal warning
logger.warn('Feature flag evaluation failed', { flagKey: 'new-checkout', userId })

// Never
logger.debug('Form submitted', { email, name, address })  // ❌ PII
logger.debug('API response', { data: apiResponse })        // ❌ may contain PII
```

---

**Related skills — apply together:**
- `error-handling` — errorHandler logs via Pino; Sentry captures 5xx
- `checklists` — logging checklist enforces level, structure, requestId, no-PII
- `data-governance` — defines which fields are classified PII
- `security-standards` — logging is the primary accidental PII/secret leak vector
