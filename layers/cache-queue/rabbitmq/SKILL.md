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
- Dead-letter queues: bind a DLX exchange to every production queue; never lose failed messages
- Set `x-message-ttl` on queues where stale messages are worse than dropped

**Consumer Patterns:**
- Always `ack` messages explicitly (`noAck: false`) — never use auto-ack in production
- Set `prefetch` (channel QoS) to limit in-flight messages per consumer; default 1 for task workers
- On failure: `nack` with `requeue: false` to send to DLX; `nack` with `requeue: true` only for transient errors (max 1 retry)

**Connection Management:**
- Use a single long-lived connection; create one channel per thread/coroutine
- Reconnect with exponential backoff on connection errors; use `amqplib`'s `error` and `close` events
- Never share a channel across concurrent operations

**Never:**
- Declare queues in consumers without also declaring them in publishers (race on startup)
- Use `autoDelete: true` on shared queues
- Block the event loop inside a consumer callback — use async handlers
- Hardcode broker URLs — load from environment variables

**Related skills:** `error-handling`, `logging-standards`, `nodejs-standards`
