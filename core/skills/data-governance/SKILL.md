---
name: data-governance
description: Data privacy and governance standards — PII field identification, GDPR/CCPA right to erasure, data retention, consent tracking, and data export. Always-on background skill applied when writing schema, services, or controllers that touch personal data.
user-invocable: false
---

Full standards in [data-governance.md](data-governance.md). Always-on summary:

**PII tagging rule** — any field storing personal data must be tagged with a `// @pii` annotation (or your ORM's equivalent) to make PII auditable with a simple grep:
```
email     String   // @pii
name      String?  // @pii
phone     String?  // @pii
ipAddress String?  // @pii:derived
```

**Right to erasure** — never hard delete a user row. Anonymise PII in place, then soft-delete:
```
// NEVER: delete user where id = userId
// ALWAYS:
anonymise all @pii fields on the user record (null them out or replace with redacted values)
set deletedAt = now()
keep the row for referential integrity and audit trail
```

**Data retention** — records past their retention window are anonymised, not deleted:
- User-generated content: retain 7 years (financial audit trail)
- Session/auth logs: retain 90 days
- Deleted user PII: anonymise within 30 days of erasure request

**Consent** — never send marketing or analytics events without recorded consent:
```
user = fetch user consent flags
if user.consentMarketing is false: skip — do not send marketing event
```

**Logs** — these fields must never appear in any log line:
`email`, `name`, `password`, `phone`, `dateOfBirth`, `address`, `ipAddress`, `token`, `cardNumber`

**Never:**
- Log PII at any severity level
- Store unencrypted PII without encryption at rest
- Share PII with third-party services without a Data Processing Agreement (DPA)
- Return PII fields in paginated list responses — only in single-resource GET

**Related skills — apply together:**
- `security` — encryption at rest, access controls on tables storing PII
- Your database layer — soft delete and schema conventions for PII fields
- `api-conventions` — strip PII from paginated list response shapes
- `error-handling` — never include user PII in error messages sent to the client
