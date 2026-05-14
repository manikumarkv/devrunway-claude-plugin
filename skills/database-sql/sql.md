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

```ts
// ❌ — offset pagination is slow on large tables (PostgreSQL scans from row 0)
const posts = await prisma.post.findMany({ skip: 10000, take: 20 })

// ✅ — cursor pagination: O(1) regardless of depth
const posts = await prisma.post.findMany({
  take: 20,
  skip: cursor ? 1 : 0,
  cursor: cursor ? { id: cursor } : undefined,
  orderBy: { createdAt: 'desc' },
  where: { deletedAt: null },
})
const nextCursor = posts[posts.length - 1]?.id ?? null
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
