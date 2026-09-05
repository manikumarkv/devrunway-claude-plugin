---
name: braintree-payment
description: Braintree payment standards — client token, nonce, transaction, vault, webhooks, and sandbox. Load when working with Braintree.
user-invocable: false
stack: payment/braintree
paths:
  - "**/braintree/**"
  - "**/payment/**"
  - "**/checkout/**"
---

Full standards in [braintree.md](braintree.md). Always-on summary:

> **Scope — applies only if this project uses braintree.** This layer shares `**/checkout/**`, `**/payment/**` with `paypal` in `layers/payment/`, so more than one may load at once and their rules conflict. If the project is not using braintree, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Flow:**
- Server generates a `clientToken` using `gateway.clientToken.generate(` and sends it to the client
- Client uses Drop-in UI or Hosted Fields to tokenize card — produces a `paymentMethodNonce`
- Server receives nonce and calls `gateway.transaction.sale()` — never pass raw card data server-side
- Always call `transaction.submitForSettlement: true` unless you intentionally want to authorize-only

**Amounts, auth and idempotency — the three rules that keep money correct:**
- Every payment route sits behind `requireAuth`, applied to the router, and the order must belong to `req.user` — authentication is not authorization
- The browser posts an order identifier and a nonce, never an amount. Build `amount` from your own order record; a body-supplied amount lets the buyer pick their own price
- `transaction.sale` takes no idempotency key, so claim the charge first — insert the order id behind a unique index and return the existing transaction if the claim fails; otherwise a retried submit charges the card twice
- Check `result.success` on the server *and* the response status on the client. `fetch` resolves on a decline, so a form that ignores `response.ok` renders a rejected card as a completed purchase

**Vault:**
- Store `paymentMethodToken` in your DB — never store raw card numbers
- Use `customerId` to group payment methods per user; create the customer once and reuse
- Verify before vaulting: use `verifyCard: true` on `paymentMethodCreate`

**Webhooks:**
- Verify every webhook with `gateway.webhookNotification.parse(bt_signature, bt_payload)` — it throws on a forged payload, and on a public route that check is the authentication
- Parse *before* you acknowledge, and reject a failed parse with 400. Acking first hands a forged payload a 200
- Handle `subscription_charged_successfully`, `subscription_charged_unsuccessfully`, `dispute_opened`
- Acknowledge only after the work is durable, and return 500 when it fails so Braintree redelivers. The payload carries no event id, so make each handler idempotent against the subscription or transaction it acts on

**Sandbox:**
- Use sandbox credentials from `BRAINTREE_ENVIRONMENT=sandbox`
- Test card numbers: `4111111111111111` (success), `4000111111111115` (declined)
- Never use sandbox credentials in production; gate on `NODE_ENV`

**Never:**
- Accept raw card data in your own API endpoints — always use nonce flow
- Accept an amount, a currency or a fulfilment target from the request body
- Leave a payment route unauthenticated
- Log or store `paymentMethodNonce` — it is single-use and expires
- Skip signature verification on webhooks, or verify it after responding

**Related skills:** `security-principles` (auth middleware on route groups, ownership checks, never trust client-supplied values), `payment/paypal` (PayPal alternative), `backend/express` (webhook endpoint setup), `error-handling`
