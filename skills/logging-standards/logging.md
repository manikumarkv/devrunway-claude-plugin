# Logging Standards

---

## Stack

| Layer | Tool | Purpose |
|---|---|---|
| Backend structured logs | **Pino** | JSON logs, child loggers, redaction, pino-http |
| Frontend error capture | **Sentry** (`@sentry/react`) | Unhandled errors, caught exceptions, user context |
| Frontend critical events | Thin `logger` wrapper over `console` | Warn/error only — stripped in prod builds |
| Log shipping | **CloudWatch Logs** (via Lambda/ECS log driver) | Retention, metric filters, alarms |
| Error aggregation | **Sentry** | Grouping, alerts, stack traces, release tracking |

---

## Backend — Pino setup

### Logger singleton

```ts
// src/lib/logger.ts
import pino, { type Logger } from 'pino'
import { env } from './env'

export const logger: Logger = pino({
  level: env.LOG_LEVEL ?? 'info',   // 'debug' | 'info' | 'warn' | 'error'

  // Always emit ISO timestamps
  timestamp: pino.stdTimeFunctions.isoTime,

  // Rename pino's default 'msg' field to 'message' for CloudWatch Insights compatibility
  messageKey: 'message',

  // Rewrite level number → label ('info' not 30)
  formatters: {
    level: (label) => ({ level: label }),
    // Attach service name to every log line
    bindings: (bindings) => ({
      service: env.SERVICE_NAME ?? 'api',
      env:     env.NODE_ENV,
      pid:     bindings.pid,
    }),
  },

  // Automatic redaction — strips these paths before the log is written
  // Never rely on code-level checks alone — redact defensively here too
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'body.password',
      'body.passwordConfirm',
      'body.currentPassword',
      'body.token',
      'body.refreshToken',
      'body.accessToken',
      'body.cardNumber',
      'body.cvv',
      'body.ssn',
      '*.password',
      '*.token',
      '*.secret',
      '*.apiKey',
      '*.privateKey',
    ],
    censor: '[REDACTED]',
  },

  // Pretty-print in development only — JSON in all other envs
  transport: env.NODE_ENV === 'development'
    ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:standard', ignore: 'pid,hostname' } }
    : undefined,
})
```

### pino-http middleware — automatic request/response logging

```bash
npm install pino-http
```

```ts
// src/middleware/httpLogger.ts
import pinoHttp from 'pino-http'
import { logger } from '../lib/logger'
import { randomUUID } from 'crypto'

export const httpLogger = pinoHttp({
  logger,

  // Generate requestId for every request; attach to req and response header
  genReqId: (req, res) => {
    const id = (req.headers['x-request-id'] as string) ?? randomUUID()
    res.setHeader('X-Request-Id', id)
    return id
  },

  // Custom log fields added to every request/response log line
  customLogLevel: (_req, res, err) => {
    if (err || res.statusCode >= 500) return 'error'
    if (res.statusCode >= 400) return 'warn'
    return 'info'
  },

  customSuccessMessage: (req, res) =>
    `${req.method} ${req.url} — ${res.statusCode}`,

  customErrorMessage: (_req, res, err) =>
    `Request failed — ${res.statusCode}: ${err.message}`,

  // Fields to include in each request log
  customReceivedObject: (req) => ({
    action:    'http_request',
    method:    req.method,
    url:       req.url,
    userAgent: req.headers['user-agent'],
  }),

  // Fields to include in each response log
  customSuccessObject: (req, res, val) => ({
    action:     'http_response',
    statusCode: res.statusCode,
    durationMs: val.responseTime,
    requestId:  res.getHeader('X-Request-Id'),
  }),

  // Never log the full body — too much noise and potential PII
  serializers: {
    req: (req) => ({
      id:     req.id,
      method: req.method,
      url:    req.url,
    }),
    res: (res) => ({
      statusCode: res.statusCode,
    }),
  },
})
```

Mount order in `app.ts`:
```ts
app.use(httpLogger)   // ← must be first middleware; sets req.id and req.log
app.use(express.json())
app.use('/api/v1', routes)
app.use(notFoundHandler)
app.use(errorHandler)
```

### Child logger — attach request context once, propagate everywhere

```ts
// In a controller — create child logger with request context
export const createOrder = asyncHandler(async (req, res) => {
  const log = req.log.child({ userId: req.user.sub, action: 'createOrder' })

  log.debug({ body: { productId: req.body.productId, quantity: req.body.quantity } }, 'Creating order')

  const order = await orderService.create(req.body, req.user)

  log.info({ orderId: order.id, total: order.total }, 'Order created')

  created(req, res, order)
})
```

Pass the child logger into services — do not re-import the root logger in services:

```ts
// Service receives logger as a parameter — easier to test, no coupling to request cycle
export async function createOrder(
  input: CreateOrderInput,
  user: AuthUser,
  log: Logger,  // passed from controller
): Promise<Order> {
  log.debug({ productId: input.productId }, 'Checking inventory')
  const inventory = await inventoryRepo.get(input.productId)

  if (inventory.stock < input.quantity) {
    log.warn({ productId: input.productId, available: inventory.stock, requested: input.quantity }, 'Insufficient stock')
    throw new UnprocessableError('Insufficient stock', { available: String(inventory.stock), requested: String(input.quantity) })
  }

  const order = await orderRepo.create(input, user.sub)
  log.info({ orderId: order.id }, 'Order persisted')
  return order
}
```

---

## Log field schema — standard fields

Every log line must contain these fields. Pino/pino-http populates the first group automatically.

### Always-present (auto-populated)
| Field | Type | Example | Source |
|---|---|---|---|
| `timestamp` | ISO 8601 | `2026-05-14T10:30:00.000Z` | Pino |
| `level` | string | `info` | Pino |
| `service` | string | `api` | Logger bindings |
| `env` | string | `production` | Logger bindings |
| `message` | string | `Order created` | Your code |

### Per-request (populated by pino-http)
| Field | Type | Example | Source |
|---|---|---|---|
| `requestId` | UUID | `a1b2-c3d4` | pino-http genReqId |
| `method` | string | `POST` | pino-http |
| `url` | string | `/api/v1/orders` | pino-http |
| `statusCode` | number | `201` | pino-http |
| `durationMs` | number | `43` | pino-http |

### Per-operation (your code adds these)
| Field | Type | When to add | Example |
|---|---|---|---|
| `action` | string | Every log line | `createOrder`, `processPayment` |
| `userId` | string | Authenticated requests | `sub` from JWT |
| `resourceId` | string | Any mutation or read | `orderId`, `productId` |
| `resourceType` | string | Generic error handlers | `Order`, `Product` |
| `durationMs` | number | External calls, jobs | `142` |
| `err` | Error object | Any `logger.error()` | Pino serialises stack |
| `reason` | string | Warn/error on expected failures | `insufficient_stock`, `token_expired` |
| `attempt` | number | Retries | `2` |

---

## What to log — by action type

### 1 — HTTP requests and responses
Handled automatically by `pino-http`. Do not add extra `logger.info` calls for request start/end — it would duplicate lines.

**Only add a manual log when:**
- The route has unusual business significance (payment processed, account deleted)
- You need extra context that pino-http doesn't capture

### 2 — Authentication events

```ts
// Sign-in success
logger.info({ userId, action: 'auth.signIn', method: 'password' }, 'User signed in')

// Sign-in failure — warn, not error (expected; user may have mistyped password)
logger.warn({ email: maskedEmail, action: 'auth.signIn', reason: 'invalid_password', attempt }, 'Sign-in failed')

// Account locked after too many attempts
logger.warn({ email: maskedEmail, action: 'auth.accountLocked', lockedUntil }, 'Account locked')

// Token refresh
logger.debug({ userId, action: 'auth.tokenRefresh' }, 'Token refreshed')

// Sign-out
logger.info({ userId, action: 'auth.signOut' }, 'User signed out')

// Suspicious: valid token but expired session
logger.warn({ userId, action: 'auth.sessionExpired', requestPath: req.path }, 'Session expired')
```

> Always log auth failures — they are the primary signal for brute-force and credential-stuffing detection.

### 3 — Resource mutations (CRUD)

```ts
// ✅ — log resource type, ID, actor, and key business fields only
logger.info(
  { action: 'order.created', orderId: order.id, userId, total: order.total, itemCount: items.length },
  'Order created',
)

logger.info(
  { action: 'order.statusChanged', orderId, userId, from: 'PENDING', to: 'CONFIRMED' },
  'Order status updated',
)

logger.info(
  { action: 'order.deleted', orderId, userId },
  'Order deleted',
)

// ❌ — never log the full input or full entity
logger.info({ action: 'order.created', body: req.body }, 'Order created')       // may contain PII
logger.info({ action: 'order.created', order: fullOrderObject }, 'Order created') // too much data
```

### 4 — External service calls (HTTP, AWS SDK, third-party)

```ts
const start = Date.now()
try {
  const result = await stripeClient.charges.create(chargeParams)
  logger.info(
    { action: 'stripe.charge', chargeId: result.id, amount: chargeParams.amount, durationMs: Date.now() - start },
    'Stripe charge succeeded',
  )
} catch (err) {
  logger.error(
    { action: 'stripe.charge', orderId, amount: chargeParams.amount, durationMs: Date.now() - start, err },
    'Stripe charge failed',
  )
  throw err  // re-throw — don't swallow
}
```

> Rule: every external call gets a log on **success** (`info`) and **failure** (`error`) with `durationMs`. This is how you spot slow dependencies in CloudWatch.

### 5 — Background jobs / queues

```ts
// Job start
logger.info({ action: 'job.orderDigestEmail.start', scheduledAt: new Date() }, 'Job started')

// Job complete
logger.info(
  { action: 'job.orderDigestEmail.complete', processedCount: 142, failedCount: 2, durationMs },
  'Job completed',
)

// Individual item failure inside job — warn, not error (job continues)
logger.warn(
  { action: 'job.orderDigestEmail.itemFailed', userId, reason: err.message },
  'Email failed for user',
)

// Job-level failure — error (job aborted)
logger.error(
  { action: 'job.orderDigestEmail.failed', err, processedCount },
  'Job failed',
)
```

### 6 — Database / query events

Do not log every query — Prisma's query logging in development is sufficient for that.

**Log these DB events:**
```ts
// Unexpected missing record (after findUniqueOrThrow would have thrown — use that instead)
logger.warn({ action: 'db.recordNotFound', table: 'orders', id: orderId }, 'Record not found')

// Slow query detected (if you have a timing wrapper)
if (durationMs > 500) {
  logger.warn({ action: 'db.slowQuery', table, operationType, durationMs }, 'Slow query')
}

// Migration ran at startup
logger.info({ action: 'db.migrated', appliedCount }, 'Migrations applied')
```

### 7 — Application startup / shutdown

```ts
// Server ready
logger.info({ action: 'server.start', port: env.PORT, env: env.NODE_ENV }, 'Server started')

// Graceful shutdown triggered
logger.info({ action: 'server.shutdown', signal }, 'Graceful shutdown initiated')

// Shutdown complete
logger.info({ action: 'server.shutdown.complete', durationMs }, 'Server stopped')

// Config validation failure at startup (always fatal)
logger.fatal({ action: 'config.invalid', errors: configErrors }, 'Invalid configuration — exiting')
process.exit(1)
```

---

## What NEVER to log

### Secrets and credentials
```ts
// ❌ — all of these must never appear in any log
logger.info({ token: req.headers.authorization })   // JWT / Bearer token
logger.info({ password: req.body.password })         // plaintext password
logger.info({ apiKey: process.env.STRIPE_SECRET })   // API key
logger.info({ body: req.body })                      // body may contain any of the above

// ✅ — log what you need, redact everything else
logger.info({ userId, action: 'auth.signIn' }, 'Sign-in attempt')
```

Pino's `redact` config in the logger singleton catches most of these at the framework level, but defensive coding matters — do not pass sensitive fields at all.

### PII — personal identifiable information

| Data | Classification | Logging rule |
|---|---|---|
| Email address | PII | Allowed in `error` only; mask for `warn/info`: `j***@example.com` |
| Full name | PII | Never log; use userId to look up in admin tools |
| Phone number | PII | Never log |
| Home address | PII | Never log |
| Date of birth | PII | Year only is OK for analytics; never full DOB |
| IP address | Quasi-PII | OK in security audit logs; not in business event logs |
| Credit card number | PCI-DSS | Never — ever |
| CVV / expiry | PCI-DSS | Never — ever |
| Bank account / routing | PCI-DSS | Never — ever |
| SSN / National ID | Sensitive PII | Never — ever |
| Passport number | Sensitive PII | Never — ever |
| Health / medical data | HIPAA/GDPR special | Never — ever |
| Biometric data | GDPR special | Never — ever |
| Children's data (under 13) | COPPA/GDPR special | Never — ever |

```ts
// ❌ — PII in log
logger.info({ email: user.email, name: user.fullName, action: 'user.updated' }, 'User updated')

// ✅ — ID only; look up name/email in admin panel using the ID
logger.info({ userId: user.id, action: 'user.updated', fields: ['email', 'fullName'] }, 'User updated')

// ✅ — masked email in error context (acceptable with justification)
const maskedEmail = email.replace(/(.{2})(.*)(@.*)/, '$1***$3')   // jo***@example.com
logger.error({ maskedEmail, action: 'auth.signIn', reason: 'account_not_found' }, 'Sign-in failed')
```

### Full objects and bodies

```ts
// ❌ — full object may contain PII, secrets, or just too much noise
logger.info({ user })
logger.info({ order })
logger.info({ body: req.body })
logger.info({ response: apiResponse })

// ✅ — extract only what you need
logger.info({ userId: user.id, roleId: user.roleId })
logger.info({ orderId: order.id, status: order.status, total: order.total })
logger.info({ productId: req.body.productId, quantity: req.body.quantity })
logger.info({ chargeId: apiResponse.id, status: apiResponse.status })
```

### Loops

```ts
// ❌ — one log per item = thousands of log lines; CloudWatch costs money
for (const order of orders) {
  logger.info({ orderId: order.id }, 'Processing order')
  await processOrder(order)
}

// ✅ — log once before, once after, and once per failure
logger.info({ action: 'job.processDailyOrders.start', count: orders.length }, 'Processing orders')
let failed = 0
for (const order of orders) {
  try {
    await processOrder(order)
  } catch (err) {
    failed++
    logger.warn({ orderId: order.id, err }, 'Order processing failed')
  }
}
logger.info({ action: 'job.processDailyOrders.complete', total: orders.length, failed }, 'Orders processed')
```

---

## Log format — full JSON shape

Every production log line is a flat JSON object. Example for an `info` business event:

```json
{
  "level": "info",
  "timestamp": "2026-05-14T10:30:42.123Z",
  "service": "api",
  "env": "production",
  "requestId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "userId": "clxyz123",
  "action": "order.created",
  "orderId": "clabc456",
  "total": 49.99,
  "itemCount": 2,
  "message": "Order created"
}
```

Error log with stack trace:
```json
{
  "level": "error",
  "timestamp": "2026-05-14T10:30:43.456Z",
  "service": "api",
  "env": "production",
  "requestId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "userId": "clxyz123",
  "action": "stripe.charge",
  "orderId": "clabc456",
  "durationMs": 1203,
  "err": {
    "type": "StripeCardError",
    "message": "Your card has insufficient funds.",
    "stack": "StripeCardError: Your card has insufficient funds.\n    at ..."
  },
  "message": "Stripe charge failed"
}
```

---

## Frontend logging

### Sentry setup — captures all unhandled errors automatically

```bash
npm install @sentry/react
```

```ts
// src/lib/sentry.ts
import * as Sentry from '@sentry/react'
import { env } from './env'

export function initSentry() {
  if (env.VITE_ENV === 'production' || env.VITE_ENV === 'staging') {
    Sentry.init({
      dsn:         env.VITE_SENTRY_DSN,
      environment: env.VITE_ENV,
      release:     env.VITE_APP_VERSION,

      integrations: [
        Sentry.browserTracingIntegration(),
        Sentry.replayIntegration({
          maskAllText:   true,   // GDPR: mask all text in session replays
          blockAllMedia: true,
        }),
      ],

      tracesSampleRate:   0.1,   // 10% of transactions for performance monitoring
      replaysOnErrorSampleRate: 1.0,  // 100% of sessions with errors

      // Strip PII from breadcrumbs and events before sending to Sentry
      beforeSend(event) {
        // Remove any accidentally captured auth headers
        if (event.request?.headers) {
          delete event.request.headers['Authorization']
          delete event.request.headers['Cookie']
        }
        return event
      },
    })
  }
}
```

```tsx
// src/main.tsx
import { initSentry } from './lib/sentry'
initSentry()
```

### Set user context — helps trace errors to a specific user

```ts
// After sign-in — set user context on Sentry (ID only, never PII)
import * as Sentry from '@sentry/react'

export function onSignIn(user: AuthUser) {
  Sentry.setUser({ id: user.sub })   // id only — never email, name, or other PII
}

export function onSignOut() {
  Sentry.setUser(null)
}
```

### Error boundaries — wrap every async feature

```tsx
// src/shared/components/ErrorBoundary/ErrorBoundary.tsx
import * as Sentry from '@sentry/react'

// Use Sentry's built-in error boundary so errors are captured automatically
export const ErrorBoundary = Sentry.withErrorBoundary

// Usage — wrap every route-level feature
<ErrorBoundary fallback={<ErrorFallback />}>
  <OrdersPage />
</ErrorBoundary>
```

### Frontend logger wrapper — warn/error only, stripped in production

```ts
// src/lib/logger.ts
import * as Sentry from '@sentry/react'

const isProd = import.meta.env.PROD

export const logger = {
  /** Captured by Sentry and written to console in dev */
  error(message: string, context?: Record<string, unknown>) {
    if (!isProd) console.error('[error]', message, context)  // eslint-disable-line no-console
    Sentry.captureMessage(message, {
      level: 'error',
      extra: context,
    })
  },

  /** Console warn in dev only; not sent to Sentry (too noisy) */
  warn(message: string, context?: Record<string, unknown>) {
    if (!isProd) console.warn('[warn]', message, context)    // eslint-disable-line no-console
  },

  /** Debug: dev only, stripped from prod builds */
  debug(message: string, context?: Record<string, unknown>) {
    if (!isProd) console.debug('[debug]', message, context)  // eslint-disable-line no-console
  },
}
```

### What to capture on the frontend

```ts
// ✅ — unexpected mutation failure not covered by React Query's onError
logger.error('Payment form submit failed', { step: 'card_tokenisation', orderId })

// ✅ — feature flag evaluation error
logger.warn('Feature flag evaluation failed', { flagKey: 'new-checkout', userId })

// ✅ — manual Sentry capture for caught errors in critical paths
try {
  await processCheckout()
} catch (err) {
  Sentry.captureException(err, { extra: { orderId, step: 'checkout' } })
  toast.error(t('errors.checkoutFailed'))
}

// ❌ — never log user input, form values, or API responses with PII
logger.debug('Form submitted', { email, name, address })  // PII
logger.debug('API response', { data: apiResponse })        // may contain PII
```

---

## Pino redact — defence-in-depth

The `redact` config in the logger singleton is a safety net, not a substitute for careful coding. Paths are dot-notation and support wildcards:

```ts
redact: {
  paths: [
    // Auth headers
    'req.headers.authorization',
    'req.headers.cookie',
    'req.headers["x-api-key"]',

    // Common body fields
    'body.password',
    'body.currentPassword',
    'body.newPassword',
    'body.token',
    'body.refreshToken',
    'body.accessToken',
    'body.idToken',
    'body.cardNumber',
    'body.cvv',
    'body.ssn',

    // Wildcard — catches nested objects too
    '*.password',
    '*.token',
    '*.secret',
    '*.apiKey',
    '*.privateKey',
    '*.accessKey',
  ],
  censor: '[REDACTED]',
}
```

Verify redaction works in development:
```ts
logger.info({ body: { password: 'should-not-appear', productId: 'clxyz' } }, 'test')
// Output: { "body": { "password": "[REDACTED]", "productId": "clxyz" }, "message": "test" }
```

---

## CloudWatch configuration

### Log group naming convention

```
/aws/lambda/<service>-<env>         e.g. /aws/lambda/api-production
/aws/lambda/<service>-<env>-worker  e.g. /aws/lambda/api-production-worker
```

### Retention policy — set in CDK, never leave at "Never expire"

```ts
// infra/stacks/LoggingStack.ts
import { LogGroup, RetentionDays } from 'aws-cdk-lib/aws-logs'

new LogGroup(this, 'ApiLogGroup', {
  logGroupName: `/aws/lambda/${serviceName}-${env}`,
  retention: env === 'production' ? RetentionDays.THREE_MONTHS : RetentionDays.TWO_WEEKS,
})
```

### CloudWatch Insights queries

```
# All errors in the last hour — with trace
fields @timestamp, level, message, err.message, userId, requestId, action
| filter level = "error"
| sort @timestamp desc
| limit 100

# Slow API requests (> 1s)
fields @timestamp, method, url, durationMs, statusCode, requestId
| filter durationMs > 1000
| sort durationMs desc
| limit 50

# Auth failures — detect brute-force attempts
fields @timestamp, maskedEmail, action, reason, attempt
| filter action like "auth." and level = "warn"
| stats count() as failures by maskedEmail
| sort failures desc
| limit 20

# Orders created in last 24 h — business metric
fields @timestamp, userId, orderId, total
| filter action = "order.created"
| stats count() as orderCount, sum(total) as revenue by bin(1h)
| sort @timestamp desc

# External service slow calls (> 500ms)
fields @timestamp, action, durationMs, message
| filter action like /\.(charge|send|upload)/ and durationMs > 500
| sort durationMs desc
| limit 50

# Errors by user — find a specific user's error trail
fields @timestamp, level, message, action, err.message
| filter userId = "clxyz123"
| sort @timestamp desc
| limit 50
```

### Metric filters — turn log patterns into CloudWatch metrics

```ts
// infra/stacks/LoggingStack.ts
import { MetricFilter, FilterPattern } from 'aws-cdk-lib/aws-logs'

// Count errors per minute → alarm when > 10
new MetricFilter(this, 'ErrorMetric', {
  logGroup,
  metricNamespace: 'App/Errors',
  metricName:      'ErrorCount',
  filterPattern:   FilterPattern.stringValue('$.level', '=', 'error'),
  metricValue:     '1',
})

// Track order creation rate
new MetricFilter(this, 'OrderCreatedMetric', {
  logGroup,
  metricNamespace: 'App/Business',
  metricName:      'OrdersCreated',
  filterPattern:   FilterPattern.stringValue('$.action', '=', 'order.created'),
  metricValue:     '1',
})
```

---

## Log sampling — high-volume paths

Some paths generate too many `info` logs at scale. Sample them to control cost:

```ts
// src/lib/logger.ts — add a sampled child logger
export function sampledLogger(logger: Logger, sampleRate: number): Logger {
  // sampleRate: 0.1 = log 10% of events
  return {
    ...logger,
    info(obj: object, msg?: string) {
      if (Math.random() < sampleRate) logger.info(obj, msg)
    },
  } as Logger
}

// Usage — health check hits every 30s; log only 10%
const healthLog = sampledLogger(logger, 0.1)
app.get('/health', (req, res) => {
  healthLog.debug({ action: 'health.check' }, 'Health check')
  res.json({ status: 'ok' })
})
```

---

## Common mistakes

### Mistake 1 — Template string as message

```ts
// ❌ — values interpolated into the string; not searchable in CloudWatch
logger.info(`Order ${orderId} created for user ${userId}`)

// ✅ — values in the context object; filterable and queryable
logger.info({ orderId, userId, action: 'order.created' }, 'Order created')
```

### Mistake 2 — Logging inside a catch then re-throwing

```ts
// ❌ — the same error gets logged twice (once here, once in errorHandler)
try {
  await processOrder(order)
} catch (err) {
  logger.error({ err }, 'Order processing failed')  // logged here
  throw err                                          // AND in errorHandler
}

// ✅ — only log if you handle the error; if you re-throw, let errorHandler log it
try {
  await processOrder(order)
} catch (err) {
  // Add context and re-throw — errorHandler will log it
  throw new UnprocessableError('Order processing failed', { orderId: order.id })
}
```

### Mistake 3 — Logging `err` without the key name

```ts
// ❌ — 'error' is not the Pino serialiser key; stack trace won't appear
logger.error({ error: err }, 'Failed')

// ✅ — 'err' is the key Pino's error serialiser watches
logger.error({ err }, 'Failed')
```

### Mistake 4 — Missing `action` field

```ts
// ❌ — impossible to filter by this operation in CloudWatch
logger.info({ userId, orderId }, 'Done')

// ✅ — 'action' is the primary grouping field for Insights queries
logger.info({ userId, orderId, action: 'order.shipped' }, 'Order shipped')
```

### Mistake 5 — Debug logs left in production paths

```ts
// ❌ — debug calls still compile to production even if level filters them out;
//      adding huge objects here creates serialisation cost at every call
logger.debug({ fullRequest: req, fullResponse: response }, 'API call debug')

// ✅ — guard heavy serialisation so it never runs in production
if (process.env.NODE_ENV !== 'production') {
  logger.debug({ requestPath: req.path, responseStatus: response.status }, 'API call')
}
```
