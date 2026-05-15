---
name: braintree
description: Braintree payment standards — client token, nonce, transaction, vault, webhooks, and sandbox. Load when working with Braintree.
user-invocable: false
stack: payment/braintree
paths:
  - "**/braintree/**"
  - "**/payment/**"
  - "**/checkout/**"
---

Full standards in [braintree.md](braintree.md). Always-on summary:

**Flow:**
- Server generates a `clientToken` and sends it to the client
- Client uses Drop-in UI or Hosted Fields to tokenize card — produces a `paymentMethodNonce`
- Server receives nonce and calls `gateway.transaction.sale()` — never pass raw card data server-side
- Always call `transaction.submitForSettlement: true` unless you intentionally want to authorize-only

**Vault:**
- Store `paymentMethodToken` in your DB — never store raw card numbers
- Use `customerId` to group payment methods per user; create the customer once and reuse
- Verify before vaulting: use `verifyCard: true` on `paymentMethodCreate`

**Webhooks:**
- Verify every webhook with `gateway.webhookNotification.parse(signature, payload)`
- Handle `subscription_charged_successfully`, `subscription_charged_unsuccessfully`, `dispute_opened`
- Respond 200 immediately — process async via a queue

**Sandbox:**
- Use sandbox credentials from `BRAINTREE_ENVIRONMENT=sandbox`
- Test card numbers: `4111111111111111` (success), `4000111111111115` (declined)
- Never use sandbox credentials in production; gate on `NODE_ENV`

**Never:**
- Accept raw card data in your own API endpoints — always use nonce flow
- Log or store `paymentMethodNonce` — it is single-use and expires
- Skip signature verification on webhooks

**Related skills:** `payment/paypal` (PayPal alternative), `backend/express` (webhook endpoint setup), `error-handling`
