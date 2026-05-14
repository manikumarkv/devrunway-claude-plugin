# Datadog APM Standards

---

## Setup

```bash
npm install dd-trace
```

```typescript
// src/instrument.ts — MUST be the first file imported by your entry point
import tracer from 'dd-trace'

tracer.init({
  service:      process.env.DD_SERVICE ?? 'my-api',
  env:          process.env.DD_ENV     ?? 'development',
  version:      process.env.DD_VERSION ?? process.env.npm_package_version,

  logInjection: true,   // inject trace_id + span_id into log output

  // Sampling — trace 100% of errors, 10% of everything else
  sampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,

  // Auto-instrument popular libraries
  plugins: true,        // http, express, pg, redis, ioredis, mongoose, etc.

  runtimeMetrics: true, // emit CPU, memory, event loop lag metrics
})

export { tracer }
```

```typescript
// src/server.ts — instrument.ts MUST come first
import './instrument'   // ← first import
import express from 'express'
import { db } from './lib/db'
// ...
```

---

## Environment variables

```bash
# Set in your deployment environment — not in code
DD_SERVICE=my-api
DD_ENV=production
DD_VERSION=1.2.3
DD_AGENT_HOST=datadog-agent   # Kubernetes: DaemonSet; local: localhost
DD_TRACE_AGENT_PORT=8126
DD_LOGS_INJECTION=true
DD_RUNTIME_METRICS_ENABLED=true

# In Kubernetes — read from downward API
DD_VERSION=$(kubectl get pod $POD_NAME -o jsonpath='{.metadata.labels.version}')
```

```yaml
# kubernetes/deployment.yaml — inject from pod metadata
env:
  - name: DD_SERVICE
    value: my-api
  - name: DD_ENV
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels['tags.datadoghq.com/env']
  - name: DD_VERSION
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels['tags.datadoghq.com/version']
  - name: DD_AGENT_HOST
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
```

---

## Custom spans

```typescript
import tracer from 'dd-trace'
import { ERROR_MESSAGE, ERROR_TYPE, ERROR_STACK } from 'dd-trace/ext/tags'

// Manual span around a business operation
async function processPayment(orderId: string, amount: number) {
  const span = tracer.startSpan('payment.process', {
    childOf: tracer.scope().active() ?? undefined,  // link to current trace
    tags: {
      'order.id':     orderId,
      'payment.amount': amount,
      'resource.name': 'processPayment',
    },
  })

  try {
    const result = await stripeClient.charges.create({ amount, currency: 'usd' })

    span.setTag('payment.status',   'success')
    span.setTag('payment.chargeId', result.id)

    return result
  } catch (err) {
    // Always tag errors before finishing
    span.setTag(ERROR_MESSAGE, (err as Error).message)
    span.setTag(ERROR_TYPE,    (err as Error).name)
    span.setTag(ERROR_STACK,   (err as Error).stack)
    span.setTag('error', true)

    throw err
  } finally {
    span.finish()   // ALWAYS finish, even on error
  }
}

// Using tracer.wrap() — simpler for functions
const tracedProcessPayment = tracer.wrap(
  'payment.process',
  { tags: { component: 'payments' } },
  processPayment
)
```

---

## Express middleware integration

```typescript
// src/middleware/datadog.ts
import tracer from 'dd-trace'
import type { Request, Response, NextFunction } from 'express'

// Add request context to the current span
export function datadogMiddleware(req: Request, _res: Response, next: NextFunction) {
  const span = tracer.scope().active()
  if (span) {
    // These appear in Datadog traces
    span.setTag('http.route',   req.route?.path ?? req.path)
    span.setTag('user.id',      req.user?.id)
    span.setTag('tenant.id',    req.user?.tenantId)
    span.setTag('request.id',   req.headers['x-request-id'])
  }
  next()
}
```

---

## Logs correlation

```typescript
// src/lib/logger.ts — with Winston + dd-trace log injection
import winston from 'winston'
import tracer from 'dd-trace'

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL ?? 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json(),
    // dd-trace injects dd.trace_id + dd.span_id when logInjection: true
  ),
  transports: [new winston.transports.Console()],
})

// Log output (Datadog-correlated):
// {
//   "message": "Order created",
//   "orderId": "ord_123",
//   "dd": { "trace_id": "...", "span_id": "..." },
//   "timestamp": "2025-01-15T10:30:00.000Z"
// }

export { logger }
```

---

## Custom metrics (DogStatsD)

```typescript
import StatsD from 'hot-shots'

const dogstatsd = new StatsD({
  host:   process.env.DD_AGENT_HOST ?? 'localhost',
  port:   8125,
  prefix: 'myapp.',
  globalTags: {
    env:     process.env.DD_ENV ?? 'development',
    service: process.env.DD_SERVICE ?? 'my-api',
    version: process.env.DD_VERSION ?? '0.0.0',
  },
})

// Counter — track occurrences
dogstatsd.increment('orders.created', { payment_method: 'card' })
dogstatsd.increment('orders.failed',  { reason: 'invalid_card' })

// Histogram — track distributions (latency, sizes)
const start = Date.now()
await processOrder(order)
dogstatsd.histogram('orders.processing_time_ms', Date.now() - start)

// Gauge — track current values
dogstatsd.gauge('queue.depth', queueLength)

// Timing — shorthand for histogram in ms
dogstatsd.timing('db.query_time', queryDuration)
```

---

## Error tracking

```typescript
// Errors auto-captured for:
// - HTTP 5xx responses (via auto-instrumentation)
// - Uncaught exceptions and unhandled rejections

// For custom error tracking in background jobs:
import tracer from 'dd-trace'

async function processJob(job: Job) {
  const span = tracer.startSpan('job.process', {
    tags: {
      'job.id':   job.id,
      'job.type': job.name,
    },
  })

  try {
    await handleJob(job)
  } catch (err) {
    span.setTag('error', true)
    span.setTag(ERROR_MESSAGE, (err as Error).message)
    span.setTag(ERROR_TYPE,    (err as Error).name)
    span.setTag(ERROR_STACK,   (err as Error).stack)
    // Datadog auto-captures this as an error in APM
    throw err
  } finally {
    span.finish()
  }
}
```

---

## Useful Datadog queries

```
# APM — slow endpoints
service:my-api @http.status_code:200 | stats avg(duration) by resource

# Error rate by endpoint
service:my-api @http.status_code:[500 TO 599] | stats count by resource

# Latency p99 by service
service:my-api | stats p99(duration) by service

# Logs — errors in production
service:my-api env:production status:error

# Logs — by trace
service:my-api @dd.trace_id:1234567890

# Infrastructure — host CPU
avg:system.cpu.user{env:production,service:my-api}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `import 'dd-trace'` after other imports | Must be the very first import — `dd-trace` patches modules at require-time |
| No `span.finish()` in catch block | Use try/catch/finally — always `finish()` the span |
| Setting PII in span tags | Hash or redact user-identifying data before tagging |
| `DD_AGENT_HOST=localhost` in Kubernetes | Use the node's IP via downward API `fieldRef: status.hostIP` |
| No `logInjection: true` | Without it, logs and traces can't be correlated |
| Custom metrics without global tags | Add `env`, `service`, `version` to all metrics for proper filtering |
