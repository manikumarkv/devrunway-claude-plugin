---
name: setup
description: Configure devrunway for this project. Detects the stack from the project's files, confirms it with you, asks only what files can't show (about 4 questions), then writes stack.json and .mcp.json so the right layer standards auto-load.
user-invocable: true
effort: medium
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash(python3 *)
  - Bash(git remote *)
  - Bash(ls *)
  - Bash(find *)
---

# Setup

Configure devrunway for this project in four steps: **detect → confirm → ask the rest → write**. A typical repo needs about 4 questions.

Use the `AskUserQuestion` tool for every question (up to 4 questions per call, up to 4 options per question; the user can always pick "Other"). Never print questions as plain text and wait.

---

## Step 0 — Existing config

If `stack.json` already exists in the project root, read it and ask: **Update it** (keep its values, re-detect and fill gaps) or **Start over** or **Cancel**.

## Step 1 — Detect

Run the detector that ships with this skill, from the project root. Its path is this skill's base directory (shown when the skill loads) plus `detect_stack.py`:

```bash
python3 "<this skill's base directory>/detect_stack.py" .
```

It prints JSON:

```json
{
  "detected": { "frontend": "react", "validation": "zod", "testing-unit": "vitest" },
  "evidence": { "frontend": "package.json: react", "validation": "package.json: zod", "testing-unit": "package.json: vitest" },
  "ask": ["project-management", "documents", "design", "policies"]
}
```

It reads `package.json`, lockfiles, Python and Flutter manifests, CI config, deploy config and the git remote, and only returns values that `setup/stack.schema.json` accepts.

If `python3` is not available, detect by hand: read `package.json` (and `pyproject.toml` / `requirements.txt` / `pubspec.yaml`), and map packages to slots with the reference table at the end.

## Step 2 — Confirm

Show what was found as a short table (slot, value, evidence). Then one `AskUserQuestion`:

- **Looks right**: go to Step 3.
- **Change something**: ask which slots in one follow-up, then one question per slot with the values from the reference table.
- **Add something it missed**: same, for slots it didn't detect.

Never ask about slots the user didn't mention. Slots nobody detected or answered are **left out** of `stack.json`; the `layer-autoload` hook infers them later from `package.json`.

## Step 3 — Ask what files can't show

Ask only the slots in `ask`, in one call (two if there are 5):

| Slot | Question | Options (`header`) |
|---|---|---|
| `source-control` (only if no git remote was found) | Where does the code live? | GitHub · GitLab · Bitbucket · Azure DevOps (`Git host`) |
| `project-management` | Where do you track work? | GitHub Issues · Jira · Linear · None (`Tickets`) |
| `documents` | Where do specs and docs live? | Confluence · Notion · None (`Docs`) |
| `design` | Design tool? | Figma · Sketch · None (`Design`) |
| `policies` | Team rules to enforce in this repo? (`multiSelect: true`) | Protect main: no commits directly on main/master/develop/release · Conventional commits: `type(scope): subject` messages (`Policies`) |

Policies are off unless picked, because devrunway is often installed at user level and runs in every repo. (Conventional commits are also enforced, without this answer, in a repo that already has a commitlint config.)

**Empty or new project** (fewer than 3 slots detected): also ask, in one more call, frontend, backend, database and unit testing, with the most common values from the reference table.

## Step 4 — Write the files

### Output 1 — stack.json

Write `stack.json` in the project root: `devrunway`, every detected or confirmed slot, every answered slot (`"none"` when the user picked None), and `policies`. Leave out slots nobody detected or answered. `frontend` is a string, or an array when there are several (`["nextjs", "react"]`, `["astro", "react"]`).

Example for a Next.js app:

```json
{
  "devrunway": "1.0",
  "source-control": "github",
  "ci": "github-actions",
  "package-manager": "pnpm",
  "frontend": ["nextjs", "react"],
  "css": "tailwind",
  "ui-components": "shadcn",
  "validation": "zod",
  "database": "postgres-prisma",
  "auth": "clerk",
  "testing-unit": "vitest",
  "testing-e2e": "playwright",
  "language": "typescript",
  "project-management": "linear",
  "documents": "notion",
  "design": "figma",
  "policies": {
    "protect-main": true,
    "conventional-commits": false
  }
}
```

The file must validate against `setup/stack.schema.json`; only the values in the reference table are allowed.

### Output 2 — .mcp.json

Write `.mcp.json` only if the stack uses a tool below. All are the vendors' official remote servers; nothing is installed locally. If `.mcp.json` exists, merge into its `mcpServers` and keep unrelated servers.

| Add | When `stack.json` has | Entry |
|---|---|---|
| `github` | `source-control` or `project-management` = `github` | `{ "type": "http", "url": "https://api.githubcopilot.com/mcp/", "headers": { "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" } }` |
| `gitlab` | `source-control` or `project-management` = `gitlab` | `{ "type": "http", "url": "https://gitlab.com/api/v4/mcp" }` (self-hosted: use your GitLab host) |
| `linear` | `project-management` = `linear` | `{ "type": "http", "url": "https://mcp.linear.app/mcp" }` |
| `atlassian` | `project-management` = `jira` or `documents` = `confluence` | `{ "type": "http", "url": "https://mcp.atlassian.com/v1/mcp" }` (one server for Jira and Confluence) |
| `figma` | `design` = `figma` | `{ "type": "http", "url": "https://mcp.figma.com/mcp" }` |
| `notion` | `documents` = `notion` | `{ "type": "http", "url": "https://mcp.notion.com/mcp" }` |
| `neon` | `database` = `neon` | `{ "type": "http", "url": "https://mcp.neon.tech/mcp" }` |

Shape:

```json
{
  "mcpServers": {
    "linear": { "type": "http", "url": "https://mcp.linear.app/mcp" }
  }
}
```

### Output 3 — Summary

Print:

1. The stack, one line per slot.
2. The layers that will auto-load: for each slot and value, `layers/<slot>/<value>`, where `logging-framework`, `logging-provider` and `testing-*` map to `logging/framework`, `logging/provider` and `testing/<kind>`. Skip `none`, `env-only` and `language: python` (no layer). They load when Claude reads or edits a matching file.
3. If `.mcp.json` was written, the next step for each server:
   - **github:** set `GITHUB_PERSONAL_ACCESS_TOKEN` in your shell (github.com → Settings → Developer settings → Personal access tokens). GitHub's server does not support browser sign-in for Claude Code.
   - **Every other server:** run `/mcp` in Claude Code, pick the server, and sign in in the browser. No tokens needed.
4. Next steps: `/product-brainstorm` for a new feature, `/dev-design <issue>` for an existing ticket, or just start coding.

---

## Reference — slots and values

Every value `stack.json` accepts (`none` is also allowed for every slot):

| Slot | Values |
|---|---|
| `source-control` | `github`, `gitlab`, `bitbucket`, `azure-devops` |
| `ci` | `github-actions`, `gitlab-ci`, `circleci`, `azure-pipelines` |
| `package-manager` | `npm`, `pnpm`, `yarn`, `bun` |
| `code-quality` | `github-security`, `sonarqube`, `snyk` |
| `frontend` | `react`, `vue`, `angular`, `nextjs`, `astro` (one, or an array) |
| `css` | `tailwind`, `styled-components`, `css-modules`, `bootstrap` |
| `ui-components` | `shadcn`, `mui`, `ant-design`, `chakra` |
| `state` | `zustand`, `redux-toolkit`, `jotai`, `pinia` |
| `i18n` | `react-i18next`, `lingui`, `vue-i18n` |
| `component-docs` | `storybook`, `ladle` |
| `design` | `figma`, `sketch`, `adobe-xd` |
| `backend` | `node-express`, `python-fastapi`, `python-django`, `dotnet` |
| `api-style` | `rest`, `graphql`, `trpc`, `grpc` |
| `validation` | `zod`, `yup`, `valibot`, `joi` |
| `api-docs` | `swagger-express`, `openapi-fastapi` |
| `cloud` | `aws`, `gcp`, `azure` |
| `container` | `serverless`, `docker`, `kubernetes`, `vercel`, `railway` |
| `database` | `postgres-prisma`, `neon`, `mongodb`, `dynamodb`, `sqlalchemy` |
| `auth` | `cognito`, `firebase`, `auth0`, `azure-ad`, `clerk` |
| `cache-queue` | `redis`, `sqs`, `bullmq`, `rabbitmq` |
| `storage` | `s3`, `gcs`, `cloudinary`, `uploadthing` |
| `secrets` | `aws-secrets-manager`, `doppler`, `vault`, `env-only` |
| `feature-flags` | `aws-appconfig`, `launchdarkly`, `posthog`, `flagsmith` |
| `logging-framework` | `pino`, `winston`, `morgan` |
| `logging-provider` | `cloudwatch`, `datadog`, `splunk`, `grafana-loki`, `newrelic` |
| `error-monitoring` | `sentry`, `datadog-apm`, `bugsnag` |
| `realtime` | `socketio`, `pusher`, `ably` |
| `search` | `algolia`, `typesense`, `elasticsearch`, `pagefind` |
| `payment` | `stripe`, `paypal`, `braintree` |
| `email` | `resend`, `sendgrid`, `ses` |
| `analytics` | `posthog` |
| `cms` | `keystatic` |
| `testing-unit` | `vitest`, `jest`, `pytest` |
| `testing-e2e` | `playwright`, `cypress`, `selenium`, `webdriverio` |
| `testing-api` | `bruno`, `postman`, `insomnia` |
| `mocking` | `msw`, `mirage`, `json-server` |
| `project-management` | `github`, `jira`, `gitlab`, `linear`, `huly` |
| `documents` | `confluence`, `notion` |
| `language` | `typescript`, `python` |
| `mobile` | `flutter` |
| `notifications` | `fcm` |
