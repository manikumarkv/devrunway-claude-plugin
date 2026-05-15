---
name: paypal
description: PayPal REST SDK standards — orders API, capture, webhooks, sandbox, and smart buttons. Load when working with PayPal.
user-invocable: false
stack: payment/paypal
paths:
  - "**/paypal/**"
  - "**/payment/**"
  - "**/checkout/**"
---

Full standards in [paypal.md](paypal.md). Always-on summary:

**Orders flow:**
- Server calls `orders.create(` with order details — returns `orderId`
- Client renders Smart Buttons using the `orderId`; buyer approves on PayPal
- On buyer approval, server calls `orders.capture(` — check `capture.status === 'COMPLETED'` before fulfilling

**Authentication:**
- Exchange client ID + secret for an access token via `POST /v1/oauth2/token`
- Cache the token until `expires_in` — do not fetch a new token per request
- Store `process.env.PAYPAL_CLIENT_ID` and `process.env.PAYPAL_CLIENT_SECRET` — never hardcode

**Webhooks:**
- Verify each event using `verifyWebhookSignature(` with the `webhookId` from your PayPal app config
- Handle `PAYMENT.CAPTURE.COMPLETED`, `PAYMENT.CAPTURE.DENIED`, `CHECKOUT.ORDER.APPROVED`
- Respond 200 immediately; process events asynchronously

**Sandbox:**
- Use `https://api-m.sandbox.paypal.com` when `NODE_ENV !== 'production'`
- Create sandbox buyer/merchant accounts at developer.paypal.com
- Never mix sandbox and production credentials

**Smart Buttons (client):**
- Load SDK with `?client-id=&currency=USD&intent=capture`
- In `createOrder` callback, call your server — do not create the order client-side
- In `onApprove` callback, call your server capture endpoint; show success only after `COMPLETED`

**Never:**
- Capture server-side without re-verifying order status
- Expose `PAYPAL_CLIENT_SECRET` to the browser
- Skip webhook signature verification

**Related skills:** `payment/braintree` (Braintree alternative), `backend/express` (webhook endpoint), `error-handling`
