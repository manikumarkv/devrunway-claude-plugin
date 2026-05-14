# Architecture Reference

Target architecture for projects built with this plugin. Every code generation command, scaffold, and background skill writes to this structure.

---

## Tech Stack

### Frontend
| Technology | Version | Purpose |
|---|---|---|
| React | 18+ | UI component library |
| TypeScript | 5+ | Type safety across all layers |
| Vite | 5+ | Build tool + dev server |
| React Router | 6+ | Client-side routing |
| React Query (TanStack) | 5+ | Server state, caching, mutations |
| Zod | 3+ | Runtime schema validation + type inference |
| Tailwind CSS | 3+ | Utility-first styling |
| Playwright | 1.40+ | End-to-end + smoke tests |
| Vitest + React Testing Library | — | Unit + component tests |

### Backend
| Technology | Version | Purpose |
|---|---|---|
| Node.js | 20+ | Runtime |
| TypeScript | 5+ | Type safety |
| Express | 4+ | HTTP routing |
| Prisma | 5+ | ORM — schema, migrations, type-safe queries |
| PostgreSQL | 15+ | Primary relational database (via RDS) |
| Pino | 8+ | Structured JSON logging |
| Zod | 3+ | Request validation + shared schema types |
| Vitest | 1+ | Unit + integration tests |

### Cloud (AWS)
| Service | Purpose |
|---|---|
| **Lambda** | Backend runtime — one Lambda per API |
| **API Gateway (HTTP API)** | REST API front door — routes to Lambda |
| **RDS PostgreSQL** | Primary database (Prisma migrations on deploy) |
| **DynamoDB** | Session store, high-throughput lookup tables |
| **S3 + CloudFront** | Frontend static hosting + CDN |
| **Cognito User Pool** | Authentication — signup, login, JWT issuance |
| **AWS CDK** | All infrastructure defined as code |
| **AppConfig** | Feature flags — zero polling cost, 30s TTL cache |
| **CloudWatch Logs** | All Lambda structured logs |
| **CloudWatch Alarms** | Error rate, latency, canary alarms |
| **CloudWatch Synthetics** | Every-minute canary health checks |
| **SNS** | Alarm → notification routing |
| **SSM Parameter Store** | Runtime config (domain, API keys, non-secret config) |
| **Secrets Manager** | Secrets (DB password, API keys with rotation) |
| **IAM** | Least-privilege roles per Lambda function |
| **CodePipeline / GitHub Actions** | CI/CD pipeline |

### Tooling
| Tool | Purpose |
|---|---|
| GitHub | Source control, Issues, PRs, Milestones, Actions CI |
| Figma | Design files — accessed via MCP in brainstorm/design commands |
| Bruno | API collection testing (`.bru` files committed alongside code) |
| k6 | Load testing — staged ramp, p95/p99 thresholds |
| Renovate | Automated dependency updates (auto-merge patch, review major) |
| CDK Nag | Security/compliance rule checks at `cdk synth` time |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Browser                                                         │
│  React SPA (Vite build → S3 → CloudFront CDN)                  │
│  Auth: Cognito Hosted UI / Amplify Auth                         │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTTPS  (JWT in Authorization header)
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  API Gateway (HTTP API)                                          │
│  - JWT authorizer → validates Cognito tokens                    │
│  - Routes: /api/v1/*  →  Lambda                                 │
│  - Routes: /health    →  Lambda (unauthenticated)               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Lambda (Node.js 20, Express via serverless-http)               │
│                                                                  │
│  Request lifecycle:                                              │
│  API Gateway → handler.ts → app.ts → router → controller        │
│                → middleware (auth, validate, error)             │
│                → service (business logic)                       │
│                → repository (Prisma / DynamoDB)                 │
│                → response (ok / created / paginated)            │
└──────┬──────────────────┬────────────────────────────────────────┘
       │                  │
       ▼                  ▼
┌──────────────┐  ┌──────────────────┐
│  RDS         │  │  DynamoDB         │
│  PostgreSQL  │  │  (sessions /      │
│  (Prisma)    │  │   hot lookups)    │
└──────────────┘  └──────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  Supporting AWS services             │
│  AppConfig   → feature flags         │
│  SSM         → runtime config        │
│  Secrets Mgr → credentials           │
│  CloudWatch  → logs + alarms         │
│  Synthetics  → canary checks         │
└──────────────────────────────────────┘
```

---

## Request Flow (end to end)

```
Browser
  │
  │  1. User triggers action (e.g. submit order form)
  │
  ▼
React component
  │  useCreateOrder() hook (React Query mutation)
  │
  ▼
orders.api.ts
  │  POST /api/v1/orders  { Authorization: Bearer <jwt> }
  │
  ▼
API Gateway
  │  JWT authorizer: verify Cognito token → extract sub, email, groups
  │  Route match → invoke Lambda
  │
  ▼
handler.ts  (serverless-http wraps Express)
  │
  ▼
middleware stack
  │  1. requestId — attach correlation ID to every log
  │  2. pino-http — log method, path, statusCode, duration
  │  3. authenticate — attach req.user from verified JWT claims
  │  4. validate — Zod parse req.body / req.params / req.query
  │
  ▼
OrdersController.create()
  │  asyncHandler wraps — catches and forwards errors
  │
  ▼
OrdersService.createOrder()
  │  Business logic: ownership check, inventory check, pricing
  │  assertConsent() if sending marketing event
  │
  ▼
OrdersRepository.create()
  │  prisma.order.create({ data: ... })
  │  prisma.$transaction() if multi-step
  │
  ▼
PostgreSQL (RDS)
  │  Returns created record
  │
  ▼ (back up the stack)
Controller
  │  return created(res, order)   → 201 { success: true, data: order }
  │
  ▼
API Gateway → Browser
  │
  ▼
React Query
  │  Invalidates ['orders'] cache → UI re-fetches
  │
  ▼
UI updated
```

---

## Frontend Folder Structure

```
frontend/
├── src/
│   │
│   ├── features/                      ← One folder per product feature
│   │   └── orders/                    ← Example: orders feature
│   │       ├── api/
│   │       │   └── orders.api.ts      ← React Query hooks (useOrders, useCreateOrder …)
│   │       ├── components/
│   │       │   ├── OrderList/
│   │       │   │   ├── OrderList.tsx
│   │       │   │   ├── OrderList.test.tsx
│   │       │   │   └── index.ts
│   │       │   └── OrderForm/
│   │       │       ├── OrderForm.tsx
│   │       │       ├── OrderForm.test.tsx
│   │       │       └── index.ts
│   │       ├── types.ts               ← Zod schemas + inferred TS types for this feature
│   │       └── index.ts               ← Public barrel — only re-export what other features need
│   │
│   ├── pages/                         ← Route-level components (thin — compose features)
│   │   ├── OrdersPage.tsx
│   │   ├── OrderDetailPage.tsx
│   │   └── NotFoundPage.tsx
│   │
│   ├── shared/                        ← Cross-feature reusable code
│   │   ├── components/                ← Generic UI (Button, Modal, Table, Spinner …)
│   │   │   └── Button/
│   │   │       ├── Button.tsx
│   │   │       ├── Button.test.tsx
│   │   │       └── index.ts
│   │   ├── hooks/                     ← Generic hooks (useDebounce, usePagination …)
│   │   ├── utils/                     ← Pure utility functions (formatDate, cn …)
│   │   └── types/                     ← Global shared TS types (Paginated<T>, ApiResponse<T> …)
│   │
│   ├── lib/                           ← Third-party client setup (one file per library)
│   │   ├── queryClient.ts             ← React Query client + global error handler
│   │   ├── auth.ts                    ← Cognito Amplify Auth config
│   │   ├── flags.ts                   ← Feature flag client (GET /api/v1/flags + useFlag hook)
│   │   ├── api.ts                     ← Fetch wrapper — base URL, auth header, error normalisation
│   │   └── logger.ts                  ← Client-side error logging (to CloudWatch via API or Sentry)
│   │
│   ├── router/
│   │   └── index.tsx                  ← React Router — route definitions + auth guards
│   │
│   ├── App.tsx                        ← Root component — providers, router outlet
│   └── main.tsx                       ← Vite entry point
│
├── tests/
│   ├── e2e/                           ← Playwright end-to-end specs (full user journeys)
│   │   └── orders.spec.ts
│   └── smoke/                         ← /test-smoke read-only post-deploy checks
│       └── smoke.spec.ts
│
├── public/                            ← Static assets (favicon, robots.txt, og images)
├── index.html                         ← Vite HTML entry
├── vite.config.ts
├── playwright.config.ts               ← E2E config (local + CI)
├── playwright.smoke.config.ts         ← Smoke config (targets live env)
├── tailwind.config.ts
└── tsconfig.json
```

### Feature structure rules

```
features/<name>/
  api/<name>.api.ts          ← ALL server calls for this feature live here
  components/<Component>/    ← One folder per component
    <Component>.tsx          ← Component implementation
    <Component>.test.tsx     ← Unit + RTL tests alongside the component
    index.ts                 ← Re-export default
  types.ts                   ← Zod schemas first, then z.infer<> types
  index.ts                   ← Public surface — only export what other features need
```

Never import across features directly — go through the `index.ts` barrel.  
Never put API calls inside components — always in `api/<name>.api.ts`.  
Never put business logic in pages — pages only compose feature components.

---

## Backend Folder Structure

```
backend/
├── src/
│   │
│   ├── controllers/                   ← HTTP layer — validate input, call service, return response
│   │   └── orders.controller.ts       ← asyncHandler(async (req, res) => { … })
│   │
│   ├── services/                      ← Business logic — owns rules, orchestrates repositories
│   │   └── orders.service.ts          ← No HTTP objects (req/res) in services
│   │
│   ├── repositories/                  ← Data access only — Prisma queries, DynamoDB calls
│   │   └── orders.repository.ts       ← Returns domain types, no HTTP concepts
│   │
│   ├── types/                         ← Zod schemas + inferred types (shared with FE via package)
│   │   └── orders.types.ts            ← CreateOrderInput, UpdateOrderInput, OrderResponse …
│   │
│   ├── middleware/                    ← Express middleware
│   │   ├── authenticate.ts            ← Verify Cognito JWT → attach req.user
│   │   ├── validate.ts                ← Zod request validation factory
│   │   ├── errorHandler.ts            ← Global error → HTTP status mapper
│   │   └── requestId.ts               ← Attach x-request-id to every request + log
│   │
│   ├── errors/                        ← Domain error classes
│   │   └── index.ts                   ← NotFoundError · ConflictError · ForbiddenError · ValidationError
│   │
│   ├── routes/                        ← Express routers — wire controllers to paths
│   │   ├── orders.routes.ts           ← router.get('/', …) router.post('/', …)
│   │   ├── health.routes.ts           ← GET /health (unauthenticated)
│   │   ├── flags.routes.ts            ← GET /api/v1/flags (AppConfig feature flags)
│   │   └── index.ts                   ← Mount all routers onto app
│   │
│   ├── lib/                           ← Singleton clients and utilities
│   │   ├── prisma.ts                  ← PrismaClient singleton (avoids connection exhaustion)
│   │   ├── logger.ts                  ← Pino with PII redaction serialiser
│   │   ├── cognito.ts                 ← JWT verification + Cognito JWKS client
│   │   ├── flags.ts                   ← AppConfig isFlagEnabled() with 30s Lambda memory cache
│   │   └── response.ts                ← ok() · created() · paginated() response helpers
│   │
│   ├── app.ts                         ← Express app — register middleware + routes
│   └── handler.ts                     ← Lambda entry point (serverless-http wraps Express)
│
├── prisma/
│   ├── schema.prisma                  ← Source of truth — all models, relations, enums
│   └── migrations/                    ← Never edit existing migrations — always add new
│       └── <timestamp>_<name>/
│           └── migration.sql
│
├── scripts/
│   ├── retention-cleanup.ts           ← Nightly Lambda — anonymise stale PII, purge auth logs
│   └── seed.ts                        ← Dev/staging seed data
│
├── tests/
│   ├── unit/                          ← Service + repository unit tests (Vitest, mocked Prisma)
│   └── integration/                   ← Controller tests against real DB (test containers)
│
├── bruno/                             ← Bruno API collections (committed to repo)
│   └── orders/
│       ├── list-orders.bru
│       ├── create-order.bru
│       ├── get-order.bru
│       ├── update-order.bru
│       └── delete-order.bru
│
├── tsconfig.json
├── vitest.config.ts
└── package.json
```

### Layer rules

| Layer | Allowed imports | Forbidden |
|---|---|---|
| **Controller** | Service, types, response helpers, errors | Prisma, DynamoDB SDK, other controllers |
| **Service** | Repository, lib/, types, errors, logger | Express (req/res), Prisma directly |
| **Repository** | Prisma, DynamoDB SDK, types, logger | Service, controllers, HTTP concepts |
| **Middleware** | lib/, errors, logger | Service, repository |
| **Routes** | Controllers, middleware | Service, repository, Prisma |

---

## Infrastructure Folder Structure

```
infra/
├── bin/
│   └── app.ts                         ← CDK app entry — instantiate all stacks
│
├── lib/
│   ├── api-stack.ts                   ← Lambda + API Gateway HTTP API + Cognito JWT authorizer
│   ├── data-stack.ts                  ← RDS PostgreSQL + DynamoDB tables
│   ├── frontend-stack.ts             ← S3 bucket + CloudFront distribution + Route53 record
│   ├── auth-stack.ts                  ← Cognito User Pool + App Client
│   ├── monitoring-stack.ts            ← CloudWatch alarms + SLO dashboard + Synthetics canary
│   └── pipeline-stack.ts             ← CI/CD — CodePipeline or GitHub Actions OIDC role
│
├── canary/
│   └── canary.js                      ← CloudWatch Synthetics script (Node.js runtime)
│
├── cdk.json                           ← CDK context + feature flags
└── tsconfig.json
```

### Stack dependency order

```
AuthStack          (Cognito — no dependencies)
     ↓
DataStack          (RDS, DynamoDB — no dependencies)
     ↓
ApiStack           (Lambda — depends on Auth + Data outputs)
     ↓
FrontendStack      (S3/CF — depends on Api domain output)
     ↓
MonitoringStack    (alarms + canary — depends on Api + Frontend)
```

---

## Database Schema Conventions

Every Prisma model follows this pattern:

```prisma
model Order {
  // ─── Identity ─────────────────────────────
  id        String      @id @default(cuid())
  createdAt DateTime    @default(now())
  updatedAt DateTime    @updatedAt
  deletedAt DateTime?                          // soft delete — never hard delete

  // ─── PII fields (tag every one) ───────────
  // (user model only — orders reference userId)

  // ─── Domain fields ────────────────────────
  userId    String
  status    OrderStatus @default(PENDING)
  total     Decimal     @db.Decimal(10, 2)
  shippingAddress String?

  // ─── Relations ────────────────────────────
  user      User        @relation(fields: [userId], references: [id], onDelete: Cascade)
  items     OrderItem[]

  // ─── Indexes ──────────────────────────────
  @@index([userId])
  @@index([status])
  @@index([userId, createdAt(sort: Desc)])

  // ─── Table name ───────────────────────────
  @@map("orders")
}
```

### PII tagging (data-governance skill enforces this)

```prisma
model User {
  email       String    @unique  // @pii
  name        String?            // @pii
  phone       String?            // @pii
  dateOfBirth DateTime?          // @pii:sensitive
  ipAddress   String?            // @pii:derived
}
```

---

## API Response Shape

All API responses follow a consistent envelope. The `response.ts` helper enforces this.

```ts
// Success — single resource
{ "success": true, "data": { … } }                       // 200 ok()

// Success — created
{ "success": true, "data": { … } }                       // 201 created()

// Success — paginated list
{
  "success": true,
  "data": [ … ],
  "meta": { "nextCursor": "xyz", "hasMore": true }       // 200 paginated()
}

// Error
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Order not found"
    // never include stack traces or PII in production errors
  }
}
```

### HTTP status mapping

| Error class | HTTP status |
|---|---|
| `ValidationError` | 400 |
| `AuthenticationError` | 401 |
| `ForbiddenError` | 403 |
| `NotFoundError` | 404 |
| `ConflictError` | 409 |
| Unhandled / unknown | 500 |

---

## Authentication Flow

```
Browser                    Cognito                    API Gateway          Lambda
   │                          │                            │                  │
   │── POST /login ──────────▶│                            │                  │
   │   (email + password)     │                            │                  │
   │◀─ AccessToken + ─────────│                            │                  │
   │   IdToken + RefreshToken │                            │                  │
   │                          │                            │                  │
   │── GET /api/v1/orders ────────────────────────────────▶│                  │
   │   Authorization: Bearer <AccessToken>                 │                  │
   │                          │                            │                  │
   │                          │◀── Verify JWT (JWKS) ──────│                  │
   │                          │─── Claims OK ─────────────▶│                  │
   │                          │                            │── Invoke ────────▶│
   │                          │                            │   event.requestContext│
   │                          │                            │   .authorizer.jwt │
   │                          │                            │   .claims         │
   │◀─ 200 { data: […] } ────────────────────────────────────────────────────│
```

The Lambda reads `req.user.sub` (Cognito user ID) set by the `authenticate` middleware — never trust user-supplied IDs.

---

## Feature Flag Flow

```
Lambda startup                AppConfig                    Frontend
     │                            │                            │
     │── GetLatestConfiguration ─▶│                            │
     │◀─ { "newCheckout": true } ─│                            │
     │   (cached in memory 30s)   │                            │
     │                            │                            │
     │                            │   GET /api/v1/flags ───────│
     │◀───────────────────────────────────────────────────────│
     │── { newCheckout: true } ───────────────────────────────▶│
     │                            │                useFlag('newCheckout')
     │                            │                → true → render new UI
```

Flags are not secrets — it is safe to expose them to the frontend. Sensitive configuration (kill switches, server-side logic gates) stays backend-only.

---

## Environment Strategy

| Environment | Branch | Deploy trigger | Purpose |
|---|---|---|---|
| `local` | any | `npm run dev` | Development (Docker Compose — Postgres + LocalStack) |
| `staging` | `develop` | Auto on merge | Integration testing, QA, load tests |
| `prod` | `main` | Manual approval | Live traffic |

SSM parameter naming convention: `/<project>/<env>/<key>`

```bash
/<project>/staging/domain          → api-staging.example.com
/<project>/prod/domain             → api.example.com
/<project>/prod/db/password        → (Secrets Manager, not SSM)
/<project>/prod/cloudfront/distribution-id
```

---

## Logging Standard

All logs are structured JSON via Pino, shipped to CloudWatch Logs.

```ts
// Every log line includes:
{
  "level": "info",
  "time": 1715689200000,
  "requestId": "abc-123",           // from x-request-id header
  "userId": "clxyz...",             // Cognito sub — never email or name
  "msg": "Order created",
  "orderId": "clord..."
  // PII fields are auto-redacted by the Pino serialiser
}
```

**Never log:** `email`, `name`, `phone`, `password`, `token`, `dateOfBirth`, `address`, `ipAddress`, `cardNumber`

Log group naming: `/aws/lambda/<project>-<env>`

---

## Project Root Layout

```
<project-root>/
├── frontend/                  ← React SPA (see Frontend Folder Structure)
├── backend/                   ← Node.js API (see Backend Folder Structure)
├── infra/                     ← AWS CDK (see Infrastructure Folder Structure)
├── docs/
│   ├── product-brainstorm/    ← /product-brainstorm output
│   ├── product-plans/         ← /product-plan output
│   ├── product-tasks/         ← /product-tasks + /product-refine output
│   ├── dev-brainstorm/        ← /dev-brainstorm output
│   ├── dev-tech-designs/      ← /dev-design output
│   ├── adr/                   ← Architecture Decision Records
│   ├── dora/                  ← DORA metric reports
│   ├── perf/                  ← Load test reports
│   ├── slo/                   ← SLO definitions + error budget
│   ├── validation/            ← Post-deploy validation reports
│   ├── smoke/                 ← Smoke test reports
│   └── evolve/                ← Plugin improvement plans
├── .github/
│   └── workflows/
│       ├── ci.yml             ← PR checks (typecheck, lint, test)
│       └── deploy.yml         ← Deploy to staging on merge to develop
├── ARCHITECTURE.md            ← This document
├── README.md                  ← Plugin documentation
└── package.json               ← Workspace root (npm workspaces)
```

---

## CI/CD Pipeline

```
PR opened
    │
    ▼
GitHub Actions — ci.yml
    ├── tsc --noEmit              (frontend + backend)
    ├── eslint .                  (frontend + backend)
    ├── vitest run --coverage     (backend unit tests)
    ├── playwright test           (frontend e2e — against local docker stack)
    └── cdk synth                 (infra — includes CDK Nag checks)
    │
    ▼ (all green)
PR approved + merged to develop
    │
    ▼
GitHub Actions — deploy.yml
    ├── prisma migrate deploy     (staging DB)
    ├── cdk deploy ApiStack       (staging Lambda + API Gateway)
    ├── cdk deploy FrontendStack  (staging S3 + CloudFront)
    ├── CloudFront invalidation
    ├── /logs health staging      (error rate + latency check)
    └── /test-smoke --env staging
    │
    ▼ (healthy)
Manual approval gate
    │
    ▼
Deploy to prod (same steps, prod env)
    │
    ▼
/test-smoke --env prod
    │
    ▼ (1h + 24h later)
/validate <issue#> --env prod
```
