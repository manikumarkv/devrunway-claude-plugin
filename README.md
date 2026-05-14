# my-dev-standards — Claude Code Plugin

Full SDLC automation for React + Node.js + AWS + Cognito + GitHub.

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
    O --> P{Healthy? · CI}
    P -- No --> Q["Dev · /debug"]
    Q --> I
    P -- Yes --> R["Lead · /pr merge"]
    R --> S["Lead · /deploy prod"]
    S --> T([Production])
    T --> A
    T -.->|"end of sprint"| U["Lead · /evolve"]
    U --> V{Gaps or\nrecurring issues?}
    V -- Yes --> W[Skills improved]
    W --> B
    V -- No --> B
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
        E2["DEBUG-*.md\nroot cause patterns"]
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
    subgraph PM["👤 PM"]
        PB["docs/product-brainstorm/\n<slug>.md"]
        PP["docs/product-plans/\n<slug>.md"]
        PT["docs/product-tasks/\n<slug>.md + GitHub issues"]
        PR["docs/product-tasks/\n<ticket>-refined.md"]
    end

    subgraph Dev["💻 Dev"]
        DB["docs/dev-brainstorm/\n<ticket>.md"]
        DD["docs/dev-tech-designs/\n<ticket>-design.md"]
        RV["REVIEW-<branch>.md"]
    end

    PB -->|"/product-plan"| PP
    PP -->|"/product-tasks"| PT
    PT -->|"/product-refine"| PR
    PR -->|"/dev-brainstorm"| DB
    DB -->|"/dev-design"| DD
    DD -->|"/dev-code"| RV
    RV -->|"/pr create"| GH[GitHub PR]
```

---

## Workflows

### PM Tier — From idea to GitHub issues

```mermaid
flowchart LR
    A(["💡 Idea"]) -->|"/product-brainstorm"| B["docs/product-brainstorm/"]
    B -->|"/product-plan"| C["Personas · Flows · Stories"]
    C -->|"/product-tasks"| D["GitHub Issues + Milestones"]
    D -->|"/product-refine ticket"| E["Refined story · Q&A doc"]
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
```

### Bug Fix

```mermaid
flowchart LR
    A([Bug reported]) -->|debug this| B[Root cause identified]
    B --> C[Minimal fix + failing test]
    C -->|pr create| D[Hotfix PR]
    D -->|deploy staging| E["/logs health"]
    E -->|Healthy| F["/deploy prod"]
    F --> G([Fixed])
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
    L --> M([Production live])
```

### Debug Flow

```mermaid
flowchart TD
    A([Error or Incident]) --> B["/debug this description"]
    B --> C[debugger agent]
    C --> D[CloudWatch logs]
    C --> E[Error traces]
    C --> F[Recent commits]
    D & E & F --> G[Root cause identified]
    G --> H[Minimal fix]
    H --> I[Failing test added]
    I --> J["BUG-REPORT-date.md saved"]
    J --> K["/pr create"]
```

---

## Commands

### PM Workflow

| Command | Input | Output |
|---|---|---|
| `/product-brainstorm <slug>` | Idea / feature description | `docs/product-brainstorm/<slug>.md` — UX exploration, open questions, scope thoughts |
| `/product-plan <slug>` | Brainstorm doc | `docs/product-plans/<slug>.md` — personas, user flows, in/out of scope, epics, stories with AC |
| `/product-tasks <slug>` | Plan doc | GitHub milestones + issues · `docs/product-tasks/<slug>.md` summary |
| `/product-refine <ticket#>` | GitHub issue number | GitHub comment + `docs/product-tasks/<ticket>-refined.md` — Q&A, decisions, final AC |

### Dev Workflow

| Command | Input | Output |
|---|---|---|
| `/dev-brainstorm <ticket#>` | GitHub issue number | `docs/dev-brainstorm/<ticket>.md` — challenges, approaches, decision matrix, recommendation |
| `/dev-design <ticket#>` | Issue or brainstorm doc | `docs/dev-tech-designs/<ticket>-design.md` — phased plan with numbered steps for `/dev-code` |
| `/dev-code <ticket#>` | Design doc | Code built step by step with user confirmation · branch created · ticket updated |
| `/dev-review` | Current branch | `REVIEW-<branch>.md` tracked list · user picks items to fix · status updated per item |

### `/scaffold` — Boilerplate

```mermaid
flowchart LR
    A["/scaffold orders fullstack"] --> B{"Reads docs/dev-tech-designs/orders-design.md?"}
    B -->|Yes| C[Pre-filled with real field names]
    B -->|No| D[Placeholder TODOs]
    C & D --> E["Frontend: src/features/orders/"]
    C & D --> F["Backend: controller + service + repository + types"]
    C & D --> G["Database: prisma model appended"]
    C & D --> H["Infra: CDK grants + routes"]
    C & D --> I["Bruno: 5 request stubs"]
```

### `/branch` — Branches
| Command | Action |
|---|---|
| `create <#> <slug> [fullstack]` | Branch + scaffold |
| `switch <name-or-#>` | Switch branch |
| `status` | Ahead/behind + uncommitted |
| `delete <name>` | Safe delete |

### `/test` — Tests
| Command | Action |
|---|---|
| `unit [file]` | Vitest |
| `e2e [spec]` | Playwright |
| `api [collection]` | Bruno |
| `coverage` | Coverage ≥ 80% gate |
| `generate [file]` | Stub missing tests |

### `/pr` — Pull Requests
| Command | Action |
|---|---|
| `create [target]` | Auto-filled PR → develop |
| `merge <#>` | Merge after checks |
| `checks <#>` | CI status |

### `/deploy` — AWS
| Command | Action |
|---|---|
| `staging` | Pre-flight → CDK → health check |
| `prod` | Same + manual approval gate |
| `status [env]` | API + CloudWatch + latency |
| `rollback <env>` | Previous Lambda + CF invalidation |

### `/logs` — CloudWatch
| Command | Action |
|---|---|
| `health [env]` | Error rate + p95/p99 |
| `errors [env]` | Errors grouped by type |
| `tail [env]` | Stream last 20 entries |
| `search <term>` | By message, requestId, userId |

### `/fix` — Auto-fix
| Command | Action |
|---|---|
| `lint` | `eslint --fix` |
| `format` | `prettier --write` |
| `types` | Show TS errors |
| `all` | All three |

### Release & quality

| Command | Sub-commands | Action |
|---|---|---|
| `/release` | `[patch\|minor\|major\|auto]` | Semver bump · `CHANGELOG.md` · git tag · GitHub Release |
| `/deps` | `check` · `update [patch\|minor\|major\|all]` | Audit CVEs + outdated · update in batches · test-gated · Renovate config |
| `/adr` | `<title> [issue#]` | Write numbered ADR to `docs/adr/` in Nygard format · update index |
| `/dora` | `report` · `trend [--days N]` | DORA scorecard — deploy frequency, lead time, failure rate, MTTR |

### Remaining utilities

| Command | Sub-commands | Action |
|---|---|---|
| `/task` | `create [title]` · `start <#>` · `list [mine]` · `close <#>` | GitHub issue management |
| `/debug` | `this <description>` · `logs <env>` | Trigger debugger agent or tail error logs |
| `/cognito-auth` | `frontend` · `backend` · `fullstack` | Scaffold full Cognito auth flow |
| `/evolve` | `skills` · `agents` · `coverage` · `all` | End-of-sprint plugin self-improvement analysis |

---

## Agent

One autonomous agent remains — the **debugger**. All other workflows are interactive commands.

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
    FIX --> RPT["BUG-REPORT-<date>.md"]
    RPT --> PR["/pr create"]
```

The debugger is intentionally autonomous — it gathers all evidence before surfacing a root cause so you don't have to drive the investigation step by step.

---

## Background Skills (always loaded)

These apply automatically — no command needed. Claude checks them whenever writing code.

```mermaid
graph LR
    subgraph Frontend
        RS[react-standards]
        CP[composition-patterns]
        TP[typescript-patterns]
        TS[testing-standards]
        A11[accessibility]
    end

    subgraph Backend
        AC[api-conventions]
        EH[error-handling]
        SC[security]
        SQL[database-sql]
        NOSQL[database-nosql]
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
    end

    RS --- CP
    RS --- TP
    RS --- TS
    RS --- A11
    TS --- A11
    AC --- EH
    EH --- SC
    SQL --- EH
    NOSQL --- CDK
    CDK --- SC
    CDK --- MON
    PIPE --- SC
    LD --- SQL
    LD --- NOSQL
```

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

## Plugin structure

```
.claude-plugin/plugin.json     ← manifest, MCP servers, install-time tokens
agents/
  └── debugger.md              ← autonomous debug agent (only remaining agent)
skills/
  ├── PM Workflow (user-invocable)
  │   ├── product-brainstorm/  ← /product-brainstorm <slug>
  │   ├── product-plan/        ← /product-plan <slug>
  │   ├── product-tasks/       ← /product-tasks <slug>
  │   └── product-refine/      ← /product-refine <ticket#>
  │
  ├── Dev Workflow (user-invocable)
  │   ├── dev-brainstorm/      ← /dev-brainstorm <ticket#>
  │   ├── dev-design/          ← /dev-design <ticket#>
  │   ├── dev-code/            ← /dev-code <ticket#>
  │   └── dev-review/          ← /dev-review
  │
  ├── Release & Quality (user-invocable)
  │   ├── release/             ← /release [patch|minor|major|auto]
  │   ├── deps/                ← /deps check|update [scope]
  │   ├── adr/                 ← /adr <title> [issue#]
  │   └── dora/                ← /dora report|trend [--days N]
  │
  ├── Utility Commands (user-invocable)
  │   ├── task/                ← /task create|start|list|close
  │   ├── scaffold/            ← /scaffold <feature> [frontend|backend|fullstack]
  │   ├── branch/              ← /branch create|switch|status|delete
  │   ├── test/                ← /test unit|e2e|api|coverage|generate
  │   ├── pr/                  ← /pr create|merge|checks
  │   ├── deploy/              ← /deploy staging|prod|status|rollback
  │   ├── logs/                ← /logs health|errors|tail|search
  │   ├── fix/                 ← /fix lint|format|types|all
  │   ├── debug/               ← /debug this|logs
  │   ├── cognito-auth/        ← /cognito-auth frontend|backend|fullstack
  │   └── evolve/              ← /evolve [skills|agents|coverage|all]
  │
  └── Background knowledge (auto-loaded, always on)
      ├── react-standards/       ├── composition-patterns/  ├── typescript-patterns/
      ├── testing-standards/     ├── accessibility/         ├── error-handling/
      ├── api-conventions/       ├── security/              ├── database-sql/
      ├── database-nosql/        ├── project-structure/     ├── packages/
      ├── pipeline/              ├── playwright/            ├── api-docs/
      ├── monitoring/            ├── bruno/                 ├── cdk/
      ├── product-persona/       ├── conventional-commit/   ├── secret-scanning/
      └── local-dev/
hooks/
  hooks.json
  scripts/
    tsc-check.sh · console-guard.sh · destructive-git-guard.sh · session-summary.sh

docs/  (generated by commands — not committed as boilerplate)
  product-brainstorm/   ← /product-brainstorm output
  product-plans/        ← /product-plan output
  product-tasks/        ← /product-tasks + /product-refine output
  dev-brainstorm/       ← /dev-brainstorm output
  dev-tech-designs/     ← /dev-design output
  adr/                  ← /adr output (Architecture Decision Records)
  dora/                 ← /dora output (DORA metric reports)
  evolve/               ← /evolve output
```
