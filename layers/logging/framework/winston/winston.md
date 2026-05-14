# Winston Logging Standards

---

## Singleton logger

```typescript
// src/lib/logger.ts — one logger for the whole app
import winston from 'winston'

const PII_FIELDS = ['email', 'password', 'phone', 'name', 'token',
                    'creditCard', 'ssn', 'dateOfBirth', 'address', 'secret']

// Redact PII fields from log metadata
const redactPii = winston.format((info) => {
  const redact = (obj: Record<string, unknown>): Record<string, unknown> => {
    const result = { ...obj }
    for (const key of PII_FIELDS) {
      if (key in result) result[key] = '[redacted]'
    }
    return result
  }

  return { ...redact(info as Record<string, unknown>), message: info.message }
})

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL ?? (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),

  format: winston.format.combine(
    winston.format.timestamp(),
    redactPii(),
    process.env.NODE_ENV === 'production'
      ? winston.format.json()
      : winston.format.combine(
          winston.format.colorize(),
          winston.format.printf(({ level, message, timestamp, ...meta }) => {
            const metaStr = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : ''
            return `${timestamp} [${level}] ${message}${metaStr}`
          })
        )
  ),

  transports: [
    new winston.transports.Console(),
  ],

  // Do not crash the process on uncaught exceptions — log them instead
  exceptionHandlers: [new winston.transports.Console()],
  rejectionHandlers: [new winston.transports.Console()],
})

// Silence logger during tests
if (process.env.NODE_ENV === 'test') {
  logger.silent = true
}
```

---

## Log levels

| Level | Number | When to use |
|---|---|---|
| `error` | 0 | Unrecoverable — requires human attention |
| `warn` | 1 | Recoverable — retried, degraded, deprecated |
| `info` | 2 | Business events — create, update, delete, auth |
| `http` | 3 | Inbound HTTP requests (morgan/express integration) |
| `debug` | 4 | Developer detail — only in development |
| `silly` | 5 | Very verbose — never in production |

```typescript
// ✅ Correct level usage
logger.error({ err, userId, orderId }, 'Payment charge failed — manual review required')
logger.warn({ userId, attempts }, 'Login failed — rate limiting may apply')
logger.info({ userId, orderId, amount }, 'Order created')
logger.debug({ query, params }, 'Executing DB query')

// ❌ Wrong levels
logger.error('User not found')       // 404 is expected — use warn or info
logger.info('Password is invalid')   // never log anything about passwords
```

---

## Structured logging — metadata first

```typescript
// ✅ Metadata as first arg — parseable, searchable, filterable
logger.info({ userId: 'u123', orderId: 'o456', amount: 4000 }, 'Order created')
logger.error({ err: error, userId, orderId }, 'Failed to process payment')
logger.warn({ userId, ip, attempts: 5 }, 'Multiple failed login attempts')

// ❌ String interpolation — breaks log search and parsing
logger.info(`Order ${orderId} created by user ${userId}`)
logger.error(`Failed: ${error.message}`)
```

Structured logs are queryable in log aggregators (CloudWatch Insights, Datadog, Splunk):
```sql
-- CloudWatch Insights
filter @message = "Order created" | stats count() by userId
```

---

## Child loggers — binding context

```typescript
// Bind context for a request — every log in that request includes userId and requestId
const requestLogger = logger.child({
  requestId: req.id,
  userId: req.user?.id,
})

requestLogger.info('Processing order')
requestLogger.error({ err }, 'Order processing failed')
// Output: { requestId, userId, message: 'Processing order', ... }
```

---

## HTTP request logging with Morgan

```typescript
// src/middleware/request-logger.ts
import morgan from 'morgan'
import { logger } from '../lib/logger'

// Write Morgan output through Winston
const stream = {
  write: (message: string) => {
    logger.http(message.trim())
  },
}

export const requestLogger = morgan(
  ':method :url :status :response-time ms - :res[content-length]',
  {
    stream,
    // Skip health check logs — they're noisy and add no value
    skip: (req) => req.url === '/health',
  }
)
```

---

## Error logging

```typescript
// Log the full error object — Winston serialises it with stack trace
try {
  await processPayment(orderId)
} catch (err) {
  logger.error(
    { err, userId, orderId },  // pass error as 'err' key — Winston serialises it
    'Payment processing failed'
  )
  throw err  // re-throw — logging is not error handling
}

// Custom error serialiser (optional — configure once in logger setup)
const errorSerializer = winston.format((info) => {
  if (info.err instanceof Error) {
    info.error = {
      message: info.err.message,
      stack: info.err.stack,
      code: (info.err as NodeJS.ErrnoException).code,
    }
    delete info.err
  }
  return info
})
```

---

## Production transports

```typescript
// Add file transport for local testing / legacy systems
logger.add(new winston.transports.File({
  filename: 'logs/error.log',
  level: 'error',
  maxsize: 10 * 1024 * 1024,  // 10 MB
  maxFiles: 5,
  tailable: true,
}))

// CloudWatch transport (use your cloud layer skill for full config)
// npm install winston-cloudwatch
import WinstonCloudWatch from 'winston-cloudwatch'
logger.add(new WinstonCloudWatch({
  logGroupName: `/myapp/${process.env.NODE_ENV}`,
  logStreamName: process.env.HOSTNAME ?? 'default',
  awsRegion: process.env.AWS_REGION,
  jsonValueFormatter: (value: unknown) => JSON.stringify(value),
}))

// Datadog transport
// npm install @datadog/winston
import { createLogger } from '@datadog/winston'
// See: layers/logging/provider/datadog/
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `console.log()` in production | Use `logger.debug()` / `logger.info()` |
| `logger.error('User not found')` | 404 is expected — use `logger.warn()` or `logger.info()` |
| Logging PII fields | Add PII redaction format to the logger |
| String interpolation in messages | Pass metadata object as first arg |
| No `userId` on user-action logs | Use `logger.child({ userId })` per request |
| Creating a new logger per module | Import and use the singleton from `src/lib/logger.ts` |
