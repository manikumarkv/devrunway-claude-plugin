---
name: rabbitmq
description: RabbitMQ exchanges, queues, durable messages, dead-letter queues, amqplib
user-invocable: false
stack: cache-queue/rabbitmq
paths:
  - "**/*.ts"
  - "**/*.js"
  - "**/*.py"
  - "**/rabbitmq*"
  - "**/amqp*"
  - "**/queue*"
  - "**/consumer*"
  - "**/publisher*"
---

Full standards in [rabbitmq.md](rabbitmq.md). Always-on summary:

**Exchange Types:**
- `direct` — route by exact routing key; use for task queues and RPC
- `fanout` — broadcast to all bound queues; use for notifications and cache invalidation
- `topic` — route by pattern (`logs.#`, `order.created.*`); use for event-driven systems
- `headers` — route by message headers; rarely needed, prefer topic

**Queue Durability:**
- Declare queues with `durable: true` and messages with `persistent: true` (deliveryMode 2) — both required for survival across broker restart
- Dead-letter queues: declare a `deadLetterExchange` and set the `x-dead-letter-exchange` argument on every production queue: `ch.assertQueue('orders', { arguments: { 'x-dead-letter-exchange': 'orders.dlx' } })`
- Set `x-message-ttl` on queues where stale messages are worse than dropped

**Consumer Patterns:**
- Use explicit acknowledgement: `channel.ack(msg)` on success, `channel.nack(msg, false, false)` on failure (routes to DLX)
- Never use auto-acknowledgement in production — messages are lost if the consumer crashes before processing completes
- Set `prefetch` (channel QoS) to limit in-flight messages per consumer; default 1 for task workers

**Connection Management:**
- Connect with `amqplib.connect(process.env.RABBITMQ_URL)` — never hardcode credentials in code
- Use a single long-lived connection; create one channel per thread/coroutine
- Reconnect with exponential backoff on connection errors; use `amqplib`'s `error` and `close` events
- Never share a channel across concurrent operations

**Never:**
- Declare queues in consumers without also declaring them in publishers (race on startup)
- Use `autoDelete: true` on shared queues
- Block the event loop inside a consumer callback — use async handlers
- Hardcode broker URLs — load from `process.env.RABBITMQ_URL`

**Related skills:** `error-handling`, `logging-standards`, `nodejs-standards`
