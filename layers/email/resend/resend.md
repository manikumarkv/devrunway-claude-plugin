# Resend Standards

---

## Setup

```bash
npm install resend react-email @react-email/components
```

```typescript
// src/lib/resend.ts — singleton client
import { Resend } from 'resend'

export const resend = new Resend(process.env.RESEND_API_KEY)
```

```bash
# .env.example
RESEND_API_KEY=re_live_...          # production
# RESEND_API_KEY=re_test_...        # test (accepted but not delivered)
RESEND_FROM_EMAIL=hello@example.com
RESEND_FROM_NAME=Example App
```

---

## Templates with react-email

```typescript
// src/emails/welcome.email.tsx
import {
  Body, Button, Container, Head, Heading,
  Html, Link, Preview, Section, Text,
} from '@react-email/components'

interface WelcomeEmailProps {
  firstName: string
  verificationUrl: string
}

export function WelcomeEmail({ firstName, verificationUrl }: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Welcome to Example App — verify your email</Preview>
      <Body style={{ fontFamily: 'sans-serif', background: '#fff' }}>
        <Container style={{ maxWidth: 580, margin: 'auto' }}>
          <Heading>Welcome, {firstName}!</Heading>
          <Text>Thanks for signing up. Please verify your email address.</Text>
          <Section>
            <Button href={verificationUrl} style={{ background: '#0070f3', color: '#fff', padding: '12px 24px' }}>
              Verify Email
            </Button>
          </Section>
          <Text style={{ color: '#666', fontSize: 12 }}>
            Or copy this link: <Link href={verificationUrl}>{verificationUrl}</Link>
          </Text>
        </Container>
      </Body>
    </Html>
  )
}

export default WelcomeEmail
```

---

## Email service

```typescript
// src/services/email.service.ts
import { render } from '@react-email/render'
import { resend } from '../lib/resend'
import { logger } from '../lib/logger'
import { WelcomeEmail } from '../emails/welcome.email'
import { PasswordResetEmail } from '../emails/password-reset.email'
import { OrderConfirmationEmail } from '../emails/order-confirmation.email'

const FROM = `${process.env.RESEND_FROM_NAME} <${process.env.RESEND_FROM_EMAIL}>`

export async function sendWelcomeEmail(userId: string, email: string, firstName: string, verificationUrl: string) {
  const { data, error } = await resend.emails.send({
    from: FROM,
    to: email,
    subject: 'Verify your email',
    react: WelcomeEmail({ firstName, verificationUrl }),
    tags: [
      { name: 'category', value: 'onboarding' },
      { name: 'template', value: 'welcome' },
    ],
  })

  if (error) {
    logger.error({ err: error, userId, template: 'welcome' }, 'Failed to send welcome email')
    throw new Error(`Email send failed: ${error.message}`)
  }

  logger.info({ userId, emailId: data?.id, template: 'welcome' }, 'Welcome email sent')
  return data
}

export async function sendPasswordResetEmail(userId: string, email: string, resetUrl: string) {
  const { data, error } = await resend.emails.send({
    from: FROM,
    to: email,
    replyTo: 'support@example.com',
    subject: 'Reset your password',
    react: PasswordResetEmail({ resetUrl, expiresIn: '1 hour' }),
    tags: [{ name: 'category', value: 'transactional' }],
  })

  if (error) {
    logger.error({ err: error, userId, template: 'password-reset' }, 'Failed to send password reset email')
    throw new Error(`Email send failed: ${error.message}`)
  }

  logger.info({ userId, emailId: data?.id, template: 'password-reset' }, 'Password reset email sent')
  return data
}
```

---

## Batch sending

```typescript
// Send to multiple recipients (up to 50 per batch request)
const { data, error } = await resend.batch.send([
  {
    from: FROM,
    to: 'user1@example.com',
    subject: 'Your monthly report',
    react: MonthlyReportEmail({ name: 'Alice', stats: aliceStats }),
  },
  {
    from: FROM,
    to: 'user2@example.com',
    subject: 'Your monthly report',
    react: MonthlyReportEmail({ name: 'Bob', stats: bobStats }),
  },
])
```

---

## Domain verification

1. Add your domain in Resend dashboard → Domains → Add Domain
2. Add DNS records (MX, SPF, DKIM) to your DNS provider
3. Verify — Resend shows green checkmarks when DNS propagates
4. Use `from: 'hello@your-verified-domain.com'` — never a Gmail or unverified address

```bash
# Required DNS records (Resend provides the exact values)
# SPF:  TXT  @ "v=spf1 include:amazonses.com ~all"
# DKIM: CNAME resend._domainkey → ...
# DMARC: TXT _dmarc "v=DMARC1; p=quarantine; rua=mailto:..."
```

---

## Webhook events

```typescript
// src/routes/email-webhooks.ts
import express from 'express'
import { Webhook } from 'svix'     // Resend uses svix for webhook signatures

const router = express.Router()

router.post('/webhooks/resend', express.raw({ type: 'application/json' }), async (req, res) => {
  // Verify signature
  const wh = new Webhook(process.env.RESEND_WEBHOOK_SECRET!)
  const payload = wh.verify(req.body, {
    'svix-id':        req.headers['svix-id'] as string,
    'svix-timestamp': req.headers['svix-timestamp'] as string,
    'svix-signature': req.headers['svix-signature'] as string,
  }) as ResendWebhookEvent

  switch (payload.type) {
    case 'email.delivered':
      await markDelivered(payload.data.email_id)
      break
    case 'email.bounced':
      await markBounced(payload.data.to[0])
      break
    case 'email.complained':
      await suppressEmail(payload.data.to[0])
      break
  }

  res.status(200).json({ received: true })
})
```

---

## Preview templates locally

```bash
# Install react-email CLI
npm install -D @react-email/cli

# Start preview server
npx email dev --dir src/emails --port 3001

# Open http://localhost:3001 to see all templates rendered
```

---

## Testing

```typescript
// Mock in unit tests
jest.mock('../lib/resend', () => ({
  resend: {
    emails: {
      send: jest.fn().mockResolvedValue({ data: { id: 'test-email-id' }, error: null }),
    },
    batch: {
      send: jest.fn().mockResolvedValue({ data: [{ id: 'id-1' }, { id: 'id-2' }], error: null }),
    },
  },
}))

// Integration tests — use test API key (RESEND_API_KEY=re_test_...)
// Test keys accept sends but don't deliver — great for validating payload structure
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Unverified `from` domain | Verify domain in Resend dashboard before going live |
| Creating a new `Resend()` per request | Use the singleton from `src/lib/resend.ts` |
| Not checking the `error` response | `resend.emails.send()` returns `{ data, error }` — always check `error` |
| Building HTML strings | Use `react-email` components — type-safe and testable |
| Using live API key in tests | Use `re_test_...` key or mock |
| Logging full send payload | Log only `userId`, `template`, `emailId` — not email addresses or content |
