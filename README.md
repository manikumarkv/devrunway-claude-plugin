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
    A([Idea]) --> B[requirements-analyst agent]
    B --> C[GitHub Issues Created]
    C --> D["/design feature-name"]
    D --> E["docs/design/feature.md"]
    E --> F["/scaffold feature-name"]
    F --> G[All boilerplate files generated]
    G --> H["/branch create ticket slug"]
    H --> I["/task start ticket-num"]
    I --> J[Write business logic only]
    J --> K["/test unit"]
    K --> L{Tests pass?}
    L -- No --> J
    L -- Yes --> M["/review run"]
    M --> N{Review clean?}
    N -- No --> O["/fix all"]
    O --> J
    N -- Yes --> P["/pr create"]
    P --> Q[CI checks pass]
    Q --> R["/deploy staging"]
    R --> S["/logs health staging"]
    S --> T{Healthy?}
    T -- No --> U["/debug logs staging"]
    U --> J
    T -- Yes --> V["/pr merge"]
    V --> W["/deploy prod"]
    W --> X([Production])
    X --> Y["/evolve"]
    Y --> Z{Gaps or\nrecurring issues?}
    Z -- Yes --> AA[Skills and agents\nimproved]
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

## Workflows

### New Feature

```mermaid
flowchart LR
    A[Describe idea] -->|requirements-analyst| B[Issues]
    B -->|design| C[Design doc]
    C -->|scaffold| D[All files generated]
    D -->|branch create| E[Feature branch]
    E -->|Write logic| F[Code]
    F -->|review run| G{Clean?}
    G -->|No, fix all| F
    G -->|Yes| H["/pr create"]
    H -->|CI passes| I["/deploy staging"]
    I -->|logs health| J{Healthy?}
    J -->|No, debug| F
    J -->|Yes| K["/pr merge then deploy prod"]
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
    I --> J["REVIEW-branch.md saved"]
    J --> K["/pr create"]
```

---

## Commands

### `/task` — Issues
| Command | Action |
|---|---|
| `create [title]` | New GitHub issue |
| `start <#>` | Assign + label in-progress |
| `list [mine]` | List open issues |
| `close <#>` | Close issue |

### `/design` — Tech Design
| Command | Action |
|---|---|
| `/design <feature> [description]` | Generate `docs/design/<feature>.md` — API contract, DB schema, component plan, security checklist, implementation phases |

### `/scaffold` — Boilerplate

```mermaid
flowchart LR
    A["/scaffold orders fullstack"] --> B{"Reads docs/design/orders.md?"}
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

### `/review` — Code Review
| Command | Action |
|---|---|
| `run` | Full audit against all standards → `REVIEW-<branch>.md` |
| `fix` | ESLint + Prettier auto-fix |

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

---

## Agents

```mermaid
flowchart LR
    subgraph Triggers["Trigger phrases"]
        T1["I want to build X\nbreak into stories\ncreate backlog"]
        T2["design issue N\nhow should we build X"]
        T3["implement issue N\nbuild this feature"]
        T4["review the code\nis this ready to merge"]
        T5["something is broken\ndebug this\ncheck production"]
    end

    T1 --> A1[requirements-analyst]
    T2 --> A2[tech-designer]
    T3 --> A3[developer]
    T4 --> A4[reviewer]
    T5 --> A5[debugger]

    A1 -->|creates| G[GitHub Issues]
    A2 -->|writes| D["docs/design/*.md"]
    A3 -->|implements| C[Code + Tests]
    A4 -->|writes| R["REVIEW-branch.md"]
    A5 -->|writes| BF[Bug Fix Report]
```

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
agents/                        ← requirements-analyst, tech-designer, developer, reviewer, debugger
skills/
  ├── Commands (user-invocable)
  │   ├── task/                ← /task create|start|list|close
  │   ├── design/              ← /design <feature>
  │   ├── scaffold/            ← /scaffold <feature> [frontend|backend|fullstack]
  │   ├── branch/              ← /branch create|switch|status|delete
  │   ├── test/                ← /test unit|e2e|api|coverage|generate
  │   ├── review/              ← /review run|fix
  │   ├── pr/                  ← /pr create|merge|checks
  │   ├── deploy/              ← /deploy staging|prod|status|rollback
  │   ├── logs/                ← /logs health|errors|tail|search
  │   ├── fix/                 ← /fix lint|format|types|all
  │   ├── debug/               ← /debug this|logs
  │   └── cognito-auth/        ← /cognito-auth frontend|backend|fullstack
  │
  └── Background knowledge (auto-loaded)
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
```
