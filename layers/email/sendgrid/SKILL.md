---
name: sendgrid
description: SendGrid email conventions — dynamic templates, transactional email, bounce/unsubscribe handling, and webhook events. Load when sending email via SendGrid.
user-invocable: false
stack: email/sendgrid
paths:
  - "**/email/**"
  - "**/mailer/**"
  - "**/sendgrid*"
---

Full standards in [sendgrid.md](sendgrid.md). Always-on summary:

**Sending:**
- Always use Dynamic Templates — never build HTML in code; templates live in the SendGrid dashboard
- `from` address must be a verified sender or verified domain
- Always include both `to` and `from`, `templateId`, and `dynamicTemplateData`
- Set `mailSettings.sandboxMode = { enable: true }` in test/staging — delivers nothing but validates the payload

**Required fields:**
- Unsubscribe group (`asm.groupId`) — required for marketing email; CAN-SPAM law
- Reply-to address when `from` is a no-reply
- `subject` — even when using a template (overrides template subject)

**Reliability:**
- SendGrid retries failed deliveries — don't retry on your end for transient failures
- Check webhook events (`delivered`, `bounce`, `spamreport`) to track actual delivery
- Hard bounces should suppress future sends — store bounced emails, don't retry

**Rate limits:**
- Free plan: 100 emails/day; Essentials: 50k–100k/month
- Bulk sends: use batching and `sendAt` scheduling to spread load

**Never:**
- Hardcode the API key — use environment variables
- Send to unverified/bounced addresses — it damages your sender reputation
- Log the full email payload — it contains PII (name, email, personalisation data)

**Related skills:** `data-governance` (PII in email content), `secrets/env-only` (SENDGRID_API_KEY)
