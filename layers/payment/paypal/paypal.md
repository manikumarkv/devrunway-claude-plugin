# PayPal REST SDK Standards

---

## Setup

```bash
npm install @paypal/paypal-server-sdk        # server
# client uses the PayPal JS SDK loaded via <script> tag — no npm package for browser
```

---

## Environment configuration

```typescript
// src/lib/paypal.ts
const BASE_URL = process.env.NODE_ENV === 'production'
  ? 'https://api-m.paypal.com'
  : 'https://api-m.sandbox.paypal.com'

let cachedToken: { value: string; expiresAt: number } | null = null

async function getAccessToken(): Promise<string> {
  // Reuse cached token until it expires (with 60 s buffer)
  if (cachedToken && Date.now() < cachedToken.expiresAt - 60_000) {
    return cachedToken.value
  }

  const credentials = Buffer.from(
    `${process.env.PAYPAL_CLIENT_ID}:${process.env.PAYPAL_CLIENT_SECRET}`
  ).toString('base64')

  const res = await fetch(`${BASE_URL}/v1/oauth2/token`, {
    method:  'POST',
    headers: {
      Authorization:  `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  })

  if (!res.ok) throw new Error(`PayPal token error: ${res.status}`)

  const data = await res.json()

  cachedToken = {
    value:     data.access_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  }

  return cachedToken.value
}

export async function paypalRequest(path: string, options: RequestInit = {}) {
  const token = await getAccessToken()

  return fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: {
      Authorization:  `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  })
}
```

---

## Server — create order

```typescript
// src/routes/paypal.ts
import { Router } from 'express'
import { paypalRequest } from '@/lib/paypal'

const router = Router()

router.post('/orders', async (req, res) => {
  const { amount, currency = 'USD', orderId } = req.body

  const res2 = await paypalRequest('/v2/checkout/orders', {
    method: 'POST',
    body: JSON.stringify({
      intent: 'CAPTURE',
      purchase_units: [{
        reference_id: orderId,
        amount: {
          currency_code: currency,
          value:         Number(amount).toFixed(2),
        },
      }],
      payment_source: {
        paypal: {
          experience_context: {
            payment_method_preference: 'IMMEDIATE_PAYMENT_REQUIRED',
            landing_page:              'LOGIN',
            user_action:               'PAY_NOW',
            return_url:                `${process.env.APP_URL}/checkout/success`,
            cancel_url:                `${process.env.APP_URL}/checkout/cancel`,
          },
        },
      },
    }),
  })

  if (!res2.ok) {
    const err = await res2.json()
    return res.status(res2.status).json({ error: err.message })
  }

  const order = await res2.json()
  res.json({ id: order.id })
})
```

---

## Server — capture order

```typescript
router.post('/orders/:orderId/capture', async (req, res) => {
  const { orderId } = req.params

  const captureRes = await paypalRequest(`/v2/checkout/orders/${orderId}/capture`, {
    method: 'POST',
  })

  if (!captureRes.ok) {
    const err = await captureRes.json()
    return res.status(captureRes.status).json({ error: err.message })
  }

  const capture = await captureRes.json()

  // Always verify COMPLETED before fulfilling
  if (capture.status !== 'COMPLETED') {
    return res.status(422).json({ error: `Unexpected capture status: ${capture.status}` })
  }

  const captureId = capture.purchase_units[0].payments.captures[0].id

  // Persist captureId to your order record
  await db.orders.update(req.body.internalOrderId, {
    paypalCaptureId: captureId,
    status:          'paid',
  })

  res.json({ success: true, captureId })
})
```

---

## Smart Buttons (client)

```html
<!-- Load once in your HTML head — replace CLIENT_ID -->
<script src="https://www.paypal.com/sdk/js?client-id=CLIENT_ID&currency=USD&intent=capture"></script>
```

```tsx
// src/components/PayPalButton.tsx
import { useEffect, useRef } from 'react'

declare const paypal: any   // loaded via CDN

interface Props {
  amount: number
  internalOrderId: string
  onSuccess: (captureId: string) => void
  onError: (err: unknown) => void
}

export function PayPalButton({ amount, internalOrderId, onSuccess, onError }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const buttons = paypal.Buttons({
      // Step 1: create the PayPal order on your server
      createOrder: async () => {
        const res = await fetch('/api/paypal/orders', {
          method:  'POST',
          headers: { 'Content-Type': 'application/json' },
          body:    JSON.stringify({ amount, orderId: internalOrderId }),
        })
        const data = await res.json()
        if (!res.ok) throw new Error(data.error)
        return data.id    // paypalOrderId
      },

      // Step 2: capture after buyer approves
      onApprove: async ({ orderID }: { orderID: string }) => {
        const res = await fetch(`/api/paypal/orders/${orderID}/capture`, {
          method:  'POST',
          headers: { 'Content-Type': 'application/json' },
          body:    JSON.stringify({ internalOrderId }),
        })
        const data = await res.json()
        if (!res.ok) throw new Error(data.error)
        onSuccess(data.captureId)
      },

      onError,
    })

    if (containerRef.current) {
      buttons.render(containerRef.current)
    }

    return () => buttons.close?.()
  }, [amount, internalOrderId])

  return <div ref={containerRef} />
}
```

---

## Webhook verification

```typescript
router.post('/webhooks/paypal', async (req, res) => {
  // Respond 200 immediately — process async
  res.sendStatus(200)

  try {
    // Verify signature using PayPal's verify endpoint
    const verifyRes = await paypalRequest('/v1/notifications/verify-webhook-signature', {
      method: 'POST',
      body: JSON.stringify({
        auth_algo:         req.headers['paypal-auth-algo'],
        cert_url:          req.headers['paypal-cert-url'],
        transmission_id:   req.headers['paypal-transmission-id'],
        transmission_sig:  req.headers['paypal-transmission-sig'],
        transmission_time: req.headers['paypal-transmission-time'],
        webhook_id:        process.env.PAYPAL_WEBHOOK_ID,
        webhook_event:     req.body,
      }),
    })

    const { verification_status } = await verifyRes.json()

    if (verification_status !== 'SUCCESS') {
      console.warn('PayPal webhook verification failed')
      return
    }

    const event = req.body

    switch (event.event_type) {
      case 'PAYMENT.CAPTURE.COMPLETED':
        await handleCaptureCompleted(event.resource)
        break

      case 'PAYMENT.CAPTURE.DENIED':
        await handleCaptureDenied(event.resource)
        break

      case 'CHECKOUT.ORDER.APPROVED':
        // Order approved but not yet captured — capture from server
        await handleOrderApproved(event.resource)
        break
    }
  } catch (err) {
    console.error('PayPal webhook error', err)
  }
})
```

---

## Sandbox setup

1. Go to [developer.paypal.com](https://developer.paypal.com) → **Sandbox Accounts**
2. Create a **Business** account (merchant) and a **Personal** account (buyer)
3. Use the sandbox credentials in `PAYPAL_CLIENT_ID` and `PAYPAL_CLIENT_SECRET`
4. Load the JS SDK with `?client-id=<sandbox-client-id>`
5. Log in with the sandbox buyer account when the Smart Buttons open

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Fulfilling on `APPROVED` status | Only fulfil after `COMPLETED` capture — `APPROVED` means buyer clicked, not funds moved |
| Fetching access token per request | Cache the token; it is valid for hours — fetching per request is slow and rate-limited |
| Exposing `PAYPAL_CLIENT_SECRET` in browser code | Secret stays server-side; only `PAYPAL_CLIENT_ID` is safe for the browser |
| Skipping webhook signature verification | Unverified webhooks can be forged — always call the verify endpoint |
| Using `intent=authorize` with capture flow | Match intent: use `CAPTURE` for immediate payment, `AUTHORIZE` only if you capture later |
