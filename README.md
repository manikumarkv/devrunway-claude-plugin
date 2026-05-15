# devrunway — Claude Code Plugin

Extend Claude Code with a full SDLC skill set for any tech stack — configure once, works everywhere.

---

## What is devrunway?

devrunway is a Claude Code plugin that adds:
- **35+ slash commands** covering the full SDLC (brainstorm → design → code → review → deploy)
- **Background skills** that enforce your team's standards automatically on every file edit
- **MCP auto-configuration** for your design tools, issue trackers, and code platforms
- **Modular layers** — install only the standards for the tech you actually use

---

## Quick Start

Inside Claude Code:

```bash
# 1. Add the devrunway marketplace
/plugin marketplace add manikumarkv/devrunway-claude-plugin

# 2. Install the plugin
/plugin install devrunway@devrunway

# 3. Run the setup wizard to configure your stack
/setup
```

`/setup` asks 35 questions across 6 screens and generates:

| Output | What it does |
|---|---|
| `stack.json` | Declares which tech layers you use |
| `.mcp.json` | Pre-configures MCP servers (Figma, GitHub, Jira…) |

All 135 layer skills are bundled with the plugin. There is no per-layer install step. The `stack-dispatcher` agent reads `stack.json` and the files you edit, then loads only the relevant layer detail files into a sub-agent so your main thread stays light.

---

## Example: /setup output

```
Your stack: React + Node/Express + AWS + PostgreSQL/Prisma + Cognito
            shadcn + Tailwind + Zustand + Zod
            Pino → CloudWatch + Sentry
            Vitest + Playwright + Bruno + MSW
            Figma + GitHub + GitHub Actions

Layers activated for your stack (auto-load on matching files):
  layers/source-control/github
  layers/ci/github-actions
  layers/frontend/react
  layers/css/tailwind
  layers/ui-components/shadcn
  layers/state/zustand
  layers/backend/node-express
  layers/validation/zod
  layers/cloud/aws
  layers/database/postgres-prisma
  layers/auth/cognito
  layers/logging/framework/pino
  layers/logging/provider/cloudwatch
  layers/error-monitoring/sentry
  layers/testing/unit/vitest
  layers/testing/e2e/playwright
  layers/testing/api/bruno
  layers/mocking/msw
  layers/design/figma

MCP servers configured in .mcp.json (auto-registered on plugin install):
  figma  → @figma/mcp-server (FIGMA_ACCESS_TOKEN)
  github → @modelcontextprotocol/server-github (GITHUB_PERSONAL_ACCESS_TOKEN)
```

---

## Architecture

```
skills/        ← universal slash commands (product-plan, dev-code, pr, eval, forge, friction…)
agents/        ← code-reviewer, security-reviewer, debugger, stack-dispatcher, layer-consultant
hooks/         ← 35 active safety + quality hooks (destructive-git-guard, secrets-leak-guard, …)

layers/        ← 135 technology layers, auto-loaded by file pattern
  frontend/      react | vue | angular | nextjs
  backend/       node-express | python-fastapi | python-django | dotnet
  cloud/         aws | gcp | azure
  database/      postgres-prisma | dynamodb | mongodb | sqlalchemy
  auth/          cognito | firebase | auth0 | azure-ad
  css/           tailwind | styled-components | css-modules | bootstrap
  ui-components/ shadcn | mui | ant-design | chakra
  state/         zustand | redux-toolkit | jotai | pinia
  validation/    zod | yup | valibot | joi
  testing/
    unit/        vitest | jest | pytest
    e2e/         playwright | cypress | selenium
    api/         bruno | postman | insomnia
  mocking/       msw | mirage | json-server
  logging/
    framework/   pino | winston | morgan
    provider/    cloudwatch | datadog | splunk | newrelic
  error-monitoring/ sentry | datadog-apm | bugsnag
  ci/            github-actions | gitlab-ci | circleci | azure-pipelines
  design/        figma | sketch | adobe-xd
  payment/       stripe | paypal | braintree
  storage/       s3 | cloudinary | gcs | uploadthing
  search/        algolia | elasticsearch | typesense
  realtime/      socketio | pusher | ably
  cache-queue/   redis | bullmq | sqs | rabbitmq
  feature-flags/ launchdarkly | aws-appconfig | flagsmith | posthog
  secrets/       aws-secrets-manager | vault | doppler | env-only
  source-control/ github | gitlab | bitbucket | azure-devops
  ... and more (135 layers total)

setup/         ← /setup wizard
```

---

## SDLC Flow

```
/product-brainstorm → /product-plan → /product-tasks → /product-refine →
/dev-brainstorm → /dev-design → /dev-code → /dev-review → /pr create →
/deploy staging → /validate → /deploy prod
```

---

## Key Commands

| Command | What it does |
|---|---|
| `/setup` | Configure your stack — run once per project |
| `/product-brainstorm` | Turn an idea into structured user stories |
| `/product-plan` | Break user stories into epics and milestones |
| `/dev-design` | Design architecture before touching code |
| `/dev-code` | Step-by-step implementation with checkpoints |
| `/dev-review` | Full code review via `code-reviewer` agent |
| `/security-review` | OWASP + secrets audit via `security-reviewer` agent |
| `/pr` | Create PR with description, checklist, linked issues |
| `/deploy` | Deploy to staging or production |
| `/evolve` | Evidence-based plugin improvement based on session history |

---

## Background Skills

Once layers are installed, skills auto-load based on the files you touch — no commands needed:

| Stack includes… | Skills auto-load when you edit… |
|---|---|
| React | `react-standards`, `composition-patterns` |
| Zod | `zod-validation` |
| Prisma | `database-sql` |
| Pino | `logging-standards` |
| MSW | `msw-mocking` |
| shadcn/ui | `shadcn-ui` |
| Tailwind | `tailwind-css` |
| Cognito | `cognito-auth`, `security-standards` |

---

## Contributing a Layer

See [CONTRIBUTING.md](CONTRIBUTING.md) to learn how to build a layer for an unimplemented technology and get it merged.

---

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full layer status table, session log, and what's planned next.

---

## License

MIT
