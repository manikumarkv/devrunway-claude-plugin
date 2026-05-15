# RabbitMQ Standards

## Connection and Channel Setup (Node.js / amqplib)

```typescript
// src/queue/connection.ts
import amqplib, { Connection, Channel } from "amqplib";

let connection: Connection | null = null;

export async function createConnection(): Promise<Connection> {
  const url = process.env.RABBITMQ_URL;
  if (!url) throw new Error("RABBITMQ_URL is not set");

  const conn = await amqplib.connect(url);

  conn.on("error", (err) => {
    console.error("RabbitMQ connection error", err);
    reconnectWithBackoff();
  });
  conn.on("close", () => {
    console.warn("RabbitMQ connection closed — reconnecting");
    reconnectWithBackoff();
  });

  connection = conn;
  return conn;
}

async function reconnectWithBackoff(attempt = 0) {
  const delay = Math.min(1000 * 2 ** attempt, 30_000);
  await new Promise((r) => setTimeout(r, delay));
  try {
    await createConnection();
  } catch {
    reconnectWithBackoff(attempt + 1);
  }
}

// One channel per consumer/publisher — never share across concurrent ops
export async function createChannel(conn: Connection): Promise<Channel> {
  return conn.createChannel();
}
```

## Exchange and Queue Declaration

```typescript
// src/queue/topology.ts
import { Channel } from "amqplib";

export const EXCHANGE = {
  ORDERS: "orders",
  NOTIFICATIONS: "notifications.fanout",
  EVENTS: "events.topic",
} as const;

export const QUEUE = {
  ORDER_PROCESSING: "order.processing",
  ORDER_DLQ: "order.processing.dlq",
  EMAIL_NOTIFICATIONS: "notifications.email",
} as const;

export async function declareTopology(ch: Channel) {
  // Direct exchange for order processing
  await ch.assertExchange(EXCHANGE.ORDERS, "direct", { durable: true });

  // Dead-letter exchange
  await ch.assertExchange("dlx", "direct", { durable: true });
  await ch.assertQueue(QUEUE.ORDER_DLQ, { durable: true });
  await ch.bindQueue(QUEUE.ORDER_DLQ, "dlx", QUEUE.ORDER_PROCESSING);

  // Main queue with DLX and TTL
  await ch.assertQueue(QUEUE.ORDER_PROCESSING, {
    durable: true,
    arguments: {
      "x-dead-letter-exchange": "dlx",
      "x-dead-letter-routing-key": QUEUE.ORDER_PROCESSING,
      "x-message-ttl": 3_600_000, // 1 hour
    },
  });
  await ch.bindQueue(QUEUE.ORDER_PROCESSING, EXCHANGE.ORDERS, "order.process");

  // Fanout exchange for notifications
  await ch.assertExchange(EXCHANGE.NOTIFICATIONS, "fanout", { durable: true });
  await ch.assertQueue(QUEUE.EMAIL_NOTIFICATIONS, { durable: true });
  await ch.bindQueue(QUEUE.EMAIL_NOTIFICATIONS, EXCHANGE.NOTIFICATIONS, "");

  // Topic exchange for domain events
  await ch.assertExchange(EXCHANGE.EVENTS, "topic", { durable: true });
}
```

## Publisher

```typescript
// src/queue/publisher.ts
import { Channel } from "amqplib";
import { EXCHANGE } from "./topology";

export async function publishOrder(ch: Channel, order: object): Promise<void> {
  const content = Buffer.from(JSON.stringify(order));
  const published = ch.publish(EXCHANGE.ORDERS, "order.process", content, {
    persistent: true,           // survives broker restart (deliveryMode: 2)
    contentType: "application/json",
    messageId: crypto.randomUUID(),
    timestamp: Math.floor(Date.now() / 1000),
  });

  if (!published) {
    // Channel is full — wait for drain event
    await new Promise<void>((resolve) => ch.once("drain", resolve));
  }
}

export function publishEvent(ch: Channel, routingKey: string, payload: object): void {
  ch.publish(
    EXCHANGE.EVENTS,
    routingKey,
    Buffer.from(JSON.stringify(payload)),
    { persistent: true, contentType: "application/json" },
  );
}
```

## Consumer with Explicit Ack

```typescript
// src/queue/consumer.ts
import { Channel, ConsumeMessage } from "amqplib";
import { QUEUE } from "./topology";

export async function startOrderConsumer(
  ch: Channel,
  handler: (payload: unknown) => Promise<void>,
): Promise<void> {
  // Limit in-flight messages — never overwhelm the worker
  await ch.prefetch(10);

  await ch.consume(QUEUE.ORDER_PROCESSING, async (msg: ConsumeMessage | null) => {
    if (!msg) return; // consumer was cancelled

    try {
      const payload = JSON.parse(msg.content.toString());
      await handler(payload);
      ch.ack(msg);
    } catch (err) {
      const retryCount = (msg.properties.headers?.["x-death"]?.[0]?.count ?? 0) as number;

      if (retryCount < 3) {
        // Transient error — requeue once
        ch.nack(msg, false, true);
      } else {
        // Exhausted retries — send to DLQ
        console.error("Message sent to DLQ after max retries", { err });
        ch.nack(msg, false, false);
      }
    }
  }, { noAck: false }); // explicit ack required
}
```

## DLQ Monitor

```typescript
// src/queue/dlqMonitor.ts
export async function startDlqMonitor(ch: Channel): Promise<void> {
  await ch.prefetch(1);
  await ch.consume("order.processing.dlq", (msg) => {
    if (!msg) return;
    console.error("DLQ message received — manual intervention required", {
      messageId: msg.properties.messageId,
      routingKey: msg.fields.routingKey,
      body: msg.content.toString(),
    });
    ch.ack(msg); // ack to remove from DLQ after logging
  }, { noAck: false });
}
```

## Python (pika) Example

```python
import pika
import json
import os

params = pika.URLParameters(os.environ["RABBITMQ_URL"])
connection = pika.BlockingConnection(params)
channel = connection.channel()

# Declare topology before use
channel.exchange_declare("orders", exchange_type="direct", durable=True)
channel.queue_declare(
    "order.processing",
    durable=True,
    arguments={
        "x-dead-letter-exchange": "dlx",
        "x-message-ttl": 3_600_000,
    },
)

# Consumer
channel.basic_qos(prefetch_count=5)

def callback(ch, method, properties, body):
    try:
        payload = json.loads(body)
        process_order(payload)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as exc:
        print(f"Error processing message: {exc}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

channel.basic_consume("order.processing", callback, auto_ack=False)
channel.start_consuming()
```

## Checklist

- [ ] All queues declared with `durable: true`
- [ ] All messages published with `persistent: true`
- [ ] Every production queue has a dead-letter exchange configured
- [ ] Consumer uses `noAck: false` with explicit `ack`/`nack`
- [ ] `prefetch` set to a reasonable number (1–20)
- [ ] Broker URL loaded from environment variable
- [ ] Reconnect logic with exponential backoff in place
