---
name: stripe-payment
description: Stripe integration patterns — Checkout Session, Payment Intents, webhook verification, PCI compliance rules. Load when working with Stripe payment integration.
user-invocable: false
stack: payment/stripe
paths:
  - "src/lib/stripe*"
  - "src/api/webhooks/**"
  - "**/*.payment*"
  - "src/**/stripe*"
---

Full standards in [stripe-payment.md](stripe-payment.md). Always-on summary:

**PCI scope:** Never handle raw card data — use Stripe Checkout or Stripe Elements only

**Keys:** `sk_*` secret key server-side only; `pk_*` publishable key client-side only; never swap

**Amounts:** the client posts SKUs and quantities, never prices — re-price server-side from your product or order record before creating a Session, Payment Intent or Subscription

**Webhook verification:** always `stripe.webhooks.constructEvent(rawBody, sig, webhookSecret)` — never skip signature check

**Webhook ordering:** dedupe on `event.id` (delivery is at-least-once), fulfil, *then* return 200 — a 2xx sent before fulfilment stops every retry, so a later throw leaves a charge with no order. Return 500 when fulfilment fails so Stripe redelivers

**Idempotency:** pass a deterministic `idempotencyKey` derived from the order id (`pi-${orderId}`) on all mutating API calls — a key containing a clock or a random value changes on every retry, which is the one property that would have prevented the duplicate charge

**Test mode:** `sk_test_` keys in dev/staging; use Stripe test card numbers (`4242 4242 4242 4242`)

**Error handling:** catch `Stripe.errors.StripeError`, check `err.type` and `err.code`

**Metadata:** attach `userId` and `orderId` to Payment Intent for reconciliation

**Never:** expose secret key to client, process webhook without sig verification, store card numbers, trust a price or an amount that arrived in a request

**Related skills:** `security-principles` (auth on every mutating route, never trust client-supplied values), `payment/paypal` and `payment/braintree` (alternatives), `error-handling`
