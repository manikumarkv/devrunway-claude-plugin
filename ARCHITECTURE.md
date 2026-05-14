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
| React Hook Form | 7+ | Form state + validation (paired with Zod) |
| Tailwind CSS | 3+ | Utility-first styling |
| **shadcn/ui** | latest | Component library — Button, Input, Dialog, Table, Form, Select, Badge … built on Radix UI |
| Radix UI | — | Headless, accessible primitives — used under the hood by shadcn |
| clsx + tailwind-merge | — | `cn()` utility for conditional class merging |
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

```mermaid
flowchart TD
    subgraph Browser["🌐 Browser"]
        SPA["React SPA\nVite · Tailwind · React Router · React Query"]
        COGCLIENT["Cognito Auth\nAmplify Auth / Hosted UI"]
    end

    subgraph CDN["☁️ AWS — Frontend"]
        CF["CloudFront CDN\nEdge caching + HTTPS"]
        S3["S3 Bucket\nStatic build artefacts"]
    end

    subgraph API["☁️ AWS — API"]
        APIGW["API Gateway\nHTTP API · JWT Authorizer\n/api/v1/* → Lambda\n/health → Lambda (unauth)"]

        subgraph LambdaBox["λ Lambda — Node.js 20 (Express via serverless-http)"]
            MW["Middleware\nrequestId · pino-http · authenticate · validate"]
            CTRL["Controller\nasyncHandler"]
            SVC["Service\nBusiness logic"]
            REPO["Repository\nPrisma · DynamoDB SDK"]
        end
    end

    subgraph Data["☁️ AWS — Data"]
        RDS[("RDS PostgreSQL\nPrisma ORM")]
        DDB[("DynamoDB\nSessions · hot lookups")]
    end

    subgraph Obs["☁️ AWS — Config & Observability"]
        APPCFG["AppConfig\nFeature flags · 30s TTL"]
        SSM["SSM Parameter Store\nRuntime config"]
        SM["Secrets Manager\nDB password · API keys"]
        CW["CloudWatch\nLogs · Alarms · Dashboard"]
        SYN["Synthetics\nCanary · every 1 min"]
        SNS["SNS\nAlarm notifications"]
    end

    COGCLIENT -->|"AccessToken + IdToken"| SPA
    SPA -->|"Vite build assets"| CF
    CF --> S3
    SPA -->|"HTTPS · Authorization: Bearer jwt"| APIGW
    APIGW -->|"Verify JWT via Cognito JWKS"| COGCLIENT
    APIGW --> MW
    MW --> CTRL
    CTRL --> SVC
    SVC --> REPO
    REPO --> RDS
    REPO --> DDB
    LambdaBox -->|"isFlagEnabled()"| APPCFG
    LambdaBox -->|"getParameter()"| SSM
    LambdaBox -->|"getSecretValue()"| SM
    LambdaBox -->|"structured JSON logs"| CW
    CW --> SNS
    SYN -->|"GET /health + critical paths"| APIGW
    SYN --> CW
```

---

## Request Flow (end to end)

```mermaid
flowchart TD
    A(["👤 User action\ne.g. submit order form"]) --> B

    subgraph FE["Frontend"]
        B["React Component\nuseCreateOrder() — React Query mutation"]
        C["orders.api.ts\nPOST /api/v1/orders\nAuthorization: Bearer jwt"]
        M["React Query\ninvalidates 'orders' cache\nUI re-fetches + updates"]
    end

    subgraph GW["API Gateway"]
        D["JWT Authorizer\nverify Cognito token\nextract sub · email · groups"]
    end

    subgraph LAM["λ Lambda"]
        E["handler.ts\nserverless-http wraps Express"]

        subgraph MWStack["Middleware stack — runs on every request"]
            MW1["1. requestId\nattach x-request-id correlation ID"]
            MW2["2. pino-http\nlog method · path · statusCode · duration"]
            MW3["3. authenticate\nattach req.user from JWT claims"]
            MW4["4. validate\nZod parse body · params · query"]
        end

        F["OrdersController.create()\nasyncHandler — catch → errorHandler"]
        G["OrdersService.createOrder()\nownership check · inventory · pricing\nassertConsent() for marketing events"]
        H["OrdersRepository.create()\nprisma.order.create()\nprisma.$transaction() if multi-step"]
    end

    DB[("PostgreSQL\nRDS")]

    B --> C
    C --> D
    D --> E
    E --> MW1 --> MW2 --> MW3 --> MW4
    MW4 --> F
    F --> G
    G --> H
    H <-->|"SQL"| DB
    H --> G
    G --> F
    F --> K["created(res, order)\n201 · success: true · data: order"]
    K --> L["Response → Browser"]
    L --> M
```

---

## Frontend Folder Structure

```
frontend/
├── src/
│   │
│   ├── components/
│   │   └── ui/                        ← shadcn/ui components (auto-generated — do NOT hand-edit)
│   │       ├── button.tsx             ← npx shadcn@latest add button
│   │       ├── input.tsx              ← npx shadcn@latest add input
│   │       ├── dialog.tsx             ← npx shadcn@latest add dialog
│   │       ├── form.tsx               ← npx shadcn@latest add form
│   │       ├── select.tsx             ← npx shadcn@latest add select
│   │       ├── table.tsx              ← npx shadcn@latest add table
│   │       ├── badge.tsx              ← npx shadcn@latest add badge
│   │       ├── card.tsx               ← npx shadcn@latest add card
│   │       ├── toast.tsx              ← npx shadcn@latest add toast
│   │       └── …                     ← add more as needed
│   │
│   ├── features/                      ← One folder per product feature
│   │   └── orders/                    ← Example: orders feature
│   │       ├── api/
│   │       │   └── orders.api.ts      ← React Query hooks (useOrders, useCreateOrder …)
│   │       ├── components/
│   │       │   ├── OrderList/
│   │       │   │   ├── OrderList.tsx  ← composes shadcn <Table>, <Badge> etc.
│   │       │   │   ├── OrderList.test.tsx
│   │       │   │   └── index.ts
│   │       │   └── OrderForm/
│   │       │       ├── OrderForm.tsx  ← composes shadcn <Form>, <Input>, <Button>
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
│   │   ├── components/                ← Custom composite components built on shadcn primitives
│   │   │   ├── DataTable/             ← shadcn Table + sorting + pagination wrapper
│   │   │   │   ├── DataTable.tsx
│   │   │   │   ├── DataTable.test.tsx
│   │   │   │   └── index.ts
│   │   │   ├── ConfirmDialog/         ← shadcn Dialog + confirm/cancel actions
│   │   │   │   ├── ConfirmDialog.tsx
│   │   │   │   └── index.ts
│   │   │   └── PageHeader/            ← Heading + breadcrumb + action slot
│   │   │       ├── PageHeader.tsx
│   │   │       └── index.ts
│   │   ├── hooks/                     ← Generic hooks (useDebounce, usePagination …)
│   │   ├── utils/                     ← Pure utility functions (formatDate …)
│   │   └── types/                     ← Global shared TS types (Paginated<T>, ApiResponse<T> …)
│   │
│   ├── lib/                           ← Third-party client setup + shared utilities
│   │   ├── constants.ts               ← ALL app-wide constants (single source of truth)
│   │   ├── api-routes.ts              ← ALL API endpoint paths (never inline strings)
│   │   ├── i18n.ts                    ← i18next initialisation + language detector
│   │   ├── utils.ts                   ← cn() helper: clsx + tailwind-merge
│   │   ├── queryClient.ts             ← React Query client + global error handler
│   │   ├── auth.ts                    ← Cognito Amplify Auth config
│   │   ├── flags.ts                   ← Feature flag client (GET /api/v1/flags + useFlag hook)
│   │   ├── api.ts                     ← Fetch wrapper — base URL, auth header, error normalisation
│   │   └── logger.ts                  ← Client-side error logging
│   │
│   ├── locales/                       ← i18n translation files (one folder per locale)
│   │   ├── en/
│   │   │   ├── common.json            ← Shared strings (save, cancel, loading, errors …)
│   │   │   └── orders.json            ← Feature-specific strings
│   │   └── fr/
│   │       ├── common.json
│   │       └── orders.json
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
├── components.json                    ← shadcn/ui config (style, paths, tailwind)
├── vite.config.ts
├── playwright.config.ts               ← E2E config (local + CI)
├── playwright.smoke.config.ts         ← Smoke config (targets live env)
├── tailwind.config.ts
└── tsconfig.json
```

### Frontend component hierarchy

```mermaid
flowchart TD
    subgraph ShadcnUI["src/components/ui/  ← shadcn (auto-generated, never hand-edit)"]
        SH1["button.tsx"]
        SH2["input.tsx"]
        SH3["dialog.tsx"]
        SH4["form.tsx"]
        SH5["table.tsx · badge.tsx · card.tsx · …"]
    end

    subgraph SharedComps["src/shared/components/  ← custom composites built on shadcn"]
        SC1["DataTable/\n(Table + sort + pagination)"]
        SC2["ConfirmDialog/\n(Dialog + confirm actions)"]
        SC3["PageHeader/\n(heading + breadcrumb + slot)"]
    end

    subgraph Feature["src/features/orders/  ← feature-specific components"]
        FC1["OrderList/\n(DataTable + Badge)"]
        FC2["OrderForm/\n(Form + Input + Button)"]
        FAPI["api/orders.api.ts\nuseOrders · useCreateOrder"]
        FTYPE["types.ts\nZod schemas · TS types"]
    end

    PAGE["src/pages/\nOrdersPage.tsx"] --> FC1
    PAGE --> FC2
    FC1 --> SC1
    FC2 --> SC2
    FC1 --> SH5
    FC2 --> SH4
    FC2 --> SH2
    FC2 --> SH1
    SC1 --> SH5
    SC1 --> SH1
    SC2 --> SH3
    SC2 --> SH1
    FC1 --> FAPI
    FC2 --> FAPI
    FAPI --> FTYPE
```

**Rules:**
- Always use a shadcn component before building from scratch — check `src/components/ui/` first
- Never hand-edit files in `src/components/ui/` — re-run `npx shadcn@latest add` to update
- `src/shared/components/` holds custom composites that wrap shadcn primitives
- Feature components compose shared components and shadcn primitives directly
- Never import directly across feature folders — go through `index.ts`
- Never put API calls inside components — always in `api/<name>.api.ts`
- Never put business logic in pages — pages only compose feature components

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
│   │   ├── constants.ts               ← ALL app-wide constants (single source of truth)
│   │   ├── api-routes.ts              ← ALL route path strings used in Express routers
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

### Backend layer rules

```mermaid
flowchart LR
    ROUTES["routes/\nExpress Router"] --> CTRL
    CTRL["controllers/\nHTTP in · response out\nasyncHandler"] --> SVC
    SVC["services/\nBusiness logic\nno req/res"] --> REPO
    REPO["repositories/\nPrisma · DynamoDB\nno HTTP concepts"] --> DB

    DB[("RDS / DynamoDB")]

    CTRL --> TYPES
    SVC --> TYPES
    REPO --> TYPES
    TYPES["types/\nZod schemas\nTS inferred types"]

    MW["middleware/\nauthenticate · validate\nerrorHandler · requestId"] --> CTRL
    ERR["errors/\nNotFoundError\nForbiddenError\nConflictError"] --> CTRL
    ERR --> SVC
    LIB["lib/\nprisma · logger\ncognito · flags\nresponse helpers"] --> REPO
    LIB --> SVC
    LIB --> MW
```

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
│   ├── auth-stack.ts                  ← Cognito User Pool + App Client
│   ├── data-stack.ts                  ← RDS PostgreSQL + DynamoDB tables
│   ├── api-stack.ts                   ← Lambda + API Gateway HTTP API + Cognito JWT authorizer
│   ├── frontend-stack.ts              ← S3 bucket + CloudFront distribution + Route53 record
│   ├── monitoring-stack.ts            ← CloudWatch alarms + SLO dashboard + Synthetics canary
│   └── pipeline-stack.ts             ← CI/CD — CodePipeline or GitHub Actions OIDC role
│
├── canary/
│   └── canary.js                      ← CloudWatch Synthetics script (Node.js runtime)
│
├── cdk.json                           ← CDK context + feature flags
└── tsconfig.json
```

### CDK stack dependency order

```mermaid
flowchart TD
    A["AuthStack\nCognito User Pool\nApp Client · JWKS endpoint"]
    B["DataStack\nRDS PostgreSQL\nDynamoDB tables"]
    C["ApiStack\nLambda · API Gateway\nJWT Authorizer · IAM roles"]
    D["FrontendStack\nS3 · CloudFront\nRoute53 · ACM cert"]
    E["MonitoringStack\nCloudWatch Alarms\nSLO Dashboard · Synthetics Canary\nSNS Alert Topic"]

    A -->|"User Pool ARN\nJWKS URL"| C
    B -->|"DB connection string\nTable ARNs"| C
    C -->|"API domain\nLambda ARN"| D
    C -->|"API endpoint"| E
    D -->|"CloudFront domain\nDistribution ID"| E
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

```mermaid
sequenceDiagram
    actor User
    participant Browser
    participant Cognito as Amazon Cognito
    participant APIGW as API Gateway
    participant Lambda

    User->>Browser: Enter email + password
    Browser->>Cognito: InitiateAuth (email + password)
    Cognito-->>Browser: AccessToken · IdToken · RefreshToken

    Note over Browser: Tokens stored in memory (not localStorage)

    User->>Browser: Trigger action (e.g. view orders)
    Browser->>APIGW: GET /api/v1/orders\nAuthorization: Bearer AccessToken
    APIGW->>Cognito: Verify JWT signature (JWKS endpoint)
    Cognito-->>APIGW: Claims valid — sub · email · cognito:groups

    APIGW->>Lambda: Invoke with requestContext.authorizer.jwt.claims
    Note over Lambda: authenticate middleware\nattaches req.user.sub from claims
    Lambda-->>APIGW: 200 { success: true, data: [...] }
    APIGW-->>Browser: 200 { success: true, data: [...] }
    Browser-->>User: Render orders list

    Note over Browser,Cognito: AccessToken expires (1h) — use RefreshToken silently
    Browser->>Cognito: InitiateAuth (REFRESH_TOKEN)
    Cognito-->>Browser: New AccessToken
```

The Lambda always reads `req.user.sub` (Cognito user ID) — never trust a user-supplied ID in the request body.

---

## Feature Flag Flow

```mermaid
sequenceDiagram
    participant AppConfig as AWS AppConfig
    participant Lambda as Lambda (Node.js)
    participant Frontend as React Frontend

    Note over Lambda: Cold start or 30s cache expiry
    Lambda->>AppConfig: StartConfigurationSession + GetLatestConfiguration
    AppConfig-->>Lambda: { "newCheckout": true, "darkMode": false }
    Note over Lambda: Stored in module-level variable\nExpires after 30 seconds

    Frontend->>Lambda: GET /api/v1/flags\n(Authorization: Bearer jwt)
    Lambda-->>Frontend: { "newCheckout": true, "darkMode": false }

    Note over Frontend: useFlag('newCheckout') → true\nRender new checkout UI

    Note over AppConfig,Lambda: Flag toggled in AppConfig console
    Lambda->>AppConfig: GetLatestConfiguration (next poll)
    AppConfig-->>Lambda: { "newCheckout": false, "darkMode": false }
    Note over Lambda: Cache updated — takes effect within 30s
```

Flags are not secrets — it is safe to expose all flag values to the frontend. Sensitive configuration (server-side kill switches, auth logic gates) uses SSM or environment variables instead.

---

## Constants, API Routes & Localisation

### Rule: one file per concern, one file per layer

```mermaid
flowchart LR
    subgraph FE["Frontend (src/lib/)"]
        FC["constants.ts\napp-wide magic values"]
        FA["api-routes.ts\nall endpoint paths"]
        FI["i18n.ts\ni18next setup"]
        FL["locales/en/\ncommon.json · orders.json …"]
    end

    subgraph BE["Backend (src/lib/)"]
        BC["constants.ts\napp-wide magic values"]
        BA["api-routes.ts\nExpress route path strings"]
    end

    FC -.->|"same value both sides\ne.g. DEFAULT_PAGE_SIZE"| BC
    FA -.->|"FE constructs URL\nBE declares path"| BA
```

**Rule:** if a value appears more than once, it belongs in `constants.ts`. If a URL string appears more than once, it belongs in `api-routes.ts`. Never hard-code either inline.

---

### Frontend — `src/lib/constants.ts`

```ts
// src/lib/constants.ts
// ─── Pagination ────────────────────────────────────────────────────────────────
export const DEFAULT_PAGE_SIZE   = 20
export const MAX_PAGE_SIZE       = 100

// ─── Upload limits ─────────────────────────────────────────────────────────────
export const MAX_UPLOAD_SIZE_MB  = 10
export const MAX_UPLOAD_SIZE_B   = MAX_UPLOAD_SIZE_MB * 1024 * 1024
export const ACCEPTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const

// ─── Timing ────────────────────────────────────────────────────────────────────
export const DEBOUNCE_MS         = 300        // search input debounce
export const TOAST_DURATION_MS   = 4000       // snackbar auto-dismiss
export const FLAG_POLL_MS        = 30_000     // feature flag refetch interval

// ─── Auth ──────────────────────────────────────────────────────────────────────
export const TOKEN_REFRESH_BUFFER_S = 60      // refresh token 60s before expiry

// ─── Localisation ─────────────────────────────────────────────────────────────
export const DEFAULT_LOCALE      = 'en'
export const SUPPORTED_LOCALES   = ['en', 'fr', 'de'] as const
export type  Locale              = typeof SUPPORTED_LOCALES[number]

// ─── App ───────────────────────────────────────────────────────────────────────
export const APP_NAME            = 'MyApp'
export const APP_VERSION         = __APP_VERSION__  // injected by Vite define
```

---

### Frontend — `src/lib/api-routes.ts`

All API endpoint paths in one place. Functions for parameterised paths, plain strings for fixed paths.

```ts
// src/lib/api-routes.ts

const BASE = '/api/v1'

export const API_ROUTES = {
  // ─── Health ──────────────────────────────────────────────────────────────────
  health:   '/health',

  // ─── Auth / me ───────────────────────────────────────────────────────────────
  me:        `${BASE}/me`,
  meDataExport: `${BASE}/me/data-export`,

  // ─── Feature flags ────────────────────────────────────────────────────────────
  flags:     `${BASE}/flags`,

  // ─── Orders ──────────────────────────────────────────────────────────────────
  orders: {
    list:    `${BASE}/orders`,
    create:  `${BASE}/orders`,
    get:     (id: string) => `${BASE}/orders/${id}`,
    update:  (id: string) => `${BASE}/orders/${id}`,
    delete:  (id: string) => `${BASE}/orders/${id}`,
    items:   (id: string) => `${BASE}/orders/${id}/items`,
  },

  // ─── Users (admin) ────────────────────────────────────────────────────────────
  users: {
    list:    `${BASE}/users`,
    get:     (id: string) => `${BASE}/users/${id}`,
    anonymise: (id: string) => `${BASE}/users/${id}/anonymise`,
  },
} as const

// Usage in orders.api.ts:
// import { API_ROUTES } from '@/lib/api-routes'
// const res = await api.get(API_ROUTES.orders.list)
// const res = await api.get(API_ROUTES.orders.get(id))
```

---

### Backend — `src/lib/constants.ts`

```ts
// src/lib/constants.ts

// ─── Pagination ────────────────────────────────────────────────────────────────
export const DEFAULT_PAGE_SIZE       = 20
export const MAX_PAGE_SIZE           = 100

// ─── Security ─────────────────────────────────────────────────────────────────
export const BCRYPT_ROUNDS           = 12
export const MAX_LOGIN_ATTEMPTS      = 5
export const LOCKOUT_DURATION_MS     = 15 * 60 * 1000   // 15 minutes

// ─── Data retention (days) ────────────────────────────────────────────────────
export const RETENTION = {
  DELETED_USER_PII_DAYS: 30,
  AUTH_LOG_DAYS:         90,
  SESSION_DAYS:           7,
} as const

// ─── Feature flags ────────────────────────────────────────────────────────────
export const FLAG_CACHE_TTL_MS       = 30_000   // AppConfig poll interval

// ─── File uploads ─────────────────────────────────────────────────────────────
export const MAX_UPLOAD_SIZE_B       = 10 * 1024 * 1024   // 10 MB

// ─── CORS ─────────────────────────────────────────────────────────────────────
export const ALLOWED_ORIGINS         = [
  'https://myapp.com',
  'https://staging.myapp.com',
  ...(process.env.NODE_ENV !== 'production' ? ['http://localhost:5173'] : []),
]
```

---

### Backend — `src/lib/api-routes.ts`

Express route path strings — used in both router registration and any place that references a path programmatically (e.g. logging, tests).

```ts
// src/lib/api-routes.ts

const V1 = '/api/v1'

export const ROUTES = {
  health:        '/health',
  flags:         `${V1}/flags`,
  me:            `${V1}/me`,
  meDataExport:  `${V1}/me/data-export`,

  orders: {
    base:        `${V1}/orders`,          // GET (list), POST (create)
    byId:        `${V1}/orders/:id`,      // GET, PATCH, DELETE
    items:       `${V1}/orders/:id/items`,
  },

  users: {
    base:        `${V1}/users`,
    byId:        `${V1}/users/:id`,
    anonymise:   `${V1}/users/:id/anonymise`,
  },
} as const

// Usage in orders.routes.ts:
// import { ROUTES } from '@/lib/api-routes'
// router.get(ROUTES.orders.base, list)
// router.post(ROUTES.orders.base, create)
// router.get(ROUTES.orders.byId, getById)
```

---

### Localisation — `src/lib/i18n.ts`

i18next with browser language detection. Ready to use — activate by wrapping any string with `t()`.

```bash
npm install i18next react-i18next i18next-browser-languagedetector
```

```ts
// src/lib/i18n.ts
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import LanguageDetector from 'i18next-browser-languagedetector'

// Import all locale namespaces
import enCommon from '@/locales/en/common.json'
import enOrders from '@/locales/en/orders.json'
import frCommon from '@/locales/fr/common.json'
import frOrders from '@/locales/fr/orders.json'

i18n
  .use(LanguageDetector)          // detects browser language
  .use(initReactI18next)
  .init({
    resources: {
      en: { common: enCommon, orders: enOrders },
      fr: { common: frCommon, orders: frOrders },
    },
    defaultNS:   'common',        // useTranslation() without ns arg → common.json
    fallbackLng: 'en',
    supportedLngs: ['en', 'fr', 'de'],
    interpolation: { escapeValue: false },
    detection: {
      order: ['localStorage', 'navigator'],
      caches: ['localStorage'],
    },
  })

export default i18n
```

Bootstrap in `src/main.tsx`:

```tsx
// src/main.tsx
import './lib/i18n'              // import before anything renders
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
)
```

### Translation files

```json
// src/locales/en/common.json
{
  "actions": {
    "save":    "Save",
    "cancel":  "Cancel",
    "delete":  "Delete",
    "edit":    "Edit",
    "create":  "Create",
    "back":    "Back",
    "confirm": "Confirm"
  },
  "states": {
    "loading":  "Loading…",
    "saving":   "Saving…",
    "empty":    "No results found",
    "error":    "Something went wrong"
  },
  "validation": {
    "required":   "This field is required",
    "minLength":  "Must be at least {{min}} characters",
    "maxLength":  "Must be no more than {{max}} characters",
    "email":      "Enter a valid email address",
    "url":        "Enter a valid URL"
  },
  "pagination": {
    "loadMore":   "Load more",
    "showing":    "Showing {{count}} results"
  }
}
```

```json
// src/locales/en/orders.json
{
  "title":        "Orders",
  "createButton": "New order",
  "emptyState":   "No orders yet. Create your first one.",
  "status": {
    "PENDING":    "Pending",
    "PROCESSING": "Processing",
    "SHIPPED":    "Shipped",
    "DELIVERED":  "Delivered",
    "CANCELLED":  "Cancelled"
  },
  "fields": {
    "id":      "Order ID",
    "total":   "Total",
    "status":  "Status",
    "created": "Created"
  },
  "messages": {
    "created": "Order created successfully",
    "updated": "Order updated",
    "deleted": "Order deleted"
  }
}
```

```json
// src/locales/fr/common.json
{
  "actions": {
    "save":    "Enregistrer",
    "cancel":  "Annuler",
    "delete":  "Supprimer",
    "edit":    "Modifier",
    "create":  "Créer",
    "back":    "Retour",
    "confirm": "Confirmer"
  },
  "states": {
    "loading":  "Chargement…",
    "saving":   "Enregistrement…",
    "empty":    "Aucun résultat",
    "error":    "Une erreur s'est produite"
  }
}
```

### Using translations in components

```tsx
// ✅ — always use t(), never hardcode user-visible strings
import { useTranslation } from 'react-i18next'

function OrdersPage() {
  const { t } = useTranslation('orders')         // namespace = orders.json
  const { t: tc } = useTranslation('common')     // namespace = common.json

  return (
    <>
      <h1>{t('title')}</h1>
      <Button asChild>
        <Link to="/orders/new">{t('createButton')}</Link>
      </Button>
    </>
  )
}

// Interpolation
tc('validation.minLength', { min: 3 })   // "Must be at least 3 characters"
tc('pagination.showing',   { count: 42 }) // "Showing 42 results"

// Enum labels from translation file
const statusLabel = t(`status.${order.status}`)  // t('status.PENDING') → "Pending"

// Language switcher
import { useTranslation } from 'react-i18next'
import { SUPPORTED_LOCALES } from '@/lib/constants'

function LanguageSwitcher() {
  const { i18n } = useTranslation()
  return (
    <Select value={i18n.language} onValueChange={lng => i18n.changeLanguage(lng)}>
      <SelectTrigger><SelectValue /></SelectTrigger>
      <SelectContent>
        {SUPPORTED_LOCALES.map(lng => (
          <SelectItem key={lng} value={lng}>{lng.toUpperCase()}</SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
```

---

## URL Design

Every meaningful view has a unique, bookmarkable URL. The URL is the source of truth for navigation and list state — not component state.

### Route structure

```mermaid
flowchart TD
    ROOT["/\ndashboard"] --> ORDERS
    ROOT --> PROFILE

    subgraph ORDERS["Orders feature"]
        OL["/orders\nlist + filters"]
        ON["/orders/new\ncreate page"]
        OD["/orders/:id\ndetail page"]
        OE["/orders/:id/edit\nedit page"]
        OI["/orders/:id/items\nnested list"]
    end

    subgraph PROFILE["Profile feature"]
        PR["/profile\nsettings"]
        PS["/profile/security\nsub-section"]
    end

    OL --> ON
    OL --> OD
    OD --> OE
    OD --> OI
```

### URL search params — list state

All list state (filters, search, sort, pagination) lives in the URL as search params — never in `useState`.

| Search param | Purpose | Example |
|---|---|---|
| `?q=` | Full-text search query | `?q=laptop` |
| `?status=` | Filter by enum field | `?status=PENDING` |
| `?sort=` | Sort column | `?sort=createdAt` |
| `?order=` | Sort direction | `?order=desc` |
| `?cursor=` | Pagination cursor | `?cursor=clxyz` |
| `?tab=` | Active tab | `?tab=items` |

Example deep link: `/orders?status=PENDING&q=laptop&sort=createdAt&tab=items`  
Result: opens the orders list, filtered, sorted, on the items tab — browser back button restores it.

### UI pattern rules

```mermaid
flowchart TD
    ACTION{What is the\nuser doing?}

    ACTION -->|"Create a resource"| CREATE["Navigate to\n/resource/new\n(dedicated page)"]
    ACTION -->|"Edit a resource"| EDIT["Navigate to\n/resource/:id/edit\n(dedicated page)"]
    ACTION -->|"View a resource"| VIEW["Navigate to\n/resource/:id\n(dedicated page)"]
    ACTION -->|"Destructive action\n(delete, archive)"| CONFIRM["AlertDialog\nconfirmation modal"]
    CONFIRM -->|"Confirmed"| TOAST_S

    ACTION -->|"API success"| TOAST_S["toast.success()"]
    ACTION -->|"API error"| TOAST_E["toast.error()"]
    ACTION -->|"Warning / info"| TOAST_W["toast.warning()\ntost.info()"]
    ACTION -->|"Async operation"| TOAST_P["toast.promise()"]
    ACTION -->|"Field validation"| FIELD["&lt;FormMessage /&gt;\ninline under field"]
```

| Situation | Do this | Not this |
|---|---|---|
| Create resource | Navigate to `/resource/new` | Open a create modal |
| Edit resource | Navigate to `/resource/:id/edit` | Open an edit modal |
| Filter / sort list | Write to `?filter=&sort=` in URL | `useState` |
| Active tab | Write to `?tab=` in URL | `useState` |
| Delete confirmation | `AlertDialog` modal | Inline button with no confirm |
| API success | `toast.success()` | Alert modal or inline banner |
| API error | `toast.error()` | Alert modal or console.log |
| Field error | `<FormMessage />` inline | Toast |

---

## Environment Strategy

| Environment | Branch | Deploy trigger | Purpose |
|---|---|---|---|
| `local` | any | `npm run dev` | Development (Docker Compose — Postgres + LocalStack) |
| `staging` | `develop` | Auto on merge | Integration testing, QA, load tests |
| `prod` | `main` | Manual approval | Live traffic |

SSM parameter naming convention: `/<project>/<env>/<key>`

```bash
/<project>/staging/domain                   → api-staging.example.com
/<project>/prod/domain                      → api.example.com
/<project>/prod/db/password                 → (Secrets Manager, not SSM)
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

```mermaid
flowchart TD
    A([PR opened]) --> CI

    subgraph CI["GitHub Actions — ci.yml (runs on every PR)"]
        CI1["tsc --noEmit\nfrontend + backend"]
        CI2["eslint .\nfrontend + backend"]
        CI3["vitest run --coverage\nunit tests · coverage gate ≥ 80%"]
        CI4["playwright test\ne2e against local Docker stack"]
        CI5["cdk synth\nCDK Nag security checks"]
    end

    CI1 & CI2 & CI3 & CI4 & CI5 --> GATE1{All checks\ngreen?}
    GATE1 -- No --> FIX([Fix + push])
    FIX --> A
    GATE1 -- Yes --> MERGE(["PR approved\nmerge to develop"])

    MERGE --> STG

    subgraph STG["GitHub Actions — deploy.yml · staging (auto on merge to develop)"]
        S1["prisma migrate deploy\nstaging DB"]
        S2["cdk deploy ApiStack\nLambda + API Gateway"]
        S3["cdk deploy FrontendStack\nS3 + CloudFront"]
        S4["CloudFront invalidation"]
        S5["/logs health staging\nerror rate + p95 latency"]
        S6["/test-smoke --env staging\nread-only Playwright checks"]
    end

    S1 --> S2 --> S3 --> S4 --> S5 --> S6
    S6 --> GATE2{Staging\nhealthy?}
    GATE2 -- No --> RB1["/deploy rollback staging"]
    GATE2 -- Yes --> APPROVE(["✅ Manual approval gate\nLead signs off"])

    APPROVE --> PROD

    subgraph PROD["GitHub Actions — deploy.yml · prod (manual trigger after approval)"]
        P1["prisma migrate deploy\nprod DB"]
        P2["cdk deploy ApiStack\nLambda + API Gateway"]
        P3["cdk deploy FrontendStack\nS3 + CloudFront"]
        P4["CloudFront invalidation"]
        P5["/test-smoke --env prod\nread-only Playwright checks"]
    end

    P1 --> P2 --> P3 --> P4 --> P5
    P5 --> GATE3{Smoke\npass?}
    GATE3 -- No --> RB2["/deploy rollback prod"]
    GATE3 -- Yes --> LIVE(["✅ Production live"])
    LIVE -.->|"1h + 24h post-deploy"| VAL["/validate issue# --env prod\nerror delta · AC check · verdict"]
    LIVE -.->|"every 1 min · always on"| CAN["CloudWatch Synthetics canary\n/health + critical paths"]
```
