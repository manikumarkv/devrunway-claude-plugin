# Stripe Integration Standards

## PCI Compliance First

Never handle raw card data. Always use:
- **Stripe Checkout** — hosted page, zero PCI scope
- **Stripe Elements** — embedded UI, SAQ A scope

This means never building your own card form fields.

## Server-Side: Checkout Session

```ts
// src/lib/stripe.ts
import Stripe from 'stripe'

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2024-06-20',
})

// src/api/checkout/create.ts

// The client posts what it wants to buy. It never posts what it costs.
interface CartLine {
  sku: string
  quantity: number
}

export async function createCheckoutSession(
  userId: string,
  orderId: string,
  items: CartLine[]
): Promise<string> {
  // Re-price server-side from your own product records. The request body is a
  // statement of intent from an untrusted client, not a source of prices.
  const products = await productRepo.findBySkus(items.map((i) => i.sku))

  const session = await stripe.checkout.sessions.create(
    {
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: items.map((item) => {
        const product = products.get(item.sku)
        if (!product) throw new AppError('Unknown SKU', 400)
        if (!Number.isInteger(item.quantity) || item.quantity < 1) {
          throw new AppError('Invalid quantity', 400)
        }
        return {
          price_data: {
            currency: product.currency,
            product_data: { name: product.name },
            unit_amount: product.priceCents,   // server-side price — the only price
          },
          quantity: item.quantity,
        }
      }),
      success_url: `${process.env.APP_URL}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.APP_URL}/checkout/cancelled`,
      metadata: { userId, orderId },
      customer_email: await getUserEmail(userId),
    },
    {
      // Deterministic and order-scoped. A retry after a network timeout sends
      // the same key and Stripe returns the first session instead of opening a
      // second one. A clock or a random suffix produces a new key per attempt,
      // which is exactly the property idempotency exists to remove.
      idempotencyKey: `checkout-${orderId}`,
    }
  )

  return session.url!
}
```

The buyer chooses the SKU and the quantity. Your server chooses the amount —
always, for Checkout Sessions, Payment Intents and Subscriptions alike. A handler
that reads a price out of the request body lets the buyer post one cent and
receive a genuine, fully-verified, signature-checked payment for one cent.

## Client-Side: Redirect

```ts
// Client only uses publishable key and session URL
const { data } = await api.post('/checkout/create', { items })
window.location.href = data.sessionUrl  // redirect to Stripe-hosted page
```

## Webhook Verification

Raw body required — use `express.raw()` for webhook routes:

```ts
// src/api/webhooks/stripe.ts
import express from 'express'
import Stripe from 'stripe'
import { stripe } from '@/lib/stripe'

const router = express.Router()
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!

router.post(
  '/webhooks/stripe',
  express.raw({ type: 'application/json' }),  // must be raw — not parsed JSON
  async (req, res) => {
    const sig = req.headers['stripe-signature']!

    let event: Stripe.Event
    try {
      event = stripe.webhooks.constructEvent(
        req.body,                              // raw Buffer
        sig,
        webhookSecret
      )
    } catch (err) {
      // Never echo the underlying error across the boundary
      logger.warn({ err }, 'Stripe webhook signature verification failed')
      return res.status(400).send('Invalid signature')
    }

    // Stripe delivers at least once and redelivers on retry, so the same event
    // arrives more than once in normal operation. Claim the event id first —
    // a unique index on event_id turns every later delivery into a no-op.
    const claimed = await claimWebhookEvent(event.id)
    if (!claimed) {
      return res.status(200).json({ received: true, duplicate: true })
    }

    try {
      await processWebhookEvent(event)
    } catch (err) {
      // Release the claim so the redelivery can retry the work, then fail
      // loudly. A 2xx here would tell Stripe the event is handled and it would
      // never redeliver — the charge stands and no order exists.
      await releaseWebhookEvent(event.id)
      logger.error({ err, eventId: event.id }, 'Stripe webhook processing failed')
      return res.status(500).json({ error: 'Webhook processing failed' })
    }

    // Ack last. The 2xx is a commitment that fulfilment is durable.
    res.status(200).json({ received: true })
  }
)

async function processWebhookEvent(event: Stripe.Event) {
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session
      await fulfillOrder(session.metadata!.orderId, session.metadata!.userId)
      break
    }
    case 'payment_intent.payment_failed': {
      const intent = event.data.object as Stripe.PaymentIntent
      await notifyPaymentFailed(intent.metadata.orderId)
      break
    }
  }
}
```

### Two rules the ordering encodes

**Acknowledge after fulfilment, never before.** The 2xx is the only signal Stripe
has that the event was handled, and it stops the retry schedule permanently. If
the response goes out first and `processWebhookEvent` then throws — a database
timeout, a downstream 503 — the money has moved, no order exists, and Stripe
will never send the event again. Do the work, then ack; return 500 when the work
fails so the redelivery arrives.

**Dedupe on `event.id`.** At-least-once delivery means duplicates are normal, not
exceptional. `claimWebhookEvent` is an insert against a unique index:

```ts
// Returns false when this event id was already claimed
async function claimWebhookEvent(eventId: string): Promise<boolean> {
  const inserted = await db.webhookEvents.insertIfAbsent({ eventId })
  return inserted
}
```

Keep fulfilment itself idempotent as well — the claim protects against a repeated
delivery, not against a partially applied handler that is retried after a crash.

## Error Handling

```ts
import Stripe from 'stripe'

async function chargeCustomer(paymentMethodId: string, amount: number) {
  try {
    const intent = await stripe.paymentIntents.create({
      amount,
      currency: 'usd',
      payment_method: paymentMethodId,
      confirm: true,
    })
    return intent
  } catch (err) {
    if (err instanceof Stripe.errors.StripeCardError) {
      // Card was declined — safe to show to user
      throw new AppError(`Payment declined: ${err.message}`, 402, err.code)
    }
    if (err instanceof Stripe.errors.StripeInvalidRequestError) {
      // Bad API call — log but don't expose
      logger.error({ err }, 'Invalid Stripe request')
      throw new AppError('Payment processing failed', 500)
    }
    throw err
  }
}
```

## Idempotency

Pass `idempotencyKey` on all mutating calls to safely retry on network failure.
The key must be **deterministic**: derived only from the identity of the thing
being paid for, so every attempt at the same charge computes the same string.

```ts
const order = await orderRepo.findById(orderId)   // amount comes from here

await stripe.paymentIntents.create(
  {
    amount: order.totalCents,   // server-side amount, never from the request
    currency: order.currency,
    metadata: { orderId: order.id, userId: order.userId },
  },
  { idempotencyKey: `pi-${order.id}` }   // deterministic, order-scoped
)
```

A key is only idempotent if a retry reproduces it. These do not:

| Key | Why it fails |
|---|---|
| a clock reading in the key | Every attempt is a new key, so every retry is a new charge |
| a random value or UUID per call | Same — the key is unique per attempt, not per order |
| the user id alone | Deterministic but too coarse: the user's *next*, legitimate order is silently deduped into the first |

The rule is one key per intent-to-charge. `pi-${order.id}` satisfies both halves:
it repeats across retries of the same order and differs across orders.

## Subscriptions

```ts
// Create subscription after collecting payment method via Elements
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: process.env.STRIPE_PRICE_ID }],
  payment_settings: { payment_method_types: ['card'], save_default_payment_method: 'on_subscription' },
  expand: ['latest_invoice.payment_intent'],
})
```

Key webhook events for subscriptions:
- `customer.subscription.created` — provisioning
- `customer.subscription.deleted` — deprovision
- `invoice.payment_failed` — notify + retry
- `invoice.paid` — renew access

## Environment Variables

```
STRIPE_SECRET_KEY=sk_live_...        # server only — never in client env
STRIPE_PUBLISHABLE_KEY=pk_live_...   # safe for client
STRIPE_WEBHOOK_SECRET=whsec_...      # for webhook signature verification
STRIPE_PRICE_ID=price_...            # subscription price ID
```

Test equivalents use `sk_test_`, `pk_test_` prefixes.

## Anti-Patterns

| Anti-pattern | Risk | Fix |
|---|---|---|
| `express.json()` on webhook route | Signature check fails (wrong body type) | Use `express.raw()` |
| Skipping webhook signature | Forgeable events → fraud | Always `constructEvent()` |
| Storing card numbers | PCI violation | Use Stripe Elements or Checkout |
| `sk_live_` in client bundle | Secret exposed | Server-side only |
| Fulfilling before webhook | Order before payment confirmed | Fulfil in `checkout.session.completed` handler |
| No idempotency key | Duplicate charges on retry | Always pass deterministic key |
| Any amount read out of the request body | Buyer sets their own price and gets a genuine, fully verified payment for it | Re-price server-side from your product or order record |
| Idempotency key built from a clock or a random value | Regenerates on every attempt, so the retry charges again | Derive the key from the order id alone |
| Acking the webhook before fulfilment finishes | 2xx stops all retries; a throw after it loses the order permanently | Fulfil first, ack last, 500 on failure |
| No dedupe on the event id | At-least-once delivery fulfils the same order twice | Claim the event id behind a unique index |
