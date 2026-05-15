---
name: setup
description: Interactive stack configuration wizard. Asks 35 questions across 6 screens to configure your full tech stack, then generates stack.json and .mcp.json so the right layer skills auto-load when you edit matching files.
user-invocable: true
effort: medium
allowed-tools:
  - Read
  - Write
  - Bash(ls *)
  - Bash(find *)
  - Bash(mkdir *)
---

# Setup Wizard

Configure the devrunway plugin for this project by running a 6-screen interactive wizard. Each screen covers a different layer of the stack. After all screens, two outputs are generated: `stack.json` (declares your tech choices) and `.mcp.json` (pre-wired MCP servers for the tools you picked, if any). All 135 layer skills come bundled with the plugin — the dispatcher auto-loads only the relevant ones based on `stack.json` and the files you edit.

---

## How to run this wizard

Present each screen as a numbered list of questions. Wait for the user to answer **all questions on the current screen** before moving to the next. Accept answers on a single line (e.g. `1. github  2. github-actions  3. pnpm  4. none`) or one per line. If the user types `skip` for any question, treat it as `none`.

After Screen 6, generate all three outputs without further prompting.

---

## Screen 1 of 6 — Source Control & CI/CD

Display this exact text:

```
─────────────────────────────────────────────────
  devrunway /setup  ·  Screen 1 of 6
  Source Control & CI/CD
─────────────────────────────────────────────────

Answer each question. Type the option key (e.g. "github") or "none".

1. Git provider
   github | gitlab | bitbucket | azure-devops | none

2. CI/CD platform
   github-actions | gitlab-ci | circleci | azure-pipelines | none

3. Package manager
   npm | pnpm | yarn | bun

4. Code quality / scanning
   github-security | sonarqube | snyk | none
```

Wait for the user's answers, then proceed to Screen 2.

---

## Screen 2 of 6 — Frontend

Display this exact text:

```
─────────────────────────────────────────────────
  devrunway /setup  ·  Screen 2 of 6
  Frontend
─────────────────────────────────────────────────

5. Frontend framework
   react | vue | angular | nextjs | none

6. CSS framework
   tailwind | styled-components | css-modules | bootstrap | none

7. UI component library
   shadcn | mui | ant-design | chakra | none

8. State management
   zustand | redux-toolkit | jotai | pinia | none

9. Internationalisation (i18n)
   react-i18next | lingui | vue-i18n | none

10. Component documentation
    storybook | ladle | none

11. Design tool
    figma | sketch | adobe-xd | none
```

Wait for the user's answers, then proceed to Screen 3.

---

## Screen 3 of 6 — Backend & API

Display this exact text:

```
─────────────────────────────────────────────────
  devrunway /setup  ·  Screen 3 of 6
  Backend & API
─────────────────────────────────────────────────

12. Backend runtime / framework
    node-express | python-fastapi | python-django | dotnet | none

13. API style
    rest | graphql | trpc | grpc | none

14. Validation library
    zod | yup | valibot | joi | none

15. API documentation
    swagger-express | openapi-fastapi | none
```

Wait for the user's answers, then proceed to Screen 4.

---

## Screen 4 of 6 — Infrastructure

Display this exact text:

```
─────────────────────────────────────────────────
  devrunway /setup  ·  Screen 4 of 6
  Infrastructure
─────────────────────────────────────────────────

16. Cloud provider
    aws | gcp | azure | none

17. Container / deployment target
    serverless | docker | kubernetes | vercel | railway | none

18. Database
    postgres-prisma | mongodb | dynamodb | sqlalchemy | none

19. Authentication
    cognito | firebase | auth0 | azure-ad | none

20. Cache / queue
    redis | sqs | bullmq | rabbitmq | none

21. File storage
    s3 | gcs | cloudinary | uploadthing | none

22. Secrets management
    aws-secrets-manager | doppler | vault | env-only

23. Feature flags
    aws-appconfig | launchdarkly | posthog | flagsmith | none
```

Wait for the user's answers, then proceed to Screen 5.

---

## Screen 5 of 6 — Observability & Services

Display this exact text:

```
─────────────────────────────────────────────────
  devrunway /setup  ·  Screen 5 of 6
  Observability & Services
─────────────────────────────────────────────────

24. Logging framework
    pino | winston | morgan | none

25. Logging provider / destination
    cloudwatch | datadog | splunk | grafana-loki | newrelic | none

26. Error monitoring
    sentry | datadog-apm | bugsnag | none

27. Realtime / websockets
    socketio | pusher | ably | none

28. Search
    algolia | typesense | elasticsearch | none

29. Payment processing
    stripe | paypal | braintree | none

30. Transactional email
    resend | sendgrid | ses | none
```

Wait for the user's answers, then proceed to Screen 6.

---

## Screen 6 of 6 — Developer Tooling

Display this exact text:

```
─────────────────────────────────────────────────
  devrunway /setup  ·  Screen 6 of 6
  Developer Tooling
─────────────────────────────────────────────────

31. Unit testing
    vitest | jest | pytest | none

32. End-to-end testing
    playwright | cypress | selenium | webdriverio | none

33. API testing
    bruno | postman | insomnia | none

34. API mocking
    msw | mirage | json-server | none

35. Project management
    github | jira | gitlab | linear | huly | none

36. Primary programming language (for language-specific pattern standards)
    typescript | python | none

37. Documentation / knowledge-base tool (where specs, ADRs, runbooks live)
    confluence | notion | none
```

Wait for the user's answers. After receiving answers to Screen 6, generate all outputs.

---

## Output 1 — stack.json

Write this file to `stack.json` in the project root (the directory where the user ran `/setup`). Use the user's answers verbatim. Use `"none"` for any question answered `none` or `skip`.

```json
{
  "devrunway": "1.0",
  "source-control": "<answer to Q1>",
  "ci": "<answer to Q2>",
  "package-manager": "<answer to Q3>",
  "code-quality": "<answer to Q4>",
  "frontend": "<answer to Q5>",
  "css": "<answer to Q6>",
  "ui-components": "<answer to Q7>",
  "state": "<answer to Q8>",
  "i18n": "<answer to Q9>",
  "component-docs": "<answer to Q10>",
  "design": "<answer to Q11>",
  "backend": "<answer to Q12>",
  "api-style": "<answer to Q13>",
  "validation": "<answer to Q14>",
  "api-docs": "<answer to Q15>",
  "cloud": "<answer to Q16>",
  "container": "<answer to Q17>",
  "database": "<answer to Q18>",
  "auth": "<answer to Q19>",
  "cache-queue": "<answer to Q20>",
  "storage": "<answer to Q21>",
  "secrets": "<answer to Q22>",
  "feature-flags": "<answer to Q23>",
  "logging-framework": "<answer to Q24>",
  "logging-provider": "<answer to Q25>",
  "error-monitoring": "<answer to Q26>",
  "realtime": "<answer to Q27>",
  "search": "<answer to Q28>",
  "payment": "<answer to Q29>",
  "email": "<answer to Q30>",
  "testing-unit": "<answer to Q31>",
  "testing-e2e": "<answer to Q32>",
  "testing-api": "<answer to Q33>",
  "mocking": "<answer to Q34>",
  "project-management": "<answer to Q35>",
  "language": "<answer to Q36>",
  "documents": "<answer to Q37>"
}
```

---

## Output 2 — .mcp.json

Only generate `.mcp.json` if the user selected one or more tools that have MCP server support. The tools with MCP support and their configurations are:

### figma (selected when Q11 = `figma`)

```json
"figma": {
  "command": "npx",
  "args": ["-y", "@figma/mcp-server"],
  "env": {
    "FIGMA_ACCESS_TOKEN": "<get from figma.com → Account → Personal access tokens>"
  }
}
```

### github (selected when Q1 = `github` OR Q35 = `github`)

```json
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "<get from github.com → Settings → Developer settings → PATs>"
  }
}
```

### jira (selected when Q35 = `jira`)

```json
"jira": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-jira"],
  "env": {
    "JIRA_HOST": "<your-org.atlassian.net>",
    "JIRA_EMAIL": "<your-email>",
    "JIRA_API_TOKEN": "<get from id.atlassian.com → Security → API tokens>"
  }
}
```

### linear (selected when Q35 = `linear`)

```json
"linear": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-linear"],
  "env": {
    "LINEAR_API_KEY": "<get from linear.app → Settings → API → Personal API keys>"
  }
}
```

### gitlab (selected when Q1 = `gitlab` OR Q35 = `gitlab`)

```json
"gitlab": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-gitlab"],
  "env": {
    "GITLAB_PERSONAL_ACCESS_TOKEN": "<get from gitlab.com → User Settings → Access Tokens (scopes: api, read_repository)>",
    "GITLAB_API_URL": "<https://gitlab.com/api/v4 for SaaS; self-hosted URL otherwise>"
  }
}
```

### confluence (selected when Q37 = `confluence`)

```json
"confluence": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-confluence"],
  "env": {
    "CONFLUENCE_BASE_URL": "<your-org.atlassian.net/wiki>",
    "CONFLUENCE_EMAIL": "<your-email>",
    "CONFLUENCE_API_TOKEN": "<get from id.atlassian.com → Security → API tokens>"
  }
}
```

### notion (selected when Q37 = `notion`)

```json
"notion": {
  "command": "npx",
  "args": ["-y", "@notionhq/notion-mcp-server"],
  "env": {
    "NOTION_API_KEY": "<get from notion.so → Settings → Integrations → New internal integration>"
  }
}
```

If none of the above tools are selected, do **not** write `.mcp.json`.

If `.mcp.json` already exists in the project root, read its current contents first and **merge** the new entries into the existing `mcpServers` object rather than overwriting unrelated servers.

Write the complete `.mcp.json` in this shape:

```json
{
  "mcpServers": {
    "<tool>": { ... }
  }
}
```

---

## Output 3 — Install commands and summary

Print the following after writing the files. Replace each `<...>` with the actual user selections. Omit lines for any selection that is `none`.

```
─────────────────────────────────────────────────
  devrunway /setup complete
─────────────────────────────────────────────────

Your stack summary:
  Source Control : <Q1>  |  CI : <Q2>  |  Package Manager : <Q3>
  Frontend       : <Q5> + <Q6> + <Q7> + <Q8> + <Q9>
  Backend        : <Q12> + <Q13> + <Q14> + <Q15>
  Cloud          : <Q16>  |  DB : <Q18>  |  Auth : <Q19>
  Logging        : <Q24> → <Q25>  |  Errors : <Q26>
  Testing        : <Q31> + <Q32> + <Q33> + <Q34>
  Design         : <Q11>  |  PM : <Q35>  |  Language : <Q36>  |  Docs : <Q37>

stack.json written to ./stack.json

Layers activated for your stack — these auto-load when you edit matching files:
```

All layer skills are bundled with the plugin. There is no per-layer install step. The `stack-dispatcher` agent reads `stack.json` plus the files you edit and loads only the relevant layer detail files into a sub-agent — your main thread stays light.

Print the table of layers that will be active for the user's choices, using these mappings:

| Question | Value | Active layer |
|---|---|---|
| Q1 | `github` | `layers/source-control/github` |
| Q1 | `gitlab` | `layers/source-control/gitlab` |
| Q1 | `bitbucket` | `layers/source-control/bitbucket` |
| Q1 | `azure-devops` | `layers/source-control/azure-devops` |
| Q2 | `github-actions` | `layers/ci/github-actions` |
| Q2 | `gitlab-ci` | `layers/ci/gitlab-ci` |
| Q2 | `circleci` | `layers/ci/circleci` |
| Q2 | `azure-pipelines` | `layers/ci/azure-pipelines` |
| Q3 | `npm` | `layers/package-manager/npm` |
| Q3 | `pnpm` | `layers/package-manager/pnpm` |
| Q3 | `yarn` | `layers/package-manager/yarn` |
| Q3 | `bun` | `layers/package-manager/bun` |
| Q4 | `github-security` | `layers/code-quality/github-security` |
| Q4 | `sonarqube` | `layers/code-quality/sonarqube` |
| Q4 | `snyk` | `layers/code-quality/snyk` |
| Q5 | `react` | `layers/frontend/react` |
| Q5 | `vue` | `layers/frontend/vue` |
| Q5 | `angular` | `layers/frontend/angular` |
| Q5 | `nextjs` | `layers/frontend/nextjs` |
| Q6 | `tailwind` | `layers/css/tailwind` |
| Q6 | `styled-components` | `layers/css/styled-components` |
| Q6 | `css-modules` | `layers/css/css-modules` |
| Q6 | `bootstrap` | `layers/css/bootstrap` |
| Q7 | `shadcn` | `layers/ui-components/shadcn` |
| Q7 | `mui` | `layers/ui-components/mui` |
| Q7 | `ant-design` | `layers/ui-components/ant-design` |
| Q7 | `chakra` | `layers/ui-components/chakra` |
| Q8 | `zustand` | `layers/state/zustand` |
| Q8 | `redux-toolkit` | `layers/state/redux-toolkit` |
| Q8 | `jotai` | `layers/state/jotai` |
| Q8 | `pinia` | `layers/state/pinia` |
| Q9 | `react-i18next` | `layers/i18n/react-i18next` |
| Q9 | `lingui` | `layers/i18n/lingui` |
| Q9 | `vue-i18n` | `layers/i18n/vue-i18n` |
| Q10 | `storybook` | `layers/component-docs/storybook` |
| Q10 | `ladle` | `layers/component-docs/ladle` |
| Q11 | `figma` | `layers/design/figma` |
| Q11 | `sketch` | `layers/design/sketch` |
| Q11 | `adobe-xd` | `layers/design/adobe-xd` |
| Q12 | `node-express` | `layers/backend/node-express` |
| Q12 | `python-fastapi` | `layers/backend/python-fastapi` |
| Q12 | `python-django` | `layers/backend/python-django` |
| Q12 | `dotnet` | `layers/backend/dotnet` |
| Q13 | `rest` | `layers/api-style/rest` |
| Q13 | `graphql` | `layers/api-style/graphql` |
| Q13 | `trpc` | `layers/api-style/trpc` |
| Q13 | `grpc` | `layers/api-style/grpc` |
| Q14 | `zod` | `layers/validation/zod` |
| Q14 | `yup` | `layers/validation/yup` |
| Q14 | `valibot` | `layers/validation/valibot` |
| Q14 | `joi` | `layers/validation/joi` |
| Q15 | `swagger-express` | `layers/api-docs/swagger-express` |
| Q15 | `openapi-fastapi` | `layers/api-docs/openapi-fastapi` |
| Q16 | `aws` | `layers/cloud/aws` |
| Q16 | `gcp` | `layers/cloud/gcp` |
| Q16 | `azure` | `layers/cloud/azure` |
| Q17 | `serverless` | `layers/container/serverless` |
| Q17 | `docker` | `layers/container/docker` |
| Q17 | `kubernetes` | `layers/container/kubernetes` |
| Q17 | `vercel` | `layers/container/vercel` |
| Q17 | `railway` | `layers/container/railway` |
| Q18 | `postgres-prisma` | `layers/database/postgres-prisma` |
| Q18 | `mongodb` | `layers/database/mongodb` |
| Q18 | `dynamodb` | `layers/database/dynamodb` |
| Q18 | `sqlalchemy` | `layers/database/sqlalchemy` |
| Q19 | `cognito` | `layers/auth/cognito` |
| Q19 | `firebase` | `layers/auth/firebase` |
| Q19 | `auth0` | `layers/auth/auth0` |
| Q19 | `azure-ad` | `layers/auth/azure-ad` |
| Q20 | `redis` | `layers/cache-queue/redis` |
| Q20 | `sqs` | `layers/cache-queue/sqs` |
| Q20 | `bullmq` | `layers/cache-queue/bullmq` |
| Q20 | `rabbitmq` | `layers/cache-queue/rabbitmq` |
| Q21 | `s3` | `layers/storage/s3` |
| Q21 | `gcs` | `layers/storage/gcs` |
| Q21 | `cloudinary` | `layers/storage/cloudinary` |
| Q21 | `uploadthing` | `layers/storage/uploadthing` |
| Q22 | `aws-secrets-manager` | `layers/secrets/aws-secrets-manager` |
| Q22 | `doppler` | `layers/secrets/doppler` |
| Q22 | `vault` | `layers/secrets/vault` |
| Q22 | `env-only` | _(no install needed — skip)_ |
| Q23 | `aws-appconfig` | `layers/feature-flags/aws-appconfig` |
| Q23 | `launchdarkly` | `layers/feature-flags/launchdarkly` |
| Q23 | `posthog` | `layers/feature-flags/posthog` |
| Q23 | `flagsmith` | `layers/feature-flags/flagsmith` |
| Q24 | `pino` | `layers/logging/framework/pino` |
| Q24 | `winston` | `layers/logging/framework/winston` |
| Q24 | `morgan` | `layers/logging/framework/morgan` |
| Q25 | `cloudwatch` | `layers/logging/provider/cloudwatch` |
| Q25 | `datadog` | `layers/logging/provider/datadog` |
| Q25 | `splunk` | `layers/logging/provider/splunk` |
| Q25 | `grafana-loki` | `layers/logging/provider/grafana-loki` |
| Q25 | `newrelic` | `layers/logging/provider/newrelic` |
| Q26 | `sentry` | `layers/error-monitoring/sentry` |
| Q26 | `datadog-apm` | `layers/error-monitoring/datadog-apm` |
| Q26 | `bugsnag` | `layers/error-monitoring/bugsnag` |
| Q27 | `socketio` | `layers/realtime/socketio` |
| Q27 | `pusher` | `layers/realtime/pusher` |
| Q27 | `ably` | `layers/realtime/ably` |
| Q28 | `algolia` | `layers/search/algolia` |
| Q28 | `typesense` | `layers/search/typesense` |
| Q28 | `elasticsearch` | `layers/search/elasticsearch` |
| Q29 | `stripe` | `layers/payment/stripe` |
| Q29 | `paypal` | `layers/payment/paypal` |
| Q29 | `braintree` | `layers/payment/braintree` |
| Q30 | `resend` | `layers/email/resend` |
| Q30 | `sendgrid` | `layers/email/sendgrid` |
| Q30 | `ses` | `layers/email/ses` |
| Q31 | `vitest` | `layers/testing/unit/vitest` |
| Q31 | `jest` | `layers/testing/unit/jest` |
| Q31 | `pytest` | `layers/testing/unit/pytest` |
| Q32 | `playwright` | `layers/testing/e2e/playwright` |
| Q32 | `cypress` | `layers/testing/e2e/cypress` |
| Q32 | `selenium` | `layers/testing/e2e/selenium` |
| Q32 | `webdriverio` | `layers/testing/e2e/webdriverio` |
| Q33 | `bruno` | `layers/testing/api/bruno` |
| Q33 | `postman` | `layers/testing/api/postman` |
| Q33 | `insomnia` | `layers/testing/api/insomnia` |
| Q34 | `msw` | `layers/mocking/msw` |
| Q34 | `mirage` | `layers/mocking/mirage` |
| Q34 | `json-server` | `layers/mocking/json-server` |
| Q35 | `github` | `layers/project-management/github` |
| Q35 | `jira` | `layers/project-management/jira` |
| Q35 | `gitlab` | `layers/project-management/gitlab` |
| Q35 | `linear` | `layers/project-management/linear` |
| Q35 | `huly` | `layers/project-management/huly` |
| Q36 | `typescript` | `layers/language/typescript` |
| Q36 | `python` | _(no layer yet — python patterns covered in backend layers)_ |
| Q37 | `confluence` | `layers/documents/confluence` |
| Q37 | `notion` | `layers/documents/notion` |

After the layer table, if `.mcp.json` was written, append:

```
MCP servers configured: <comma-separated list of server names>

These were auto-registered when you installed the plugin. Set the
required tokens in Claude Code's plugin settings if you haven't already
(e.g. GITHUB_TOKEN, FIGMA_TOKEN, JIRA_API_TOKEN, etc. — see the install
prompt or run /plugin to manage).
```

End with:

```
─────────────────────────────────────────────────
Your stack is configured. Layers auto-load when you edit matching files.

Next steps:
  • Set any required tokens via /plugin (GitHub PAT is required)
  • Try /product-brainstorm to start a new feature
  • Or /dev-design <issue-number> if you already have a ticket
  • Or just start writing code — hooks and layers activate automatically

Happy building.
─────────────────────────────────────────────────
```

---

## Error handling

- If the user provides an answer that is not in the allowed options for a question, respond: `"<value>" is not a valid option for question <N>. Valid options are: <list>. Please re-answer question <N>.`
- If `stack.json` already exists in the project root, read it and ask the user: `stack.json already exists. Overwrite it? (yes / no)` — abort if they say no.
