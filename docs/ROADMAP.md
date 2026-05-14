# Plugin Roadmap — Living Document

> **How to use this file:**
> Start every Claude session by reading this file. It tells you exactly what has been built, what is in progress, and what to do next. Update the session log and layer status table at the end of every session before committing.

---

## Vision

Transform this plugin from a single hardwired stack (React + Node.js + AWS) into a **community platform** where any developer team can configure the exact standards they need for their specific stack.

Architecture: `core/` (universal SDLC, always installed) + `layers/` (technology-specific, mix and match via `/setup`).

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
  project-management/ github | jira* | linear* | huly*
  validation/      zod | yup* | valibot* | joi*
  ci/              github-actions | gitlab-ci* | circleci*
  testing/         vitest-rtl | playwright | pytest* | jest*
  api-docs/        swagger-express | openapi-fastapi*

setup/             ← /setup command: 15 questions → stack.json → install commands

* = STUB (not yet implemented, community contribution welcome)
```

---

## `/setup` — The 15 Questions

When a developer runs `/setup`, they are asked:

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
| 11 | Localisation (i18n) | `react-i18next` / `lingui` / `vue-i18n` / `none` |
| 12 | Design tool | `figma` / `sketch` / `adobe-xd` / `none` |
| 13 | Project management | `github` / `jira` / `linear` / `huly` / `none` |
| 14 | Validation framework | `zod` / `yup` / `valibot` / `joi` / `none` |
| 15 | CI/CD | `github-actions` / `gitlab-ci` / `circleci` / `none` |

Output: `stack.json` + list of `/install` commands for chosen layers.

---

## Layer Status

| Layer | Status | Skills inside | Notes |
|---|---|---|---|
| `core/` | 📋 Planned | ~30 skills to extract from flat `skills/` | Phase 1 |
| `layers/frontend/react` | 📋 Planned | react-standards, composition-patterns | Move from skills/ |
| `layers/frontend/vue` | 🫥 Stub | — | Community |
| `layers/frontend/angular` | 🫥 Stub | — | Community |
| `layers/frontend/nextjs` | 🫥 Stub | — | Community |
| `layers/backend/node-express` | 📋 Planned | nodejs-standards, swagger-docs, bruno, Pino setup, Express error handling | Move + split |
| `layers/backend/python-fastapi` | 🫥 Stub | — | Community |
| `layers/backend/python-django` | 🫥 Stub | — | Community |
| `layers/backend/dotnet` | 🫥 Stub | — | Community |
| `layers/cloud/aws` | 📋 Planned | cdk, deploy, validate, logs, feature-flag, synthetic, monitoring | Move from skills/ |
| `layers/cloud/gcp` | 🫥 Stub | — | Community |
| `layers/cloud/azure` | 🫥 Stub | — | Community |
| `layers/database/postgres-prisma` | 📋 Planned | database-sql | Move from skills/ |
| `layers/database/dynamodb` | 📋 Planned | database-nosql | Move from skills/ |
| `layers/database/mongodb` | 🫥 Stub | — | Community |
| `layers/database/sqlalchemy` | 🫥 Stub | — | Community |
| `layers/auth/cognito` | 📋 Planned | cognito-auth | Move from skills/ |
| `layers/auth/firebase` | 🫥 Stub | — | Community |
| `layers/auth/azure-ad` | 🫥 Stub | — | Community |
| `layers/auth/auth0` | 🫥 Stub | — | Community |
| `layers/ui-components/shadcn` | 📋 Planned | shadcn patterns extracted from react-standards | Split |
| `layers/ui-components/mui` | 🫥 Stub | — | Community |
| `layers/ui-components/ant-design` | 🫥 Stub | — | Community |
| `layers/ui-components/chakra` | 🫥 Stub | — | Community |
| `layers/css/tailwind` | 📋 Planned | Tailwind config, conventions (extract from react-standards) | Split |
| `layers/css/styled-components` | 🫥 Stub | — | Community |
| `layers/css/css-modules` | 🫥 Stub | — | Community |
| `layers/css/bootstrap` | 🫥 Stub | — | Community |
| `layers/logging/framework/pino` | 📋 Planned | Pino singleton, pino-http, redact (extract from logging-standards) | Split |
| `layers/logging/framework/winston` | 🫥 Stub | — | Community |
| `layers/logging/framework/morgan` | 🫥 Stub | — | Community |
| `layers/logging/provider/cloudwatch` | 📋 Planned | CloudWatch CDK, Insights queries (extract from logging-standards) | Split |
| `layers/logging/provider/datadog` | 🫥 Stub | — | Community |
| `layers/logging/provider/splunk` | 🫥 Stub | — | Community |
| `layers/logging/provider/grafana-loki` | 🫥 Stub | — | Community |
| `layers/logging/provider/newrelic` | 🫥 Stub | — | Community |
| `layers/mocking/msw` | 📋 Planned | MSW v2 handlers, server setup (extract from testing-standards) | Split |
| `layers/mocking/mirage` | 🫥 Stub | — | Community |
| `layers/mocking/json-server` | 🫥 Stub | — | Community |
| `layers/i18n/react-i18next` | 📋 Planned | i18next setup, t() usage (extract from react-standards) | Split |
| `layers/i18n/lingui` | 🫥 Stub | — | Community |
| `layers/i18n/vue-i18n` | 🫥 Stub | — | Community |
| `layers/design/figma` | 📋 Planned | Figma MCP wiring, token conventions, handoff checklist | New skill |
| `layers/design/sketch` | 🫥 Stub | — | Community |
| `layers/design/adobe-xd` | 🫥 Stub | — | Community |
| `layers/project-management/github` | 📋 Planned | Issues, milestones, labels, gh CLI (from task/pr/release skills) | Move |
| `layers/project-management/jira` | 🫥 Stub | — | Community |
| `layers/project-management/linear` | 🫥 Stub | — | Community |
| `layers/project-management/huly` | 🫥 Stub | — | Community |
| `layers/validation/zod` | 📋 Planned | Zod schemas, .parse(), zod-to-openapi (extract from api-conventions + swagger-docs) | Split |
| `layers/validation/yup` | 🫥 Stub | — | Community |
| `layers/validation/valibot` | 🫥 Stub | — | Community |
| `layers/validation/joi` | 🫥 Stub | — | Community |
| `layers/ci/github-actions` | 📋 Planned | pipeline skill | Move |
| `layers/ci/gitlab-ci` | 🫥 Stub | — | Community |
| `layers/ci/circleci` | 🫥 Stub | — | Community |
| `layers/testing/vitest-rtl` | 📋 Planned | Vitest + RTL (extract from testing-standards) | Split |
| `layers/testing/playwright` | 📋 Planned | playwright skill | Move |
| `layers/testing/pytest` | 🫥 Stub | — | Community |
| `layers/testing/jest` | 🫥 Stub | — | Community |
| `layers/api-docs/swagger-express` | 📋 Planned | swagger-docs skill | Move |
| `layers/api-docs/openapi-fastapi` | 🫥 Stub | — | Community |
| `setup/` | 📋 Planned | /setup skill with 15 questions | New skill |

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
- `context: fork` added to 6 skills (test, validate, dev-review, evolve, security-review, debug)
- `effort:` added to 10 skills (scaffold/deploy/dev-design/evolve=high; dev-code/dev-review/validate/security-review=medium; test/fix=low)
- `ultrathink` added at 5 decision points (dev-design ×2, adr, evolve, product-plan)
- **Bug fixed:** `skills/review/SKILL.md` had `agent: reviewer` but `agents/reviewer.md` did not exist → fixed to `agent: code-reviewer`
- Created `agents/code-reviewer.md` — full review workflow, 9 standards checklists, BLOCKER/WARNING/SUGGESTION
- Created `agents/security-reviewer.md` — OWASP, CVE scan, secrets grep, Cognito checks, IAM audit
- Created `skills/security-review/SKILL.md` — new `/security-review` command
- MCP wiring: `mcp__git__*` added to dev-code + dev-design allowed-tools with MCP preferred notes
- Created `CLAUDE.md` at plugin root (85 lines)
- `paths:` scoping added to react-standards and cdk skills

---

## Next Session Checklist

Start here when resuming:

1. `cat docs/ROADMAP.md` — read this file
2. Check layer status table above — find first `📋 Planned` item
3. **Phase 0 is done** (this file exists)
4. **Phase 1 next:** Create `core/` directory, move universal skills, split 6 mixed skills

### Phase 1 — Exact steps

```bash
# 1. Create directories
mkdir -p core/skills core/agents core/hooks

# 2. Move universal skills (no content changes)
# See Skill Migration Map in plan file for full list

# 3. Split mixed skills:
#    logging-standards → core/logging-principles/ + layers/logging/framework/pino/
#    error-handling → core/error-handling-principles/ + layers/backend/node-express/
#    security-standards → core/security-principles/ + layers/auth/cognito/
#    typescript-patterns → core/ + layers/frontend/react/
#    api-conventions → core/ + layers/backend/node-express/
#    testing-standards → core/ + layers/testing/vitest-rtl/
```

### Phase 2 — After Phase 1

Create `layers/` structure and move stack-specific skills. See plan file for full mapping.

### Phase 3 — After Phase 2

Create `setup/SKILL.md` with 15-question flow.

### Phase 4 — After Phase 3

Create STUB READMEs for ~25 unimplemented layers.

### Phase 5 — After Phase 4

Update README.md, CLAUDE.md, create CONTRIBUTING.md.

---

## Future Ideas (not this session)

- **Visual stack configurator website** — UI where users click choices and get install commands. Same 15 dimensions. Planned for a dedicated session.
- **Community contribution pipeline** — GitHub issue templates for voting on new layers, PR template for layer contributions
- **`/install` command** — skill that reads stack.json and activates the right layers
- **Layer compatibility matrix** — which layers work together (e.g. pino + cloudwatch is tested; pino + splunk is untested)
- **Domain:** `airunway.dev` is available at $13/year — strong candidate for plugin brand
