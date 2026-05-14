# Plugin Roadmap — Living Document

> **How to use this file:**
> Start every Claude session by reading this file. It tells you exactly what has been built, what is in progress, and what to do next. Update the session log and layer status table at the end of every session before committing.

---

## Vision

Transform this plugin from a single hardwired stack (React + Node.js + AWS) into a **community platform** where any developer team can configure the exact standards they need for their specific stack.

Architecture: `core/` (universal SDLC, always installed) + `layers/` (technology-specific, mix and match via `/setup`).

`/setup` outputs **three things**: `stack.json` (layer config) + `.mcp.json` (MCP servers, pre-configured) + install commands. One command, zero manual wiring.

---

## Architecture: Layer Structure

```
core/                          ← always install; works for any stack
  skills/                      ← ~30 universal SDLC skills
  agents/                      ← code-reviewer, security-reviewer, debugger
  hooks/                       ← destructive-git-guard, session-summary

layers/
  frontend/        react | vue* | angular* | nextjs*
  backend/         node-express | python-fastapi* | python-django* | dotnet*
  cloud/           aws | gcp* | azure*
  database/        postgres-prisma | mongodb* | dynamodb | sqlalchemy*
  auth/            cognito | firebase* | azure-ad* | auth0*
  ui-components/   shadcn | mui* | ant-design* | chakra*
  css/             tailwind | styled-components* | css-modules* | bootstrap*
  logging/
    framework/     pino | winston* | morgan*
    provider/      cloudwatch | datadog* | splunk* | grafana-loki* | newrelic*
  mocking/         msw | mirage* | json-server*
  i18n/            react-i18next | lingui* | vue-i18n*
  design/          figma | sketch* | adobe-xd*
  project-management/  github | jira* | linear* | huly*
  validation/      zod | yup* | valibot* | joi*
  ci/              github-actions | gitlab-ci* | circleci*
  testing/
    unit/          vitest | jest* | pytest* | dotnet-xunit*
    e2e/           playwright | cypress* | selenium* | webdriverio*
    api/           bruno | postman* | insomnia*
  api-docs/        swagger-express | openapi-fastapi*

setup/             ← /setup command: 18 questions → stack.json + .mcp.json + install commands

* = STUB (not yet implemented, community contribution welcome)
```

---

## `/setup` — The 18 Questions

When a developer runs `/setup`, they are asked (all in one message):

| # | Dimension | Options |
|---|---|---|
| 1 | Frontend framework | `react` / `vue` / `angular` / `nextjs` / `none` |
| 2 | Backend language/framework | `node-express` / `python-fastapi` / `python-django` / `dotnet` / `none` |
| 3 | Cloud provider | `aws` / `gcp` / `azure` / `none` |
| 4 | Database | `postgres-prisma` / `mongodb` / `dynamodb` / `sqlalchemy` / `none` |
| 5 | Auth provider | `cognito` / `firebase` / `azure-ad` / `auth0` / `custom` / `none` |
| 6 | UI component library | `shadcn` / `mui` / `ant-design` / `chakra` / `none` |
| 7 | CSS framework | `tailwind` / `styled-components` / `css-modules` / `bootstrap` / `none` |
| 8 | Logging framework | `pino` / `winston` / `morgan` / `none` |
| 9 | Logging provider | `cloudwatch` / `datadog` / `splunk` / `grafana-loki` / `newrelic` / `none` |
| 10 | Mock API framework | `msw` / `mirage` / `json-server` / `none` |
| 11 | Unit / component testing | `vitest` / `jest` / `pytest` / `none` |
| 12 | E2E testing | `playwright` / `cypress` / `selenium` / `webdriverio` / `none` |
| 13 | API testing client | `bruno` / `postman` / `insomnia` / `none` |
| 14 | Localisation (i18n) | `react-i18next` / `lingui` / `vue-i18n` / `none` |
| 15 | Design tool | `figma` / `sketch` / `adobe-xd` / `none` |
| 16 | Project management | `github` / `jira` / `linear` / `huly` / `none` |
| 17 | Validation framework | `zod` / `yup` / `valibot` / `joi` / `none` |
| 18 | CI/CD | `github-actions` / `gitlab-ci` / `circleci` / `none` |

---

## `/setup` — Three Outputs

### Output 1 — `stack.json`
```json
{
  "frontend": "react",
  "backend": "node-express",
  "cloud": "aws",
  "database": "postgres-prisma",
  "auth": "cognito",
  "ui-components": "shadcn",
  "css": "tailwind",
  "logging-framework": "pino",
  "logging-provider": "cloudwatch",
  "mocking": "msw",
  "testing-unit": "vitest",
  "testing-e2e": "playwright",
  "testing-api": "bruno",
  "i18n": "react-i18next",
  "design": "figma",
  "project-management": "github",
  "validation": "zod",
  "ci": "github-actions"
}
```

### Output 2 — `.mcp.json` (auto-generated, ready to use)
```json
{
  "mcpServers": {
    "figma": {
      "command": "npx",
      "args": ["-y", "@figma/mcp-server"],
      "env": { "FIGMA_ACCESS_TOKEN": "${FIGMA_ACCESS_TOKEN}" }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "DATABASE_URL": "${DATABASE_URL}" }
    }
  }
}
```

Then prints:
```
✅ .mcp.json generated with 4 MCP servers.

Set these env vars before starting Claude Code:
  FIGMA_ACCESS_TOKEN   → figma.com → Settings → Account → Personal tokens
  GITHUB_TOKEN         → github.com/settings/tokens (repo + issues scope)
  DATABASE_URL         → your postgres connection string

⚠️  No MCP available yet for: tailwind, pino, cognito, msw
    These use skill-based guidance only.
```

### Output 3 — Layer install commands
```
Install these layers:
  /install core
  /install layers/frontend/react
  /install layers/backend/node-express
  ... (one per chosen layer)

Or all at once:
  /install --config stack.json
```

---

## MCP Registry — Tool → MCP Mapping

Each layer declares its MCP in frontmatter. `/setup` reads these to build `.mcp.json`.

| Tool | MCP package | Env vars needed | Status |
|---|---|---|---|
| `figma` | `@figma/mcp-server` | `FIGMA_ACCESS_TOKEN` | ✅ Official |
| `github` | `@modelcontextprotocol/server-github` | `GITHUB_TOKEN` | ✅ Official |
| `linear` | `@linear/mcp-server` | `LINEAR_API_KEY` | ✅ Official |
| `playwright` | `@playwright/mcp` | none | ✅ Official |
| `postgres-prisma` | `@modelcontextprotocol/server-postgres` | `DATABASE_URL` | ✅ Official |
| `mongodb` | `mongodb-mcp-server` | `MONGODB_URI` | ✅ Official |
| `aws` | `@aws/mcp-server-core` | AWS credentials | ✅ Official |
| `datadog` | `@datadog/mcp-server` | `DD_API_KEY` | ⚠️ Verify |
| `jira` | community | `JIRA_TOKEN` + `JIRA_HOST` | ⚠️ Community |
| `splunk` | community | `SPLUNK_TOKEN` | ⚠️ Community |
| `newrelic` | community | `NEW_RELIC_API_KEY` | ⚠️ Community |
| `tailwind` | none | — | ❌ No MCP |
| `pino` | none | — | ❌ No MCP |
| `cognito` | none | — | ❌ No MCP |
| `msw` | none | — | ❌ No MCP |
| `shadcn` | none | — | ❌ No MCP |
| `zod` | none | — | ❌ No MCP |

> **Keep this table updated** as new MCPs are released. The plugin auto-generates `.mcp.json` only for rows marked ✅ or ⚠️ (with a warning).

---

## Layer `mcp:` Frontmatter Field

Every layer skill that has an MCP declares it in its `SKILL.md` frontmatter:

```yaml
---
name: figma
stack: design/figma
user-invocable: false
mcp:
  package: "@figma/mcp-server"
  env:
    FIGMA_ACCESS_TOKEN: "figma.com → Settings → Account → Personal access tokens"
---
```

```yaml
---
name: playwright
stack: testing/e2e/playwright
user-invocable: false
mcp:
  package: "@playwright/mcp"
  env: {}
---
```

Layers without an MCP omit the `mcp:` field entirely. `/setup` scans all active layer `SKILL.md` files, collects `mcp:` blocks, and assembles `.mcp.json`.

---

## Layer Status

| Layer | Status | Skills inside | MCP | Notes |
|---|---|---|---|---|
| `core/` | 📋 Planned | ~30 universal skills | — | Phase 1 |
| `layers/frontend/react` | 📋 Planned | react-standards, composition-patterns | — | Move from skills/ |
| `layers/frontend/vue` | 🫥 Stub | — | — | Community |
| `layers/frontend/angular` | 🫥 Stub | — | — | Community |
| `layers/frontend/nextjs` | 🫥 Stub | — | — | Community |
| `layers/backend/node-express` | 📋 Planned | nodejs-standards, swagger-docs, Express error handling | — | Move + split |
| `layers/backend/python-fastapi` | 🫥 Stub | — | — | Community |
| `layers/backend/python-django` | 🫥 Stub | — | — | Community |
| `layers/backend/dotnet` | 🫥 Stub | — | — | Community |
| `layers/cloud/aws` | 📋 Planned | cdk, deploy, validate, logs, feature-flag, synthetic, monitoring | `@aws/mcp-server-core` | Move from skills/ |
| `layers/cloud/gcp` | 🫥 Stub | — | — | Community |
| `layers/cloud/azure` | 🫥 Stub | — | — | Community |
| `layers/database/postgres-prisma` | 📋 Planned | database-sql | `@modelcontextprotocol/server-postgres` | Move from skills/ |
| `layers/database/dynamodb` | 📋 Planned | database-nosql | — | Move from skills/ |
| `layers/database/mongodb` | 🫥 Stub | — | `mongodb-mcp-server` | Community |
| `layers/database/sqlalchemy` | 🫥 Stub | — | — | Community |
| `layers/auth/cognito` | 📋 Planned | cognito-auth | — | Move from skills/ |
| `layers/auth/firebase` | 🫥 Stub | — | — | Community |
| `layers/auth/azure-ad` | 🫥 Stub | — | — | Community |
| `layers/auth/auth0` | 🫥 Stub | — | — | Community |
| `layers/ui-components/shadcn` | 📋 Planned | shadcn patterns extracted from react-standards | — | Split |
| `layers/ui-components/mui` | 🫥 Stub | — | — | Community |
| `layers/ui-components/ant-design` | 🫥 Stub | — | — | Community |
| `layers/ui-components/chakra` | 🫥 Stub | — | — | Community |
| `layers/css/tailwind` | 📋 Planned | Tailwind config, conventions | — | Split from react-standards |
| `layers/css/styled-components` | 🫥 Stub | — | — | Community |
| `layers/css/css-modules` | 🫥 Stub | — | — | Community |
| `layers/css/bootstrap` | 🫥 Stub | — | — | Community |
| `layers/logging/framework/pino` | 📋 Planned | Pino singleton, pino-http, redact, bindings | — | Split from logging-standards |
| `layers/logging/framework/winston` | 🫥 Stub | — | — | Community |
| `layers/logging/framework/morgan` | 🫥 Stub | — | — | Community |
| `layers/logging/provider/cloudwatch` | 📋 Planned | CloudWatch CDK, Insights queries, metric filters | — | Split from logging-standards |
| `layers/logging/provider/datadog` | 🫥 Stub | — | `@datadog/mcp-server` | Community |
| `layers/logging/provider/splunk` | 🫥 Stub | — | community MCP | Community |
| `layers/logging/provider/grafana-loki` | 🫥 Stub | — | — | Community |
| `layers/logging/provider/newrelic` | 🫥 Stub | — | — | Community |
| `layers/mocking/msw` | 📋 Planned | MSW v2 handlers, server setup | — | Split from testing-standards |
| `layers/mocking/mirage` | 🫥 Stub | — | — | Community |
| `layers/mocking/json-server` | 🫥 Stub | — | — | Community |
| `layers/i18n/react-i18next` | 📋 Planned | i18next setup, t() usage, namespace conventions | — | Split from react-standards |
| `layers/i18n/lingui` | 🫥 Stub | — | — | Community |
| `layers/i18n/vue-i18n` | 🫥 Stub | — | — | Community |
| `layers/design/figma` | 📋 Planned | Figma MCP wiring, token conventions, handoff checklist | `@figma/mcp-server` | New skill |
| `layers/design/sketch` | 🫥 Stub | — | — | Community |
| `layers/design/adobe-xd` | 🫥 Stub | — | — | Community |
| `layers/project-management/github` | 📋 Planned | Issues, milestones, labels, gh CLI | `@modelcontextprotocol/server-github` | Move from task/pr/release |
| `layers/project-management/jira` | 🫥 Stub | — | community MCP | Community |
| `layers/project-management/linear` | 🫥 Stub | — | `@linear/mcp-server` | Community |
| `layers/project-management/huly` | 🫥 Stub | — | — | Community |
| `layers/validation/zod` | 📋 Planned | Zod schemas, .parse(), zod-to-openapi | — | Split from api-conventions |
| `layers/validation/yup` | 🫥 Stub | — | — | Community |
| `layers/validation/valibot` | 🫥 Stub | — | — | Community |
| `layers/validation/joi` | 🫥 Stub | — | — | Community |
| `layers/ci/github-actions` | 📋 Planned | pipeline skill | — | Move from skills/ |
| `layers/ci/gitlab-ci` | 🫥 Stub | — | — | Community |
| `layers/ci/circleci` | 🫥 Stub | — | — | Community |
| `layers/testing/unit/vitest` | 📋 Planned | Vitest + RTL patterns | — | Split from testing-standards |
| `layers/testing/unit/jest` | 🫥 Stub | — | — | Community |
| `layers/testing/unit/pytest` | 🫥 Stub | — | — | Community |
| `layers/testing/e2e/playwright` | 📋 Planned | Playwright E2E patterns | `@playwright/mcp` | Move from skills/ |
| `layers/testing/e2e/cypress` | 🫥 Stub | — | — | Community |
| `layers/testing/e2e/selenium` | 🫥 Stub | — | — | Community |
| `layers/testing/e2e/webdriverio` | 🫥 Stub | — | — | Community |
| `layers/testing/api/bruno` | 📋 Planned | Bruno collections, .bru patterns, env files | — | Moved from node-express |
| `layers/testing/api/postman` | 🫥 Stub | — | — | Community |
| `layers/testing/api/insomnia` | 🫥 Stub | — | — | Community |
| `layers/api-docs/swagger-express` | 📋 Planned | swagger-docs skill | — | Move from skills/ |
| `layers/api-docs/openapi-fastapi` | 🫥 Stub | — | — | Community |
| `setup/` | 📋 Planned | /setup skill — 18 questions → stack.json + .mcp.json + install commands | — | New skill |

**Legend:** ✅ Done · 🔨 In progress · 📋 Planned · 🫥 Stub (community)

---

## Session Log

### Session 1 — Foundation
_Skills and agents built from scratch._

**Built:**
- Core SDLC skills: product-brainstorm, product-plan, product-tasks, product-refine, dev-brainstorm, dev-design, dev-code, dev-review, adr, conventional-commit, branch, pr, task, release, fix, debug, evolve, review
- Background standards: react-standards, typescript-patterns, error-handling, api-conventions, security-standards, testing-standards, accessibility, data-governance
- Infrastructure: cdk, deploy, validate, logs, cognito-auth, feature-flag, synthetic, monitoring, pipeline, local-dev, dora, slo
- Agents: debugger

### Session 2 — Standards Depth
_All skills fleshed out with detailed content._

**Built:**
- database-sql: Prisma patterns, cursor pagination, migrations (expand-contract), seeders (idempotent upsert)
- linting: ESLint v9 flat config for FE + BE, Prettier, lint-staged, husky
- swagger-docs: zod-to-openapi, swagger-ui-express, response helpers
- playwright: Playwright MCP wiring, .mcp.json template
- checklists: 7 checklists (API, Component, Page, API Integration, Logging, DB Query, DB Schema)
- logging-standards: rebuilt — Pino singleton, pino-http, child logger, field schema, CloudWatch, Sentry

### Session 3 — Conflict Fixes + Logging Depth
_14 cross-skill conflicts fixed. Logging standards rebuilt comprehensively._

**Fixed conflicts:**
- react-hot-toast → sonner across error-handling, packages, react
- AppError constructor argument order standardised
- pagination key (not meta) in API responses
- `<QueryClientProvider>` corrected in testing patterns
- `requireGroup('Admin')` casing fixed

**Built:**
- logging-standards/logging.md: ~900 lines — Pino singleton with host/version/region, pino-http correlationId strategy, field schema (3 tiers), what/when/never to log, PII table, frontend Sentry, CloudWatch CDK + Insights queries

### Session 4 — Claude Best Practices Upgrade
_Metadata, agents, MCP wiring, CLAUDE.md._
_Date: 2026-05-14_

**Built:**
- `context: fork` added to 6 skills; `effort:` to 10 skills; `ultrathink` at 5 decision points
- Bug fixed: `skills/review/SKILL.md` had `agent: reviewer` → fixed to `agent: code-reviewer`
- Created `agents/code-reviewer.md` and `agents/security-reviewer.md`
- Created `skills/security-review/SKILL.md` — new `/security-review` command
- MCP wiring: `mcp__git__*` added to dev-code + dev-design
- Created `CLAUDE.md` at plugin root
- `paths:` scoping added to react-standards and cdk

### Session 5 — Architecture Planning
_Modular layer architecture designed. ROADMAP.md created._
_Date: 2026-05-14_

**Designed:**
- Full `core/` + `layers/` directory structure
- 18-question `/setup` flow
- Three `/setup` outputs: `stack.json` + `.mcp.json` + install commands
- MCP registry: 16 tools mapped to their MCP packages + env vars
- Layer `mcp:` frontmatter field spec
- Testing split into 3 sub-dimensions: unit (vitest/jest/pytest), e2e (playwright/cypress), api (bruno/postman)
- Bruno correctly placed in `layers/testing/api/` (not backend-specific)
- STUB system for community contributions (~30 unimplemented layers)

---

## Next Session Checklist

Start here when resuming. Run this first:
```bash
cat docs/ROADMAP.md
```

**Current status:** Architecture designed, no restructuring done yet. `skills/` is still flat.

### Phase 1 — Core extraction (start here)

```bash
# Create directory structure
mkdir -p core/skills core/agents core/hooks
mkdir -p layers/frontend/react
mkdir -p layers/backend/node-express
mkdir -p layers/cloud/aws
mkdir -p layers/database/postgres-prisma layers/database/dynamodb
mkdir -p layers/auth/cognito
mkdir -p layers/ui-components/shadcn
mkdir -p layers/css/tailwind
mkdir -p layers/logging/framework/pino layers/logging/provider/cloudwatch
mkdir -p layers/mocking/msw
mkdir -p layers/i18n/react-i18next
mkdir -p layers/design/figma
mkdir -p layers/project-management/github
mkdir -p layers/validation/zod
mkdir -p layers/ci/github-actions
mkdir -p layers/testing/unit/vitest layers/testing/e2e/playwright layers/testing/api/bruno
mkdir -p layers/api-docs/swagger-express
mkdir -p setup
```

**Move universal skills to `core/skills/`** (no content changes):
product-brainstorm, product-plan, product-tasks, product-refine, dev-brainstorm, dev-design, dev-code, dev-review, review, security-review, evolve, adr, conventional-commit, checklists, accessibility, data-governance, branch, pr, task, release, fix, debug, dora, slo, secret-scanning, standards, product-persona

**Move agents to `core/agents/`:**
code-reviewer.md, security-reviewer.md, debugger.md

**Move hooks to `core/hooks/`:**
destructive-git-guard.sh, session-summary.sh

**Split 6 mixed skills** (create principle version in core + implementation version in layer):

| Skill | Core version | Layer version |
|---|---|---|
| logging-standards | `core/skills/logging-principles/` — what/when/never, PII rules | `layers/logging/framework/pino/` — Pino singleton, pino-http, redact |
| error-handling | `core/skills/error-handling-principles/` — typed errors, fail fast | `layers/backend/node-express/` — asyncHandler, AppError, Express errorHandler |
| security-standards | `core/skills/security-principles/` — OWASP Top 10, input validation | `layers/auth/cognito/` — requireAuth, requireGroup, JWT verify |
| typescript-patterns | `core/skills/typescript-patterns/` — strict mode, generics, no-any | `layers/frontend/react/` — React-specific TS patterns |
| api-conventions | `core/skills/api-conventions/` — response envelope, pagination principles | `layers/backend/node-express/` — ok(), created(), paginated() Express helpers |
| testing-standards | `core/skills/testing-principles/` — test structure, mock at boundary | `layers/testing/unit/vitest/` — Vitest + RTL + MSW patterns |

**Move stack-specific skills to layers:**

| Current location | Move to |
|---|---|
| skills/react-standards/ | layers/frontend/react/ |
| skills/composition-patterns/ | layers/frontend/react/ |
| skills/nodejs-standards/ | layers/backend/node-express/ |
| skills/swagger-docs/ | layers/api-docs/swagger-express/ |
| skills/database-sql/ | layers/database/postgres-prisma/ |
| skills/database-nosql/ | layers/database/dynamodb/ |
| skills/cdk/ | layers/cloud/aws/ |
| skills/deploy/ | layers/cloud/aws/ |
| skills/validate/ | layers/cloud/aws/ |
| skills/logs/ | layers/cloud/aws/ |
| skills/cognito-auth/ | layers/auth/cognito/ |
| skills/feature-flag/ | layers/cloud/aws/ |
| skills/synthetic/ | layers/cloud/aws/ |
| skills/monitoring/ | layers/cloud/aws/ |
| skills/test-load/ | layers/cloud/aws/ |
| skills/test-smoke/ | layers/cloud/aws/ |
| skills/pipeline/ | layers/ci/github-actions/ |
| skills/local-dev/ | layers/ci/github-actions/ |
| skills/playwright/ | layers/testing/e2e/playwright/ |
| skills/bruno/ | layers/testing/api/bruno/ |
| skills/linting/ | split: core/skills/linting-principles/ + layers/frontend/react/ + layers/backend/node-express/ |
| skills/packages/ | split: core/ + respective layers |
| skills/project-structure/ | split: core/ + layers/frontend/react/ + layers/backend/node-express/ |

**Add `stack:` frontmatter** to every skill moved into layers/:
```yaml
stack: frontend/react      # or backend/node-express, cloud/aws, etc.
```

**Add `mcp:` frontmatter** to layers that have MCPs (see MCP Registry above).

### Phase 2 — Create `/setup` skill

Create `setup/SKILL.md` implementing:
1. 18 questions in one message
2. Generate `stack.json`
3. Scan layer SKILL.md files for `mcp:` blocks → assemble `.mcp.json`
4. Print install commands
5. Warn on STUB layers

### Phase 3 — STUB READMEs

Create `README.md` in each unimplemented layer directory explaining what it will cover and how to contribute.

### Phase 4 — Documentation

Update README.md, CLAUDE.md, create CONTRIBUTING.md with layer build guide.

---

## Future Ideas (not this session)

- **Visual stack configurator website** — UI where users click choices and get generated install commands + .mcp.json. Same 18 dimensions. Plan for dedicated session.
- **`/install` command** — skill that reads `stack.json` and symlinks/activates the right layer skills
- **Layer compatibility matrix** — which combinations are tested together
- **MCP registry auto-update** — script that checks npm for new `*-mcp-server` packages matching layer tool names
- **Domain:** `airunway.dev` is available at $13/year — strong candidate for plugin brand
