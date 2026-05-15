# Universal Engineering Standards

These principles apply regardless of language, framework, or stack. For technology-specific standards, see your installed layer skills.

---

## Naming

Names are the primary documentation of intent. Optimise for the reader, not the writer.

**Functions:** verb + noun that describes what it does and what it operates on.
- `validatePaymentAmount(amount)` not `validate(amount)` or `check(x)`
- `fetchUserById(id)` not `getUser(id)` (fetch signals async I/O)
- `buildOrderSummary(items)` not `process(items)`

**Variables:** noun that describes what the value represents, not what it is.
- `userCount` not `n` or `num`
- `isPaymentProcessed` not `flag` or `status`
- `activeSubscriptions` not `data` or `result`

**Booleans:** always a yes/no question form.
- `isLoading`, `hasError`, `canEdit`, `shouldRetry`

**Constants:** SCREAMING_SNAKE_CASE for true constants; avoid using it for mutable config.

**Files and modules:** name after the primary export or responsibility.
- `UserRepository` → `user.repository.ts`
- `paymentUtils` → `payment.utils.ts`

---

## Single Responsibility

**One function, one job.** If you need "and" to describe what a function does, it does too much:
- `validateAndSaveUser()` → split into `validateUser()` + `saveUser()`
- `fetchAndFormatReport()` → split into `fetchReport()` + `formatReport()`

**One module, one concept.** A module should have one reason to change. Mixing auth logic and billing logic in the same file means both change that file.

**Controllers are thin.** Route handlers / controllers validate input, call a service, return a response. Business logic lives in the service layer, not in controllers.

**Services contain business logic.** Services orchestrate business rules. They do not contain SQL, HTTP calls, or framework objects.

**Repositories contain data access.** Database queries belong in a repository layer, not scattered across services or controllers.

---

## DRY (Don't Repeat Yourself)

**Rule of three:** tolerate one duplicate; tolerate a second; extract on the third.

Premature abstraction — extracting after one use — creates the wrong abstraction. Real duplication reveals the right shape of the abstraction.

**What to extract:**
- Business rules that appear in multiple places
- Validation logic applied to the same data in different contexts
- Error-handling patterns repeated across similar functions

**What NOT to extract:**
- Code that looks similar but handles genuinely different concepts
- Very short expressions (extracting `x + 1` into `increment(x)` adds noise)
- Test setup — test code duplication is often intentional for readability

---

## Tests Alongside Source

Tests live next to the code they test:

```
src/
  payment/
    payment.service.ts
    payment.service.test.ts      ← next to the source
    payment.repository.ts
    payment.repository.test.ts
```

**Why:** Tests are the documentation of expected behaviour. They belong where the reader looks for that documentation — next to the code.

**Unit tests:** one file per module, testing public behaviour not implementation details.

**Integration tests:** test the component with real dependencies (DB, external service) — put in a `__tests__/integration/` folder if you need to distinguish.

**Test naming:** `describe('<function/module>')` + `it('should <expected behaviour> when <condition>')`.

---

## Explicit Dependencies

A function declares everything it needs as a parameter. No hidden reaching:

```
# ❌ Hidden dependency — function secretly uses a global
def process_order(order_id):
    db = get_global_db()          # hidden; untestable; couples to global state
    config = read_env("API_KEY")  # hidden
    ...

# ✅ Explicit — all dependencies declared
def process_order(order_id, db, api_key):
    ...
```

**Infrastructure is injected:**
- Database clients, HTTP clients, loggers, config — passed in, not imported directly into business logic
- Business logic can be tested with a fake/mock dependency without touching real infrastructure

**Business logic has no imports from frameworks.** A service should not import Express, Flask, or any HTTP framework. It receives plain data objects, returns plain data objects.

---

## Fail Fast at the Boundary

**Validate early, trust inside:**
1. Input arrives from outside the system (HTTP request, file, queue message, user input)
2. Validate it immediately at the entry point — schema, types, required fields, ranges
3. If invalid → reject immediately with a clear error
4. If valid → convert to a typed domain object and pass inward
5. Inside the system, trust the types — no redundant null-checks or re-validation

**Never silently coerce.** `"" → 0`, `null → []`, `undefined → false` hide bugs. Reject invalid input explicitly.

**Never swallow exceptions.** Every `catch` block should either: handle the error and recover, or re-throw with additional context. Empty catch blocks are bugs.

---

## No Dead Code

**Remove, don't comment out.** Commented-out code is noise — version control is the history.

**Remove unused imports immediately.** They make the dependency graph misleading.

**No unreachable branches.** An `else` after `return` is unreachable. A `catch` that only rethrows unchanged is redundant.

**TODO/FIXME must have an owner.** A bare `// TODO: fix this` is meaningless. `// TODO(2024-Q1 #123): fix race condition in token refresh` is actionable.

---

## Git & Version Control Conventions

These are universal across git providers:

**Commit messages:** imperative mood, short subject line (≤72 chars), body explains *why* not *what*.
- ✅ `Add idempotency key to payment retry logic`
- ❌ `fixed stuff` / `WIP` / `asdfgh`

**Conventional Commits:** `type(scope): description` — `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`.

**Small commits:** one logical change per commit. Large commits are hard to review, hard to revert, hard to bisect.

**Branch naming:** `type/issue-id-short-description` — e.g. `feat/123-add-payment-retry`, `fix/456-token-expiry`.

**For provider-specific workflow** (PR templates, CI gates, protected branches), see your source-control layer.
