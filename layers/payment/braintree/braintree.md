# Braintree Standards

---

## Setup

```bash
npm install braintree
```

```typescript
// src/lib/braintree.ts
import braintree from 'braintree'

if (!process.env.BRAINTREE_MERCHANT_ID)   throw new Error('BRAINTREE_MERCHANT_ID is required')
if (!process.env.BRAINTREE_PUBLIC_KEY)    throw new Error('BRAINTREE_PUBLIC_KEY is required')
if (!process.env.BRAINTREE_PRIVATE_KEY)   throw new Error('BRAINTREE_PRIVATE_KEY is required')

const environment = process.env.BRAINTREE_ENVIRONMENT === 'production'
  ? braintree.Environment.Production
  : braintree.Environment.Sandbox

export const gateway = new braintree.BraintreeGateway({
  environment,
  merchantId: process.env.BRAINTREE_MERCHANT_ID,
  publicKey:  process.env.BRAINTREE_PUBLIC_KEY,
  privateKey: process.env.BRAINTREE_PRIVATE_KEY,
})
```

---

## Client token endpoint

```typescript
// src/routes/payment.ts
import { Router } from 'express'
import { gateway } from '@/lib/braintree'
import { requireAuth } from '@/middleware/auth'

const router = Router()

// Every payment route is authenticated. Applied to the router rather than to
// each handler, so a route added later cannot silently ship unprotected.
router.use(requireAuth)

// Braintree amounts are decimal strings; your ledger is integer minor units.
const formatAmount = (cents: number) => (cents / 100).toFixed(2)

// Generate a client token — sent to the browser to initialise Drop-in UI
router.post('/client-token', async (req, res) => {
  try {
    // If the user has a Braintree customer ID, pass it to pre-select their saved methods
    const customerId = req.user.braintreeCustomerId

    const { clientToken } = await gateway.clientToken.generate(
      customerId ? { customerId } : {}
    )

    res.json({ clientToken })
  } catch (err) {
    res.status(500).json({ error: 'Failed to generate client token' })
  }
})
```

---

## Drop-in UI (client)

```tsx
// src/components/CheckoutForm.tsx
import { useEffect, useRef, useState } from 'react'
import dropin from 'braintree-web-drop-in'

interface Props {
  internalOrderId: string
  // Display only. The server prices the charge from its own order record; this
  // value is never sent anywhere as a price.
  amount: number
  onPaid: (transactionId: string) => void
}

export function CheckoutForm({ internalOrderId, amount, onPaid }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [dropinInstance, setDropinInstance] = useState<dropin.Dropin | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let instance: dropin.Dropin

    async function init() {
      const { clientToken } = await fetch('/api/payment/client-token', {
        method: 'POST',
      }).then(r => r.json())

      instance = await dropin.create({
        authorization: clientToken,
        container:     containerRef.current!,
        paypal:        { flow: 'checkout', amount: amount.toFixed(2), currency: 'USD' },
      })

      setDropinInstance(instance)
    }

    init()

    return () => { instance?.teardown() }
  }, [amount])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!dropinInstance) return

    setIsLoading(true)
    setError(null)
    try {
      const { nonce } = await dropinInstance.requestPaymentMethod()

      const response = await fetch('/api/payment/checkout', {
        method:      'POST',
        credentials: 'include',
        headers:     { 'Content-Type': 'application/json' },
        // Identifier only — the server knows what this order costs
        body:        JSON.stringify({ nonce, internalOrderId }),
      })

      const body = await response.json()

      // A declined card is a 422 with a body, not a thrown exception. Without
      // this check a decline and a successful charge render identically and the
      // buyer walks away believing they have paid.
      if (!response.ok || !body.success) {
        setError(body.error ?? 'Payment failed. Please try another method.')
        // The nonce is single-use — the buyer must re-enter a payment method
        await dropinInstance.clearSelectedPaymentMethod()
        return
      }

      onPaid(body.transactionId)
    } catch (err) {
      setError('Payment could not be processed. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div ref={containerRef} />
      {error && <p role="alert">{error}</p>}
      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Processing…' : `Pay $${amount}`}
      </button>
    </form>
  )
}
```

`fetch` only rejects on a network failure. Every gateway outcome Braintree can
report — declined, processor-rejected, gateway-rejected for fraud — arrives as a
resolved response with a non-2xx status, so a submit handler that awaits the
call without reading `response.ok` reports failure as success.

---

## Transaction — server checkout endpoint

The route is authenticated by the router-level `requireAuth` above, the amount
comes from your own order record, and the charge is claimed before it is made.

```typescript
// Receive nonce from client, create a transaction
router.post('/checkout', async (req, res) => {
  // An identifier and a single-use nonce. Never an amount.
  const { nonce, internalOrderId } = req.body

  if (!nonce || !internalOrderId) {
    return res.status(400).json({ error: 'nonce and internalOrderId are required' })
  }

  const order = await db.orders.findById(internalOrderId)

  // Ownership, not just authentication. 404 rather than 403 so the response
  // does not confirm that someone else's order id exists.
  if (!order || order.userId !== req.user.id) {
    return res.status(404).json({ error: 'Order not found' })
  }
  if (order.status !== 'pending') {
    return res.status(409).json({ error: 'Order is not payable' })
  }

  // Braintree's transaction API takes no idempotency key, so claim the charge
  // yourself: a unique index on order_id means the second attempt — a retried
  // submit, a double-clicked button, a proxy replay — inserts nothing and
  // returns the transaction the first attempt created.
  const claimed = await db.charges.insertIfAbsent({ orderId: order.id })
  if (!claimed) {
    const existing = await db.charges.findByOrderId(order.id)
    return res.json({ success: true, transactionId: existing.transactionId })
  }

  try {
    const result = await gateway.transaction.sale({
      amount:             formatAmount(order.totalCents),   // server-side price
      paymentMethodNonce: nonce,
      orderId:            order.id,    // your id on the gateway record, for reconciliation
      options: {
        submitForSettlement: true,    // capture immediately; omit for authorize-only
        storeInVaultOnSuccess: false, // set true to vault the payment method
      },
    })

    if (result.success) {
      const txId = result.transaction.id
      await db.charges.update(order.id, { transactionId: txId })
      await db.orders.update(order.id, { status: 'paid', braintreeTransactionId: txId })
      return res.json({ success: true, transactionId: txId })
    }

    // result.success === false is a definite decline: no money moved, so
    // release the claim and let the buyer retry with another method.
    await db.charges.remove(order.id)
    return res.status(422).json({ success: false, error: result.message })
  } catch (err) {
    // An exception is an *unknown* outcome — a socket timeout can land after
    // the gateway accepted the sale. Keep the claim so a retry cannot charge
    // again, and flag it for reconciliation.
    await db.charges.update(order.id, { state: 'unknown' })
    logger.error({ err, orderId: order.id }, 'Braintree sale outcome unknown')
    return res.status(500).json({ success: false, error: 'Payment processing failed' })
  }
})
```

Reconcile the `unknown` claims out of band rather than guessing, using the
`orderId` you attached to the sale:

```typescript
const found = await gateway.transaction.search((search) => {
  search.orderId().is(orderId)
})
```

That is the whole reason to pass your own `orderId` to `transaction.sale`: it is
the only handle you have on a transaction whose response you never received.

---

## Vault — create customer and store payment method

```typescript
// Create a Braintree customer and vault their payment method
async function vaultPaymentMethod(userId: string, nonce: string) {
  // 1. Create (or reuse) a Braintree customer
  const customerResult = await gateway.customer.create({
    id: `user-${userId}`,    // stable ID tied to your user
  })

  if (!customerResult.success && customerResult.message !== 'Customer ID has already been taken') {
    throw new Error(`Customer create failed: ${customerResult.message}`)
  }

  // 2. Add and verify the payment method
  const pmResult = await gateway.paymentMethod.create({
    customerId:         `user-${userId}`,
    paymentMethodNonce: nonce,
    options: {
      verifyCard: true,    // runs a $0 authorisation to validate the card
      makeDefault: true,
    },
  })

  if (!pmResult.success) {
    throw new Error(`Vault failed: ${pmResult.message}`)
  }

  // Store token in your DB — never store raw card numbers
  return pmResult.paymentMethod.token
}
```

---

## Webhook verification

The webhook route is public — Braintree cannot authenticate to it — so
`webhookNotification.parse` *is* the authentication: it fails on a payload whose
signature does not verify against your private key. That makes the ordering
load-bearing in two directions. Parse before you acknowledge, so a forged
payload is rejected with 400 rather than accepted with 200. Finish the work
before you acknowledge, so a handler that throws gets the delivery again —
Braintree retries a non-2xx with backoff, and a 200 ends that schedule.

```typescript
// Not behind requireAuth — mounted on its own router. The signature check below
// is what authenticates the caller.
webhookRouter.post('/webhooks/braintree', async (req, res) => {
  // Braintree sends bt_signature and bt_payload as form-encoded body
  const { bt_signature, bt_payload } = req.body

  if (!bt_signature || !bt_payload) {
    return res.status(400).send('Bad request')
  }

  let notification
  try {
    // Verify FIRST — this throws on a forged or tampered payload
    notification = await gateway.webhookNotification.parse(bt_signature, bt_payload)
  } catch (err) {
    logger.warn({ err }, 'Braintree webhook signature verification failed')
    return res.status(400).send('Invalid signature')
  }

  try {
    switch (notification.kind) {
      case braintree.WebhookNotification.Kind.SubscriptionChargedSuccessfully:
        await handleSubscriptionCharged(notification.subscription)
        break

      case braintree.WebhookNotification.Kind.SubscriptionChargedUnsuccessfully:
        await handleSubscriptionFailed(notification.subscription)
        break

      case braintree.WebhookNotification.Kind.DisputeOpened:
        await handleDisputeOpened(notification.dispute)
        break
    }
  } catch (err) {
    // Ask for the delivery again. A 2xx here would tell Braintree the event was
    // handled and it would never be redelivered.
    logger.error({ err, kind: notification.kind }, 'Braintree webhook processing failed')
    return res.status(500).send('Processing failed')
  }

  // Acknowledge last — the 2xx is a commitment that the work is durable
  res.status(200).send('OK')
})
```

Braintree's payload carries no event id, so there is no id to dedupe on: make
each handler idempotent against the subject it acts on instead — keyed on the
subscription or transaction id, so a redelivery finds the work already done.
If a handler is slow, do the durable part inline (record the event, enqueue the
job) and acknowledge after *that* — the rule is that the 2xx follows something
that survives a crash, not that the whole job runs in the request.

---

## Sandbox test cards

| Card number         | Result                              |
|---------------------|-------------------------------------|
| 4111111111111111    | Visa — authorisation success        |
| 4000111111111115    | Visa — declined (do not honour)     |
| 4000111111111107    | Visa — declined (insufficient funds)|
| 5431111111111111    | Mastercard — success                |

Use `expiry: 12/2030`, `CVV: any 3 digits` for all test cards.

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Passing raw card data to your server | Always tokenise with Drop-in UI or Hosted Fields — only nonce reaches server |
| Logging `paymentMethodNonce` | Nonces are single-use and must not be stored or logged |
| Skipping `submitForSettlement: true` | Authorises but never captures — the charge never lands |
| Not handling `result.success === false` | Braintree returns a result object; always check `.success` before accessing `.transaction` |
| Using production credentials in dev | Gate on `BRAINTREE_ENVIRONMENT` env var; sandbox and production keys are distinct |
| Submitting the checkout form without reading the response status | `fetch` resolves on a decline, so a rejected card renders as a completed purchase — check the response and show the error |
| Charging an amount that arrived in the request | The buyer sets their own price — price from your order record |
| Payment routes without `requireAuth` and an ownership check | Anyone can charge and mark an order paid; authentication alone is not authorization |
| Calling `transaction.sale` with no claim on the order | The API has no idempotency key, so a retried submit charges the card twice — claim the order id behind a unique index first |
| Acknowledging the webhook before `parse()` | A forged payload gets a 200, and a genuine event whose handler throws is never redelivered |
