# Monitoring Standards

---

## Frontend — error boundaries

Every route and every async feature component gets an error boundary. A single top-level boundary catches nothing useful — boundaries must be granular.

```tsx
// src/components/ErrorBoundary/ErrorBoundary.tsx
import { Component, type ReactNode } from 'react'
import * as Sentry from '@sentry/react'

type Props = { children: ReactNode; fallback?: ReactNode }
type State = { hasError: boolean; eventId?: string }

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false }

  static getDerivedStateFromError(): State {
    return { hasError: true }
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    const eventId = Sentry.captureException(error, {
      extra: { componentStack: info.componentStack },
    })
    this.setState({ eventId })
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div role="alert" className="p-4 text-red-600">
          Something went wrong.{' '}
          <button onClick={() => this.setState({ hasError: false })}>Try again</button>
        </div>
      )
    }
    return this.props.children
  }
}
```

```tsx
// src/pages/OrdersPage.tsx — wrap feature components
import { ErrorBoundary } from '@/components/ErrorBoundary'
import { OrderList } from '@/features/orders'

export function OrdersPage() {
  return (
    <ErrorBoundary fallback={<p>Failed to load orders.</p>}>
      <OrderList />
    </ErrorBoundary>
  )
}
```

---

## Frontend — Sentry setup

```bash
npm install @sentry/react
```

```ts
// src/main.tsx
import * as Sentry from '@sentry/react'

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.VITE_ENV,        // 'staging' | 'production'
  enabled: import.meta.env.VITE_ENV !== 'development',
  tracesSampleRate: import.meta.env.VITE_ENV === 'production' ? 0.1 : 1.0,
  replaysSessionSampleRate: 0.05,
  replaysOnErrorSampleRate: 1.0,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
})
```

**Identify users after login:**

```ts
// src/features/auth/hooks/useAuthUser.ts — after sign-in
Sentry.setUser({ id: user.sub, email: user.email })

// On sign-out
Sentry.setUser(null)
```

---

## Frontend — web vitals

```ts
// src/lib/webVitals.ts
import { onCLS, onFCP, onFID, onLCP, onTTFB } from 'web-vitals'

function sendToAnalytics(metric: { name: string; value: number; rating: string }) {
  // Send to your own API endpoint — avoids third-party analytics
  fetch('/api/metrics', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: metric.name,
      value: Math.round(metric.value),
      rating: metric.rating,           // 'good' | 'needs-improvement' | 'poor'
      page: window.location.pathname,
    }),
    keepalive: true,
  })
}

export function reportWebVitals() {
  onCLS(sendToAnalytics)
  onFCP(sendToAnalytics)
  onFID(sendToAnalytics)
  onLCP(sendToAnalytics)
  onTTFB(sendToAnalytics)
}
```

```ts
// src/main.tsx
import { reportWebVitals } from './lib/webVitals'
reportWebVitals()
```

**Targets (Core Web Vitals):**

| Metric | Good | Needs improvement | Poor |
|---|---|---|---|
| LCP (Largest Contentful Paint) | ≤ 2.5s | ≤ 4s | > 4s |
| FID (First Input Delay) | ≤ 100ms | ≤ 300ms | > 300ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

---

## Backend — structured logging with Pino

```ts
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  ...(process.env.NODE_ENV === 'development' && {
    transport: { target: 'pino-pretty' },
  }),
})
```

```ts
// src/middleware/requestLogger.ts
import pinoHttp from 'pino-http'
import { logger } from '../lib/logger'
import { randomUUID } from 'crypto'

export const requestLogger = pinoHttp({
  logger,
  genReqId: () => randomUUID(),          // Every request gets a requestId
  customProps: (req) => ({
    userId: (req as any).user?.sub,      // Attach after auth middleware
  }),
})
```

Every log line must have: `requestId`, `method`, `url`, `statusCode`, `responseTime`.

**Log levels:**
- `logger.error` — unhandled exceptions, failed integrations
- `logger.warn` — recoverable issues (retry succeeded, deprecated usage)
- `logger.info` — business events (order created, user logged in)
- `logger.debug` — development only (never in production)

---

## Backend — CloudWatch

**Custom metrics via EMF (Lambda):**

```ts
// src/lib/metrics.ts
export function emitMetric(name: string, value: number, unit = 'Count') {
  // EMF format — CloudWatch parses structured log lines
  console.log(JSON.stringify({
    _aws: {
      Timestamp: Date.now(),
      CloudWatchMetrics: [{
        Namespace: 'MyApp',
        Dimensions: [['Environment']],
        Metrics: [{ Name: name, Unit: unit }],
      }],
    },
    Environment: process.env.ENVIRONMENT ?? 'unknown',
    [name]: value,
  }))
}
```

```ts
// In service layer
emitMetric('OrderCreated', 1)
emitMetric('OrderFailed', 1)
emitMetric('CheckoutDuration', durationMs, 'Milliseconds')
```

---

## CloudWatch alarms

Define in CDK:

```ts
// infra/lib/alarms.ts
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch'

// Lambda error rate > 1% for 5 minutes
new cloudwatch.Alarm(this, 'ApiErrorRate', {
  metric: lambdaFunction.metricErrors().createAlarm(this, 'Errors', {
    threshold: 1,
    evaluationPeriods: 5,
    comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
    treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
  }),
  alarmDescription: 'Lambda error rate exceeded 1%',
})

// API p99 latency > 2s
new cloudwatch.Alarm(this, 'ApiLatencyP99', {
  metric: api.metricLatency({ statistic: 'p99' }),
  threshold: 2000,
  evaluationPeriods: 3,
  alarmDescription: 'API p99 latency exceeded 2s',
})
```

---

## Never

- `console.log` in production backend code — use `logger.info`
- `console.error` as a substitute for Sentry — it disappears after the session
- Missing error boundaries — uncaught errors blank the whole page
- Catching errors silently without logging or reporting them

```ts
// ❌ Silent catch
try {
  await placeOrder(data)
} catch (e) {
  setError('Something went wrong')  // error never reaches Sentry
}

// ✅ Catch, report, surface
try {
  await placeOrder(data)
} catch (e) {
  Sentry.captureException(e)
  setError('Something went wrong')
}
```
