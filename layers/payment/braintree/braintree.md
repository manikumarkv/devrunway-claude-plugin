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

const router = Router()

// Generate a client token — sent to the browser to initialise Drop-in UI
router.post('/client-token', async (req, res) => {
  try {
    // If the user has a Braintree customer ID, pass it to pre-select their saved methods
    const customerId = req.user?.braintreeCustomerId

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

export function CheckoutForm({ amount }: { amount: number }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [dropinInstance, setDropinInstance] = useState<dropin.Dropin | null>(null)
  const [isLoading, setIsLoading] = useState(false)

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
    try {
      const { nonce } = await dropinInstance.requestPaymentMethod()

      await fetch('/api/payment/checkout', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ nonce, amount }),
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div ref={containerRef} />
      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Processing…' : `Pay $${amount}`}
      </button>
    </form>
  )
}
```

---

## Transaction — server checkout endpoint

```typescript
// Receive nonce from client, create a transaction
router.post('/checkout', async (req, res) => {
  const { nonce, amount } = req.body

  if (!nonce || !amount) {
    return res.status(400).json({ error: 'nonce and amount are required' })
  }

  try {
    const result = await gateway.transaction.sale({
      amount:             String(Number(amount).toFixed(2)),
      paymentMethodNonce: nonce,
      orderId:            req.body.orderId,
      options: {
        submitForSettlement: true,    // capture immediately; omit for authorize-only
        storeInVaultOnSuccess: false, // set true to vault the payment method
      },
    })

    if (result.success) {
      const txId = result.transaction.id
      // Persist txId to your order record
      return res.json({ success: true, transactionId: txId })
    }

    // result.success === false — surface the message
    return res.status(422).json({ error: result.message })
  } catch (err) {
    return res.status(500).json({ error: 'Payment processing failed' })
  }
})
```

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

```typescript
router.post('/webhooks/braintree', async (req, res) => {
  // Braintree sends bt_signature and bt_payload as form-encoded body
  const { bt_signature, bt_payload } = req.body

  if (!bt_signature || !bt_payload) {
    return res.status(400).send('Bad request')
  }

  // Respond 200 immediately — process async
  res.sendStatus(200)

  try {
    const notification = await gateway.webhookNotification.parse(bt_signature, bt_payload)

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
    // Log but do not re-throw — response already sent
    console.error('Braintree webhook processing error', err)
  }
})
```

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
