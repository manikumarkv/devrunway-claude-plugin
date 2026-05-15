---
name: sqs
description: Amazon SQS standards — queue types, visibility timeout, DLQ, batching, and consumer patterns. Load when working with Amazon SQS.
user-invocable: false
stack: cache-queue/sqs
paths:
  - "**/sqs/**"
  - "**/queues/**"
  - "**/workers/**"
---

Full standards in [sqs.md](sqs.md). Always-on summary:

**Queue types:**
- Standard queue: at-least-once delivery, best-effort ordering — for most async workloads
- FIFO queue: exactly-once, strict ordering — for financial transactions, inventory updates
- FIFO queue names must end in `.fifo`

**Visibility timeout:**
- Set `VisibilityTimeout` longer than your maximum processing time — prevents duplicate processing
- Call `ChangeMessageVisibility` if processing takes longer than expected
- If a job is never deleted, SQS makes it visible again after the timeout — design consumers to be idempotent

**Dead Letter Queue (DLQ):**
- Always configure a DLQ with `deadLetterTargetArn` and `maxReceiveCount: 3` — failed messages are rerouted after 3 attempts
- Monitor the DLQ — alert when it receives messages
- Never consume the DLQ automatically — investigate failures first

**Polling:**
- Use Long Polling (`WaitTimeSeconds: 20`) — reduces empty responses and costs
- Batch: receive up to 10 messages per call (`MaxNumberOfMessages: 10`)
- After successful processing, delete the message using `DeleteMessageCommand` with the message's `ReceiptHandle` — SQS does not auto-delete processed messages

**Message design:**
- Keep message size under 64 KB (hard limit: 256 KB) — store large payloads in S3, pass the S3 key
- Include a `messageType` field for consumers to route by type
- Include a `traceId` for distributed tracing

**Never:**
- Delete a message before confirming it was processed — it may be lost on failure
- Process messages one-at-a-time in a loop when batching is available
- Use Standard queue when ordering is critical — use FIFO

**Related skills:** `cache-queue/bullmq` (Redis-based alternative), `cache-queue/rabbitmq`
