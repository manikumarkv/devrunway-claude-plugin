# my-dev-standards — Claude Code Plugin

Full SDLC automation for React + Node.js + AWS + Cognito + GitHub.

---

## Tech Stack

This plugin is purpose-built for the following stack. All commands, skills, code generation, and standards assume these technologies — nothing in this plugin is generic.

| Layer | Technology | Role |
|---|---|---|
| **Frontend** | [React](https://react.dev) + TypeScript | Component library, hooks, Zod validation, React Query |
| **Backend** | [Node.js](https://nodejs.org) + TypeScript | REST API, Lambda functions, Prisma ORM |
| **Cloud** | [AWS](https://aws.amazon.com) (CDK, Lambda, API Gateway, DynamoDB, RDS, AppConfig, CloudWatch, Cognito, S3, CloudFront) | All infrastructure defined as code via CDK |
| **Auth** | [Amazon Cognito](https://aws.amazon.com/cognito) | User pools, JWT verification, `/cognito-auth` scaffolding |
| **Source control & issues** | [GitHub](https://github.com) | Issues, milestones, PRs, Actions CI — all PM and Dev workflow commands use the GitHub API |
| **Design** | [Figma](https://figma.com) | Design file access via MCP — referenced in brainstorm and design commands |

> If your stack differs (e.g. Vue instead of React, GCP instead of AWS) the background skills and workflow commands will need to be adapted before use.

---

## Setup

```bash
# Install plugin, then provide tokens when prompted
GITHUB_TOKEN   # required — fine-grained PAT (Contents, Issues, PRs, Metadata)
FIGMA_TOKEN    # optional — design file access
```

---

## Full SDLC Flow

```mermaid
flowchart TD
    A(["💡 Idea · PM"]) --> B["PM · /product-brainstorm"]
    B --> C["PM · /product-plan"]
    C --> D["PM · /product-tasks"]
    D --> E[GitHub Issues + Milestones]
    E --> F["PM + Dev · /product-refine"]
    F --> G["Dev · /dev-brainstorm"]
    G --> H["Dev · /dev-design"]
    H --> I["Dev · /dev-code\n▶ execute step N"]
    I -->|"confirm → next step"| I
    I -->|"review plan"| H
    I -->|"all steps done"| J["Dev · /dev-review"]
    J --> K{All items resolved? · Dev}
    K -- Fix selected --> J
    K -- Done --> L["Dev · /pr create"]
    L --> M[CI checks · CI]
    M --> N["Dev · /deploy staging"]
    N --> O["Dev · /logs health"]
    O --> P{Healthy? · Dev}
    P -- No --> Q["Dev · /debug"]
    Q --> I
    P -- Yes --> R["Lead · /pr merge"]
    R --> S["Lead · /deploy prod"]
    S --> T["Dev · /test-smoke prod"]
    T --> U{Smoke pass? · Dev}
    U -- No --> V["Dev · /deploy rollback prod"]
    U -- Yes --> W(["✅ Production"])
    W --> A
    W -.->|"1h · 24h"| X["Dev · /validate <#>"]
    W -.->|"end of sprint"| Y["Lead · /evolve"]
    Y --> Z{Gaps or\nrecurring issues?}
    Z -- Yes --> AA[Skills improved]
    AA --> B
    Z -- No --> B
```

---

## Compounding Loop

The plugin improves itself. After every sprint, `/evolve` analyses review reports,
debug reports, and design docs to find recurring gaps — then updates the skills and
agents that caused them. Each cycle makes the next sprint faster.

```mermaid
flowchart LR
    subgraph Evidence["Evidence collected"]
        E1["REVIEW-*.md\nrecurring issues"]
        E2["BUG-REPORT-*.md\nroot cause patterns"]
        E3["git log\nwhat changed most"]
        E4["design docs\npatterns in use"]
    end

    subgraph Analysis["/evolve analysis"]
        A1[Skill coverage audit\nagainst SDLC stages]
        A2[Agent charter audit\ntriggers and outputs]
        A3[Cross-reference gaps\nmissing Related links]
        A4[New skill candidates\nfrom evidence]
    end

    subgraph Output["Output"]
        O1["docs/evolve/EVOLVE-date.md\nprioritised improvement plan"]
        O2[Skills updated]
        O3[Agents sharpened]
        O4[New skills added]
    end

    Evidence --> Analysis
    Analysis --> Output
    O2 & O3 & O4 -->|next sprint| E1
```

---

## Document Chain

Every command reads the previous command's output. This is the full paper trail from idea to PR.

```mermaid
flowchart LR
    subgraph PM["👤 PM Tier"]
        PB["docs/product-brainstorm/\n&lt;slug&gt;.md"]
        PP["docs/product-plans/\n&lt;slug&gt;.md"]
        PT["GitHub Issues\n+ Milestones"]
        PR["docs/product-tasks/\n&lt;ticket&gt;-refined.md"]
    end

    subgraph Dev["💻 Dev Tier"]
        DB["docs/dev-brainstorm/\n&lt;ticket&gt;.md"]
        DD["docs/dev-tech-designs/\n&lt;ticket&gt;-design.md"]
        RV["REVIEW-&lt;branch&gt;.md"]
        GH["GitHub PR"]
    end

    PB -->|"/product-plan"| PP
    PP -->|"/product-tasks"| PT
    PT -->|"/product-refine"| PR
    PR -->|"/dev-brainstorm"| DB
    DB -->|"/dev-design"| DD
    DD -->|"/dev-code"| RV
    RV -->|"/pr create"| GH
```

---

## Workflows

### PM Tier — From idea to GitHub issues

```mermaid
flowchart LR
    A(["💡 Idea"]) -->|"/product-brainstorm"| B["docs/product-brainstorm/"]
    B -->|"/product-plan"| C["Personas · Flows · Stories"]
    C -->|"/product-tasks"| D["GitHub Issues + Milestones"]
    D -->|"/product-refine &lt;#&gt;"| E["Refined story · Q&A doc"]
    E -->|Hand to Dev| F(["Dev picks up ticket"])
```

### Dev Tier — From ticket to production

```mermaid
flowchart LR
    A(["Ticket"]) -->|"/dev-brainstorm"| B["Approaches\nDecision matrix"]
    B -->|"/dev-design"| C["Phased plan\nN phases · M steps"]
    C -->|"/dev-code"| D["▶ Execute step N\nshow output"]
    D -->|"confirm → next step"| D
    D -->|"review plan"| C
    D -->|"all steps done"| E["/dev-review\nfull findings list"]
    E -->|"fix selected"| E
    E -->|"done"| F["/pr create"]
    F --> G{CI}
    G -->|Pass| H["/deploy staging"]
    H --> I{Healthy?}
    I -->|No| J["/debug"]
    J --> D
    I -->|Yes| K["Lead · /pr merge"]
    K --> L["Lead · /deploy prod"]
    L --> M["/test-smoke prod"]
    M -->|Pass| N(["✅ Production"])
    M -->|Fail| O["/deploy rollback prod"]
```

### Deploy Pipeline

```mermaid
flowchart TD
    A["/deploy staging"] --> B{Pre-flight checks}
    B --> B1["tsc --noEmit"]
    B --> B2["eslint ."]
    B --> B3["vitest run"]
    B --> B4[AWS creds]
    B1 & B2 & B3 & B4 --> C[cdk deploy ApiStack]
    C --> D[CloudFront invalidation]
    D --> E[Health check]
    E --> F{Status}
    F -->|Healthy| G([Done])
    F -->|Unhealthy| H["/logs errors staging"]
    H --> I["/deploy rollback staging"]

    J["/deploy prod"] --> K{Manual approval required}
    K -->|Confirmed| L[Same as staging + production gate]
    L --> M["/test-smoke prod"]
    M -->|Pass| N([Production live])
    M -->|Fail| O["/deploy rollback prod"]
    N -.->|"1h + 24h"| P["/validate &lt;issue#&gt;"]
```

### Bug Fix

```mermaid
flowchart LR
    A([Bug reported]) -->|"debug this"| B[Root cause identified]
    B --> C[Minimal fix + failing test]
    C -->|"pr create"| D[Hotfix PR]
    D -->|"deploy staging"| E["/logs health"]
    E -->|Healthy| F["/deploy prod"]
    F --> G([Fixed])
```

### Debug Flow

```mermaid
flowchart TD
    A([Error or Incident]) --> B["/debug this &lt;description&gt;"]
    B --> C[debugger agent]
    C --> D[CloudWatch logs]
    C --> E[Error traces]
    C --> F[Recent commits]
    D & E & F --> G[Root cause identified]
    G --> H[Minimal fix]
    H --> I[Failing test added]
    I --> J["BUG-REPORT-&lt;date&gt;.md saved"]
    J --> K["/pr create"]
```

---

## Commands

### PM Workflow

| Command | Input | Output |
|---|---|---|
| `/product-brainstorm <slug>` | Idea / feature description | `docs/product-brainstorm/<slug>.md` — UX exploration, open questions, scope boundary |
| `/product-plan <slug>` | Brainstorm doc | `docs/product-plans/<slug>.md` — personas, user flows, in/out of scope, epics, stories with AC |
| `/product-tasks <slug>` | Plan doc | GitHub milestones + issues · `docs/product-tasks/<slug>.md` summary |
| `/product-refine <ticket#>` | GitHub issue number | GitHub comment + `docs/product-tasks/<ticket>-refined.md` — Q&A, decisions, final AC |

### Dev Workflow

| Command | Input | Output |
|---|---|---|
| `/dev-brainstorm <ticket#>` | GitHub issue number | `docs/dev-brainstorm/<ticket>.md` — challenges, 2–3 approaches, decision matrix, recommendation |
| `/dev-design <ticket#>` | Issue or brainstorm doc | `docs/dev-tech-designs/<ticket>-design.md` — phased plan with numbered steps for `/dev-code` |
| `/dev-code <ticket#>` | Design doc | Code built phase by phase with confirmation checkpoints · branch created · ticket status updated |
| `/dev-review` | Current branch | `REVIEW-<branch>.md` tracked findings · user picks items to fix · status updated per item |

### Release & Quality

| Command | Sub-commands | Action |
|---|---|---|
| `/release` | `patch` · `minor` · `major` · `auto` | Semver bump · `CHANGELOG.md` · git tag · GitHub Release |
| `/deps` | `check` · `update [patch\|minor\|major\|all]` | Audit CVEs + outdated · batch updates · test-gated · ships `renovate.json` |
| `/adr <title>` | `[issue#]` | Numbered ADR in Nygard format → `docs/adr/` · updates index |
| `/dora` | `report` · `trend [--days N]` | DORA scorecard — deploy frequency, lead time, change failure rate, MTTR |

### Performance & Reliability

| Command | Sub-commands | Action |
|---|---|---|
| `/test-load` | `run <endpoint>` · `bundle` · `baseline` | k6 ramp 10→50→100 VUs · p95/p99 thresholds · bundle size budget |
| `/feature-flag` | `create <name>` · `enable` · `disable` · `list` | AWS AppConfig flags · CDK construct · `isFlagEnabled()` backend · `useFlag()` React hook |
| `/validate <issue#>` | `[--env prod\|staging]` | Post-deploy: error rate delta · endpoint hits · AC check · ship-green or rollback verdict |
| `/slo` | `define` · `status` · `budget` | SLOs interactively defined · error budget calc · CloudWatch composite alarms + dashboard |

### Coverage & Observability

| Command | Sub-commands | Action |
|---|---|---|
| `/test-smoke` | `[--env prod\|staging]` | Read-only Playwright checks against live env · generates `tests/smoke/smoke.spec.ts` if absent · rollback verdict on failure |
| `/synthetic` | `setup` · `status` · `pause` · `resume` | CloudWatch Synthetics canary every 1 min · CDK construct · alarm → SNS on 2 consecutive failures |

### Running Playwright tests from prompts (no command needed)

Because the `playwright` background skill is always loaded and `.mcp.json` registers the Playwright MCP, you can run, inspect, and debug E2E tests with plain English prompts:

| Prompt | What runs |
|---|---|
| "Run all E2E tests" | `npx playwright test` |
| "Run the orders spec" | `npx playwright test e2e/orders.spec.ts` |
| "Run tests tagged @smoke" | `npx playwright test --grep @smoke` |
| "Open Playwright UI mode" | `npx playwright test --ui` |
| "Show failing tests from the last run" | Reads `playwright-report/results.json` |
| "Generate a test for the checkout flow" | `npx playwright codegen http://localhost:5173` |
| "Navigate to /orders and take a screenshot" | Playwright MCP browser control |

### Utilities

| Command | Sub-commands | Action |
|---|---|---|
| `/scaffold <feature>` | `frontend` · `backend` · `fullstack` | Generate feature boilerplate from design doc — types, API, components, controller, service, repository, Prisma model, CDK grants, Bruno stubs |
| `/branch` | `create <#> <slug>` · `switch` · `status` · `delete` | Branch lifecycle tied to GitHub issue numbers |
| `/test` | `unit [file]` · `e2e [spec]` · `api [collection]` · `coverage` · `generate [file]` | Run Vitest / Playwright / Bruno · coverage ≥ 80% gate · stub missing tests |
| `/pr` | `create [target]` · `merge <#>` · `checks <#>` | Auto-filled PR → develop · merge after CI · CI status check |
| `/deploy` | `staging` · `prod` · `status [env]` · `rollback <env>` | Pre-flight → CDK → CloudFront · manual approval for prod · Lambda + CF rollback |
| `/logs` | `health [env]` · `errors [env]` · `tail [env]` · `search <term>` | CloudWatch error rate · p95/p99 · stream · search by message or requestId |
| `/fix` | `lint` · `format` · `types` · `all` | `eslint --fix` · `prettier --write` · show TS errors |
| `/task` | `create [title]` · `start <#>` · `list [mine]` · `close <#>` | GitHub issue management |
| `/debug` | `this <description>` · `logs <env>` | Trigger debugger agent or tail error logs |
| `/cognito-auth` | `frontend` · `backend` · `fullstack` | Scaffold full Cognito auth flow |
| `/evolve` | `skills` · `agents` · `coverage` · `all` | End-of-sprint plugin self-improvement — analyses patterns, updates skills |

---

## Agent

One autonomous agent — the **debugger**. All other workflows are interactive commands.

```mermaid
flowchart LR
    subgraph Trigger["Trigger phrases"]
        T["something is broken\ndebug this\ncheck production\nunexpected error in..."]
    end

    T --> DBG[debugger agent]
    DBG --> CW[CloudWatch logs]
    DBG --> TR[Error traces]
    DBG --> RC[Recent commits]
    CW & TR & RC --> ROOT[Root cause identified]
    ROOT --> FIX[Minimal fix + failing test]
    FIX --> RPT["BUG-REPORT-&lt;date&gt;.md"]
    RPT --> PR["/pr create"]
```

The debugger is intentionally autonomous — it gathers all evidence before surfacing a root cause so you don't have to drive the investigation step by step.

---

## Background Skills (always loaded)

These apply automatically — no command needed. Claude checks them whenever writing code.

```mermaid
graph LR
    subgraph Quality
        CL[checklists]
        LN[linting]
        SW[swagger-docs]
    end

    subgraph Frontend
        RS[react-standards]
        CP[composition-patterns]
        TP[typescript-patterns]
        TS[testing-standards]
        A11[accessibility]
        PW[playwright]
    end

    subgraph Backend
        AC[api-conventions]
        EH[error-handling]
        SC[security]
        SQL[database-sql]
        NOSQL[database-nosql]
        DG[data-governance]
    end

    subgraph Infrastructure
        CDK[cdk]
        PIPE[pipeline]
        MON[monitoring]
        LD[local-dev]
    end

    subgraph Process
        PP[product-persona]
        CC[conventional-commit]
        SS[secret-scanning]
        PKG[packages]
        PS[project-structure]
        AD[api-docs]
        BR[bruno]
    end

    CL --- RS
    CL --- AC
    CL --- SQL
    LN --- RS
    LN --- TP
    SW --- AC
    SW --- EH
    RS --- CP
    RS --- TP
    RS --- TS
    RS --- A11
    TS --- PW
    AC --- EH
    EH --- SC
    SQL --- EH
    SQL --- DG
    NOSQL --- CDK
    CDK --- SC
    CDK --- MON
    PIPE --- SC
    LD --- SQL
    LD --- NOSQL
    AC --- AD
    AC --- BR
```

---

## Development Checklists

The `checklists` background skill auto-applies the relevant checklist whenever one of these actions is taken. No prompt needed — Claude runs the checklist before marking work done.

| Action | Checklist |
|---|---|
| New route / controller / method | API Creation / Modification |
| New `.tsx` component file | Component Creation |
| New page route or major page update | Page Creation / Update |
| Calling a backend API from frontend | API Integration |
| Adding a `logger.*` call | Logging |
| Writing a Prisma query | DB Query |
| New Prisma model / adding column / migration | DB Schema Change |

**Quick pillars per checklist:**

| Checklist | Must-haves |
|---|---|
| **API** | Zod validation · response envelope · `asyncHandler` · Swagger registered · tests |
| **Component** | shadcn/ui first · typed props · `t()` strings · constants file · named export · test |
| **Page** | Dedicated route · `useSearchParams` for list state · toast feedback · loading/empty/error states · E2E spec |
| **API Integration** | `api-routes.ts` constant · React Query hook · invalidate on success · error toast · skeleton |
| **Logging** | Pino (no `console.log`) · correct level · structured context · no PII · `requestId` |
| **DB Query** | `deletedAt: null` filter · no N+1 · cursor pagination · transaction · user-scoped |
| **DB Schema** | Base fields · FK `onDelete` · indexes · safe migration pattern · seeder · API schema updated |

---

## Hooks (automatic)

```mermaid
flowchart LR
    subgraph PostWrite["After any .ts or .tsx write"]
        W[File saved] --> H1["tsc-check.sh — TypeScript errors"]
        W --> H2["console-guard.sh — Warn on console.*"]
    end

    subgraph PreBash["Before any Bash command"]
        B[Bash command] --> H3{destructive-git-guard.sh}
        H3 -->|"force push, reset --hard, rm -rf"| BLOCK[Blocked]
        H3 -->|safe| ALLOW[Allowed]
    end

    subgraph OnStop["Session end"]
        S[Claude stops] --> H4["session-summary.sh\nBranch · uncommitted · ahead of develop"]
    end
```

---

## What `/scaffold` generates

```mermaid
flowchart TD
    CMD["/scaffold orders fullstack"] --> FE & BE & DB & INFRA & BRUNO

    subgraph FE["Frontend — src/features/orders/"]
        F1["types.ts — Order, CreateOrderInput"]
        F2["api/orders.api.ts — useOrders, useCreateOrder ..."]
        F3["components/OrderList/ — .tsx + .test.tsx + index.ts"]
        F4["components/OrderForm/ — .tsx + .test.tsx + index.ts"]
        F5["index.ts — public API barrel"]
    end

    subgraph BE["Backend"]
        B1["src/types/orders.types.ts — Zod schemas"]
        B2["src/repositories/orders.repository.ts — Prisma + cursor pagination"]
        B3["src/services/orders.service.ts — Ownership checks + errors"]
        B4["src/controllers/orders.controller.ts — asyncHandler + ok/created/paginated"]
    end

    subgraph DB["Database"]
        D1["prisma/schema.prisma — Order model appended"]
        D2["npx prisma migrate dev"]
    end

    subgraph INFRA["Infra — CDK"]
        I1["IAM grant — table.grantReadWriteData"]
        I2["API Gateway routes — GET POST PATCH DELETE"]
    end

    subgraph BRUNO["Bruno — bruno/orders/"]
        BR1[list-orders.bru]
        BR2[create-order.bru]
        BR3[get-order.bru]
        BR4[update-order.bru]
        BR5[delete-order.bru]
    end
```

---

## Plugin Structure

```
.claude-plugin/plugin.json          ← manifest, MCP servers, install-time tokens
agents/
  └── debugger.md                   ← autonomous debug agent (only remaining agent)
skills/
  │
  ├── PM Workflow (user-invocable)
  │   ├── product-brainstorm/       ← /product-brainstorm <slug>
  │   ├── product-plan/             ← /product-plan <slug>
  │   ├── product-tasks/            ← /product-tasks <slug>
  │   └── product-refine/           ← /product-refine <ticket#>
  │
  ├── Dev Workflow (user-invocable)
  │   ├── dev-brainstorm/           ← /dev-brainstorm <ticket#>
  │   ├── dev-design/               ← /dev-design <ticket#>
  │   ├── dev-code/                 ← /dev-code <ticket#>
  │   └── dev-review/               ← /dev-review
  │
  ├── Release & Quality (user-invocable)
  │   ├── release/                  ← /release [patch|minor|major|auto]
  │   ├── deps/                     ← /deps check|update [scope]
  │   ├── adr/                      ← /adr <title> [issue#]
  │   └── dora/                     ← /dora report|trend [--days N]
  │
  ├── Performance & Reliability (user-invocable)
  │   ├── test-load/                ← /test-load run|bundle|baseline
  │   ├── feature-flag/             ← /feature-flag create|enable|disable|list
  │   ├── validate/                 ← /validate <issue#> [--env prod|staging]
  │   └── slo/                      ← /slo define|status|budget
  │
  ├── Coverage & Observability (user-invocable)
  │   ├── test-smoke/               ← /test-smoke [--env prod|staging]
  │   └── synthetic/                ← /synthetic setup|status|pause|resume
  │
  ├── Utilities (user-invocable)
  │   ├── scaffold/                 ← /scaffold <feature> [frontend|backend|fullstack]
  │   ├── branch/                   ← /branch create|switch|status|delete
  │   ├── test/                     ← /test unit|e2e|api|coverage|generate
  │   ├── pr/                       ← /pr create|merge|checks
  │   ├── deploy/                   ← /deploy staging|prod|status|rollback
  │   ├── logs/                     ← /logs health|errors|tail|search
  │   ├── fix/                      ← /fix lint|format|types|all
  │   ├── task/                     ← /task create|start|list|close
  │   ├── debug/                    ← /debug this|logs
  │   ├── cognito-auth/             ← /cognito-auth frontend|backend|fullstack
  │   └── evolve/                   ← /evolve skills|agents|coverage|all
  │
  └── Background Knowledge (auto-loaded, always on)
      ├── checklists/               ← Quality checklists — API · component · page · integration · logs · DB query · DB schema
      ├── react-standards/          ← React component patterns
      ├── composition-patterns/     ← Component composition rules
      ├── typescript-patterns/      ← TS best practices
      ├── testing-standards/        ← Vitest + RTL conventions
      ├── accessibility/            ← a11y requirements
      ├── playwright/               ← E2E test patterns + MCP runner (run tests from prompts)
      ├── linting/                  ← ESLint v9 flat config + Prettier — FE and BE rules
      ├── swagger-docs/             ← OpenAPI 3.1 via zod-to-openapi, Swagger UI setup
      ├── api-conventions/          ← REST shape, status codes, pagination
      ├── error-handling/           ← Error classes, asyncHandler, Prisma mapping
      ├── security/                 ← Auth, IAM, input validation
      ├── database-sql/             ← Prisma + PostgreSQL + safe migrations + seeders
      ├── database-nosql/           ← DynamoDB patterns
      ├── data-governance/          ← GDPR · PII tagging · erasure · consent · CCPA
      ├── cdk/                      ← CDK constructs + CDK Nag
      ├── monitoring/               ← CloudWatch alarms + dashboards
      ├── pipeline/                 ← CI/CD GitHub Actions
      ├── local-dev/                ← Docker Compose, env setup
      ├── api-docs/                 ← OpenAPI / Bruno documentation
      ├── bruno/                    ← Bruno API collection conventions
      ├── product-persona/          ← User personas reference
      ├── conventional-commit/      ← Commit message format
      ├── secret-scanning/          ← Prevent secrets in code
      └── packages/                 ← Approved dependency list

hooks/
  hooks.json
  scripts/
    tsc-check.sh              ← TypeScript error check after every .ts/.tsx write
    console-guard.sh          ← Warn on console.* usage
    destructive-git-guard.sh  ← Block force push, reset --hard, rm -rf
    session-summary.sh        ← Branch status summary on session end

docs/  (generated by commands — not committed as boilerplate)
  product-brainstorm/         ← /product-brainstorm output
  product-plans/              ← /product-plan output
  product-tasks/              ← /product-tasks + /product-refine output
  dev-brainstorm/             ← /dev-brainstorm output
  dev-tech-designs/           ← /dev-design output
  adr/                        ← Architecture Decision Records
  dora/                       ← DORA metric reports
  perf/                       ← Load test + baseline reports
  slo/                        ← SLO definitions + error budget
  validation/                 ← Post-deploy validation reports
  smoke/                      ← Smoke test reports
  evolve/                     ← /evolve improvement plans
```
