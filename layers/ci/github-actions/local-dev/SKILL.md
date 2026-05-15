---
name: local-dev
description: Local development environment standards — Docker Compose for Postgres and DynamoDB Local, seed scripts, .env setup, running the full stack locally. Load when setting up or troubleshooting local dev.
user-invocable: false
stack: ci/github-actions
---

Full standards in [local-dev.md](local-dev.md). Always-on summary:

**Local stack runs via Docker Compose:**
- PostgreSQL 16 on port 5432
- DynamoDB Local on port 8000
- No real AWS credentials needed locally — DynamoDB Local is fully offline

**Setup in 3 commands:**
```bash
cp .env.example .env          # fill in local values
docker compose up -d          # start Postgres + DynamoDB Local
npm run db:setup              # migrate + seed
```

**npm scripts every project must have:**
- `npm run dev` — start API + frontend concurrently
- `npm run db:setup` — `prisma migrate dev` + seed
- `npm run db:reset` — drop + recreate + seed (safe locally)
- `npm run db:studio` — Prisma Studio on port 5555

**Never:**
- Point local dev at a real AWS account's DynamoDB or RDS
- Commit `.env` — only `.env.example` is committed
- Seed production data with real user PII

**Related skills — apply together:**
- `secret-scanning` — `.env` must be gitignored; `.env.example` committed
- `database-sql` — `prisma migrate dev` follows migration safety rules
- `database-nosql` — DynamoDB Local replicates real table/GSI behaviour
- `packages` — use `tsx` for seed scripts, never `ts-node`
