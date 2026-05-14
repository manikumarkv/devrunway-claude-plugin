---
name: monitoring
description: Frontend monitoring standards — error boundaries, Sentry setup, web vitals, CloudWatch for backend. Load when adding error handling, observability, or performance tracking.
user-invocable: false
stack: cloud/aws---

Full standards in [monitoring.md](monitoring.md). Always-on summary:

**Frontend:**
- Error boundaries wrap every route and every async feature component
- Sentry: `Sentry.init` in `main.tsx`, `Sentry.captureException` in error boundaries
- Web vitals: `getCLS`, `getFID`, `getLCP` reported to CloudWatch via API
- `console.error` is NOT monitoring — it disappears after the session

**Backend:**
- Pino structured logs — every request has `requestId`, `userId`, `duration`
- CloudWatch Log Insights queries for error rates and p99 latency
- Lambda: report custom metrics via EMF (Embedded Metric Format)
- Never `console.log` in production — use `logger.info/warn/error`

**Alerting:**
- CloudWatch alarm on Lambda error rate > 1% for 5 minutes
- CloudWatch alarm on API p99 latency > 2s
- Sentry alert on new issue or error spike


**Related skills — apply together:**
- `error-handling` — Sentry.captureException in error boundaries; structured logs on 5xx backend errors
- `cdk` — CloudWatch alarms and EMF metrics are defined in MonitoringStack
- `security` — never log sensitive fields (tokens, passwords, PII) in Pino or CloudWatch