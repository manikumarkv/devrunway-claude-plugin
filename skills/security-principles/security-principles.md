# Security Principles

Universal security standards. These hold regardless of language, framework or cloud. Where a rule needs a vendor's API, this document states the *requirement* and defers the mechanics to the relevant auth layer.

**Scope boundary.** This skill covers securing code as it is written. It does not cover: scanning for already-committed secrets (`secret-scanning`), PII classification and erasure (`data-governance`), or running an audit over a branch (`/security-review`). Vendor token mechanics belong to the auth layer in use — `layers/auth/cognito`, `layers/auth/auth0`, `layers/auth/azure-ad`.

---

## 1. Authentication

Authentication answers *who is calling*. It does not answer *what they may do* — see §2.

### Enforce it structurally, not per-handler

Apply authentication as middleware to a route group, so a new route inherits it by default:

```
router.use(requireAuth)          // everything below is authenticated
router.get('/orders', listOrders)
router.post('/orders', createOrder)
```

Never rely on each handler remembering to call an auth check. A handler that forgot is textually identical to one that is intentionally public — so the bug is invisible in review and invisible in the diff that introduces it.

Public routes go on an **explicit allowlist**. The default is authenticated.

**Never:**
- Add a route outside the authenticated group without a comment stating why it is public
- Use a "skip auth in development" flag that can be set in production — make the environment gate the *credentials*, not the *check*

### Verify tokens, do not decode them

Decoding a JWT reads attacker-controlled JSON. Verification checks a signature.

- Verify against the issuer's published public keys (JWKS), cached with a TTL and refreshed on unknown `kid`
- Reject `alg: none` and reject an algorithm the endpoint did not expect — algorithm confusion turns an RS256 verifier into an HS256 one using the public key as the secret
- Check `exp` (expiry), `iss` (issuer) and `aud` (audience) on every token. A correctly signed token from a *different* application is still not valid for yours
- Allow minimal clock skew (≤60s), never unbounded

**Never:**
- `jwt.decode(token)` as the basis for a trust decision — that is not verification
- Accept a token from a query string; it lands in access logs, browser history and referrer headers. Use the `Authorization` header
- Write your own crypto or signature comparison. Use the platform's constant-time verify

### Sessions and cookies

- Session cookies: `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict` for sensitive apps)
- Regenerate the session identifier on privilege change — login, role elevation, password change. Otherwise a pre-login identifier remains valid afterwards (session fixation)
- Invalidate server-side on logout. Deleting the client cookie alone leaves the token usable if it was captured
- Set an absolute maximum lifetime, not only an idle timeout

---

## 2. Authorization

**Authentication is not authorization.** Proving a caller is Alice does not establish that order #4471 is Alice's. Most real-world data exposure is a missing ownership check on an endpoint whose authentication worked perfectly.

### Check ownership in the service layer, on every mutation

```
async function updateOrder(orderId, patch, actor) {
  const order = await repo.findById(orderId)
  if (!order) throw new NotFoundError('Order', orderId)
  if (order.ownerId !== actor.id) throw new ForbiddenError()
  ...
}
```

The check belongs in the service, not the controller: a second caller (a job, a GraphQL resolver, a CLI) reaches the service without passing through the controller.

- Derive `actor` from the **verified token**, never from a body field, query param or header
- Deny by default — an unmatched branch in a permission check fails closed, not open
- Apply the same check to read paths that return records, not only to writes

**Never:**
- Trust `req.body.userId`, `?userId=`, or an `X-User-Id` header as the actor's identity
- Trust a client-supplied `role`, `plan`, `tier` or `isAdmin` — read authorization facts from your own store or from verified token claims
- Rely on the UI not showing a button. The endpoint is the boundary

### Object references

Sequential identifiers let an attacker enumerate by incrementing. The defence is the ownership check above — an unguessable ID is not authorization, only obscurity. Prefer UUIDs where enumeration is itself a leak (knowing how many orders exist), but never treat them as a substitute for §2.

---

## 3. Input validation

### Validate at the boundary, once, into a type

Parse the whole input into a validated shape at the edge, then trust that shape inwards. Field-by-field checks scattered through business logic drift apart.

- Validate **body, path params, query params and headers** — path and query are as attacker-controlled as the body
- **Reject unknown fields** rather than stripping them silently. A renamed field then fails loudly instead of quietly doing nothing
- Enforce length, size and range limits before processing. Unbounded input is a denial-of-service vector, and an unbounded array is one for your database too
- Validate `Content-Type` — do not parse a body as JSON because it happens to look like JSON

### Never pass raw input to a sink

| Sink | Requirement |
|---|---|
| Filesystem path | Resolve, then confirm the result is inside the intended directory — blocking `../` textually is bypassable |
| Shell command | Argument array, never a joined string through a shell |
| Outbound URL fetch | Allowlist of hosts. Otherwise the server becomes a proxy into your private network (SSRF) |
| Redirect target | Allowlist of paths. An open redirect launders phishing through your domain |
| Deserialization | Never deserialize untrusted data into arbitrary types |

### File uploads

- Validate type by inspecting content, not by trusting the `Content-Type` header or the filename extension
- Cap size before reading the stream into memory
- Store outside the web root under a generated name; never serve a user-supplied filename back as a path
- Never make an uploaded file executable

---

## 4. Injection

The rule is one sentence: **never build a query, document or command by concatenating strings that contain user input.**

### SQL

```
// BLOCKER
db.query(`SELECT * FROM orders WHERE id = '${id}'`)

// Correct
db.query('SELECT * FROM orders WHERE id = $1', [id])
```

- Parameterised queries or an ORM's binding API, always
- An ORM does not make you safe — its raw-query escape hatch is exactly as dangerous as the driver's
- Identifiers (table and column names) cannot be parameterised. If one must be dynamic, map it through an allowlist; never interpolate it

### HTML and XSS

- Let the framework escape by default. Reaching for `dangerouslySetInnerHTML`, `v-html` or `innerHTML` means sanitising with a maintained library first, and a comment saying why raw HTML is required
- Escape for the destination context. HTML body, HTML attribute, JavaScript and URL contexts have different rules; a single "sanitise" pass does not cover all four
- Never place user input inside a `<script>` block or an event-handler attribute
- Set a Content-Security-Policy. It is defence in depth, not a substitute for escaping

### Commands and templates

- Pass an argument array; avoid the shell entirely where the platform allows
- Never interpolate user input into a template that is then evaluated — server-side template injection executes code

---

## 5. Secrets

### They never enter the repository

- No credential, API key, token, private key or connection string in source, config, fixtures, test files, seed data, or committed `.env` files
- Read from the environment or a secret manager. Commit a `.env.example` with keys and empty values
- A secret that reached the repository is compromised: **rotate it**, then remove it. Deleting the line does not remove it from history

### They never reach a log or a response

- Never log a secret, token, password, session identifier, or a full `Authorization` header
- Redact at the point of logging with a field allowlist. Logging an object and stripping fields afterwards fails the moment someone adds a field
- Never return a secret in an error response, and never embed one in a frontend bundle — anything shipped to the browser is public, including "private" build-time variables

### Handling

- Least privilege: a credential grants the narrowest scope for the shortest lifetime that works
- Prefer short-lived, automatically rotated credentials over long-lived static keys
- One credential per service per environment — a shared key cannot be revoked without an outage

---

## 6. Failing safely

### Error responses

Say what the caller can fix. Never what the system is.

- No stack traces, SQL fragments, internal file paths, hostnames, or dependency versions across the boundary
- Log the detail server-side with a correlation ID; return that ID so a user can quote it in a support request
- A generic 500 with a reference beats a helpful message that maps your internals

### Do not confirm what you have not authorized

- Return an identical response for "wrong password" and "no such account". Divergent responses or timings enumerate users
- Where existence is itself sensitive, prefer 404 over 403 — a 403 confirms the record exists
- Rate-limit authentication endpoints, password reset and any enumerable lookup

### Timing

Compare secrets, tokens and MACs with a constant-time function. A normal string comparison returns faster on an earlier mismatch, which leaks the value one byte at a time.

---

## 7. Dependencies and transport

- TLS everywhere, including internal service-to-service calls. Never disable certificate verification — a `rejectUnauthorized: false` in committed code is a BLOCKER
- HSTS on anything browser-facing
- Keep a lockfile committed and run dependency audits in CI. Treat a known-exploitable transitive dependency as a build failure, not a warning
- Pin or verify anything executed at build time; a build step that curls a script and pipes it to a shell is a supply-chain hole

---

## Common mistakes

| Mistake | Why it fails | Correct |
|---|---|---|
| Auth checked in each handler | One forgotten handler is invisible in review | Middleware on the route group; public routes allowlisted |
| `jwt.decode()` to read claims | Reads attacker-controlled JSON; no signature checked | Verify against JWKS, check `exp`/`iss`/`aud` |
| Authenticated, so authorized | Proves identity, not access to *this* record | Ownership check in the service layer |
| Actor read from request body | Client controls it — trivially impersonated | Actor from the verified token only |
| `WHERE id = '${id}'` | SQL injection | Parameterised query |
| Sanitising once, generically | HTML, attribute, JS and URL contexts differ | Escape for the destination context |
| Secret removed in a later commit | History still contains it | Rotate first, then remove |
| Logging the whole request object | New sensitive fields get logged automatically | Field allowlist at the log call |
| Stack trace in the error response | Maps internals for an attacker | Log server-side, return a correlation ID |
| "No such user" vs "wrong password" | Enumerates accounts | One identical response for both |
