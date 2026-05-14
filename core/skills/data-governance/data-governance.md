# Data Governance Standards

---

## PII field identification

Tag every Prisma field that holds personal data with a `// @pii` comment. This makes PII auditable with a simple grep.

```prisma
model User {
  id              String    @id @default(cuid())
  email           String    @unique  // @pii
  name            String?            // @pii
  phone           String?            // @pii
  dateOfBirth     DateTime?          // @pii:sensitive
  addressLine1    String?            // @pii
  addressLine2    String?            // @pii
  city            String?            // @pii
  country         String?            // @pii:derived
  ipAddress       String?            // @pii:derived
  consentMarketing Boolean  @default(false)
  consentAnalytics Boolean  @default(false)
  consentDate      DateTime?
  deletedAt       DateTime?
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt

  @@map("users")
}
```

**PII tiers:**
- `// @pii` — directly identifies a person (email, name, phone)
- `// @pii:sensitive` — special category (health, financial, biometric)
- `// @pii:derived` — indirectly identifying (IP address, device ID, location)

Audit all PII fields with:
```bash
grep -rn '@pii' prisma/schema.prisma
```

---

## Right to erasure (GDPR Article 17)

Never hard-delete a user. Anonymise all PII in place, then soft-delete.

```ts
// src/services/user.service.ts

const PII_ANONYMOUS_VALUES = {
  email: (id: string) => `deleted-${id}@redacted.invalid`,
  name: null,
  phone: null,
  dateOfBirth: null,
  addressLine1: null,
  addressLine2: null,
  city: null,
  country: null,
  ipAddress: null,
}

export async function anonymiseUser(userId: string): Promise<void> {
  // 1. Anonymise the user record
  await prisma.user.update({
    where: { id: userId },
    data: {
      ...PII_ANONYMOUS_VALUES,
      email: PII_ANONYMOUS_VALUES.email(userId),
      deletedAt: new Date(),
    },
  })

  // 2. Anonymise related records that contain PII
  //    Keep records for audit trail — only null out the personal fields
  await prisma.order.updateMany({
    where: { userId },
    data: { shippingAddress: '[redacted]' },
  })

  // 3. Log the erasure (without PII — just the user ID and timestamp)
  logger.info({ userId, action: 'user_anonymised' }, 'User data anonymised on erasure request')
}
```

**Do NOT:**
- Delete the user row — breaks foreign key audit trails
- Delete orders/transactions — required for financial compliance
- Erase data within a retention hold (legal, financial, fraud investigation)

---

## Data retention policy

Define retention per data category. Implement via a nightly Prisma job.

| Data type | Retention | Action after |
|---|---|---|
| Active user PII | Until erasure request | Anonymise on request |
| Deleted user PII | 30 days after deletedAt | Auto-anonymise |
| Order / transaction records | 7 years | Anonymise PII fields, keep financial data |
| Auth / session logs | 90 days | Hard delete |
| CloudWatch logs | 90 days (set in CDK) | Auto-expire |
| Sentry error events | 90 days | Sentry auto-purge |

```ts
// scripts/retention-cleanup.ts — run nightly via Lambda scheduled event

import { prisma } from '../src/lib/prisma'
import { anonymiseUser } from '../src/services/user.service'

async function runRetentionCleanup() {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)

  // Find users deleted more than 30 days ago that still have PII
  const staleUsers = await prisma.user.findMany({
    where: {
      deletedAt: { lt: thirtyDaysAgo },
      email: { not: { endsWith: '@redacted.invalid' } },  // not yet anonymised
    },
    select: { id: true },
  })

  for (const user of staleUsers) {
    await anonymiseUser(user.id)
    logger.info({ userId: user.id }, 'Retention cleanup: user anonymised')
  }

  // Hard delete auth logs older than 90 days
  const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)
  const deleted = await prisma.authLog.deleteMany({
    where: { createdAt: { lt: ninetyDaysAgo } },
  })
  logger.info({ count: deleted.count }, 'Retention cleanup: auth logs purged')
}
```

---

## GDPR data export (Article 20 — data portability)

Every user can request a machine-readable export of all their data.

```ts
// src/services/data-export.service.ts

export async function generateUserDataExport(userId: string): Promise<object> {
  const [user, orders, sessions] = await Promise.all([
    prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: {
        id: true, email: true, name: true, phone: true,
        createdAt: true, consentMarketing: true, consentAnalytics: true,
      },
    }),
    prisma.order.findMany({
      where: { userId },
      select: { id: true, createdAt: true, total: true, status: true },
    }),
    prisma.authLog.findMany({
      where: { userId },
      select: { createdAt: true, action: true, ipAddress: true },
      take: 1000,
    }),
  ])

  return {
    exportedAt: new Date().toISOString(),
    exportVersion: '1.0',
    subject: {
      id: user.id,
      email: user.email,
      name: user.name,
      phone: user.phone,
      memberSince: user.createdAt,
      marketingConsent: user.consentMarketing,
      analyticsConsent: user.consentAnalytics,
    },
    orders: orders.map(o => ({
      id: o.id,
      date: o.createdAt,
      total: o.total,
      status: o.status,
    })),
    loginHistory: sessions.map(s => ({
      date: s.createdAt,
      action: s.action,
      ipAddress: s.ipAddress,
    })),
  }
}
```

Expose via a protected endpoint:
```ts
// GET /api/v1/me/data-export — returns JSON, triggers download header
router.get('/me/data-export', requireAuth(), asyncHandler(async (req, res) => {
  const data = await generateUserDataExport(req.user.sub)
  res.setHeader('Content-Disposition', `attachment; filename="my-data-${Date.now()}.json"`)
  res.setHeader('Content-Type', 'application/json')
  res.json(data)
}))
```

---

## Consent management

Never assume consent. Always read it from the user record before using personal data.

```ts
// src/lib/consent.ts

export async function assertConsent(userId: string, type: 'marketing' | 'analytics'): Promise<void> {
  const user = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
    select: { consentMarketing: true, consentAnalytics: true },
  })

  const hasConsent = type === 'marketing' ? user.consentMarketing : user.consentAnalytics
  if (!hasConsent) {
    throw new ForbiddenError(`User has not consented to ${type} data use`)
  }
}

// Usage in analytics service:
export async function trackEvent(userId: string, event: string, properties: object) {
  await assertConsent(userId, 'analytics')
  // safe to track
  segment.track({ userId, event, properties })
}
```

Record consent changes with a timestamp and source:
```prisma
model ConsentLog {
  id          String   @id @default(cuid())
  userId      String
  type        String   // 'marketing' | 'analytics'
  granted     Boolean
  source      String   // 'signup' | 'settings' | 'cookie-banner'
  ipAddress   String   // @pii:derived
  createdAt   DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@map("consent_logs")
}
```

---

## PII in logs — hard rules

**Never log these fields at any severity level:**

```ts
// src/lib/logger.ts — add a redaction serializer to Pino

import pino from 'pino'

const PII_FIELDS = ['email', 'name', 'phone', 'password', 'token',
                    'dateOfBirth', 'address', 'ipAddress', 'cardNumber',
                    'ssn', 'taxId', 'passportNumber']

function redact(obj: Record<string, unknown>): Record<string, unknown> {
  const result = { ...obj }
  for (const key of PII_FIELDS) {
    if (key in result) result[key] = '[redacted]'
  }
  return result
}

export const logger = pino({
  redact: {
    paths: PII_FIELDS.map(f => `*.${f}`),
    censor: '[redacted]',
  },
})
```

---

## CCPA — opt-out of data sale

For California users, provide a "Do Not Sell My Personal Information" mechanism:

```prisma
// Add to User model
doNotSell Boolean @default(false)  // CCPA opt-out
```

```ts
// Check before sharing with any third-party data processor
export async function shareWithThirdParty(userId: string, data: object, vendor: string) {
  const user = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
    select: { doNotSell: true, country: true },
  })

  if (user.doNotSell || user.country === 'US') {
    logger.info({ userId, vendor }, 'Third-party share blocked — CCPA opt-out or US user')
    return
  }

  await externalVendor.send(vendor, data)
}
```

---

## Response shape rules

PII fields must never appear in paginated list responses. Only in single-resource GETs.

```ts
// ❌ — exposes all users' emails in a list
const users = await prisma.user.findMany()
return paginated(res, users, meta)

// ✅ — list returns only non-PII fields
const users = await prisma.user.findMany({
  select: { id: true, displayName: true, avatarUrl: true, createdAt: true },
})
return paginated(res, users, meta)

// ✅ — single user GET includes PII (own account only, after auth check)
const user = await prisma.user.findUniqueOrThrow({
  where: { id: req.user.sub },
  select: { id: true, email: true, name: true, phone: true, createdAt: true },
})
return ok(res, user)
```
