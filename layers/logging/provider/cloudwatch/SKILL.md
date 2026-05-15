---
name: cloudwatch-logging
description: CloudWatch log standards — retention CDK construct, Insights queries, metric filters, structured log format. Load when working with CloudWatch logs.
user-invocable: false
stack: logging/provider/cloudwatch
paths:
  - "infra/**"
  - "cdk/**"
  - "src/lib/logger*"
---

Full standards in [cloudwatch-logging.md](cloudwatch-logging.md). Always-on summary:

**Log groups:**
- Every LogGroup needs retention: `retention: RetentionDays.ONE_MONTH` minimum in CDK
- Naming convention: set `logGroupName` to `/aws/lambda/<service>/<function>` or `/app/<service>/<environment>`

**Format:** structured JSON required — CloudWatch Insights can't parse unstructured text

**Required fields in every log line:** `timestamp`, `level`, `service`, `requestId`, `message`

**Sending logs via SDK:**
- Use `PutLogEventsCommand` with the correct `sequenceToken` from the previous `PutLogEvents` response — missing the token causes `InvalidSequenceTokenException`

**Essential Insights queries:**
- Errors: `fields @timestamp, @message | filter level = "error" | sort @timestamp desc | limit 100`
- Slow requests: `fields @timestamp, responseTime | filter responseTime > 3000 | sort responseTime desc`
- 5xx: `fields @timestamp, path, statusCode | filter statusCode >= 500`

**Alarms:** Define a `MetricFilter` with a `filterPattern` to extract error counts, then create a `Alarm` at > 5 errors per 5 minutes

**Never:** log PII — redact at the logger level with Pino `redact:`

**Cross-account:** Kinesis Data Firehose + subscription filter for log shipping

**Related skills:** `logging-standards` (Pino setup, what to log), `security-standards` (PII rules)
