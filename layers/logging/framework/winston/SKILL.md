---
name: winston
description: Winston logging conventions — singleton logger, transports, log levels, structured JSON output, request logging, and PII redaction. Load when working with Winston.
user-invocable: false
stack: logging/framework/winston
paths:
  - "**/logger*"
  - "**/winston*"
  - "**/logging/**"
---

Full standards in [winston.md](winston.md). Always-on summary:

**Logger setup:**
- Create one `winston.createLogger()` instance — export it as a singleton
- Always use JSON format in production (`winston.format.json()`)
- Human-readable format in development only (`winston.format.prettyPrint()`)

**Log levels — use the right one:**
- `error` — unrecoverable errors that require attention (exceptions, failed health checks)
- `warn` — recoverable issues that shouldn't happen (retries, deprecated usage)
- `info` — significant business events (user created, order shipped, payment processed)
- `debug` — development detail — never in production by default

**Structured logging:**
- Always pass metadata as the first argument, message as the second: `logger.info({ userId, orderId }, 'Order shipped')`
- Never interpolate variables into message strings: ❌ `logger.info(\`Order ${id} shipped\`)` → ❌ breaks search
- Include `userId` and resource `id` on every log in a user-scoped context

**PII — hard rules:**
- Never log: `email`, `password`, `phone`, `name`, `token`, `creditCard`, `ssn`, `dateOfBirth`
- Use Winston's `format.printf` or a custom format to redact fields before they hit transports

**Never:**
- `console.log()` in production code — it bypasses log level filtering, format, and transports
- Log full request/response bodies — they contain PII and credentials
- Use `error` level for expected errors (404, 400) — use `warn`

**Related skills:** `data-governance` (PII field list), your logging provider layer (CloudWatch, Datadog transport config)
