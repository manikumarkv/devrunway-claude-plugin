# PayPal REST API Standards

This layer talks to the PayPal REST API directly with `fetch` through one shared
`paypalRequest` helper. Every server-side call below is a documented REST route
(`/v2/checkout/orders`, `/v1/notifications/verify-webhook-signature`), so the
guidance stays valid across server SDK major versions and does not depend on any
particular SDK's method names.

---

## Setup

```bash
# No server SDK required — the REST API is called through fetch (Node 18+).
# The browser loads the PayPal JS SDK via <script> tag; there is no npm package
# for the buttons.
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

Two rules govern this route and the capture route below, and neither is optional:

1. **The amount comes from your order record.** The browser posts an identifier,
   never a price. A route that reads the amount out of the request body lets the
   buyer pay one cent for a five-hundred-dollar cart and receive a genuine
   `COMPLETED` capture for it — every signature valid, every status correct.
2. **The route is authenticated and the record is owned by the caller.** These
   routes move money; they belong behind the same `requireAuth` middleware as
   the rest of your API, and the order must belong to `req.user`.

```typescript
// src/routes/paypal.ts
import { Router } from 'express'
import { paypalRequest } from '@/lib/paypal'
import { requireAuth } from '@/middleware/auth'

const router = Router()

// Every PayPal route is authenticated. Applied to the router, not per-handler,
// so a route added later cannot silently ship without it.
router.use(requireAuth)

// PayPal amounts are decimal strings; your ledger is integer minor units.
const formatAmount = (cents: number) => (cents / 100).toFixed(2)

router.post('/orders', async (req, res) => {
  // The body carries an identifier only — never an amount, never a currency
  const { internalOrderId } = req.body

  const order = await db.orders.findById(internalOrderId)

  // Ownership, not just authentication. 404 rather than 403 so the response
  // does not confirm that someone else's order id exists.
  if (!order || order.userId !== req.user.id) {
    return res.status(404).json({ error: 'Order not found' })
  }
  if (order.status !== 'pending') {
    return res.status(409).json({ error: 'Order is not payable' })
  }

  const res2 = await paypalRequest('/v2/checkout/orders', {
    method: 'POST',
    headers: {
      // Deterministic idempotency key — a retried create returns the first
      // order instead of opening a second one for the same cart.
      'PayPal-Request-Id': `order-${order.id}`,
    },
    body: JSON.stringify({
      intent: 'CAPTURE',
      purchase_units: [{
        // Ties the PayPal order back to ours. Every later step reads the
        // internal order from here, not from a client-supplied field.
        reference_id: order.id,
        amount: {
          currency_code: order.currency,
          value:         formatAmount(order.totalCents),   // server-side price
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
    // Log the upstream detail, return something the caller can act on. PayPal's
    // message can name internal fields and merchant configuration.
    logger.error({ err, orderId: order.id }, 'PayPal order create failed')
    return res.status(502).json({ error: 'Could not start PayPal checkout' })
  }

  const paypalOrder = await res2.json()
  res.json({ id: paypalOrder.id })
})
```

---

## Server — capture order

```typescript
router.post('/orders/:paypalOrderId/capture', async (req, res) => {
  const { paypalOrderId } = req.params

  // 1. Re-read the order from PayPal and derive OUR order from reference_id.
  //    The caller chose the PayPal order id in the URL; if the fulfilment
  //    target also came from the caller, the caller would be choosing which of
  //    your orders a payment marks paid.
  const lookupRes = await paypalRequest(`/v2/checkout/orders/${paypalOrderId}`)
  if (!lookupRes.ok) {
    return res.status(404).json({ error: 'Order not found' })
  }
  const paypalOrder = await lookupRes.json()

  const unit  = paypalOrder.purchase_units[0]
  const order = await db.orders.findById(unit.reference_id)

  if (!order || order.userId !== req.user.id) {
    return res.status(404).json({ error: 'Order not found' })
  }

  // 2. Re-verify what PayPal is holding against what we priced. This is the
  //    "never capture without re-verifying the order" rule: status APPROVED,
  //    our amount, our currency.
  if (paypalOrder.status !== 'APPROVED') {
    return res.status(409).json({ error: `Order is ${paypalOrder.status}` })
  }
  if (
    unit.amount.value !== formatAmount(order.totalCents) ||
    unit.amount.currency_code !== order.currency
  ) {
    return res.status(409).json({ error: 'Order amount mismatch' })
  }

  // 3. Capture, with a deterministic request id so a retry after a timeout
  //    returns the original capture instead of charging the buyer twice.
  const captureRes = await paypalRequest(`/v2/checkout/orders/${paypalOrderId}/capture`, {
    method:  'POST',
    headers: { 'PayPal-Request-Id': `capture-${order.id}` },
  })

  if (!captureRes.ok) {
    const err = await captureRes.json()
    logger.error({ err, orderId: order.id }, 'PayPal capture failed')
    return res.status(502).json({ error: 'Capture failed' })
  }

  const capture   = await captureRes.json()
  const captured  = capture.purchase_units[0].payments.captures[0]
  const captureId = captured.id

  // 4. Persist BEFORE branching on the status and before responding. A capture
  //    can come back PENDING — under review, pending currency conversion — and
  //    it will usually settle minutes later via PAYMENT.CAPTURE.COMPLETED. If
  //    the handler returns an error without writing the id first, money has
  //    moved and there is no record connecting it to an order.
  await db.orders.update(order.id, {
    paypalCaptureId:     captureId,
    paypalCaptureStatus: captured.status,
    status:              captured.status === 'COMPLETED' ? 'paid' : 'awaiting_capture',
  })

  if (captured.status !== 'COMPLETED') {
    // 202: recorded, not yet fulfilled. The webhook finishes the job.
    return res.status(202).json({ status: captured.status, captureId })
  }

  await fulfillOnce(order.id, captureId)

  res.json({ success: true, captureId })
})
```

### One fulfilment path, claimed by capture id

Three separate paths can conclude that this order is paid: this capture route,
the `PAYMENT.CAPTURE.COMPLETED` webhook, and the `CHECKOUT.ORDER.APPROVED`
webhook. In normal operation at least two of them fire for every order. Give
them one function and let a unique index decide which one does the work:

```typescript
// src/services/fulfilment.ts
export async function fulfillOnce(internalOrderId: string, captureId: string) {
  // Unique index on capture_id — the second caller inserts nothing and returns
  const claimed = await db.fulfilments.insertIfAbsent({ captureId, internalOrderId })
  if (!claimed) return

  await grantEntitlements(internalOrderId)
  await sendReceipt(internalOrderId)
}
```

The capture id is the right key because PayPal generates one per movement of
money. Keying on the internal order id instead would silently swallow a second,
legitimate payment for a re-opened order.

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
  // The amount is displayed elsewhere from the same order record the server
  // prices from. It is deliberately not a prop of this component: nothing the
  // browser holds is ever sent as a price.
  internalOrderId: string
  onSuccess: (captureId: string) => void
  onError: (err: unknown) => void
}

export function PayPalButton({ internalOrderId, onSuccess, onError }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const buttons = paypal.Buttons({
      // Step 1: create the PayPal order on your server
      createOrder: async () => {
        const res = await fetch('/api/paypal/orders', {
          method:      'POST',
          credentials: 'include',
          headers:     { 'Content-Type': 'application/json' },
          body:        JSON.stringify({ internalOrderId }),   // identifier only
        })
        const data = await res.json()
        if (!res.ok) throw new Error(data.error)
        return data.id    // paypalOrderId
      },

      // Step 2: capture after buyer approves. No body — the server reads the
      // internal order from the PayPal order's reference_id.
      onApprove: async ({ orderID }: { orderID: string }) => {
        const res = await fetch(`/api/paypal/orders/${orderID}/capture`, {
          method:      'POST',
          credentials: 'include',
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
  }, [internalOrderId])

  return <div ref={containerRef} />
}
```

---

## Webhook verification

The webhook route is public — PayPal cannot authenticate to it — so the
signature check *is* the authentication. Verify first, do the work, acknowledge
last. PayPal retries any delivery that does not return 2xx for up to three days;
a 200 sent before the work is durable spends that entire retry budget on the
first attempt.

```typescript
// Not behind requireAuth — mounted on its own router. The verify call below is
// what authenticates the caller.
webhookRouter.post('/webhooks/paypal', async (req, res) => {
  // 1. Verify before touching anything in the payload
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
    logger.warn({ transmissionId: req.headers['paypal-transmission-id'] },
      'PayPal webhook verification failed')
    return res.status(400).send('Invalid signature')
  }

  const event = req.body

  // 2. Dedupe on the event id — delivery is at-least-once by design
  const claimed = await db.webhookEvents.insertIfAbsent({ eventId: event.id })
  if (!claimed) return res.sendStatus(200)

  // 3. Do the work, then ack
  try {
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
    // Release the claim so the retry can run, then tell PayPal to retry. A 2xx
    // here would end the retry schedule on a payment that was never fulfilled.
    await db.webhookEvents.remove({ eventId: event.id })
    logger.error({ err, eventId: event.id }, 'PayPal webhook processing failed')
    return res.status(500).send('Processing failed')
  }

  res.sendStatus(200)
})
```

Both capture handlers end in the same place as the capture route:

```typescript
async function handleCaptureCompleted(resource: PayPalCapture) {
  // custom_id / the parent order's reference_id links back to your order —
  // resolve it server-side, never from anything the caller supplied
  const order = await db.orders.findByPaypalCaptureId(resource.id)
  if (!order) return

  await db.orders.update(order.id, { paypalCaptureStatus: 'COMPLETED', status: 'paid' })
  await fulfillOnce(order.id, resource.id)
}
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
| Taking the order amount from the request | The buyer sets their own price and gets a genuine `COMPLETED` capture for it — price from your own order record |
| Capture route without `requireAuth` and an ownership check | Any caller can capture and mark an order paid; authentication alone is not authorization |
| Deriving the internal order from the request body | The caller picks which of your orders a payment fulfils — read it from the PayPal order's `reference_id` |
| Returning an error on a non-`COMPLETED` capture without writing the capture id | Money moved and nothing records it; persist the id and status first, then respond `202` |
| No `PayPal-Request-Id` on create or capture | A retried timeout opens a second order or takes a second payment |
| Fulfilling inline in each of the three paths | Capture route and both webhooks fire for the same order — funnel them through one claim on the capture id |
| Acknowledging the webhook before the work is durable | 2xx ends a three-day retry budget; a later throw loses the event permanently |
