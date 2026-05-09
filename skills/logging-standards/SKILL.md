---
name: logging-standards
description: Structured logging standards with Pino. Load when writing any backend code that logs, troubleshoots, or instruments operations. Also relevant when writing CloudWatch queries or debugging production issues.
user-invocable: false
---

## Core Rules
- Use Pino exclusively — no `console.log`, `console.error`, `console.warn` anywhere in production code
- Always structured JSON — never template strings as the primary log message
- Every log line must include: `timestamp`, `level`, `requestId`, `action`
- Add `userId` on any authenticated request
- Add domain-specific fields relevant to the operation (not the full object — pick key identifiers)

## Log Levels
| Level | When to use |
|---|---|
| `error` | Unhandled exceptions, failed operations requiring action |
| `warn` | Expected but unusual situations (validation failure, rate limit hit, deprecated usage) |
| `info` | Business events: resource created, payment processed, user logged in |
| `debug` | Detailed flow for development troubleshooting — disabled in production |

## Pino Setup
```ts
// utils/logger.ts
import pino from 'pino';
import { env } from '../config/env';

export const logger = pino({
  level: env.LOG_LEVEL,
  formatters: { level: label => ({ level: label }) },
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: ['req.headers.authorization', 'body.password', 'body.token'],
});
```

## Request Logger Middleware
```ts
// middleware/requestLogger.ts
import { randomUUID } from 'crypto';
import { logger } from '../utils/logger';

export const requestLogger = (req: any, res: any, next: any) => {
  req.id = randomUUID();
  req.log = logger.child({ requestId: req.id, method: req.method, path: req.path });
  req.log.info('Request received');

  const start = Date.now();
  res.on('finish', () => {
    req.log.info({ statusCode: res.statusCode, durationMs: Date.now() - start }, 'Request completed');
  });
  next();
};
```

## Logging Patterns

```ts
// Correct: structured, specific fields, human message at end
logger.info(
  { userId, action: 'createOrder', orderId: order.id, itemCount: items.length },
  'Order created'
);

logger.error(
  { userId, action: 'processPayment', orderId, err },
  'Payment processing failed'
);

logger.warn(
  { userId, action: 'login', reason: 'invalid_password', attempt: attemptCount },
  'Failed login attempt'
);

// Wrong: template strings, missing fields, logging full objects
console.log(`Order created for user ${userId}`);  // ❌ console
logger.info(`Order ${orderId} created`);           // ❌ template string as only content
logger.info({ order });                             // ❌ full object (bloated, potential PII)
```

## CloudWatch Log Queries (for debugging)
```
# Errors in last hour
fields @timestamp, level, msg, err.message, userId, requestId
| filter level = "error"
| sort @timestamp desc
| limit 50

# Slow requests
fields @timestamp, path, durationMs, statusCode
| filter durationMs > 1000
| sort durationMs desc

# Failed auth attempts
fields @timestamp, userId, reason, attempt
| filter action = "login" and level = "warn"
| sort @timestamp desc
```

## What to NEVER log
- JWT tokens or `Authorization` header values
- Passwords or secret keys
- Full request/response bodies on sensitive endpoints
- Credit card numbers, SSNs, or other PII unless masked
- Stack traces in production `info`/`warn` logs (only in `error` with `err` field)
