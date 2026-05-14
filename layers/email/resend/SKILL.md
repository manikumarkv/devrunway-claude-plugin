---
name: resend
description: Resend email conventions — SDK setup, react-email templates, domain verification, and webhook handling. Load when sending email via Resend.
user-invocable: false
stack: email/resend
paths:
  - "**/email/**"
  - "**/resend*"
  - "**/emails/**"
---

Full standards in [resend.md](resend.md). Always-on summary:

**Setup:**
- One `Resend` client instance — import and reuse, never instantiate per-request
- `from` must be a verified domain: `Team <hello@verified-domain.com>` format
- Use `react-email` for templates — JSX components are versioned, testable, and reusable

**Sending:**
- `resend.emails.send()` is async — always await it
- Pass `tags` for filtering in the Resend dashboard
- Set `replyTo` when `from` is a no-reply address

**Templates:**
- One file per email type: `welcome.email.tsx`, `password-reset.email.tsx`
- Keep templates in `src/emails/` — preview with `email dev` from react-email CLI
- Props-typed — TypeScript catches missing template variables at build time

**Testing:**
- Set `RESEND_API_KEY=re_test_...` (test API key) — Resend accepts but doesn't deliver
- Or mock the `Resend` class in unit tests

**Never:**
- Use the API key starting with `re_live_` in test environments
- Build HTML strings directly — use react-email components
- Log the full email payload — it contains PII

**Related skills:** `data-governance` (PII in email), `secrets/env-only` (RESEND_API_KEY)
