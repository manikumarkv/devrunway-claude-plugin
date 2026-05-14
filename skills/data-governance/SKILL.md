---
name: data-governance
description: Data privacy and governance standards — PII field identification, GDPR/CCPA right to erasure, data retention, consent tracking, and data export. Always-on background skill applied when writing schema, services, or controllers that touch personal data.
user-invocable: false
---

Full standards in [data-governance.md](data-governance.md). Always-on summary:

**PII tagging rule** — any Prisma field storing personal data must have a `// @pii` comment:
```prisma
email     String  @unique  // @pii
name      String?          // @pii
phone     String?          // @pii
ipAddress String?          // @pii:derived
```

**Right to erasure** — never hard delete a user row. Anonymise in place:
```ts
// NEVER: prisma.user.delete({ where: { id } })
// ALWAYS: anonymise then soft-delete
await anonymiseUser(userId)   // replaces @pii fields with hashed/nulled values
await prisma.user.update({ where: { id: userId }, data: { deletedAt: new Date() } })
```

**Data retention** — records past their retention window are anonymised, not deleted:
- User-generated content: retain 7 years (financial audit trail)
- Session/auth logs: retain 90 days
- Deleted user PII: anonymise within 30 days of erasure request

**Consent** — never send marketing or analytics events without recorded consent:
```ts
const user = await prisma.user.findUniqueOrThrow({ where: { id }, select: { consentMarketing: true } })
if (!user.consentMarketing) return   // skip — no consent
```

**Logs** — these fields must never appear in any log line:
`email`, `name`, `password`, `phone`, `dateOfBirth`, `address`, `ipAddress`, `token`, `cardNumber`

**Never:**
- Log PII at any severity level
- Store unencrypted PII in DynamoDB or S3 without SSE
- Share PII with third-party services without a DPA
- Return PII fields in paginated list responses — only in single-resource GET

**Related skills — apply together:**
- `security` — encryption at rest, IAM controls on tables storing PII
- `database-sql` — soft delete and schema conventions for PII fields
- `api-conventions` — strip PII from paginated list response shapes
- `error-handling` — never include user PII in error messages sent to the client
