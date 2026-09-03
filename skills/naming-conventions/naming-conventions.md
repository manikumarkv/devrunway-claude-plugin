# Naming Conventions

Names at a system boundary are contracts. A local variable can be renamed in one commit; a column name is embedded in migrations, ORM models, API responses, client types, dashboards, and analytics queries. This document covers the boundary names — the ones that are expensive to change after they ship.

---

## Ownership — what lives where

This skill deliberately does not restate conventions owned elsewhere:

| Naming domain | Owner |
|---|---|
| Functions, variables, booleans, constants, file names | `standards` |
| Route paths, path segments, query parameter casing, API versioning | `api-conventions` |
| Commit messages, branch names | `standards` + `conventional-commit` |
| **Tables, columns, indexes, constraints, enums, migrations** | **this skill** |
| **JSON payload keys, custom headers** | **this skill** |
| **Environment variables and secret names** | **this skill** |
| **Test names, fixtures, factories** | **this skill** |

If a rule here appears to contradict one of those skills, they win for their domain.

---

## Database — tables

**`snake_case`, plural.**

```sql
-- ✅
CREATE TABLE order_items (...);
CREATE TABLE users (...);

-- ❌ folds to lowercase and becomes unreadable
CREATE TABLE orderItems (...);   -- Postgres stores this as "orderitems"
```

Postgres folds unquoted identifiers to lowercase. `orderItems` becomes `orderitems` — so the camelCase you wrote is not the name the database holds. The only way to preserve it is double-quoting every reference forever, which is worse than the problem it solves.

**Plural** because a table holds many rows. `users` reads correctly in every query it appears in: `SELECT * FROM users WHERE ...`.

**Join tables:** both table names, alphabetical, singular-plural preserved — `role_users`, `post_tags`.

**Prefixes:** do not prefix tables with `tbl_` or the app name. The schema already provides the namespace.

---

## Database — columns

| Kind | Convention | Example |
|---|---|---|
| Primary key | `id` | `id` |
| Foreign key | `<singular_referenced_table>_id` | `user_id` → `users.id` |
| Timestamp | `<verb_past>_at`, timezone-aware | `created_at`, `deleted_at` |
| Boolean | `is_` / `has_` / `can_` prefix | `is_active`, `has_verified_email` |
| Money | include the unit | `amount_cents`, not `amount` |
| Duration | include the unit | `timeout_ms`, `ttl_seconds` |
| Enum-backed | singular noun | `status`, `role` |

**Foreign keys must match the referenced table.** `user_id` references `users.id`. A column named `owner_id` that references `users.id` requires every reader to look it up — if the relationship genuinely is "owner", name the constraint to disambiguate rather than obscuring the target.

**Booleans in question form.** `is_active` reads as a yes/no. A bare `active` is ambiguous — is it a boolean, a status enum, or a timestamp of activation? The prefix removes the guess.

**Units in the name.** `amount` invites a currency bug; `amount_cents` does not. `timeout` invites a seconds-vs-milliseconds bug; `timeout_ms` does not. This is the single highest-value naming rule in this document.

---

## Database — indexes and constraints

Postgres will auto-name these. Auto-generated names are fine until you need to drop one in a migration and cannot predict what it's called.

| Object | Pattern | Example |
|---|---|---|
| Index | `idx_<table>_<columns>` | `idx_orders_user_id_created_at` |
| Unique | `uq_<table>_<columns>` | `uq_users_email` |
| Foreign key | `fk_<table>_<referenced_table>` | `fk_orders_users` |
| Check | `ck_<table>_<rule>` | `ck_orders_amount_cents_positive` |
| Primary key | `pk_<table>` | `pk_orders` |

```sql
-- ✅ predictable — a later migration can DROP INDEX by name
CREATE INDEX idx_orders_user_id_created_at ON orders (user_id, created_at DESC);

ALTER TABLE orders
  ADD CONSTRAINT ck_orders_amount_cents_positive CHECK (amount_cents > 0);
```

Column order in the index name matches column order in the index, because for a compound index the order is the meaning.

---

## Database — enums and schemas

**Enum type:** singular, `snake_case`, named for the concept — `order_status`, not `order_statuses` or `OrderStatus`.

**Enum values:** `snake_case` lowercase, no prefix repeating the type name.

```sql
-- ✅
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'shipped', 'cancelled');

-- ❌ prefix repeats the type on every read
CREATE TYPE order_status AS ENUM ('order_status_pending', 'ORDER_PAID');
```

**Schemas:** name by bounded context, not by layer — `billing`, `identity`, not `tables`, `views`.

**Roles:** `<app>_<capability>` — `api_readwrite`, `analytics_readonly`. The capability in the name makes an over-privileged connection string obvious on sight.

---

## Database — migration files

```
<timestamp>_<verb>_<subject>.sql
```

```
20260902103000_create_orders_table.sql
20260902104500_add_email_index_to_users.sql
20260902110000_backfill_order_amount_cents.sql
```

- **Timestamp prefix** — `YYYYMMDDHHMMSS`, so files sort in apply order and two developers branching in parallel don't collide on a sequence number
- **Verb** — `create`, `add`, `drop`, `rename`, `backfill`, `alter`. The verb tells a reviewer the blast radius before they open the file
- **Subject** — what is being changed, specific enough to identify without opening

One logical change per migration. A file named `create_orders_table_and_add_user_index_and_backfill` cannot be reverted cleanly.

---

## JSON payload keys

**Pick one casing and hold it at every boundary.** Convert in an explicit mapping layer at the edge — never mid-payload, and never by leaking the database's casing into the response.

```ts
// ✅ explicit boundary mapping — the DB column name is an internal detail
function toOrderResponse(row: OrderRow) {
  return {
    id: row.id,
    amountCents: row.amount_cents,
    createdAt: row.created_at.toISOString(),
  }
}

// ❌ spreads the row — every column rename becomes a breaking API change
function toOrderResponse(row: OrderRow) {
  return { ...row }
}
```

The `...row` spread is the specific anti-pattern to watch for. It couples your public API to your schema, so a column rename that should be a private refactor becomes a client-breaking change, and any column added later — including internal or sensitive ones — is exposed automatically.

**Never expose:** internal surrogate keys you may want to change, columns whose names reveal implementation (`legacy_user_id_v2`), or anything you would not document publicly.

---

## Custom HTTP headers

**Do not use the `X-` prefix.** It was deprecated by RFC 6648 in 2012, because headers that prove useful get standardised and the `X-` name then has to be migrated.

```
✅  Acme-Request-Id: 8f3c...
✅  Acme-Idempotency-Key: 4b21...
❌  X-Request-Id: 8f3c...
```

Pattern: `<Org>-<Purpose>`. Header names are case-insensitive on the wire, but use `Hyphenated-Title-Case` in code and documentation so they read consistently.

---

## Environment variables

**`SCREAMING_SNAKE_CASE`, prefixed by the service or system they belong to.**

```bash
# ✅ unambiguous when 40 vars share one environment
STRIPE_SECRET_KEY=...
DATABASE_URL=...
REDIS_CACHE_URL=...
AUTH_JWT_ISSUER=...
HTTP_CLIENT_TIMEOUT_MS=5000

# ❌ whose key? which URL? seconds or milliseconds?
SECRET_KEY=...
URL=...
TIMEOUT=5000
```

**Suffix by kind** so the type is readable without opening the config:

| Suffix | Holds |
|---|---|
| `_URL` | full connection or endpoint URL |
| `_TOKEN`, `_SECRET`, `_KEY`, `_PASSWORD` | a credential |
| `_TIMEOUT_MS`, `_TTL_SECONDS` | a duration, unit included |
| `_ENABLED` | a boolean feature switch |

**The credential suffixes are a contract with your logging.** Anything ending `_SECRET`, `_TOKEN`, `_KEY`, or `_PASSWORD` must be redacted by your log serialiser and never echoed in error messages or CI output. Naming them consistently is what makes a single redaction rule possible — see `data-governance` and `secret-scanning`.

**Never** name a variable `NODE_ENV`-adjacent to overload it (`APP_ENV`, `ENVIRONMENT`, and `NODE_ENV` all present is a configuration bug waiting to happen). Pick one.

---

## Test names

Name the **behaviour and the condition**, not the function under test. The function name is already visible in the file path and the `describe` block.

```ts
// ✅ reads as a specification; a failure message states what broke
describe('OrderService.cancel', () => {
  it('returns 404 when the order does not exist', ...)
  it('refunds the payment when the order was already paid', ...)
  it('rejects cancellation once the order has shipped', ...)
})

// ❌ a failure tells you nothing
describe('OrderService', () => {
  it('test cancel', ...)
  it('works', ...)
  it('should work correctly', ...)
})
```

**Fixtures and factories:** `<entity>Factory` / `build<Entity>` for generated data, `<entity>Fixture` for a fixed known-value record. Keep the distinction — mixing them makes it unclear whether a test depends on specific values.

---

## Avoid

Anti-patterns, and what each one costs you:

| Avoid | Why it costs you | Instead |
|---|---|---|
| `camelCase` table or column names in Postgres | Unquoted identifiers fold to lowercase, so the stored name differs from the written one; every reference then needs double quotes | `snake_case` throughout |
| Reserved words as identifiers — `user`, `order`, `group`, `end` | Every query must quote them; forgetting once is a runtime syntax error found in production | `users`, `orders`, `groups` |
| `data`, `info`, `value`, `meta`, `payload` as a column name | Names the shape, not the meaning — unreadable in a query written a year later | Name the concept: `settings_json`, `failure_reason` |
| Non-universal abbreviations — `usr_addr_ln1`, `cst_dt` | Saves keystrokes once, costs comprehension on every read; abbreviation schemes are never applied consistently | Write it out: `user_address_line_1` |
| Mixed `id` / `Id` / `ID` in one schema | Forces a lookup before writing any join; ORM mapping layers then need per-column overrides | Pick `id` and hold it |
| Bare adjective booleans — `active`, `deleted` | Ambiguous between boolean, enum, and timestamp; `deleted` in particular is often a nullable timestamp elsewhere in the same schema | `is_active`, `deleted_at` |
| Units omitted — `amount`, `timeout`, `size` | Cents-vs-dollars and seconds-vs-milliseconds are among the most common production bugs, and the name is where they are preventable | `amount_cents`, `timeout_ms` |
| `tbl_` / `t_` prefixes on tables | Hungarian notation for a type the schema already declares; pure noise in every query | Unprefixed |
| Auto-generated constraint names left implicit | A later migration cannot `DROP CONSTRAINT` by a name it cannot predict | Name every constraint explicitly |
| Spreading a DB row into an API response | Couples the public contract to the schema; a private column rename becomes a client-breaking change, and new columns leak automatically | Explicit field mapping at the boundary |
| `X-` prefixed custom headers | Deprecated by RFC 6648; standardisation later forces a migration | `<Org>-<Purpose>` |
| Unprefixed env vars — `SECRET_KEY`, `URL` | Collides as soon as a second service is added; obscures which system a value belongs to | `STRIPE_SECRET_KEY` |
| Multi-change migrations | Cannot be reverted cleanly; a partial failure leaves an unknown state | One logical change per file |

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Choosing a column name to match the ORM's field name | Name the column for the domain; let the ORM map it (`@@map` / `db.Column(name=...)`). The database outlives the ORM. |
| Renaming a column without a deprecation window | Add the new column, backfill, dual-write, migrate readers, then drop. A rename is two contracts, not one. |
| Naming a boolean for the state you happen to check | `is_active` is not `is_not_disabled`. Negated booleans compound into unreadable conditions. |
| Using the plural for an enum type | The type describes one value: `order_status`, not `order_statuses`. |
| Letting the migration filename describe the ticket, not the change | `20260902103000_JIRA_1234.sql` is unreviewable. Put the ticket in the commit message, the change in the filename. |
| Adding a `_v2` suffix to a table or column | Signals an unfinished migration that will now live forever. Finish the migration or keep the original name. |
| Treating naming as style-only in review | Boundary names are contracts. In a new migration or public payload, a naming problem is a blocker, not a nit. |
