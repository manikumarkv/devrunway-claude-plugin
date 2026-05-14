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
export async function createCheckoutSession(
  userId: string,
  items: CartItem[]
): Promise<string> {
  const session = await stripe.checkout.sessions.create(
    {
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: items.map((item) => ({
        price_data: {
          currency: 'usd',
          product_data: { name: item.name },
          unit_amount: item.priceCents,
        },
        quantity: item.quantity,
      })),
      success_url: `${process.env.APP_URL}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.APP_URL}/checkout/cancelled`,
      metadata: { userId, orderId: generateOrderId() },
      customer_email: await getUserEmail(userId),
    },
    {
      idempotencyKey: `checkout-${userId}-${Date.now()}`,
    }
  )

  return session.url!
}
```

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
        process.env.STRIPE_WEBHOOK_SECRET!
      )
    } catch (err) {
      return res.status(400).send(`Webhook signature verification failed: ${err}`)
    }

    // Always return 200 immediately — process async
    res.status(200).json({ received: true })
    await processWebhookEvent(event)
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

Pass `idempotencyKey` on all mutating calls to safely retry on network failure:

```ts
await stripe.paymentIntents.create(
  { amount: 1000, currency: 'usd' },
  { idempotencyKey: `pi-${orderId}` }   // deterministic, order-scoped
)
```

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
