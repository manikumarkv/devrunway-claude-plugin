---
name: neon
description: Neon (Lakebase Postgres) standards — pooled vs direct connection strings, serverless driver selection, client lifecycle, scale-to-zero, migrations, egress cost, and read replicas. Load when connecting to, querying, or migrating a Neon database.
user-invocable: false
stack: database/neon
mcp:
  type: http
  url: "https://mcp.neon.tech/mcp"
  auth: oauth
paths:
  - "**/db/**"
  - "**/db.ts"
  - "**/database.ts"
  - "**/drizzle.config.*"
  - "**/drizzle/**"
  - "**/prisma/schema.prisma"
  - "**/migrations/**"
  - "**/*.sql"
  - "**/neon*"
---

Full standards in [neon.md](neon.md). Always-on summary.

> **Scope — applies only if this project uses neon.** This layer shares `**/*.sql`, `**/migrations/**` with `postgres-prisma` in `layers/database/`, so more than one may load at once and their rules conflict. If the project is not using neon, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Scope:** this layer holds the enforceable rules. For API reference and setup walkthroughs use the official `neon` plugin skills. For SQL schema, index, and query rules see `database-sql`. For table and column naming see `naming-conventions`.

**Connection strings — two, never one:**
- `DATABASE_URL` — pooled (hostname carries the `-pooler` suffix), routes through PgBouncer in transaction mode. Application queries.
- `DATABASE_URL_UNPOOLED` — direct. Migrations, `pg_dump`/`pg_restore`, logical replication, `LISTEN`/`NOTIFY`, and anything using `SET` or session state.
- PgBouncer transaction mode drops session state. Running a migration through the pooled URL fails intermittently rather than cleanly — hardest possible failure to diagnose.

**Driver selection:**
- `@neondatabase/serverless` `neon()` — HTTP, one-shot queries, edge/serverless. **No transactions.**
- `@neondatabase/serverless` `Pool` — WebSocket, when you need a real transaction in serverless
- `pg` — long-lived Node servers

**Client lifecycle — inverted from a traditional server:**
- Long-lived Node process: one `Pool` per process, module singleton, never per request
- Serverless/edge: create per invocation. Do **not** cache a WebSocket `Pool` in a module global across invocations

**Scale-to-zero:** idle compute suspends after ~5 min (configurable); the first query after suspend pays a cold start of a few hundred ms. Never set a statement or connect timeout below ~1s on a scale-to-zero branch, and never add a keep-warm ping without a documented latency requirement — it bills continuous compute to avoid a cost you probably don't have.

**Egress is a review concern, not just a perf one.** Neon bills data transfer: explicit column projection, `LIMIT` on every list query, keyset pagination, and wide `JSONB`/`TEXT`/`BYTEA` columns excluded from list endpoints.

**Never:** commit or log a connection string · disable TLS verification · run migrations from serverless app startup · point tests at the production branch · write through a read replica.

**Related:** `database-sql`, `naming-conventions`, `data-governance`, `secret-scanning`, `api-conventions` (pagination).
