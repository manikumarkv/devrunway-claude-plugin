# Neon (Lakebase Postgres) Standards

Neon is Postgres with storage decoupled from compute. Everything you know about Postgres still applies — this document covers only what changes *because* compute is elastic, suspends when idle, branches, and bills egress.

**Scope boundaries.** This layer holds enforceable rules. For API reference, setup walkthroughs, and product documentation, use the official `neon` plugin skills (`neon-postgres`, `neon-postgres-branches`, `neon-postgres-egress-optimizer`). For SQL schema design, indexing, and query construction see `database-sql`. For table, column, and env var naming see `naming-conventions`.

---

## 1. Connection strings — you have two, and they are not interchangeable

Neon issues two connection strings for the same database. `neon env pull` writes both:

| Variable | Hostname | Routes through | Use for |
|---|---|---|---|
| `DATABASE_URL` | carries `-pooler` | PgBouncer, transaction mode | All application queries |
| `DATABASE_URL_UNPOOLED` | no `-pooler` | Direct to compute | Migrations, `pg_dump`/`pg_restore`, logical replication, `LISTEN`/`NOTIFY`, `SET`, advisory locks, session state |

**Rule: application code uses the pooled URL. Anything touching session state uses the unpooled URL.**

PgBouncer in transaction mode hands a different backend connection to each transaction. Session-scoped state — `SET`, session advisory locks, prepared statements outside a transaction, `LISTEN` — does not survive between statements.

```bash
# ✅ migrations against the direct connection
DATABASE_URL=$DATABASE_URL_UNPOOLED npx prisma migrate deploy
DATABASE_URL=$DATABASE_URL_UNPOOLED npx drizzle-kit migrate
alembic -x url="$DATABASE_URL_UNPOOLED" upgrade head
```

**Why this is a blocker, not a warning:** a migration run through the pooled URL does not fail cleanly. It fails *intermittently*, depending on whether PgBouncer happened to keep the same backend for the whole migration. You get a green CI run and a broken schema in a way that is very hard to reproduce.

**Never** define a single `DATABASE_URL` and use it for both. If your framework only reads one variable, override it at the migration command, as above.

---

## 2. Driver selection

| Driver | Transport | Use when | Cannot do |
|---|---|---|---|
| `@neondatabase/serverless` → `neon()` | HTTP | One-shot queries, and fixed batches via `sql.transaction([...])`, in serverless or edge functions | An *interactive* transaction — one where a later statement depends on an earlier statement's result |
| `@neondatabase/serverless` → `Pool` | WebSocket | You need an interactive transaction in serverless | — |
| `pg` (node-postgres) | TCP | Long-lived Node servers, workers, cron containers | Run on edge runtimes |

```ts
// ✅ edge / serverless — one-shot read
import { neon } from '@neondatabase/serverless'
const sql = neon(process.env.DATABASE_URL!)
const rows = await sql`SELECT id, email FROM users WHERE id = ${id}`
```

Each `sql\`\`` call over HTTP is its own implicit transaction, so two sequential
calls are two transactions with no atomicity between them. A **fixed batch** of
statements — none of them depending on another's result — can still go over HTTP
atomically with `sql.transaction()`:

```ts
// ✅ serverless — fixed batch, no statement depends on another's result
await sql.transaction([
  sql`UPDATE accounts SET balance_cents = balance_cents - ${amountCents} WHERE id = ${from}`,
  sql`UPDATE accounts SET balance_cents = balance_cents + ${amountCents} WHERE id = ${to}`,
])
```

An **interactive** transaction — where a later statement depends on a value read
by an earlier one, such as checking the balance before debiting it — cannot go
over HTTP. That needs the WebSocket `Pool`. Create it **inside the handler** and
close it there too (see §3 — a `Pool` in a module global is the anti-pattern this
runtime punishes):

```ts
// ✅ serverless — interactive transaction, so WebSocket Pool, per invocation
import { Pool } from '@neondatabase/serverless'

export async function handler(req: Request) {
  // Create the Pool inside the request handler, never at module scope
  const pool = new Pool({ connectionString: process.env.DATABASE_URL })
  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    const { rows: [account] } = await client.query(
      'SELECT balance_cents FROM accounts WHERE id = $1 FOR UPDATE', [from])
    if (account.balance_cents < amountCents) throw new InsufficientFundsError()
    await client.query('UPDATE accounts SET balance_cents = balance_cents - $1 WHERE id = $2', [amountCents, from])
    await client.query('UPDATE accounts SET balance_cents = balance_cents + $1 WHERE id = $2', [amountCents, to])
    await client.query('COMMIT')
    return new Response(null, { status: 204 })
  } catch (e) {
    await client.query('ROLLBACK')
    throw e
  } finally {
    client.release()
    // End the Pool in the same invocation that created it
    await pool.end()
  }
}
```

On Node 21 and below the WebSocket driver needs a constructor supplied once at
startup: `import ws from 'ws'; neonConfig.webSocketConstructor = ws`. Node 22+
and edge runtimes have a global `WebSocket` and need nothing.

---

## 3. Client lifecycle — the rule inverts by runtime

This is the rule most often carried over incorrectly from other database layers.

**Long-lived process** (Express server, worker, container):

```ts
// ✅ module-level singleton — one Pool for the process lifetime
import { Pool } from 'pg'
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
})
```

In a long-lived process, never construct a pool inside a request handler. Each one opens new connections and none of them are ever released. (Serverless inverts this — see below and §2.)

**Serverless / edge function:**

```ts
// ✅ per-invocation client — the runtime may freeze or discard the sandbox between calls
export async function handler(req: Request) {
  const sql = neon(process.env.DATABASE_URL!)
  return Response.json(await sql`SELECT id, name FROM projects LIMIT 50`)
}
```

Do **not** cache a WebSocket `Pool` in a module global across serverless invocations. The runtime can freeze the sandbox mid-socket; the resumed invocation then holds a connection the server has already closed, and you get intermittent `Connection terminated unexpectedly` errors that do not reproduce locally. This applies to the transactional `Pool` in §2 as much as to a read client — construct it in the handler and `await pool.end()` in the same invocation. On Cloudflare Workers, `ctx.waitUntil(pool.end())` closes it without holding up the response.

> Note the contrast with the `mongodb` layer, which mandates a single client for the application lifetime. That rule is correct for MongoDB and for Neon *in a long-lived process*, and wrong for Neon in serverless. Check the runtime before applying either.

---

## 4. Scale-to-zero

- Idle compute suspends automatically after a default of **5 minutes** (configurable; disabling it requires a paid plan).
- The first query after suspend pays a cold start in the **hundreds of milliseconds**.
- Storage stays available while compute is suspended — suspension costs you latency, not data.

**Rules:**

- Never set a statement timeout, connect timeout, or health-check timeout below ~1s on a scale-to-zero branch. A 500ms timeout turns a normal cold start into a paging incident.
- Retry **once** on a connection-level error before surfacing it. A cold start can present as a connection error rather than a slow query.
- Do not add a keep-warm ping (cron, uptime monitor, synthetic query) without a written latency requirement. A ping more frequent than the suspend window bills continuous compute, which is usually more expensive than the cold start it avoids.
- Do not disable scale-to-zero on development, preview, or CI branches. Those are exactly the branches that should suspend.

```ts
// ✅ timeouts sized for a cold start, with a single connection-level retry
import { Pool } from 'pg'

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  connectionTimeoutMillis: 10_000,  // never below ~1s on a scale-to-zero branch
  idleTimeoutMillis:       30_000,
})

export async function query<T>(text: string, params: unknown[]): Promise<T[]> {
  try {
    return (await pool.query(text, params)).rows as T[]
  } catch (err) {
    // Retry once, and only for a connection-level error — a cold start can
    // surface as a failed connection rather than a slow query. Never retry a
    // query error; that turns one bad statement into two.
    if (!isConnectionError(err)) throw err
    return (await pool.query(text, params)).rows as T[]
  }
}
```

`connectionTimeoutMillis` is the option name for both `pg` and
`@neondatabase/serverless`. MongoDB's driver spells its connect timeout
differently; carrying that spelling over here silently configures nothing,
because an unrecognised key is ignored rather than rejected.

---

## 5. Migrations

- **Always run against `DATABASE_URL_UNPOOLED`** (§1).
- **Never run migrations from application startup code.** In serverless, every concurrent cold start races to run the same migration. Migrations belong in a deploy step or CI job with a single runner.
- **Test the migration on a branch before it reaches production.** Branch from production, apply, verify, discard. Prefer a schema-only branch when the parent holds PII.
- **One logical change per migration file**, named `<timestamp>_<verb>_<subject>` — see `naming-conventions`.
- **Expand/contract for anything destructive.** Add column → backfill → dual-write → migrate readers → drop old column, across separate deploys. A rename or drop in a single migration breaks every instance still running the previous release during rollout.

---

## 6. Egress — a cost rule enforced at review time

Neon bills data transferred out of the database. Overfetching is not just slow here, it is billed. Treat these as correctness rules in review, not style preferences:

- **Explicit column projection always.** No `SELECT *`. No Prisma `findMany()` without `select`. No Drizzle `db.select()` without a column list.
- **Every list query has a `LIMIT`.** An unbounded list query is a bill that scales with your table.
- **Keyset pagination over `OFFSET`** for large tables — see `api-conventions`.
- **Exclude wide columns from list endpoints.** `JSONB`, `TEXT`, and `BYTEA` columns are the dominant egress contributors. Fetch them on the detail endpoint only.
- **Aggregate in the database.** `SELECT count(*)` beats fetching rows to call `.length` on them by the full size of the result set.
- **N+1 queries multiply egress**, not just round trips. Each repeated query re-transfers its rows.

```ts
// ❌ transfers every column of every row, including a large JSONB settings blob
const users = await db.select().from(usersTable)

// ✅ transfers three columns of at most 50 rows
const users = await db
  .select({ id: usersTable.id, email: usersTable.email, createdAt: usersTable.createdAt })
  .from(usersTable)
  .limit(50)
```

For diagnosing an existing egress bill (as opposed to preventing one), use the official `neon-postgres-egress-optimizer` skill — it drives `pg_stat_statements` analysis, which is out of scope here.

---

## 7. Read replicas

A read replica is a separate read-only compute endpoint sharing the same storage. Creation is fast and it scales independently of the primary.

- Route analytics, reporting, exports, and read-heavy endpoints to a replica via a distinct `DATABASE_URL_REPLICA`.
- **Never write through a replica.** Enforce it by giving the replica connection a read-only role, not by convention.
- **Never read-after-write from a replica.** After a mutation, read from the primary within the same request; a replica read can miss the write you just made.
- Do not add a replica for a workload that has no measured read pressure. It is additional compute with an additional bill.

---

## 8. Connection security

- `sslmode=require` on every connection string. **Never** set `sslmode=disable` or `rejectUnauthorized: false` — including in local development, where it trains the habit that ships to production.
- Connection strings are credentials. Never committed, never logged, never in an error message returned to a client. The `_URL` name carries the password inline, which makes it easy to miss in a log-redaction rule keyed on `_SECRET`/`_TOKEN` — add `DATABASE_URL` to the redaction list explicitly. See `secret-scanning` and `naming-conventions`.
- The application connects with a least-privileged role, never the project owner role. The app role needs `SELECT`/`INSERT`/`UPDATE`/`DELETE` on its tables — not `CREATE`, not `DROP`.
- Use an IP allow list where the client is a fixed egress address. It does not replace least-privilege roles; it layers with them.

---

## 9. Testing

- Each CI run gets its **own branch**, not a shared development database. Shared test databases produce order-dependent test failures that only appear under parallelism.
- Delete the branch when the run finishes, or set an expiry. Branches left behind by failed runs are the most common source of surprise Neon cost.
- **Never point a test suite at the production branch**, including read-only tests — a test that only reads still holds compute open and can be changed later by someone who does not know its origin.
- Prefer a schema-only branch when the parent contains PII. See `data-governance`.

---

## Common mistakes

| Mistake | Fix |
|---|---|
| One `DATABASE_URL` used for both queries and migrations | Pull both strings; override to `DATABASE_URL_UNPOOLED` at the migration command. Pooled migrations fail intermittently, not cleanly. |
| Separate HTTP `neon()` calls treated as one transaction | Each HTTP call is its own transaction. A fixed batch can use `sql.transaction([...])`; an interactive transaction needs the WebSocket `Pool`. |
| Caching a WebSocket `Pool` in a serverless module global | Create per invocation, inside the handler, and `end()` it there. A frozen sandbox resumes holding a connection the server already closed. |
| A serverless `Pool` that is never closed | `await pool.end()` in the same invocation — `ctx.waitUntil(pool.end())` on Cloudflare Workers. |
| Creating a `Pool` inside a request handler in a long-lived server | Module-level singleton. Per-request pools leak connections until the compute hits its limit. |
| Aggressive statement timeout on a scale-to-zero branch | Keep timeouts above ~1s and retry once on connection error, or the cold start reads as an outage. |
| Keep-warm cron to avoid cold starts | Only with a documented latency requirement — continuous compute usually costs more than the cold start it prevents. |
| Running migrations at application startup | Concurrent cold starts race the same migration. Move it to a deploy step with one runner. |
| `SELECT *` or `findMany()` without `select` | Explicit projection. Egress is billed; the unused columns are on the invoice. |
| List endpoint returning a `JSONB` blob column | Exclude wide columns from list queries; serve them from the detail endpoint. |
| Reading immediately after writing, via a replica | Read from the primary within the same request. Replica reads can miss a just-committed write. |
| `rejectUnauthorized: false` to silence a local TLS error | Fix the certificate chain. This flag disables the protection it appears to configure. |
| Application connecting as the project owner role | Least-privileged role with DML only. The app has no reason to hold `DROP`. |
| CI branches created but never deleted | Delete on run completion or set an expiry. Orphaned branches are the most common unexpected cost. |
