# Local Development Environment

---

## Docker Compose — full local stack

```yaml
# docker-compose.yml (project root)
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    ports:
      - '5432:5432'
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U dev -d myapp']
      interval: 5s
      timeout: 5s
      retries: 5

  dynamodb-local:
    image: amazon/dynamodb-local:latest
    restart: unless-stopped
    ports:
      - '8000:8000'
    command: '-jar DynamoDBLocal.jar -sharedDb -dbPath /data'
    volumes:
      - dynamodb_data:/data

volumes:
  postgres_data:
  dynamodb_data:
```

Start and stop:

```bash
docker compose up -d        # start in background
docker compose down         # stop (data persists in volumes)
docker compose down -v      # stop + wipe all data (full reset)
```

---

## Environment files

```bash
# .env.example — committed to git (no real values)
# Copy to .env and fill in for local dev

# Database
DATABASE_URL=postgresql://dev:dev@localhost:5432/myapp

# AWS (local — DynamoDB Local needs fake credentials)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=local
AWS_SECRET_ACCESS_KEY=local
DYNAMODB_ENDPOINT=http://localhost:8000

# Cognito (use real staging pool for local dev auth)
COGNITO_USER_POOL_ID=
COGNITO_CLIENT_ID=

# App
VITE_API_URL=http://localhost:3000
API_PORT=3000
LOG_LEVEL=debug
NODE_ENV=development

# Monitoring (optional locally)
SENTRY_DSN=
VITE_SENTRY_DSN=
```

```bash
# .gitignore — ensure these are present
.env
.env.local
.env.*.local
```

---

## npm scripts

Every project must define these in `package.json`:

```json
{
  "scripts": {
    "dev": "concurrently \"npm run dev:api\" \"npm run dev:web\"",
    "dev:api": "tsx watch apps/api/src/server.ts",
    "dev:web": "vite",

    "db:setup": "prisma migrate dev && tsx scripts/seed.ts",
    "db:reset": "prisma migrate reset --force && tsx scripts/seed.ts",
    "db:studio": "prisma studio",
    "db:generate": "prisma generate",

    "dynamo:setup": "tsx scripts/dynamo-setup.ts",
    "dynamo:reset": "tsx scripts/dynamo-reset.ts",

    "build": "tsc --noEmit && vite build",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",

    "lint": "eslint . --max-warnings 0",
    "typecheck": "tsc --noEmit"
  }
}
```

Install `concurrently`:

```bash
npm install --save-dev concurrently
```

---

## Prisma seed script

```ts
// scripts/seed.ts
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 Seeding database...')

  // Clean existing seed data
  await prisma.order.deleteMany({ where: { userId: { startsWith: 'seed-' } } })
  await prisma.user.deleteMany({ where: { id: { startsWith: 'seed-' } } })

  // Create seed users
  const alice = await prisma.user.upsert({
    where: { email: 'alice@example.com' },
    update: {},
    create: {
      id: 'seed-user-alice',
      email: 'alice@example.com',
      name: 'Alice Dev',
    },
  })

  // Create seed data
  await prisma.order.createMany({
    data: [
      { id: 'seed-order-1', userId: alice.id, status: 'pending', total: 99.99 },
      { id: 'seed-order-2', userId: alice.id, status: 'confirmed', total: 149.00 },
    ],
    skipDuplicates: true,
  })

  console.log('✅ Seed complete')
}

main()
  .catch((e) => { console.error(e); process.exit(1) })
  .finally(() => prisma.$disconnect())
```

**Seed rules:**
- Use stable IDs with a `seed-` prefix — idempotent, safe to re-run
- Use `upsert` / `skipDuplicates` — never fails if data already exists
- No real user emails, PII, or production data
- Clean up before re-seeding — keeps local state predictable

---

## DynamoDB Local setup script

```ts
// scripts/dynamo-setup.ts
import { DynamoDBClient, CreateTableCommand, ListTablesCommand } from '@aws-sdk/client-dynamodb'

const client = new DynamoDBClient({
  region: 'us-east-1',
  endpoint: process.env.DYNAMODB_ENDPOINT ?? 'http://localhost:8000',
  credentials: { accessKeyId: 'local', secretAccessKey: 'local' },
})

async function createTable(name: string) {
  const { TableNames } = await client.send(new ListTablesCommand({}))
  if (TableNames?.includes(name)) {
    console.log(`  ⏭  ${name} already exists`)
    return
  }

  await client.send(new CreateTableCommand({
    TableName: name,
    BillingMode: 'PAY_PER_REQUEST',
    AttributeDefinitions: [
      { AttributeName: 'pk', AttributeType: 'S' },
      { AttributeName: 'sk', AttributeType: 'S' },
      { AttributeName: 'gsi1pk', AttributeType: 'S' },
      { AttributeName: 'gsi1sk', AttributeType: 'S' },
    ],
    KeySchema: [
      { AttributeName: 'pk', KeyType: 'HASH' },
      { AttributeName: 'sk', KeyType: 'RANGE' },
    ],
    GlobalSecondaryIndexes: [{
      IndexName: 'GSI1',
      KeySchema: [
        { AttributeName: 'gsi1pk', KeyType: 'HASH' },
        { AttributeName: 'gsi1sk', KeyType: 'RANGE' },
      ],
      Projection: { ProjectionType: 'ALL' },
    }],
  }))
  console.log(`  ✅ ${name} created`)
}

async function main() {
  console.log('🔧 Setting up DynamoDB Local tables...')
  // Add your table names here
  await createTable('myapp-orders-local')
  await createTable('myapp-sessions-local')
  console.log('✅ DynamoDB Local setup complete')
}

main().catch((e) => { console.error(e); process.exit(1) })
```

---

## DynamoDB client — use local endpoint in dev

```ts
// src/lib/dynamodb.ts
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb'

const client = new DynamoDBClient({
  region: process.env.AWS_REGION ?? 'us-east-1',
  // In development, point to local DynamoDB instance
  ...(process.env.DYNAMODB_ENDPOINT && {
    endpoint: process.env.DYNAMODB_ENDPOINT,
    credentials: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID ?? 'local',
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY ?? 'local',
    },
  }),
})

export const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
})
```

---

## Multi-stage Dockerfile

For containerised deployments — keeps dev and production images separate.

```dockerfile
# Dockerfile (API)
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --ignore-scripts

# Development stage — includes devDependencies
FROM base AS development
RUN npm ci
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev:api"]

# Build stage
FROM base AS builder
COPY . .
RUN npx prisma generate
RUN npm run build

# Production stage — minimal image
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma

EXPOSE 3000
USER node
CMD ["node", "dist/server.js"]
```

```dockerfile
# Dockerfile.web (Frontend — for static serving or preview)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_API_URL
RUN npm run build

FROM nginx:alpine AS production
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

---

## First-time setup checklist

```bash
# 1. Clone and install
git clone <repo>
cd <repo>
npm install

# 2. Environment
cp .env.example .env
# Fill in: COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID (from staging)
# Leave DATABASE_URL and DYNAMODB_ENDPOINT as-is (Docker provides them)

# 3. Start infrastructure
docker compose up -d
# Wait for postgres healthcheck to pass (~5s)

# 4. Database setup
npm run db:setup        # Prisma migrate + seed
npm run dynamo:setup    # Create DynamoDB Local tables

# 5. Start dev servers
npm run dev
# API:     http://localhost:3000
# Web:     http://localhost:5173
# DB UI:   npm run db:studio → http://localhost:5555
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `ECONNREFUSED` on DB | `docker compose up -d` — containers not running |
| Prisma migration fails | `npm run db:reset` — wipe and recreate locally |
| DynamoDB `ResourceNotFoundException` | `npm run dynamo:setup` — table not created yet |
| Port 5432 already in use | `lsof -i :5432` → kill the conflicting process |
| Port 8000 already in use | `lsof -i :8000` → kill or change `DYNAMODB_ENDPOINT` port |
| Cognito auth fails locally | Verify `COGNITO_USER_POOL_ID` and `COGNITO_CLIENT_ID` in `.env` |
| `tsx: command not found` | `npm install --save-dev tsx` |
