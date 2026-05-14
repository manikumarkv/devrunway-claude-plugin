# SQL Database Standards (Prisma + PostgreSQL)

---

## Schema design

### Every model has standard base fields

```prisma
model User {
  id        String    @id @default(cuid())
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  deletedAt DateTime? // soft delete — never hard delete user data

  email     String    @unique
  name      String

  posts     Post[]

  @@map("users") // snake_case table name
}
```

### Foreign keys always define onDelete behaviour

```prisma
// ❌ — no onDelete: Prisma defaults to Restrict, causes confusing errors
model Post {
  userId String
  user   User   @relation(fields: [userId], references: [id])
}

// ✅ — explicit: what happens to posts when user is deleted?
model Post {
  id        String    @id @default(cuid())
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  deletedAt DateTime?

  userId    String
  user      User      @relation(fields: [userId], references: [id], onDelete: Cascade)

  title     String
  body      String    @db.Text

  @@map("posts")
  @@index([userId])          // index every foreign key
  @@index([createdAt(sort: Desc)]) // index sort columns
}
```

### Enums in Prisma

```prisma
// ✅
enum OrderStatus {
  PENDING
  PROCESSING
  SHIPPED
  DELIVERED
  CANCELLED

  @@map("order_status")
}

model Order {
  status OrderStatus @default(PENDING)
}
```

### Many-to-many with explicit join table

```prisma
// ✅ — explicit join table (not Prisma implicit) when you need extra fields
model PostTag {
  postId    String
  tagId     String
  createdAt DateTime @default(now())

  post Post @relation(fields: [postId], references: [id], onDelete: Cascade)
  tag  Tag  @relation(fields: [tagId], references: [id], onDelete: Cascade)

  @@id([postId, tagId])
  @@map("post_tags")
}
```

---

## Migrations

### Rules
- One migration per logical change — never batch unrelated changes
- Never edit an existing migration file — always create a new one
- Migration names are descriptive: `add_soft_delete_to_users`, not `migration1`
- Never run migrations inside application startup — use a separate deploy step
- Always review generated SQL before applying to production: `prisma migrate diff`

```bash
# Development
npx prisma migrate dev --name add_soft_delete_to_users

# Review what will run in production
npx prisma migrate diff \
  --from-schema-datasource prisma/schema.prisma \
  --to-schema-datamodel prisma/schema.prisma

# Production deploy (in CI/CD only)
npx prisma migrate deploy
```

### Schema changes that need care

```prisma
// ❌ — making an existing column NOT NULL without a default will fail on non-empty table
model User {
  phone String  // was String? — this migration will fail in production
}

// ✅ — add default or migrate data first
model User {
  phone String @default("")
}
// Then in a second migration, remove the default if needed
```

---

## Safe migrations — expand-contract pattern

Zero-downtime schema changes on live tables. Required for any migration that renames, removes, or changes the type of a column that the running application reads.

**The rule:** never apply a breaking schema change in a single deployment. Split into three phases:

```
Phase 1 — Expand   (deploy schema change, old app still works)
Phase 2 — Migrate  (backfill data, deploy new app code)
Phase 3 — Contract (remove old schema, old app no longer needed)
```

---

### Example A — Rename a column (`name` → `fullName`)

**❌ Wrong — single-step rename breaks live traffic:**
```prisma
// model User { name String }  →  model User { fullName String }
// Migration drops "name", app at old version crashes immediately
```

**✅ Correct — three migrations, two deploys:**

**Migration 1 (Expand) — add the new column, keep the old:**
```sql
-- prisma/migrations/<timestamp>_expand_user_full_name/migration.sql
ALTER TABLE users ADD COLUMN full_name TEXT;
```

```prisma
// schema.prisma during Expand phase — BOTH columns present
model User {
  name     String   // old — still read by current app
  fullName String?  // new — nullable while backfill runs
}
```

**App deploy 1 — write to BOTH columns:**
```ts
// src/services/user.service.ts — dual-write during migration
await prisma.user.update({
  where: { id },
  data: {
    name:     input.fullName,   // keep old column populated
    fullName: input.fullName,   // write new column
  },
})
```

**Migration 2 (Migrate) — backfill existing rows:**
```sql
-- prisma/migrations/<timestamp>_backfill_user_full_name/migration.sql
UPDATE users SET full_name = name WHERE full_name IS NULL;
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;
```

**App deploy 2 — read from new column only:**
```ts
// Dual-write removed; reads switch to fullName
await prisma.user.update({
  where: { id },
  data: { fullName: input.fullName },
})
```

**Migration 3 (Contract) — drop the old column:**
```sql
-- prisma/migrations/<timestamp>_contract_drop_user_name/migration.sql
ALTER TABLE users DROP COLUMN name;
```

```prisma
// schema.prisma final state
model User {
  fullName String  // only new column remains
}
```

---

### Example B — Add a NOT NULL column to a large table

**❌ Wrong — locks the table while backfill runs (can take minutes on large tables):**
```sql
ALTER TABLE orders ADD COLUMN region TEXT NOT NULL DEFAULT 'us-east-1';
-- PostgreSQL rewrites every row — table locked
```

**✅ Correct — nullable first, backfill, then add constraint:**

```sql
-- Migration 1: add nullable (instant — no rewrite)
ALTER TABLE orders ADD COLUMN region TEXT;

-- Migration 2: backfill in batches (background job, no lock)
-- Run via a script/Lambda, NOT inside the migration file:
UPDATE orders SET region = 'us-east-1'
WHERE id IN (SELECT id FROM orders WHERE region IS NULL LIMIT 1000);
-- Repeat until COUNT(*) WHERE region IS NULL = 0

-- Migration 3: add NOT NULL constraint
-- PostgreSQL 12+: validate without a full lock using NOT VALID + VALIDATE
ALTER TABLE orders ADD CONSTRAINT orders_region_not_null
  CHECK (region IS NOT NULL) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT orders_region_not_null;
-- After validation passes:
ALTER TABLE orders ALTER COLUMN region SET NOT NULL;
ALTER TABLE orders DROP CONSTRAINT orders_region_not_null;
```

```prisma
// schema.prisma final
model Order {
  region String  // NOT NULL enforced by DB
}
```

---

### Example C — Remove a column

Never drop a column that the current running app reads. Deploy app change first, wait for rollout, then drop.

```
1. Deploy: remove all code references to old column
2. Wait: confirm zero errors in logs (no reads/writes to old column)
3. Migrate: ALTER TABLE … DROP COLUMN old_column
```

---

### Migration safety checklist

Before running any migration on production, verify:

| Check | Why |
|---|---|
| `prisma migrate diff` output reviewed | Confirm SQL matches intent |
| Migration is additive-only (or expand phase) | No breaking changes to live app |
| Large table changes use `NOT VALID` + `VALIDATE` | Avoids full table lock |
| Backfill runs in batches (≤ 1000 rows per query) | Avoids lock contention |
| Rollback plan documented | Know how to reverse if migration causes errors |
| Tested on staging with production data volume | Performance validated before prod |

```bash
# Always diff before deploy
npx prisma migrate diff \
  --from-schema-datasource prisma/schema.prisma \
  --to-schema-datamodel prisma/schema.prisma \
  --script

# Check migration is backwards-compatible (no DROP or NOT NULL on existing column)
grep -E 'DROP COLUMN|NOT NULL|ALTER TYPE' prisma/migrations/*/migration.sql | tail -20
```

---

## Querying

### Never select everything — always specify fields for large tables

```ts
// ❌ — returns all columns including large fields (body, blob, etc.)
const posts = await prisma.post.findMany()

// ✅ — only what the caller needs
const posts = await prisma.post.findMany({
  select: {
    id: true,
    title: true,
    createdAt: true,
    author: { select: { id: true, name: true } },
  },
  where: { deletedAt: null },
  orderBy: { createdAt: 'desc' },
  take: 20,
  skip: offset,
})
```

### Eliminate N+1 — use include or nested select

```ts
// ❌ — N+1: 1 query for posts + N queries for authors
const posts = await prisma.post.findMany()
for (const post of posts) {
  const author = await prisma.user.findUnique({ where: { id: post.userId } })
}

// ✅ — single query with JOIN
const posts = await prisma.post.findMany({
  include: { author: { select: { id: true, name: true } } },
})
```

### Pagination — always use cursor-based for large datasets

Use the `where: { id: { lt: decodedCursor } }` pattern — consistent with `api-conventions.md`.
Do NOT use Prisma's native `cursor: { id }` + `skip: 1` pattern for new code — it behaves
differently under concurrent inserts and is harder to compose with other `where` filters.

```ts
// ❌ — offset pagination is slow on large tables (PostgreSQL scans from row 0)
const posts = await prisma.post.findMany({ skip: 10000, take: 20 })

// ❌ — Prisma native cursor with skip: 1 (avoid — inconsistent with api-conventions)
const posts = await prisma.post.findMany({
  take: 20,
  skip: cursor ? 1 : 0,
  cursor: cursor ? { id: cursor } : undefined,
})

// ✅ — where-filter cursor pattern (consistent with api-conventions + pagination utils)
import { decodeCursor, buildNextCursor } from '../utils/pagination'

const cursorWhere = cursor ? { id: { lt: decodeCursor(cursor).id } } : {}

const posts = await prisma.post.findMany({
  where: { deletedAt: null, ...cursorWhere },
  orderBy: { createdAt: 'desc' },
  take: limit,
})
const nextCursor = buildNextCursor(posts, limit)  // null when posts.length < limit
```

### Soft deletes — always filter deletedAt in queries

```ts
// ❌ — returns deleted records
const users = await prisma.user.findMany()

// ✅ — standard soft delete filter
const users = await prisma.user.findMany({
  where: { deletedAt: null },
})

// Soft delete (never use prisma.user.delete())
await prisma.user.update({
  where: { id },
  data: { deletedAt: new Date() },
})
```

### Transactions — wrap multi-step mutations

```ts
// ❌ — if second query fails, first is already committed
await prisma.order.create({ data: orderData })
await prisma.inventory.update({ where: { id }, data: { stock: { decrement: 1 } } })

// ✅ — atomic: both succeed or both roll back
const [order] = await prisma.$transaction([
  prisma.order.create({ data: orderData }),
  prisma.inventory.update({ where: { id }, data: { stock: { decrement: 1 } } }),
])

// For complex logic, use interactive transactions
const result = await prisma.$transaction(async (tx) => {
  const inventory = await tx.inventory.findUnique({ where: { productId } })
  if (!inventory || inventory.stock < quantity) throw new Error('OUT_OF_STOCK')

  const order = await tx.order.create({ data: orderData })
  await tx.inventory.update({
    where: { productId },
    data: { stock: { decrement: quantity } },
  })
  return order
})
```

---

## Indexing

```prisma
model Order {
  id        String      @id @default(cuid())
  userId    String
  status    OrderStatus
  createdAt DateTime    @default(now())

  @@index([userId])                    // every FK
  @@index([status])                    // filter column
  @@index([userId, status])            // compound: queries that filter by both
  @@index([createdAt(sort: Desc)])     // sort column
  @@index([userId, createdAt(sort: Desc)]) // compound: user's orders sorted by date
}
```

**Index rules:**
- Index every foreign key column
- Index every column used in `WHERE`, `ORDER BY`, or `JOIN`
- Compound indexes: put the most selective column first
- Don't over-index — each index slows down writes

---

## What never to do

```ts
// ❌ — deleteMany without where clause deletes entire table
await prisma.post.deleteMany()

// ✅
await prisma.post.deleteMany({ where: { userId, deletedAt: null } })

// ❌ — raw string interpolation in $queryRaw (SQL injection)
await prisma.$queryRaw(`SELECT * FROM users WHERE id = '${userId}'`)

// ✅ — tagged template literal is parameterized
await prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`

// ❌ — storing plain password
await prisma.user.create({ data: { password: req.body.password } })

// ✅ — hash before storing
import { hash } from 'bcryptjs'
const hashed = await hash(req.body.password, 12)
await prisma.user.create({ data: { passwordHash: hashed } })
```

---

## Prisma client setup

```ts
// src/lib/prisma.ts — singleton to avoid connection exhaustion in dev
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development'
      ? ['query', 'warn', 'error']
      : ['warn', 'error'],
  })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

---

## Migration conventions

### File naming

Prisma auto-generates the timestamp prefix. The description after the prefix must follow the pattern:

```
<timestamp>_<verb>_<noun>[_<qualifier>]
```

| Pattern | Example migration name |
|---|---|
| Add table | `20240501120000_add_orders_table` |
| Add column | `20240512093000_add_orders_shipped_at` |
| Drop column | `20240612140000_drop_orders_legacy_status` |
| Rename column | `20240712180000_rename_users_name_to_full_name` |
| Add index | `20240812090000_add_orders_user_id_index` |
| Add constraint | `20240912110000_add_orders_status_check_constraint` |
| Backfill data | `20241012100000_backfill_orders_display_id` |
| Create enum | `20241112083000_create_order_status_enum` |
| Alter column type | `20241212150000_alter_products_price_to_decimal` |

```bash
# Generate with a descriptive name
npx prisma migrate dev --name add_orders_shipped_at
```

### Migration file structure

Every migration file must be self-documenting:

```sql
-- Migration: 20240512093000_add_orders_shipped_at
-- Description: Adds shipped_at nullable timestamp to track when an order was dispatched.
--              Column is nullable — existing rows remain valid without backfill.
-- Reversibility: safe to roll back by dropping the column (no data loss)
-- Breaking change: no — adding a nullable column is backward compatible

ALTER TABLE "orders" ADD COLUMN "shipped_at" TIMESTAMP(3);
```

```sql
-- Migration: 20240812090000_add_orders_user_id_index
-- Description: Adds index on orders.user_id to speed up per-user order listing queries.
--              Index is created CONCURRENTLY so it does not lock the table.
-- Reversibility: drop the index — no data affected
-- Breaking change: no

CREATE INDEX CONCURRENTLY "orders_user_id_idx" ON "orders"("user_id");
```

### Safe migration checklist

Run this checklist before committing any migration:

```
[ ] Column added as nullable (not NOT NULL without a default)
[ ] NOT NULL added via NOT VALID + VALIDATE CONSTRAINT pattern (see Expand-Contract)
[ ] Index created with CONCURRENTLY (never plain CREATE INDEX on a live table)
[ ] No full-table rewrites (ALTER COLUMN TYPE on a large table = full rewrite; use a new column instead)
[ ] No DROP COLUMN before all code reading it is removed and deployed
[ ] No RENAME COLUMN — use expand-contract instead
[ ] Data-backfill migration uses batched UPDATE, never a single UPDATE without WHERE
[ ] Migration is idempotent where possible (IF NOT EXISTS / IF EXISTS guards)
```

### Batched backfill — never a single UPDATE on a large table

```sql
-- ❌ — locks the entire table until complete
UPDATE "orders" SET "display_id" = id::text WHERE "display_id" IS NULL;

-- ✅ — batched: process in chunks to avoid long lock holds
DO $$
DECLARE
  batch_size INT := 1000;
  rows_updated INT;
BEGIN
  LOOP
    UPDATE "orders"
    SET "display_id" = id::text
    WHERE id IN (
      SELECT id FROM "orders"
      WHERE "display_id" IS NULL
      LIMIT batch_size
    );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    EXIT WHEN rows_updated = 0;
    PERFORM pg_sleep(0.05); -- yield to other transactions
  END LOOP;
END $$;
```

### Concurrently-created indexes

Prisma does not generate `CONCURRENTLY` by default — hand-edit the SQL file after `prisma migrate dev`:

```sql
-- ❌ Prisma default (locks table)
CREATE INDEX "orders_user_id_idx" ON "orders"("user_id");

-- ✅ Hand-edited: non-blocking on live table
CREATE INDEX CONCURRENTLY "orders_user_id_idx" ON "orders"("user_id");
```

> **Note:** `CONCURRENTLY` cannot run inside a transaction block. Prisma wraps each migration in a transaction by default. Add `-- This migration does not use a transaction` at the top of any migration that uses `CONCURRENTLY`:

```sql
-- This migration does not use a transaction
-- Migration: 20240812090000_add_orders_user_id_index

CREATE INDEX CONCURRENTLY "orders_user_id_idx" ON "orders"("user_id");
```

Prisma detects that comment and skips the `BEGIN`/`COMMIT` wrapping.

### Expand-contract pattern (zero-downtime schema changes)

Three separate deploy steps — never combine them:

**Example A — Column rename (`name` → `fullName`)**

```sql
-- Step 1: EXPAND — add new column, keep old column
-- 20240601_add_users_full_name
ALTER TABLE "users" ADD COLUMN "full_name" TEXT;
UPDATE "users" SET "full_name" = "name";   -- backfill existing rows
```

App (Step 1 deploy): Write to **both** `name` and `full_name`. Read from `name`.

```sql
-- Step 2: (deploy app reading from full_name first, fallback to name)
-- No migration needed for this step
```

App (Step 2 deploy): Write to **both**. Read from `full_name`.

```sql
-- Step 3: CONTRACT — drop old column after all app versions read full_name
-- 20240701_drop_users_name
ALTER TABLE "users" DROP COLUMN "name";
```

---

**Example B — Adding NOT NULL on a large table**

```sql
-- Step 1: Add nullable, backfill, add NOT VALID constraint
ALTER TABLE "orders" ADD COLUMN "region" TEXT;
UPDATE "orders" SET "region" = 'us-east-1' WHERE "region" IS NULL;
ALTER TABLE "orders" ADD CONSTRAINT "orders_region_not_null"
  CHECK ("region" IS NOT NULL) NOT VALID;

-- Step 2 (separate migration, can run in maintenance window or off-peak)
-- Validates existing rows without locking writes
ALTER TABLE "orders" VALIDATE CONSTRAINT "orders_region_not_null";

-- Step 3 (optional — replace CHECK with true NOT NULL)
ALTER TABLE "orders" ALTER COLUMN "region" SET NOT NULL;
ALTER TABLE "orders" DROP CONSTRAINT "orders_region_not_null";
```

---

**Example C — Column removal**

1. Deploy app code with all reads/writes to the column removed  
2. Verify no queries reference the column in logs/APM  
3. Then run the migration:

```sql
-- 20240801_drop_orders_legacy_status
ALTER TABLE "orders" DROP COLUMN "legacy_status";
```

---

## Seeders

### Folder structure

```
prisma/
├── schema.prisma
├── migrations/
│   └── 20240501120000_add_orders_table/
│       └── migration.sql
├── seed.ts                  ← entry point, registered in package.json
└── seeders/
    ├── 00-roles.seeder.ts   ← number prefix controls run order
    ├── 01-users.seeder.ts
    ├── 02-products.seeder.ts
    └── 03-orders.seeder.ts
```

### package.json seed config

```json
{
  "prisma": {
    "seed": "ts-node --compiler-options '{\"module\":\"CommonJS\"}' prisma/seed.ts"
  }
}
```

### seed.ts — entry point

```ts
// prisma/seed.ts
import { PrismaClient } from '@prisma/client'
import { seedRoles } from './seeders/00-roles.seeder'
import { seedUsers } from './seeders/01-users.seeder'
import { seedProducts } from './seeders/02-products.seeder'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 Seeding database...')
  await seedRoles(prisma)
  await seedUsers(prisma)
  await seedProducts(prisma)
  console.log('✅ Seeding complete')
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
```

Run with:
```bash
npx prisma db seed
# or automatically after migrate dev/reset:
npx prisma migrate dev   # runs seed automatically after migrate
npx prisma migrate reset # drops + migrates + seeds
```

### Idempotent seeders — always use upsert

Every seeder must be safely re-runnable. Use `upsert` on a stable unique key, never `create`:

```ts
// ❌ — fails on second run with unique constraint error
await prisma.role.create({ data: { name: 'admin' } })

// ✅ — idempotent: creates on first run, updates on re-run
await prisma.role.upsert({
  where: { name: 'admin' },
  update: {},          // nothing to update — name is the key
  create: { name: 'admin', description: 'Full system access' },
})
```

### Full seeder example

```ts
// prisma/seeders/00-roles.seeder.ts
import type { PrismaClient } from '@prisma/client'

const ROLES = [
  { name: 'admin',   description: 'Full system access' },
  { name: 'manager', description: 'Manage team and orders' },
  { name: 'viewer',  description: 'Read-only access' },
] as const

export async function seedRoles(prisma: PrismaClient): Promise<void> {
  console.log('  → Seeding roles...')
  for (const role of ROLES) {
    await prisma.role.upsert({
      where:  { name: role.name },
      update: { description: role.description },
      create: role,
    })
  }
  console.log(`  ✓ ${ROLES.length} roles seeded`)
}
```

```ts
// prisma/seeders/01-users.seeder.ts
import type { PrismaClient } from '@prisma/client'
import { hash } from 'bcryptjs'
import { SEED_ADMIN_EMAIL } from '../../src/lib/constants'

export async function seedUsers(prisma: PrismaClient): Promise<void> {
  console.log('  → Seeding users...')

  const adminRole = await prisma.role.findUniqueOrThrow({ where: { name: 'admin' } })

  await prisma.user.upsert({
    where:  { email: SEED_ADMIN_EMAIL },
    update: {},
    create: {
      email:        SEED_ADMIN_EMAIL,
      fullName:     'Admin User',
      passwordHash: await hash('changeme-on-first-login', 12),
      roleId:       adminRole.id,
    },
  })
  console.log('  ✓ Admin user seeded')
}
```

### Seeder dependency ordering

Prefix numbers enforce run order and make dependencies explicit:

```
00-roles.seeder.ts      ← no dependencies
01-users.seeder.ts      ← depends on roles (roleId FK)
02-categories.seeder.ts ← no dependencies
03-products.seeder.ts   ← depends on categories (categoryId FK)
04-orders.seeder.ts     ← depends on users + products
```

FK constraints will throw if seeders run out of order — the prefix is the contract.

### Environment rules

| Environment | Seed behaviour |
|---|---|
| `development` | Full seed — roles + users + products + demo orders |
| `test` | Minimal seed in `beforeEach` — only what the test needs, via test fixtures |
| `staging` | Roles + admin user only — no synthetic business data |
| `production` | **Never run seed script** — use one-time migration scripts for required lookup data |

Gate environment-specific behaviour in `seed.ts`:

```ts
// prisma/seed.ts
const ENV = process.env.NODE_ENV ?? 'development'

async function main() {
  await seedRoles(prisma)          // always — lookup data

  if (ENV === 'development') {
    await seedUsers(prisma)
    await seedProducts(prisma)
    await seedOrders(prisma)
  } else if (ENV === 'staging') {
    await seedUsers(prisma)        // admin user only
  }
  // production: no seed beyond roles
}
```

### Required lookup data in production

For data that production needs at deploy time (e.g. permission definitions, default config rows), use a **data migration** — not the seed script:

```sql
-- prisma/migrations/20240901_seed_permission_definitions/migration.sql
INSERT INTO "permissions" ("name", "description") VALUES
  ('orders:read',   'Read orders'),
  ('orders:write',  'Create and update orders'),
  ('orders:delete', 'Delete orders')
ON CONFLICT ("name") DO NOTHING;
```

This runs as part of `prisma migrate deploy` and is tracked in migration history — unlike the seed script, it is guaranteed to run exactly once.

### Test fixtures — never use the seed script in tests

```ts
// tests/fixtures/order.fixture.ts
import type { PrismaClient } from '@prisma/client'

export async function createTestOrder(
  prisma: PrismaClient,
  overrides: Partial<Parameters<typeof prisma.order.create>[0]['data']> = {}
) {
  const user = await prisma.user.create({
    data: { email: `test-${Date.now()}@example.com`, fullName: 'Test User' },
  })
  return prisma.order.create({
    data: { userId: user.id, status: 'PENDING', total: 49.99, ...overrides },
  })
}
```

```ts
// tests/orders.service.test.ts
beforeEach(async () => {
  await prisma.$transaction([
    prisma.order.deleteMany(),
    prisma.user.deleteMany(),
  ])
  testOrder = await createTestOrder(prisma)
})
```

### Migration + seed workflow summary

```bash
# New feature — create migration and run seed
npx prisma migrate dev --name add_orders_shipped_at
# → generates migration SQL, applies to dev DB, then runs seed automatically

# Pull a fresh branch — reset and reseed
npx prisma migrate reset
# → drops dev DB, re-runs all migrations, then runs seed

# Deploy to staging/production — migrations only, no seed
npx prisma migrate deploy
# → applies pending migrations; never runs seed

# Inspect pending migrations before deploy
npx prisma migrate status

# Generate Prisma client after schema change
npx prisma generate
```
