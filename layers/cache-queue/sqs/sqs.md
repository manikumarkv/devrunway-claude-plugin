# Amazon SQS Standards

---

## Setup

```bash
npm install @aws-sdk/client-sqs
```

```typescript
// src/lib/sqs.ts — singleton client
import { SQSClient } from '@aws-sdk/client-sqs'

export const sqsClient = new SQSClient({
  region:      process.env.AWS_REGION ?? 'us-east-1',
  credentials: process.env.AWS_ACCESS_KEY_ID
    ? {
        accessKeyId:     process.env.AWS_ACCESS_KEY_ID!,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
      }
    : undefined,   // uses instance profile / environment in production
})
```

---

## Queue configuration (IaC reference)

```typescript
// CDK / Terraform reference values
const queueConfig = {
  standard: {
    VisibilityTimeout:         30,    // seconds — longer than max processing time
    MessageRetentionPeriod:   86400,  // 1 day (max 14 days)
    ReceiveMessageWaitTime:      20,  // long polling
    RedrivePolicy: {
      maxReceiveCount:            3,  // move to DLQ after 3 failures
      deadLetterTargetArn:       'arn:aws:sqs:...:orders-dlq',
    },
  },
  dlq: {
    MessageRetentionPeriod: 1209600,  // 14 days (keep for investigation)
  },
}
```

---

## Sending messages

```typescript
import {
  SendMessageCommand,
  SendMessageBatchCommand,
  type SendMessageCommandInput,
} from '@aws-sdk/client-sqs'
import { sqsClient } from '../lib/sqs'

const ORDERS_QUEUE_URL = process.env.ORDERS_QUEUE_URL!

// Message payload type
interface OrderCreatedMessage {
  messageType: 'ORDER_CREATED'
  traceId:     string
  orderId:     string
  userId:      string
  total:       number
  items:       { productId: string; quantity: number }[]
}

// Send a single message
export async function enqueueOrderCreated(order: Order, traceId: string) {
  const payload: OrderCreatedMessage = {
    messageType: 'ORDER_CREATED',
    traceId,
    orderId:     order.id,
    userId:      order.userId,
    total:       order.total,
    items:       order.items,
  }

  await sqsClient.send(new SendMessageCommand({
    QueueUrl:               ORDERS_QUEUE_URL,
    MessageBody:            JSON.stringify(payload),
    MessageGroupId:         order.userId,   // FIFO only — group by user
    MessageDeduplicationId: order.id,       // FIFO only — idempotent
    MessageAttributes: {
      messageType: {
        DataType:    'String',
        StringValue: 'ORDER_CREATED',
      },
    },
    DelaySeconds: 0,
  }))
}

// Batch send (up to 10 messages, reduces API calls)
export async function enqueueBatch(orders: Order[], traceId: string) {
  const entries = orders.map((order, i) => ({
    Id:          `msg-${i}`,             // unique within the batch
    MessageBody: JSON.stringify({
      messageType: 'ORDER_CREATED',
      traceId,
      orderId:     order.id,
      userId:      order.userId,
      total:       order.total,
    } as OrderCreatedMessage),
  }))

  const result = await sqsClient.send(new SendMessageBatchCommand({
    QueueUrl: ORDERS_QUEUE_URL,
    Entries:  entries,
  }))

  if (result.Failed?.length) {
    console.error('Failed to enqueue messages:', result.Failed)
    // Retry or alert
  }
}
```

---

## Consumer (polling)

```typescript
import {
  ReceiveMessageCommand,
  DeleteMessageCommand,
  DeleteMessageBatchCommand,
  ChangeMessageVisibilityCommand,
} from '@aws-sdk/client-sqs'

const POLL_INTERVAL_MS = 100  // back-off between polls

async function processMessage(body: string): Promise<void> {
  const message = JSON.parse(body) as { messageType: string }

  switch (message.messageType) {
    case 'ORDER_CREATED':
      await handleOrderCreated(message as OrderCreatedMessage)
      break
    default:
      console.warn(`Unknown message type: ${message.messageType}`)
      // Don't throw — unknown messages shouldn't block the queue
  }
}

export async function startConsumer(queueUrl: string, concurrency = 5) {
  let running = true
  const inFlight = new Set<Promise<void>>()

  process.on('SIGTERM', () => {
    running = false
    console.log('Stopping SQS consumer...')
  })

  while (running) {
    // Receive up to 10 messages with long polling
    const result = await sqsClient.send(new ReceiveMessageCommand({
      QueueUrl:            queueUrl,
      MaxNumberOfMessages: 10,           // batch receive
      WaitTimeSeconds:     20,           // long polling — reduces cost
      AttributeNames:      ['ApproximateReceiveCount'],
    }))

    const messages = result.Messages ?? []
    if (!messages.length) continue

    for (const message of messages) {
      // Throttle concurrency
      while (inFlight.size >= concurrency) {
        await Promise.race(inFlight)
      }

      const task = (async () => {
        try {
          await processMessage(message.Body!)

          // Only delete AFTER successful processing
          await sqsClient.send(new DeleteMessageCommand({
            QueueUrl:      queueUrl,
            ReceiptHandle: message.ReceiptHandle!,
          }))
        } catch (err) {
          console.error('Failed to process message:', err)
          // Don't delete — SQS will make it visible again after timeout
          // After maxReceiveCount failures → moves to DLQ
        }
      })()

      inFlight.add(task)
      task.finally(() => inFlight.delete(task))
    }
  }

  // Wait for in-flight tasks to complete
  await Promise.allSettled(inFlight)
  console.log('SQS consumer stopped cleanly')
}
```

---

## Extending visibility timeout (long-running jobs)

```typescript
// Call this periodically if processing takes longer than VisibilityTimeout
async function extendVisibility(queueUrl: string, receiptHandle: string, extraSeconds: number) {
  await sqsClient.send(new ChangeMessageVisibilityCommand({
    QueueUrl:          queueUrl,
    ReceiptHandle:     receiptHandle,
    VisibilityTimeout: extraSeconds,
  }))
}

// In a long-running processor:
async function processLargeJob(message: SQSMessage) {
  const keepAlive = setInterval(async () => {
    await extendVisibility(ORDERS_QUEUE_URL, message.ReceiptHandle!, 60)
  }, 45_000)   // extend every 45s (before 60s timeout)

  try {
    await runHeavyProcessing(JSON.parse(message.Body!))
  } finally {
    clearInterval(keepAlive)
  }
}
```

---

## FIFO queue patterns

```typescript
// FIFO queues: name must end in .fifo
const PAYMENTS_FIFO_URL = process.env.PAYMENTS_FIFO_QUEUE_URL!  // ends in .fifo

// MessageGroupId: messages with the same group are processed in order
// MessageDeduplicationId: prevents duplicates within a 5-minute window
await sqsClient.send(new SendMessageCommand({
  QueueUrl:               PAYMENTS_FIFO_URL,
  MessageBody:            JSON.stringify({ amount: 99.99, orderId: 'ord_123' }),
  MessageGroupId:         'ord_123',         // order of messages for this order
  MessageDeduplicationId: `pay-ord_123-${idempotencyKey}`,  // unique per attempt
}))
```

---

## Dead Letter Queue monitoring

```typescript
// Monitor DLQ depth — alert when messages arrive
// This is typically done via CloudWatch alarm on ApproximateNumberOfMessagesVisible

// To inspect DLQ messages without consuming them
const dlqResult = await sqsClient.send(new ReceiveMessageCommand({
  QueueUrl:            process.env.ORDERS_DLQ_URL!,
  MaxNumberOfMessages: 10,
  WaitTimeSeconds:     0,   // short poll — just checking, not consuming
  AttributeNames:      ['All'],
}))

dlqResult.Messages?.forEach((msg) => {
  console.log('DLQ message:', {
    body:          msg.Body,
    receiveCount:  msg.Attributes?.ApproximateReceiveCount,
    firstReceived: msg.Attributes?.ApproximateFirstReceiveTimestamp,
  })
})
```

---

## Large messages (S3 offload)

```typescript
// Message body limit: 256 KB
// For larger payloads: store in S3, send S3 reference in SQS

interface LargePayloadMessage {
  messageType: 'LARGE_PAYLOAD'
  s3Bucket:    string
  s3Key:       string
  payloadSize: number
}

async function sendLargePayload(data: unknown) {
  const key    = `payloads/${randomUUID()}.json`
  const body   = JSON.stringify(data)

  // Upload to S3
  await s3Client.send(new PutObjectCommand({
    Bucket:      process.env.PAYLOAD_BUCKET!,
    Key:         key,
    Body:        body,
    ContentType: 'application/json',
  }))

  // Send reference via SQS
  await sqsClient.send(new SendMessageCommand({
    QueueUrl:    ORDERS_QUEUE_URL,
    MessageBody: JSON.stringify({
      messageType: 'LARGE_PAYLOAD',
      s3Bucket:    process.env.PAYLOAD_BUCKET!,
      s3Key:       key,
      payloadSize: body.length,
    } as LargePayloadMessage),
  }))
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Deleting message before processing | Delete only after `processMessage()` succeeds — failure should leave message in queue |
| Short polling (no `WaitTimeSeconds`) | Long polling (`WaitTimeSeconds: 20`) reduces costs and empty responses |
| `MaxNumberOfMessages: 1` | Receive up to 10 per call — batching reduces API call costs |
| `VisibilityTimeout` shorter than processing time | Message becomes visible again mid-processing → duplicate execution |
| No DLQ configured | Failed messages accumulate in the main queue forever |
| Using Standard queue for financial transactions | FIFO queue for exactly-once and ordered processing |
| Processing messages before idempotency check | SQS delivers at-least-once — always check if already processed |
