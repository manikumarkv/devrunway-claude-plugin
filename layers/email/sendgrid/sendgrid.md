# SendGrid Standards

---

## Setup

```bash
npm install @sendgrid/mail @sendgrid/client
```

```typescript
// src/lib/email.ts — singleton client
import sgMail from '@sendgrid/mail'

sgMail.setApiKey(process.env.SENDGRID_API_KEY!)

export { sgMail }
```

---

## Sending with dynamic templates

```typescript
// src/services/email.service.ts
import { sgMail } from '../lib/email'
import { logger } from '../lib/logger'

interface WelcomeEmailData {
  userId: string
  firstName: string
  verificationUrl: string
}

export async function sendWelcomeEmail({ userId, firstName, verificationUrl }: WelcomeEmailData) {
  const msg = {
    to: { email: process.env.ENV === 'production' ? userEmail : 'dev-inbox@example.com' },
    from: { email: 'hello@example.com', name: 'Example App' },
    replyTo: 'support@example.com',
    templateId: process.env.SENDGRID_TEMPLATE_WELCOME!,  // from SendGrid dashboard
    dynamicTemplateData: {
      firstName,
      verificationUrl,
      year: new Date().getFullYear(),
    },
    // Sandbox mode — validates payload but doesn't actually send
    mailSettings: {
      sandboxMode: { enable: process.env.NODE_ENV !== 'production' },
    },
  }

  try {
    await sgMail.send(msg)
    logger.info({ userId, template: 'welcome' }, 'Welcome email sent')
  } catch (err) {
    // Log without PII — just the error code and userId
    logger.error({ err: { code: err.code, message: err.message }, userId }, 'Failed to send welcome email')
    throw err
  }
}
```

---

## Template management

**Dynamic Templates** live in the SendGrid dashboard, not in code:
- Dashboard → Email API → Dynamic Templates → Create
- Version control template changes with SendGrid's versioning UI
- Use `{{firstName}}` Handlebars syntax for personalisation

```typescript
// Template IDs as environment variables (not hardcoded)
// .env.example
SENDGRID_TEMPLATE_WELCOME=d-abc123...
SENDGRID_TEMPLATE_PASSWORD_RESET=d-def456...
SENDGRID_TEMPLATE_ORDER_CONFIRMATION=d-ghi789...
SENDGRID_TEMPLATE_SHIPPING_UPDATE=d-jkl012...
```

---

## Email service wrapper

```typescript
// src/services/email.service.ts — centralised email sending
import { sgMail } from '../lib/email'

const FROM = { email: 'hello@example.com', name: 'Example App' }

type EmailTemplate =
  | { template: 'welcome';       data: { firstName: string; verificationUrl: string } }
  | { template: 'password-reset'; data: { firstName: string; resetUrl: string; expiresIn: string } }
  | { template: 'order-confirm';  data: { orderId: string; items: Item[]; total: number } }

export async function sendEmail(to: string, payload: EmailTemplate) {
  const templateMap: Record<string, string> = {
    'welcome':        process.env.SENDGRID_TEMPLATE_WELCOME!,
    'password-reset': process.env.SENDGRID_TEMPLATE_PASSWORD_RESET!,
    'order-confirm':  process.env.SENDGRID_TEMPLATE_ORDER_CONFIRMATION!,
  }

  await sgMail.send({
    to,
    from: FROM,
    templateId: templateMap[payload.template],
    dynamicTemplateData: payload.data,
    mailSettings: {
      sandboxMode: { enable: process.env.NODE_ENV !== 'production' },
    },
  })
}
```

---

## Unsubscribe groups (CAN-SPAM / GDPR)

Every marketing email **must** include an unsubscribe link. Use SendGrid's Unsubscribe Groups:

```typescript
// Marketing email — requires unsubscribe group
await sgMail.send({
  to: userEmail,
  from: FROM,
  templateId: NEWSLETTER_TEMPLATE,
  dynamicTemplateData: { ... },
  asm: {
    groupId: Number(process.env.SENDGRID_UNSUBSCRIBE_GROUP_NEWSLETTER!),
    groupsToDisplay: [
      Number(process.env.SENDGRID_UNSUBSCRIBE_GROUP_NEWSLETTER!),
      Number(process.env.SENDGRID_UNSUBSCRIBE_GROUP_PRODUCT_UPDATES!),
    ],
  },
})
```

Transactional emails (receipts, password resets) don't require an unsubscribe group — they're expected.

---

## Webhook events

SendGrid posts delivery events to your webhook URL. Handle them to track actual delivery:

```typescript
// src/routes/email-webhooks.ts
import express from 'express'
import { emailEventService } from '../services/email-event.service'

const router = express.Router()

// Verify webhook signature (optional but recommended)
// Dashboard → Settings → Mail Settings → Event Webhook → Signed Event Webhook

router.post('/webhooks/sendgrid', express.raw({ type: 'application/json' }), async (req, res) => {
  const events = JSON.parse(req.body.toString()) as SendGridEvent[]

  for (const event of events) {
    switch (event.event) {
      case 'delivered':
        await emailEventService.markDelivered(event.sg_message_id, event.email)
        break
      case 'bounce':
        // Hard bounce — suppress future sends to this address
        await emailEventService.markBounced(event.email, event.reason)
        break
      case 'spamreport':
        // User marked as spam — unsubscribe immediately
        await emailEventService.markSpamReport(event.email)
        break
      case 'unsubscribe':
        await emailEventService.handleUnsubscribe(event.email, event.asm_group_id)
        break
    }
  }

  res.status(200).send('OK')
})
```

**Webhook events to handle:**
| Event | Action |
|---|---|
| `delivered` | Mark email as delivered in your DB |
| `bounce` (hard) | Suppress future sends — never retry a hard bounce |
| `bounce` (soft) | Log; retry is automatic |
| `spamreport` | Unsubscribe immediately — mandatory |
| `unsubscribe` | Record consent withdrawal |
| `open` / `click` | Analytics |

---

## Batch sending

```typescript
// Send to multiple recipients without revealing other addresses (BCC alternative)
const messages = users.map((user) => ({
  to: user.email,
  from: FROM,
  templateId: NEWSLETTER_TEMPLATE,
  dynamicTemplateData: {
    firstName: user.firstName,
    unsubscribeToken: user.unsubscribeToken,
  },
}))

// sgMail.send() accepts an array — batches automatically
await sgMail.send(messages)

// For large batches — schedule with sendAt
await sgMail.send({
  ...commonFields,
  to: 'newsletter@list.com',  // use a contact list for bulk
  sendAt: Math.floor(Date.now() / 1000) + 3600,  // send in 1 hour
})
```

---

## Testing

```typescript
// Mock in tests
jest.mock('@sendgrid/mail', () => ({
  setApiKey: jest.fn(),
  send: jest.fn().mockResolvedValue([{ statusCode: 202 }]),
}))

// Or use sandbox mode in staging (validates payload, sends nothing)
mailSettings: { sandboxMode: { enable: true } }
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Building HTML in code | Use SendGrid Dynamic Templates |
| Hardcoded API key | `SENDGRID_API_KEY` environment variable |
| No unsubscribe group on marketing email | Add `asm.groupId` — required by CAN-SPAM |
| Retrying hard bounces | Mark bounced addresses as suppressed; never retry |
| Logging the full email payload | Log only `userId` and `template` — the payload contains PII |
| Missing sandbox mode in staging | Set `mailSettings.sandboxMode.enable = true` outside production |
