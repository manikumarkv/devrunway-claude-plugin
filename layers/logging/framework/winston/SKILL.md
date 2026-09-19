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

> **Scope — applies only if this project uses winston.** This layer shares `**/logger*`, `**/logging/**` with `pino` in `layers/logging/`, so more than one may load at once and their rules conflict. If the project is not using winston, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Logger setup:**
- Create one `winston.createLogger(` instance — export it as a singleton
- Use `format.combine(` to compose multiple formatters; always include `format.json(` for production
- Add `transports: [` array with a `new winston.transports.Console(` entry at minimum
- Human-readable format in development only (`winston.format.prettyPrint()`)

**Log levels — use the right one:**
- `error` — unrecoverable errors that require attention (exceptions, failed health checks)
- `warn` — recoverable issues that shouldn't happen (retries, deprecated usage)
- `info` — significant business events (user created, order shipped, payment processed)
- `debug` — development detail — never in production by default

**Structured logging — message first, metadata second:**
- Winston's signature is `logger.info(message, meta)`. Always pass the message string first and the metadata object second: `logger.info('Order shipped', { userId, orderId })`
- Do **not** use Pino's argument order (metadata object first). Winston takes the first argument as the log entry, so an object there becomes the `message` field and the string that follows is discarded — the event name never reaches the log
- Never interpolate variables into message strings: ❌ `logger.info(\`Order ${id} shipped\`)` → ❌ breaks search
- Include `userId` and resource `id` on every log in a user-scoped context

**PII — hard rules:**
- Never log: `email`, `password`, `phone`, `name`, `token`, `creditCard`, `ssn`, `dateOfBirth`
- Use Winston's `format.printf` or a custom format to redact fields before they hit transports

**Never:**
- `console.*` methods in production code — they bypass log level filtering, format, and transports
- Log full request/response bodies — they contain PII and credentials
- Use `error` level for expected errors (404, 400) — use `warn`

**Related skills:** `data-governance` (PII field list), your logging provider layer (CloudWatch, Datadog transport config)
