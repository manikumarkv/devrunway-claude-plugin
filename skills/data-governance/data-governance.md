# Data Governance Standards

Universal principles for handling personal data. For ORM-specific, framework-specific, or cloud-specific implementation, consult your installed layer skills.

---

## PII field identification

Tag every field that holds personal data with a `// @pii` annotation. This makes PII auditable with a simple grep.

```
Entity: User
Fields:
  id              — unique identifier
  email           — String, unique          // @pii
  name            — String, optional        // @pii
  phone           — String, optional        // @pii
  dateOfBirth     — Date, optional          // @pii:sensitive
  addressLine1    — String, optional        // @pii
  addressLine2    — String, optional        // @pii
  city            — String, optional        // @pii
  country         — String, optional        // @pii:derived
  ipAddress       — String, optional        // @pii:derived
  consentMarketing — Boolean, default false
  consentAnalytics — Boolean, default false
  consentDate      — Timestamp, optional
  deletedAt        — Timestamp, optional    (soft delete)
  createdAt        — Timestamp, auto
  updatedAt        — Timestamp, auto
```

**PII tiers:**
- `// @pii` — directly identifies a person (email, name, phone)
- `// @pii:sensitive` — special category data (health, financial, biometric)
- `// @pii:derived` — indirectly identifying (IP address, device ID, location)

Audit all PII fields with:
```bash
grep -rn '@pii' <your-schema-file>
```

_(Use your database layer's annotation or comment convention to mark PII fields in the schema)_

---

## Right to erasure (GDPR Article 17)

Never hard-delete a user. Anonymise all PII in place, then soft-delete.

```
function anonymiseUser(userId):
  // 1. Replace all @pii fields with anonymous values
  update User where id = userId:
    email = "deleted-{userId}@redacted.invalid"
    name = null
    phone = null
    dateOfBirth = null
    addressLine1 = null
    addressLine2 = null
    city = null
    country = null
    ipAddress = null
    deletedAt = now()

  // 2. Anonymise PII in related records
  // Keep records for audit trail — only null out the personal fields
  update Order where userId = userId:
    shippingAddress = "[redacted]"

  // 3. Log the erasure (without PII — just userId and timestamp)
  log info: { userId, action: "user_anonymised", timestamp: now() }
```

**Do NOT:**
- Delete the user row — breaks foreign key audit trails
- Delete orders/transactions — required for financial compliance
- Erase data within a retention hold (legal, financial, fraud investigation)

---

## Data retention policy

| Data type | Retention | Action after |
|---|---|---|
| Active user PII | Until erasure request | Anonymise on request |
| Deleted user PII | 30 days after soft-delete | Auto-anonymise |
| Order / transaction records | 7 years | Anonymise PII fields, keep financial data |
| Auth / session logs | 90 days | Hard delete |
| Infrastructure logs | 90 days | Expire via log management config |
| Error tracking events | 90 days | Configure in your error tracking service |

```
// Nightly retention cleanup job

function runRetentionCleanup():
  thirtyDaysAgo = now() - 30 days

  // Find users deleted > 30 days ago that still have PII
  staleUsers = query User where:
    deletedAt < thirtyDaysAgo
    AND email does NOT end with "@redacted.invalid"  // not yet anonymised

  for each user in staleUsers:
    anonymiseUser(user.id)
    log info: { userId: user.id, action: "retention_cleanup" }

  // Hard delete auth logs older than 90 days
  ninetyDaysAgo = now() - 90 days
  delete from AuthLog where createdAt < ninetyDaysAgo
  log info: { action: "auth_logs_purged", count: N }
```

_(Implement using your database layer and scheduled job infrastructure)_

---

## GDPR data export (Article 20 — data portability)

Every user can request a machine-readable export of all their data.

```
function generateUserDataExport(userId):
  // Fetch user's own data
  user = fetch User where id = userId
         select: id, email, name, phone, createdAt, consentMarketing, consentAnalytics

  // Fetch related records
  orders = fetch Order where userId = userId
           select: id, createdAt, total, status

  sessions = fetch AuthLog where userId = userId
             select: createdAt, action, ipAddress
             limit: 1000

  return {
    exportedAt: now(),
    exportVersion: "1.0",
    subject: {
      id: user.id,
      email: user.email,
      name: user.name,
      phone: user.phone,
      memberSince: user.createdAt,
      marketingConsent: user.consentMarketing,
      analyticsConsent: user.consentAnalytics,
    },
    orders: [ { id, date, total, status } for each order ],
    loginHistory: [ { date, action, ipAddress } for each session ],
  }
```

Expose via a protected endpoint:
```
GET /api/v1/me/data-export — requires authentication
Returns: JSON file download
Header: Content-Disposition: attachment; filename="my-data-{timestamp}.json"
```

_(Implement using your backend layer's request handling and response conventions)_

---

## Consent management

Never assume consent. Always read it from the user record before using personal data.

```
function assertConsent(userId, type: "marketing" | "analytics"):
  user = fetch User where id = userId
         select: consentMarketing, consentAnalytics

  hasConsent = (type == "marketing") ? user.consentMarketing : user.consentAnalytics
  if NOT hasConsent:
    throw ForbiddenError("User has not consented to {type} data use")

// Usage in analytics service:
function trackEvent(userId, event, properties):
  assertConsent(userId, "analytics")   // throws if no consent
  // safe to track
  analyticsClient.track(userId, event, properties)
```

Record consent changes with a timestamp and source:

```
Entity: ConsentLog
Fields:
  id        — unique identifier
  userId    — reference to User
  type      — String ("marketing" | "analytics")
  granted   — Boolean
  source    — String ("signup" | "settings" | "cookie-banner")
  ipAddress — String  // @pii:derived
  createdAt — Timestamp, auto
```

---

## PII in logs — hard rules

**Never log these fields at any severity level:**
`email`, `name`, `phone`, `password`, `token`, `dateOfBirth`, `address`, `ipAddress`, `cardNumber`, `ssn`, `taxId`, `passportNumber`

Configure your structured logger to redact these fields automatically:

```
logger configuration:
  redact paths:
    - "*.email"
    - "*.name"
    - "*.phone"
    - "*.password"
    - "*.token"
    - "*.ipAddress"
    - "*.cardNumber"
  censor value: "[redacted]"
```

_(Use your logging layer's redaction feature — e.g. Pino `redact`, Structlog filters, NLog masking)_

---

## CCPA — opt-out of data sale

For California users, provide a "Do Not Sell My Personal Information" mechanism.

Add a `doNotSell` flag to the User entity:
```
doNotSell — Boolean, default false  // CCPA opt-out
```

Check before sharing with any third-party data processor:
```
function shareWithThirdParty(userId, data, vendor):
  user = fetch User where id = userId
         select: doNotSell, country

  if user.doNotSell OR user.country == "US":
    log info: { userId, vendor, reason: "CCPA opt-out or US user" }
    return  // do not share

  externalVendor.send(vendor, data)
```

---

## Response shape rules

PII fields must never appear in paginated list responses. Only in single-resource GETs for the authenticated user's own data.

```
// ❌ List endpoint — exposes all users' PII
GET /api/v1/users
→ returns full user objects including email, name, phone

// ✅ List endpoint — returns only non-PII fields
GET /api/v1/users
→ select: id, displayName, avatarUrl, createdAt

// ✅ Single resource — own account only, after auth check
GET /api/v1/me
→ select: id, email, name, phone, createdAt
```
