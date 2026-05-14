---
name: sentry-monitoring
description: Sentry error monitoring patterns — init config, captureException, ErrorBoundary, release tracking, PII scrubbing. Load when working with Sentry integration.
user-invocable: false
stack: error-monitoring/sentry
paths:
  - "src/lib/sentry*"
  - "sentry.*.config.*"
  - "**/*.tsx"
  - "**/*.ts"
---

Full standards in [sentry-monitoring.md](sentry-monitoring.md). Always-on summary:

**Init (app entry point):**
- `Sentry.init({ dsn, environment, release, tracesSampleRate: 0.1 })`
- `release` must match CI deployment tag — use `VITE_SENTRY_RELEASE` env var
- `tracesSampleRate`: 0.1 in production, 1.0 in staging/dev

**PII scrubbing — mandatory:**
- `beforeSend`: strip `user.email`, `user.name`, fields matching `/password|token|secret/i`
- `Sentry.setUser({ id: userId })` — ID only, never email or name

**React:**
- Wrap root with `<Sentry.ErrorBoundary fallback={<ErrorPage />}>`
- `captureException(err, { extra: { context } })` — add context but no PII

**Noise reduction:**
- `denyUrls: [/extensions\//i, /^chrome:\/\//i]` in init config
- `captureMessage()` for expected-but-notable errors (external API degraded)

**Source maps:** upload in CI via `@sentry/webpack-plugin` — keep private, not committed

**Alert routing:** Sentry Alert Rule for `New Issue` → Slack channel per project

**Related skills:** `logging-standards` (Pino for backend; Sentry for frontend errors), `security-standards` (PII rules)
