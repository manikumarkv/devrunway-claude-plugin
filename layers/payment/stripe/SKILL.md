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

**Webhook verification:** always `stripe.webhooks.constructEvent(rawBody, sig, webhookSecret)` — never skip signature check

**Idempotency:** pass `idempotencyKey` (e.g. `orderId`) on all mutating API calls

**Test mode:** `sk_test_` keys in dev/staging; use Stripe test card numbers (`4242 4242 4242 4242`)

**Error handling:** catch `Stripe.errors.StripeError`, check `err.type` and `err.code`

**Metadata:** attach `userId` and `orderId` to Payment Intent for reconciliation

**Never:** expose secret key to client, process webhook without sig verification, store card numbers
