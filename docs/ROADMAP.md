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
core/                            ← always install; works for any stack
  skills/                        ← ~30 universal SDLC skills
  agents/                        ← code-reviewer, security-reviewer, debugger
  hooks/                         ← destructive-git-guard, session-summary

layers/
  source-control/  github | gitlab* | bitbucket* | azure-devops*
  package-manager/ npm | yarn* | pnpm* | bun*
  frontend/        react | vue* | angular* | nextjs*
  state/           zustand | redux-toolkit* | jotai* | pinia* | none
  ui-components/   shadcn | mui* | ant-design* | chakra*
  css/             tailwind | styled-components* | css-modules* | bootstrap*
  i18n/            react-i18next | lingui* | vue-i18n*
  component-docs/  storybook | ladle* | none
  backend/         node-express | python-fastapi* | python-django* | dotnet*
  api-style/       rest | graphql* | trpc* | grpc*
  validation/      zod | yup* | valibot* | joi*
  realtime/        socketio | pusher* | ably* | none
  cloud/           aws | gcp* | azure*
  database/        postgres-prisma | mongodb* | dynamodb | sqlalchemy*
  auth/            cognito | firebase* | azure-ad* | auth0*
  storage/         s3 | cloudinary* | uploadthing* | gcs*
  cache-queue/     redis | bullmq* | sqs* | rabbitmq*
  container/       serverless | docker* | kubernetes* | vercel* | railway*
  secrets/         aws-secrets-manager | vault* | doppler* | env-only
  logging/
    framework/     pino | winston* | morgan*
    provider/      cloudwatch | datadog* | splunk* | grafana-loki* | newrelic*
  error-monitoring/ sentry | datadog-apm* | bugsnag* | none
  feature-flags/   launchdarkly | aws-appconfig | flagsmith* | posthog*
  payment/         stripe | paypal* | braintree* | none
  email/           sendgrid | ses | resend* | none
  search/          algolia | elasticsearch* | typesense* | none
  design/          figma | sketch* | adobe-xd*
  project-management/ github | jira* | linear* | huly*
  ci/              github-actions | gitlab-ci* | circleci* | azure-pipelines*
  testing/
    unit/          vitest | jest* | pytest* | dotnet-xunit*
    e2e/           playwright | cypress* | selenium* | webdriverio*
    api/           bruno | postman* | insomnia*
  mocking/         msw | mirage* | json-server*
  code-quality/    sonarqube* | snyk* | github-security | none
  api-docs/        swagger-express | openapi-fastapi*

setup/             ← /setup wizard: 6 groups × 5-6 questions → stack.json + .mcp.json + install commands

* = STUB (not yet implemented, community contribution welcome)
```

---

## `/setup` — Grouped Wizard (6 groups, one at a time)

Asking 32 questions at once is overwhelming. `/setup` asks them in 6 grouped screens with a progress bar.

---

### Group 1 / 6 — Source Control & CI

> **Setting up source control and CI (1/6)**
>
> 1. **Git provider?** `github` / `gitlab` / `bitbucket` / `azure-devops`
> 2. **Package manager?** `npm` / `yarn` / `pnpm` / `bun`
> 3. **CI/CD platform?** `github-actions` / `gitlab-ci` / `circleci` / `azure-pipelines`
> 4. **Code quality / SAST?** `github-security` / `sonarqube` / `snyk` / `none`

---

### Group 2 / 6 — Frontend

> **Setting up frontend (2/6)**
>
> 5. **Frontend framework?** `react` / `vue` / `angular` / `nextjs` / `none`
> 6. **UI component library?** `shadcn` / `mui` / `ant-design` / `chakra` / `none`
> 7. **CSS framework?** `tailwind` / `styled-components` / `css-modules` / `bootstrap` / `none`
> 8. **Client state management?** `zustand` / `redux-toolkit` / `jotai` / `pinia` / `none`
> 9. **Localisation (i18n)?** `react-i18next` / `lingui` / `vue-i18n` / `none`
> 10. **Component documentation?** `storybook` / `ladle` / `none`

---

### Group 3 / 6 — Backend & API

> **Setting up backend and API (3/6)**
>
> 11. **Backend framework?** `node-express` / `python-fastapi` / `python-django` / `dotnet` / `none`
> 12. **API style?** `rest` / `graphql` / `trpc` / `grpc`
> 13. **Validation framework?** `zod` / `yup` / `valibot` / `joi` / `none`
> 14. **Real-time?** `socketio` / `pusher` / `ably` / `none`
> 15. **API documentation?** `swagger-express` / `openapi-fastapi` / `none`

---

### Group 4 / 6 — Infrastructure

> **Setting up infrastructure (4/6)**
>
> 16. **Cloud provider?** `aws` / `gcp` / `azure` / `none`
> 17. **Database?** `postgres-prisma` / `mongodb` / `dynamodb` / `sqlalchemy` / `none`
> 18. **Auth provider?** `cognito` / `firebase` / `azure-ad` / `auth0` / `none`
> 19. **File storage?** `s3` / `cloudinary` / `uploadthing` / `gcs` / `none`
> 20. **Cache / queue?** `redis` / `bullmq` / `sqs` / `rabbitmq` / `none`
> 21. **Container / deploy target?** `serverless` / `docker` / `kubernetes` / `vercel` / `railway` / `none`
> 22. **Secrets management?** `aws-secrets-manager` / `vault` / `doppler` / `env-only`

---

### Group 5 / 6 — Observability & Services

> **Setting up observability and services (5/6)**
>
> 23. **Logging framework?** `pino` / `winston` / `morgan` / `none`
> 24. **Logging provider?** `cloudwatch` / `datadog` / `splunk` / `grafana-loki` / `newrelic` / `none`
> 25. **Error monitoring?** `sentry` / `datadog-apm` / `bugsnag` / `none`
> 26. **Feature flags?** `launchdarkly` / `aws-appconfig` / `flagsmith` / `posthog` / `none`
> 27. **Payment processing?** `stripe` / `paypal` / `braintree` / `none`
> 28. **Email service?** `sendgrid` / `ses` / `resend` / `none`
> 29. **Search?** `algolia` / `elasticsearch` / `typesense` / `none`

---

### Group 6 / 6 — Developer Tooling

> **Setting up developer tooling (6/6)**
>
> 30. **Design tool?** `figma` / `sketch` / `adobe-xd` / `none`
> 31. **Project management?** `github` / `jira` / `linear` / `huly` / `none`
> 32. **Unit / component testing?** `vitest` / `jest` / `pytest` / `none`
> 33. **E2E testing?** `playwright` / `cypress` / `selenium` / `webdriverio` / `none`
> 34. **API testing client?** `bruno` / `postman` / `insomnia` / `none`
> 35. **Mock API framework?** `msw` / `mirage` / `json-server` / `none`

---

## `/setup` — Three Outputs

### Output 1 — `stack.json`
```json
{
  "source-control": "github",
  "package-manager": "npm",
  "ci": "github-actions",
  "code-quality": "github-security",
  "frontend": "react",
  "ui-components": "shadcn",
  "css": "tailwind",
  "state": "zustand",
  "i18n": "react-i18next",
  "component-docs": "storybook",
  "backend": "node-express",
  "api-style": "rest",
  "validation": "zod",
  "realtime": "none",
  "api-docs": "swagger-express",
  "cloud": "aws",
  "database": "postgres-prisma",
  "auth": "cognito",
  "storage": "s3",
  "cache-queue": "redis",
  "container": "serverless",
  "secrets": "aws-secrets-manager",
  "logging-framework": "pino",
  "logging-provider": "cloudwatch",
  "error-monitoring": "sentry",
  "feature-flags": "aws-appconfig",
  "payment": "stripe",
  "email": "ses",
  "search": "none",
  "design": "figma",
  "project-management": "github",
  "testing-unit": "vitest",
  "testing-e2e": "playwright",
  "testing-api": "bruno",
  "mocking": "msw"
}
```

### Output 2 — `.mcp.json` (auto-generated, ready to use)

`/setup` scans each chosen layer's `SKILL.md` for `mcp:` frontmatter blocks and assembles this automatically:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    },
    "figma": {
      "command": "npx",
      "args": ["-y", "@figma/mcp-server"],
      "env": { "FIGMA_ACCESS_TOKEN": "${FIGMA_ACCESS_TOKEN}" }
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "DATABASE_URL": "${DATABASE_URL}" }
    },
    "sentry": {
      "command": "npx",
      "args": ["-y", "@sentry/mcp-server"],
      "env": { "SENTRY_AUTH_TOKEN": "${SENTRY_AUTH_TOKEN}" }
    },
    "stripe": {
      "command": "npx",
      "args": ["-y", "@stripe/mcp-server"],
      "env": { "STRIPE_SECRET_KEY": "${STRIPE_SECRET_KEY}" }
    },
    "aws": {
      "command": "npx",
      "args": ["-y", "@aws/mcp-server-core"],
      "env": {
        "AWS_ACCESS_KEY_ID": "${AWS_ACCESS_KEY_ID}",
        "AWS_SECRET_ACCESS_KEY": "${AWS_SECRET_ACCESS_KEY}",
        "AWS_REGION": "${AWS_REGION}"
      }
    }
  }
}
```

Then prints:
```
✅ .mcp.json generated — 7 MCP servers configured.

Set these environment variables before starting Claude Code:
  GITHUB_TOKEN          → github.com/settings/tokens (repo + issues scope)
  FIGMA_ACCESS_TOKEN    → figma.com → Account → Personal access tokens
  DATABASE_URL          → your postgres connection string
  SENTRY_AUTH_TOKEN     → sentry.io → Settings → Auth Tokens
  STRIPE_SECRET_KEY     → dashboard.stripe.com → Developers → API keys
  AWS_ACCESS_KEY_ID     → AWS IAM console
  AWS_SECRET_ACCESS_KEY → AWS IAM console
  AWS_REGION            → e.g. us-east-1

⚠️  No MCP available yet for: tailwind, pino, cognito, zustand, zod, msw, redis
    These use skill-based guidance only.
```

### Output 3 — Layer install commands
```
Install these layers (or run /install --config stack.json to do all at once):
  /install core
  /install layers/source-control/github
  /install layers/package-manager/npm
  ... one per chosen layer
```

---

## MCP Registry — Full Tool → MCP Mapping

Each layer declares its MCP in `SKILL.md` frontmatter. `/setup` reads these to build `.mcp.json`.

| Tool | Layer | MCP package | Env vars | Status |
|---|---|---|---|---|
| `github` | source-control | `@modelcontextprotocol/server-github` | `GITHUB_TOKEN` | ✅ Official |
| `gitlab` | source-control | `@gitlab/mcp-server` | `GITLAB_TOKEN` | ⚠️ Verify |
| `bitbucket` | source-control | community | `BITBUCKET_TOKEN` | ⚠️ Community |
| `figma` | design | `@figma/mcp-server` | `FIGMA_ACCESS_TOKEN` | ✅ Official |
| `playwright` | testing/e2e | `@playwright/mcp` | none | ✅ Official |
| `postgres-prisma` | database | `@modelcontextprotocol/server-postgres` | `DATABASE_URL` | ✅ Official |
| `mongodb` | database | `mongodb-mcp-server` | `MONGODB_URI` | ✅ Official |
| `aws` | cloud | `@aws/mcp-server-core` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | ✅ Official |
| `sentry` | error-monitoring | `@sentry/mcp-server` | `SENTRY_AUTH_TOKEN` | ✅ Official |
| `stripe` | payment | `@stripe/mcp-server` | `STRIPE_SECRET_KEY` | ✅ Official |
| `linear` | project-management | `@linear/mcp-server` | `LINEAR_API_KEY` | ✅ Official |
| `datadog` | logging-provider | `@datadog/mcp-server` | `DD_API_KEY` | ⚠️ Verify |
| `jira` | project-management | community | `JIRA_TOKEN`, `JIRA_HOST` | ⚠️ Community |
| `algolia` | search | community | `ALGOLIA_APP_ID`, `ALGOLIA_API_KEY` | ⚠️ Community |
| `splunk` | logging-provider | community | `SPLUNK_TOKEN` | ⚠️ Community |
| `launchdarkly` | feature-flags | community | `LD_API_KEY` | ⚠️ Community |
| `newrelic` | logging-provider | community | `NEW_RELIC_API_KEY` | ⚠️ Community |
| `storybook` | component-docs | `@storybook/mcp-server` | none | ⚠️ Verify |
| `tailwind` | css | none | — | ❌ No MCP |
| `pino` | logging/framework | none | — | ❌ No MCP |
| `cognito` | auth | none | — | ❌ No MCP |
| `zustand` | state | none | — | ❌ No MCP |
| `zod` | validation | none | — | ❌ No MCP |
| `msw` | mocking | none | — | ❌ No MCP |
| `redis` | cache-queue | none | — | ❌ No MCP |
| `shadcn` | ui-components | none | — | ❌ No MCP |

> **Keep this table updated** as new MCPs are released. Check [modelcontextprotocol.io/registry](https://modelcontextprotocol.io) for new entries.

---

## Layer `mcp:` Frontmatter Field

Every layer skill that has an MCP declares it in its `SKILL.md` frontmatter. `/setup` scans these automatically:

```yaml
---
name: stripe
stack: payment/stripe
user-invocable: false
mcp:
  package: "@stripe/mcp-server"
  env:
    STRIPE_SECRET_KEY: "dashboard.stripe.com → Developers → API keys → Secret key"
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

Layers without an MCP omit the `mcp:` field entirely.

---

## Layer Status

| Layer | Status | Skills | MCP | Notes |
|---|---|---|---|---|
| `core/` | 📋 Planned | ~30 universal skills | — | Phase 1 |
| **Source Control** | | | | |
| `layers/source-control/github` | 📋 Planned | pr, branch, task, release skills | `server-github` | Move from skills/ |
| `layers/source-control/gitlab` | 🫥 Stub | — | `@gitlab/mcp-server` | Community |
| `layers/source-control/bitbucket` | 🫥 Stub | — | community | Community |
| `layers/source-control/azure-devops` | 🫥 Stub | — | — | Community |
| **Package Manager** | | | | |
| `layers/package-manager/npm` | 📋 Planned | install commands, lockfile conventions | — | New skill |
| `layers/package-manager/pnpm` | 🫥 Stub | — | — | Community |
| `layers/package-manager/yarn` | 🫥 Stub | — | — | Community |
| `layers/package-manager/bun` | 🫥 Stub | — | — | Community |
| **Frontend** | | | | |
| `layers/frontend/react` | 📋 Planned | react-standards, composition-patterns | — | Move from skills/ |
| `layers/frontend/vue` | 🫥 Stub | — | — | Community |
| `layers/frontend/angular` | 🫥 Stub | — | — | Community |
| `layers/frontend/nextjs` | 🫥 Stub | — | — | Community |
| **State Management** | | | | |
| `layers/state/zustand` | 📋 Planned | store patterns, slice conventions | — | New skill |
| `layers/state/redux-toolkit` | 🫥 Stub | — | — | Community |
| `layers/state/jotai` | 🫥 Stub | — | — | Community |
| `layers/state/pinia` | 🫥 Stub | — | — | Community |
| **UI Components** | | | | |
| `layers/ui-components/shadcn` | 📋 Planned | shadcn patterns, cn(), component conventions | — | Split from react-standards |
| `layers/ui-components/mui` | 🫥 Stub | — | — | Community |
| `layers/ui-components/ant-design` | 🫥 Stub | — | — | Community |
| `layers/ui-components/chakra` | 🫥 Stub | — | — | Community |
| **CSS** | | | | |
| `layers/css/tailwind` | 📋 Planned | Tailwind config, class conventions, dark mode | — | Split from react-standards |
| `layers/css/styled-components` | 🫥 Stub | — | — | Community |
| `layers/css/css-modules` | 🫥 Stub | — | — | Community |
| `layers/css/bootstrap` | 🫥 Stub | — | — | Community |
| **i18n** | | | | |
| `layers/i18n/react-i18next` | 📋 Planned | i18next setup, t() usage, namespaces | — | Split from react-standards |
| `layers/i18n/lingui` | 🫥 Stub | — | — | Community |
| `layers/i18n/vue-i18n` | 🫥 Stub | — | — | Community |
| **Component Docs** | | | | |
| `layers/component-docs/storybook` | 📋 Planned | Story patterns, args, decorators | `@storybook/mcp-server` | New skill |
| `layers/component-docs/ladle` | 🫥 Stub | — | — | Community |
| **Backend** | | | | |
| `layers/backend/node-express` | 📋 Planned | nodejs-standards, Express error handling | — | Move + split |
| `layers/backend/python-fastapi` | 🫥 Stub | — | — | Community |
| `layers/backend/python-django` | 🫥 Stub | — | — | Community |
| `layers/backend/dotnet` | 🫥 Stub | — | — | Community |
| **API Style** | | | | |
| `layers/api-style/rest` | 📋 Planned | REST conventions, status codes, versioning | — | Split from api-conventions |
| `layers/api-style/graphql` | 🫥 Stub | — | — | Community |
| `layers/api-style/trpc` | 🫥 Stub | — | — | Community |
| `layers/api-style/grpc` | 🫥 Stub | — | — | Community |
| **Validation** | | | | |
| `layers/validation/zod` | 📋 Planned | Zod schemas, .parse(), zod-to-openapi | — | Split from api-conventions |
| `layers/validation/yup` | 🫥 Stub | — | — | Community |
| `layers/validation/valibot` | 🫥 Stub | — | — | Community |
| `layers/validation/joi` | 🫥 Stub | — | — | Community |
| **Real-time** | | | | |
| `layers/realtime/socketio` | 📋 Planned | Socket.io patterns, rooms, events | — | New skill |
| `layers/realtime/pusher` | 🫥 Stub | — | — | Community |
| `layers/realtime/ably` | 🫥 Stub | — | — | Community |
| **Cloud** | | | | |
| `layers/cloud/aws` | 📋 Planned | cdk, deploy, validate, logs, feature-flag, synthetic, monitoring | `@aws/mcp-server-core` | Move from skills/ |
| `layers/cloud/gcp` | 🫥 Stub | — | — | Community |
| `layers/cloud/azure` | 🫥 Stub | — | — | Community |
| **Database** | | | | |
| `layers/database/postgres-prisma` | 📋 Planned | database-sql | `server-postgres` | Move from skills/ |
| `layers/database/dynamodb` | 📋 Planned | database-nosql | — | Move from skills/ |
| `layers/database/mongodb` | 🫥 Stub | — | `mongodb-mcp-server` | Community |
| `layers/database/sqlalchemy` | 🫥 Stub | — | — | Community |
| **Auth** | | | | |
| `layers/auth/cognito` | 📋 Planned | cognito-auth | — | Move from skills/ |
| `layers/auth/firebase` | 🫥 Stub | — | — | Community |
| `layers/auth/azure-ad` | 🫥 Stub | — | — | Community |
| `layers/auth/auth0` | 🫥 Stub | — | — | Community |
| **Storage** | | | | |
| `layers/storage/s3` | 📋 Planned | S3 upload patterns, signed URLs, CDN | — | New skill |
| `layers/storage/cloudinary` | 🫥 Stub | — | — | Community |
| `layers/storage/uploadthing` | 🫥 Stub | — | — | Community |
| `layers/storage/gcs` | 🫥 Stub | — | — | Community |
| **Cache / Queue** | | | | |
| `layers/cache-queue/redis` | 📋 Planned | Redis patterns, TTL, cache invalidation | — | New skill |
| `layers/cache-queue/bullmq` | 🫥 Stub | — | — | Community |
| `layers/cache-queue/sqs` | 🫥 Stub | — | — | Community |
| `layers/cache-queue/rabbitmq` | 🫥 Stub | — | — | Community |
| **Container / Deploy Target** | | | | |
| `layers/container/serverless` | 📋 Planned | Lambda patterns, cold start, bundling | — | Extract from deploy |
| `layers/container/docker` | 🫥 Stub | — | — | Community |
| `layers/container/kubernetes` | 🫥 Stub | — | — | Community |
| `layers/container/vercel` | 🫥 Stub | — | — | Community |
| `layers/container/railway` | 🫥 Stub | — | — | Community |
| **Secrets** | | | | |
| `layers/secrets/aws-secrets-manager` | 📋 Planned | Secrets Manager patterns, rotation | — | New skill |
| `layers/secrets/vault` | 🫥 Stub | — | — | Community |
| `layers/secrets/doppler` | 🫥 Stub | — | — | Community |
| `layers/secrets/env-only` | 📋 Planned | .env conventions, never commit rules | — | New skill |
| **Logging Framework** | | | | |
| `layers/logging/framework/pino` | 📋 Planned | Pino singleton, pino-http, redact, bindings | — | Split from logging-standards |
| `layers/logging/framework/winston` | 🫥 Stub | — | — | Community |
| `layers/logging/framework/morgan` | 🫥 Stub | — | — | Community |
| **Logging Provider** | | | | |
| `layers/logging/provider/cloudwatch` | 📋 Planned | CloudWatch CDK, Insights queries, metric filters | — | Split from logging-standards |
| `layers/logging/provider/datadog` | 🫥 Stub | — | `@datadog/mcp-server` | Community |
| `layers/logging/provider/splunk` | 🫥 Stub | — | community | Community |
| `layers/logging/provider/grafana-loki` | 🫥 Stub | — | — | Community |
| `layers/logging/provider/newrelic` | 🫥 Stub | — | — | Community |
| **Error Monitoring** | | | | |
| `layers/error-monitoring/sentry` | 📋 Planned | Sentry init, captureException, ErrorBoundary | `@sentry/mcp-server` | Extract from logging-standards |
| `layers/error-monitoring/datadog-apm` | 🫥 Stub | — | `@datadog/mcp-server` | Community |
| `layers/error-monitoring/bugsnag` | 🫥 Stub | — | — | Community |
| **Feature Flags** | | | | |
| `layers/feature-flags/aws-appconfig` | 📋 Planned | AppConfig patterns (extract from feature-flag skill) | — | Move from skills/ |
| `layers/feature-flags/launchdarkly` | 🫥 Stub | — | community | Community |
| `layers/feature-flags/flagsmith` | 🫥 Stub | — | — | Community |
| `layers/feature-flags/posthog` | 🫥 Stub | — | — | Community |
| **Payment** | | | | |
| `layers/payment/stripe` | 📋 Planned | Stripe patterns, webhook verification, PCI rules | `@stripe/mcp-server` | New skill |
| `layers/payment/paypal` | 🫥 Stub | — | — | Community |
| `layers/payment/braintree` | 🫥 Stub | — | — | Community |
| **Email** | | | | |
| `layers/email/ses` | 📋 Planned | SES patterns, templates, bounce handling | — | New skill |
| `layers/email/sendgrid` | 🫥 Stub | — | — | Community |
| `layers/email/resend` | 🫥 Stub | — | — | Community |
| **Search** | | | | |
| `layers/search/algolia` | 🫥 Stub | — | community | Community |
| `layers/search/elasticsearch` | 🫥 Stub | — | — | Community |
| `layers/search/typesense` | 🫥 Stub | — | — | Community |
| **Design** | | | | |
| `layers/design/figma` | 📋 Planned | Figma MCP wiring, token conventions, handoff checklist | `@figma/mcp-server` | New skill |
| `layers/design/sketch` | 🫥 Stub | — | — | Community |
| `layers/design/adobe-xd` | 🫥 Stub | — | — | Community |
| **Project Management** | | | | |
| `layers/project-management/github` | 📋 Planned | Issues, milestones, labels, gh CLI | `server-github` | Move from task/pr/release |
| `layers/project-management/jira` | 🫥 Stub | — | community | Community |
| `layers/project-management/linear` | 🫥 Stub | — | `@linear/mcp-server` | Community |
| `layers/project-management/huly` | 🫥 Stub | — | — | Community |
| **CI/CD** | | | | |
| `layers/ci/github-actions` | 📋 Planned | pipeline skill, workflow templates | — | Move from skills/ |
| `layers/ci/gitlab-ci` | 🫥 Stub | — | — | Community |
| `layers/ci/circleci` | 🫥 Stub | — | — | Community |
| `layers/ci/azure-pipelines` | 🫥 Stub | — | — | Community |
| **Code Quality** | | | | |
| `layers/code-quality/github-security` | 📋 Planned | Dependabot, CodeQL, secret scanning | — | New skill |
| `layers/code-quality/sonarqube` | 🫥 Stub | — | — | Community |
| `layers/code-quality/snyk` | 🫥 Stub | — | — | Community |
| **Testing — Unit** | | | | |
| `layers/testing/unit/vitest` | 📋 Planned | Vitest + RTL patterns | — | Split from testing-standards |
| `layers/testing/unit/jest` | 🫥 Stub | — | — | Community |
| `layers/testing/unit/pytest` | 🫥 Stub | — | — | Community |
| **Testing — E2E** | | | | |
| `layers/testing/e2e/playwright` | 📋 Planned | Playwright patterns, page objects | `@playwright/mcp` | Move from skills/ |
| `layers/testing/e2e/cypress` | 🫥 Stub | — | — | Community |
| `layers/testing/e2e/selenium` | 🫥 Stub | — | — | Community |
| `layers/testing/e2e/webdriverio` | 🫥 Stub | — | — | Community |
| **Testing — API** | | | | |
| `layers/testing/api/bruno` | 📋 Planned | Bruno collections, .bru patterns, env files | — | Moved from node-express |
| `layers/testing/api/postman` | 🫥 Stub | — | — | Community |
| `layers/testing/api/insomnia` | 🫥 Stub | — | — | Community |
| **Mocking** | | | | |
| `layers/mocking/msw` | 📋 Planned | MSW v2 handlers, server setup | — | Split from testing-standards |
| `layers/mocking/mirage` | 🫥 Stub | — | — | Community |
| `layers/mocking/json-server` | 🫥 Stub | — | — | Community |
| **API Docs** | | | | |
| `layers/api-docs/swagger-express` | 📋 Planned | swagger-docs skill | — | Move from skills/ |
| `layers/api-docs/openapi-fastapi` | 🫥 Stub | — | — | Community |
| **Setup** | | | | |
| `setup/` | 📋 Planned | /setup wizard — 6 groups × 5-6 questions → stack.json + .mcp.json + install commands | — | New skill |

**Legend:** ✅ Done · 🔨 In progress · 📋 Planned · 🫥 Stub (community)

---

## Session Log

### Session 1 — Foundation
_Skills and agents built from scratch._
**Built:** Core SDLC skills, background standards, infrastructure skills, debugger agent.

### Session 2 — Standards Depth
_All skills fleshed out with detailed content._
**Built:** database-sql, linting, swagger-docs, playwright, checklists (7), logging-standards rebuilt.

### Session 3 — Conflict Fixes + Logging Depth
_14 cross-skill conflicts fixed. Logging standards rebuilt comprehensively._
**Fixed:** sonner, AppError constructor, pagination key, QueryClientProvider, requireGroup casing.
**Built:** logging-standards/logging.md (~900 lines).

### Session 4 — Claude Best Practices Upgrade
_Date: 2026-05-14_
**Built:** context:fork (6 skills), effort: (10 skills), ultrathink (5 points), code-reviewer agent, security-reviewer agent, /security-review skill, MCP wiring for dev-code/dev-design, CLAUDE.md, paths: scoping.
**Fixed:** agent:reviewer → agent:code-reviewer bug.

### Session 5 — Architecture Planning
_Date: 2026-05-14_
**Designed:** Full core/ + layers/ structure, 35-question grouped wizard (6 groups), 3 outputs (stack.json + .mcp.json + install commands), MCP registry (26 tools), layer mcp: frontmatter spec, testing split into 3 sub-dimensions, Bruno repositioned, ROADMAP.md created.

---

## Next Session Checklist

```bash
cat docs/ROADMAP.md   # always start here
```

**Status:** Architecture fully designed. `skills/` still flat — no restructuring done yet.

**Start with Phase 1:**

```bash
# Create full directory tree
mkdir -p core/skills core/agents core/hooks
mkdir -p layers/source-control/{github,gitlab,bitbucket,azure-devops}
mkdir -p layers/package-manager/{npm,yarn,pnpm,bun}
mkdir -p layers/frontend/{react,vue,angular,nextjs}
mkdir -p layers/state/{zustand,redux-toolkit,jotai,pinia}
mkdir -p layers/ui-components/{shadcn,mui,ant-design,chakra}
mkdir -p layers/css/{tailwind,styled-components,css-modules,bootstrap}
mkdir -p layers/i18n/{react-i18next,lingui,vue-i18n}
mkdir -p layers/component-docs/{storybook,ladle}
mkdir -p layers/backend/{node-express,python-fastapi,python-django,dotnet}
mkdir -p layers/api-style/{rest,graphql,trpc,grpc}
mkdir -p layers/validation/{zod,yup,valibot,joi}
mkdir -p layers/realtime/{socketio,pusher,ably}
mkdir -p layers/cloud/{aws,gcp,azure}
mkdir -p layers/database/{postgres-prisma,mongodb,dynamodb,sqlalchemy}
mkdir -p layers/auth/{cognito,firebase,azure-ad,auth0}
mkdir -p layers/storage/{s3,cloudinary,uploadthing,gcs}
mkdir -p layers/cache-queue/{redis,bullmq,sqs,rabbitmq}
mkdir -p layers/container/{serverless,docker,kubernetes,vercel,railway}
mkdir -p layers/secrets/{aws-secrets-manager,vault,doppler,env-only}
mkdir -p layers/logging/framework/{pino,winston,morgan}
mkdir -p layers/logging/provider/{cloudwatch,datadog,splunk,grafana-loki,newrelic}
mkdir -p layers/error-monitoring/{sentry,datadog-apm,bugsnag}
mkdir -p layers/feature-flags/{aws-appconfig,launchdarkly,flagsmith,posthog}
mkdir -p layers/payment/{stripe,paypal,braintree}
mkdir -p layers/email/{ses,sendgrid,resend}
mkdir -p layers/search/{algolia,elasticsearch,typesense}
mkdir -p layers/design/{figma,sketch,adobe-xd}
mkdir -p layers/project-management/{github,jira,linear,huly}
mkdir -p layers/ci/{github-actions,gitlab-ci,circleci,azure-pipelines}
mkdir -p layers/code-quality/{github-security,sonarqube,snyk}
mkdir -p layers/testing/unit/{vitest,jest,pytest}
mkdir -p layers/testing/e2e/{playwright,cypress,selenium,webdriverio}
mkdir -p layers/testing/api/{bruno,postman,insomnia}
mkdir -p layers/mocking/{msw,mirage,json-server}
mkdir -p layers/api-docs/{swagger-express,openapi-fastapi}
mkdir -p setup
```

Then move skills — see Skill Migration Map in the plan file.

---

## Future Ideas

- **Visual stack configurator website** — click-based UI, same 35 questions, outputs stack.json + .mcp.json + copy-paste install command. Dedicated session.
- **`/install` command** — reads stack.json, activates correct layers
- **MCP registry auto-update** — script to check modelcontextprotocol.io for new entries matching layer tool names
- **Layer compatibility matrix** — tested combinations vs untested
- **Domain:** `airunway.dev` — available at $13/year
