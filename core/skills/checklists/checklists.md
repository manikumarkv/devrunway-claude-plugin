# Universal Quality Checklists

These checklists apply to any language or stack. For technology-specific checklists, see your installed layer skills.

---

## Feature Addition Checklist

Apply when adding any new feature, endpoint, function, or behaviour.

**Correctness**
- [ ] The happy path works as expected
- [ ] Edge cases are handled (empty input, zero, null, max values)
- [ ] Error cases are handled and return meaningful messages
- [ ] Concurrent access is considered (race conditions, idempotency) where relevant

**Validation**
- [ ] All inputs are validated at the entry point before processing
- [ ] Validation errors return clear, actionable messages — not generic "invalid input"
- [ ] No trust placed in client-supplied data without verification

**Authentication & Authorisation**
- [ ] Unauthenticated requests are rejected (if the feature requires auth)
- [ ] The caller has permission to perform this action on this resource
- [ ] Ownership is checked: a user can only access their own resources unless explicitly granted broader access

**Error Handling**
- [ ] All errors are caught — no unhandled promise rejections or uncaught exceptions
- [ ] Errors are logged with enough context to diagnose them
- [ ] Error responses do not leak internal details (stack traces, query text, file paths)

**Testing**
- [ ] Happy path has at least one test
- [ ] At least two failure/edge cases are tested
- [ ] Tests verify behaviour, not implementation details

**Logging**
- [ ] Significant business events are logged (created, updated, deleted)
- [ ] No PII (names, emails, passwords, tokens) in log messages
- [ ] No debug logging left in production code

**Security**
- [ ] No secrets or credentials hardcoded
- [ ] Input is sanitised before use in queries, HTML rendering, or shell commands
- [ ] Resource identifiers are not user-controlled without validation

**Documentation**
- [ ] Public functions/endpoints have a description
- [ ] Complex logic has an inline comment explaining *why*, not *what*

---

## API Endpoint Checklist

Apply when creating or modifying any API endpoint.

**Design**
- [ ] URL follows REST conventions (plural nouns, no verbs, nested for ownership)
- [ ] Correct HTTP method (GET read, POST create, PUT/PATCH update, DELETE remove)
- [ ] Response envelope is consistent with the rest of the API
- [ ] Versioned from day one (`/v1/`, `/v2/`)

**HTTP Status Codes**
- [ ] `200` successful reads/updates · `201` creation · `204` deletion (no body)
- [ ] `400` validation errors · `401` not authenticated · `403` not authorised
- [ ] `404` not found · `409` conflict · `422` business rule violated · `500` unexpected

**Validation & Auth**
- [ ] All request body, path params, and query params validated before use
- [ ] Auth middleware applied — unauthenticated requests rejected
- [ ] Authorisation checked for this specific resource, not just the action type

**Error Responses**
- [ ] Machine-readable error code + human-readable message
- [ ] Validation errors list every invalid field (not just the first)
- [ ] No internal details exposed (no stack traces, no query text)

**Documentation**
- [ ] Endpoint registered in API docs (OpenAPI or equivalent)
- [ ] Request/response shapes documented with examples

---

## Data Model Change Checklist

Apply when adding or altering a database table, collection, schema, or model.

**Design**
- [ ] New fields have defaults or are nullable — never add non-nullable columns to existing data without a default
- [ ] Naming is consistent with existing conventions
- [ ] The change is backwards-compatible with existing data, or a migration strategy is defined

**Migration**
- [ ] Migration is reversible (has a rollback path)
- [ ] Migration tested on a copy of production data or staging
- [ ] Large table changes use a safe strategy (add → backfill → constrain — not one `ALTER` on a live table)

**Indexes**
- [ ] Columns used in WHERE, ORDER BY, or JOIN are indexed
- [ ] No redundant duplicate indexes

**Test Data**
- [ ] Test factories/seeders updated for new required fields
- [ ] Existing tests still pass after migration

---

## Logging Checklist

Apply when adding or reviewing any log statement.

- [ ] Log level is appropriate: `error` (needs response), `warn` (handled but notable), `info` (business event), `debug` (dev only)
- [ ] Log message is a static string — dynamic values are in structured fields, not interpolated into the message
- [ ] No PII in any field: no emails, full names, passwords, tokens, payment data, national IDs
- [ ] Enough context to diagnose without reading source code (request ID, user ID, relevant entity IDs)
- [ ] Sensitive values are redacted at the logger configuration level
- [ ] Project's structured logger used — not `console.log` / `print` directly

---

## Secrets & Credentials Checklist

Apply when handling any secret, token, API key, or credential.

- [ ] Secret stored in the project's secrets manager — not in committed config files
- [ ] `.env` / secrets files are in `.gitignore` — verified before first commit on any new repo
- [ ] Secret never logged — not even at `debug` level
- [ ] Secret never returned in an API response
- [ ] Secret accessed via environment variable or secrets client — never hardcoded
- [ ] Credential has only the permissions it needs (least privilege)
- [ ] Rotation plan exists for if the secret leaks

---

## Auth & Authorisation Checklist

Apply to any code path handling authentication or access control.

- [ ] Authentication enforced — unauthenticated callers rejected
- [ ] Tokens validated server-side — not just decoded and trusted
- [ ] Token expiry checked on every request, not only at login
- [ ] Authorisation checked for the specific resource (not just the action type)
- [ ] Ownership check: `resource.ownerId === caller.id` before allowing mutation
- [ ] Role/group checks use server-authoritative data — never trust role claims from the client
- [ ] `401` for unauthenticated, `403` for unauthorised — not `404` (unless security policy requires it)
- [ ] Auth errors do not reveal whether the resource exists or what permissions are required

---

*For technology-specific checklists (React components, Prisma migrations, Cognito auth, Express routes, etc.), consult your installed layer skills.*
