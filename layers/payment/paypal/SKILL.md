---
name: paypal
description: PayPal REST API standards — Orders v2, server-side pricing, capture, webhook verification, sandbox, and smart buttons. Load when working with PayPal.
user-invocable: false
stack: payment/paypal
paths:
  - "**/paypal/**"
  - "**/payment/**"
  - "**/checkout/**"
---

Full standards in [paypal.md](paypal.md). Always-on summary:

> **Scope — applies only if this project uses paypal.** This layer shares `**/checkout/**`, `**/payment/**` with `braintree` in `layers/payment/`, so more than one may load at once and their rules conflict. If the project is not using paypal, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Orders flow** — the REST API is called directly through one `paypalRequest(` helper; this layer does not depend on a server SDK's method names:
- Server `POST`s `/v2/checkout/orders` — returns the PayPal order id
- Client renders Smart Buttons using that id; buyer approves on PayPal
- On approval, server `POST`s `/v2/checkout/orders/{id}/capture` — fulfil only when the capture's `status` is `COMPLETED`

**Amounts and ownership — the two rules that keep money correct:**
- The browser posts an identifier, never a price. Build `amount.value` from your own order record; a body-supplied amount lets the buyer pay one cent and receive a genuine `COMPLETED` capture
- The order and capture routes sit behind `requireAuth`, and the order must belong to `req.user` — authentication is not authorization
- Set `reference_id` to your internal order id on create, and on capture derive the internal order by reading `reference_id` back from PayPal — never from the request body, or the caller chooses which order a payment fulfils
- Send a deterministic `PayPal-Request-Id` (`order-<id>`, `capture-<id>`) on both calls so a retried timeout does not take a second payment
- Persist the capture id and its status *before* responding, including when the status is `PENDING` — money has moved either way
- Capture route and both webhooks can all conclude "paid": funnel them through one `fulfillOnce(` claimed on the capture id

**Authentication:**
- Exchange client ID + secret for an access token via `POST /v1/oauth2/token`
- Cache the token until `expires_in` — do not fetch a new token per request
- Store `process.env.PAYPAL_CLIENT_ID` and `process.env.PAYPAL_CLIENT_SECRET` — never hardcode

**Webhooks:**
- Verify each event by `POST`ing to `/v1/notifications/verify-webhook-signature` with the `paypal-transmission-*` headers and `webhook_id: process.env.PAYPAL_WEBHOOK_ID`, and require `verification_status === 'SUCCESS'`
- The route is public, so the signature check is the authentication — reject a failed verification with 400 before reading the payload
- Dedupe on `event.id`; delivery is at-least-once
- Handle `PAYMENT.CAPTURE.COMPLETED`, `PAYMENT.CAPTURE.DENIED`, `CHECKOUT.ORDER.APPROVED`
- Do the work, *then* respond 200; return 500 on failure. PayPal retries a non-2xx for three days, and a 200 sent first spends that whole budget on an attempt that threw

**Sandbox:**
- Use `https://api-m.sandbox.paypal.com` when `NODE_ENV !== 'production'`
- Create sandbox buyer/merchant accounts at developer.paypal.com
- Never mix sandbox and production credentials

**Smart Buttons (client):**
- Load SDK with `?client-id=&currency=USD&intent=capture`
- In `createOrder` callback, call your server — do not create the order client-side
- In `onApprove` callback, call your server capture endpoint; show success only after `COMPLETED`

**Never:**
- Capture server-side without re-verifying the order — status `APPROVED`, and its amount and currency equal to your record's
- Take an amount, a currency or a fulfilment target from the request body
- Leave an order or capture route unauthenticated
- Expose `PAYPAL_CLIENT_SECRET` to the browser
- Skip webhook signature verification

**Related skills:** `security-principles` (auth middleware on route groups, ownership checks, deny by default), `payment/braintree` (Braintree alternative), `backend/express` (webhook endpoint), `error-handling`
