# Winston Logging Standards

---

## Singleton logger

```typescript
// src/lib/logger.ts — one logger for the whole app
import winston from 'winston'

const PII_FIELDS = ['email', 'password', 'phone', 'name', 'token',
                    'creditCard', 'ssn', 'dateOfBirth', 'address', 'secret']

// Serialise Errors passed in metadata as `err` — Winston does not do this itself,
// because Error.message and Error.stack are non-enumerable and JSON-stringify to {}
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
    errorSerializer(),
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
// ✅ Correct level usage — message first, metadata object second
logger.error('Payment charge failed — manual review required', { err, userId, orderId })
logger.warn('Login failed — rate limiting may apply', { userId, attempts })
logger.info('Order created', { userId, orderId, amount })
logger.debug('Executing DB query', { query, params })

// ❌ Wrong levels
logger.error('User not found')       // 404 is expected — use warn or info
logger.info('Password is invalid')   // never log anything about passwords
```

---

## Structured logging — message first, metadata second

Winston's leveled methods are typed `(message: string, ...meta: any[])`. The **message string comes first**; the metadata object is merged into the log entry alongside it.

```typescript
// ✅ Message first, metadata object second — parseable, searchable, filterable
logger.info('Order created', { userId: 'u123', orderId: 'o456', amount: 4000 })
logger.error('Failed to process payment', { err: error, userId, orderId })
logger.warn('Multiple failed login attempts', { userId, ip, attempts: 5 })

// Emits: {"level":"info","message":"Order created","userId":"u123","orderId":"o456","amount":4000,"timestamp":"..."}

// ❌ String interpolation — breaks log search and parsing
logger.info(`Order ${orderId} created by user ${userId}`)
logger.error(`Failed: ${error.message}`)
```

**Do not use Pino's argument order.** Pino is `logger.info(obj, msg)`; Winston is the reverse. Under Winston an object in the first position becomes the entry itself, so `message` is set to that object and the string in the second position is dropped — the event name never reaches the log and no query on it can ever match:

```
// what Winston actually emits when the arguments are in Pino order
{"level":"info","message":{"orderId":"o456","userId":"u123"},"timestamp":"..."}
```

Structured logs are queryable in log aggregators (CloudWatch Insights, Datadog, Splunk). Winston writes the event name to the `message` field, so query that field — `@message` is the raw log line, not the parsed field:
```sql
-- CloudWatch Insights — matches the entries the examples above emit
filter message = "Order created" | stats count() by userId
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
requestLogger.error('Order processing failed', { err })
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
// Winston does NOT serialise a nested Error by default — `{ err }` in metadata
// JSON-stringifies to `{}` because message and stack are non-enumerable.
// The `errorSerializer` format in the singleton setup above handles it; with that
// in the format chain, log the error under the `err` key and it comes out as
// { error: { message, stack, code } }.
try {
  await processPayment(orderId)
} catch (err) {
  logger.error(
    'Payment processing failed',       // message first
    { err, userId, orderId }           // metadata second — 'err' key picked up by the serialiser
  )
  throw err  // re-throw — logging is not error handling
}

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
  jsonMessage: true,  // ship the structured entry as JSON, not a formatted string
}))

// Datadog transport — the package is `datadog-winston`, and it default-exports
// a winston-transport class. There is no `@datadog/winston` package on npm.
// npm install datadog-winston
import DatadogWinston from 'datadog-winston'
logger.add(new DatadogWinston({
  apiKey: process.env.DATADOG_API_KEY!,
  service: 'myapp',
  ddsource: 'nodejs',
  hostname: process.env.HOSTNAME,
}))
// See: layers/logging/provider/datadog/
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `console.log()` in production | Use `logger.debug()` / `logger.info()` |
| `logger.error('User not found')` | 404 is expected — use `logger.warn()` or `logger.info()` |
| Logging PII fields | Add PII redaction format to the logger |
| String interpolation in messages | Pass the message string first and a metadata object second |
| Using Pino's argument order (metadata object first) | Winston is `logger.info(message, meta)` — an object in the first position becomes the `message` field and the string after it is dropped |
| `{ err }` in metadata logs as `{}` | Add the error serialiser format — `Error` message and stack are non-enumerable |
| No `userId` on user-action logs | Use `logger.child({ userId })` per request |
| Creating a new logger per module | Import and use the singleton from `src/lib/logger.ts` |
