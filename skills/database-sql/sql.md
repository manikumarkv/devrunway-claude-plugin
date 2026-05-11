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
