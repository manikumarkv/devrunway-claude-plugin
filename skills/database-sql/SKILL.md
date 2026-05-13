---
name: database-sql
description: SQL database standards using Prisma + PostgreSQL — schema design, migrations, query patterns, transactions, indexing, what to avoid. Load when writing or reviewing any database schema, Prisma queries, or migration files.
user-invocable: false
---

Full standards in [sql.md](sql.md). Always-on summary:

**Stack:** PostgreSQL + Prisma ORM

**Schema rules:**
- Every table has `id` (cuid/uuid), `createdAt`, `updatedAt`
- Soft deletes with `deletedAt DateTime?` — never hard delete user data
- Foreign keys always explicit with `onDelete` behaviour defined
- snake_case for column names (`@@map`), PascalCase for Prisma models

**Query rules:**
- Never raw SQL unless Prisma cannot express it — use `$queryRaw` with tagged templates only
- Always select only needed fields — never `findMany` without `select` on large tables
- N+1 is never acceptable — use `include` or `select` with nested relations
- Wrap multi-step operations in `prisma.$transaction()`

**Never:**
- Store passwords in plaintext (use bcrypt/argon2)
- Store tokens or secrets in the database without hashing
- Delete rows that have audit/compliance value — use soft deletes
- Run migrations in application startup code
- Use `deleteMany` without a `where` clause


**Related skills — apply together:**
- `error-handling` — Prisma P2002/P2025 map to ConflictError/NotFoundError in errorHandler
- `typescript-patterns` — type repository return values and Zod-inferred input types
- `api-conventions` — cursor pagination contract used in repositories matches the API response shape
- `security` — never raw SQL with string interpolation; always parameterized via Prisma