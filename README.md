# my-dev-standards — Claude Code Plugin

Full SDLC automation for React + Node.js + AWS + Cognito + GitHub teams.

---

## Setup

Install the plugin in Claude Code, then provide your tokens when prompted:

| Token | Required | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | Yes | Fine-grained PAT — Issues, PRs, repos |
| `FIGMA_TOKEN` | No | Design file access for design-to-code workflows |

GitHub PAT scopes needed: **Contents** (read), **Issues** (read/write), **Pull Requests** (read/write), **Metadata** (read).

---

## Commands

All commands follow the pattern `/my-dev-standards:<namespace> <sub-command> [args]`.

### `/task` — GitHub Issues

| Sub-command | What it does |
|---|---|
| `create [title]` | Create a new GitHub issue with the standard template |
| `start <issue#>` | Assign issue to yourself, label `in-progress`, prompt to create branch |
| `update <issue#>` | Edit title, labels, or assignee |
| `list [mine\|label:X]` | List open issues |
| `view <issue#>` | Show full issue with comments |
| `close <issue#>` | Close an issue |

### `/branch` — Branch management + scaffolding

| Sub-command | What it does |
|---|---|
| `create <ticket#> <slug> [frontend\|backend\|fullstack]` | Create `feature/<ticket>-<slug>` branch, optionally scaffold boilerplate |
| `switch <name-or-issue#>` | Switch to a branch |
| `list` | List local branches sorted by recency |
| `delete <name>` | Delete branch (warns if unmerged) |
| `status` | Show current branch: ahead/behind, uncommitted changes, linked issue |

### `/pr` — Pull Requests

| Sub-command | What it does |
|---|---|
| `create [target]` | Auto-fill PR from diff (title, body, checklist). Target defaults to `develop` |
| `merge <pr#>` | Merge after confirming checks pass |
| `list [mine\|review-requested]` | List open PRs |
| `view <pr#>` | Full PR details + review status |
| `checkout <pr#>` | Check out a PR's branch locally |
| `checks <pr#>` | Show CI/CD check status |
| `close <pr#>` | Close without merging |
| `update <pr#>` | Sync branch with base |

### `/test` — Tests

| Sub-command | What it does |
|---|---|
| `unit [file]` | Run Vitest unit tests |
| `e2e [spec]` | Run Playwright E2E tests |
| `api [collection]` | Run Bruno API tests |
| `coverage` | Run with coverage report, flag files < 80% |
| `watch [file]` | Vitest watch mode |
| `generate [file]` | Generate test stubs for existing code |

### `/deploy` — AWS deployment

| Sub-command | What it does |
|---|---|
| `staging` | Pre-flight (tsc, lint, tests, AWS creds, SSM) → CDK deploy → health check |
| `prod` | Same as staging with explicit confirmation gate |
| `status [env]` | Health check: API endpoint + CloudWatch errors + p95 latency |
| `rollback <env>` | Revert Lambda to previous version + CloudFront invalidation |

### `/review` — Code review

| Sub-command | What it does |
|---|---|
| `run` (default) | Full standards audit via reviewer agent → saves `REVIEW-<branch>.md` |
| `fix` | Mechanical only: `eslint --fix` + `prettier --write` |

### `/fix` — Auto-fixers

| Sub-command | What it does |
|---|---|
| `lint` | `eslint . --fix` |
| `format` | `prettier --write` |
| `types` | Show TypeScript errors (cannot auto-fix) |
| `all` | lint + format + show types |

### `/logs` — CloudWatch

| Sub-command | What it does |
|---|---|
| `health [env]` | Error count + auth failures + p95/p99 latency with 🟢/🟡/🔴 rating |
| `errors [env] [window]` | Recent errors grouped by type |
| `tail [env]` | Stream last 20 entries |
| `search <keyword> [env]` | Search by error message, requestId, userId, or action |

### `/debug` — Debugging

| Sub-command | What it does |
|---|---|
| `this [description]` | Root-cause investigation → minimal fix → failing test → Bug Fix Report |
| `logs [env]` | CloudWatch health check via debugger agent |

### `/cognito-auth` — Auth scaffolding

| Argument | What it does |
|---|---|
| `frontend` | Amplify config + `useAuth` hook + `LoginForm` + `AuthGuard` + API client |
| `backend` | `authMiddleware` (JWT verify) + `requireGroup` + error classes |
| `fullstack` | Both |

---

## Agents (auto-invoked — no slash command needed)

Tell Claude what you want to do and it picks the right agent:

| Agent | When Claude uses it | Trigger phrases |
|---|---|---|
| **requirements-analyst** | Turning ideas into GitHub issues | "I want to build X", "break this into stories", "create the backlog" |
| **tech-designer** | Designing a feature before coding | "design issue #N", "how should we build X", "create a tech design" |
| **developer** | Implementing a feature end-to-end | "implement issue #N", "build this feature", "code this up" |
| **reviewer** | Code review before a PR | "review the code", "check before PR", "is this ready to merge" |
| **debugger** | Investigating bugs or production issues | "something is broken", "debug this", "check production logs" |

---

## Hooks (automatic — always on)

| Hook | When | What it does |
|---|---|---|
| `tsc-check` | After any `.ts`/`.tsx` write | Runs `tsc --noEmit`, prints errors |
| `console-guard` | After any `.ts`/`.tsx` write | Warns if `console.*` found |
| `destructive-git-guard` | Before any Bash command | Blocks `--force`, `reset --hard`, `rm -rf` |
| `session-summary` | End of every session | Prints branch, uncommitted count, commits ahead of develop |

---

## Common workflows

### New feature end-to-end
```
1. requirements-analyst  →  creates GitHub issues from your description
2. tech-designer          →  designs the approach for a specific issue
3. /branch create <#> <slug> fullstack  →  creates branch + scaffolds files
4. /task start <#>       →  assigns issue, labels in-progress
5. developer              →  implements from the tech design
6. /test generate         →  fills in any missing tests
7. /review run            →  full audit → saves REVIEW-<branch>.md
8. /fix all               →  applies mechanical fixes
9. /pr create             →  opens PR with auto-filled description
10. /deploy staging       →  pre-flight + deploy + health check
```

### Bug investigation
```
1. /debug this <error description>  →  root-cause + fix + test
2. /pr create                        →  hotfix PR
3. /deploy staging                   →  verify fix
4. /logs health staging              →  confirm healthy after deploy
```

### Post-deploy monitoring
```
/deploy status staging   →  quick health check
/logs health staging     →  detailed error + latency report
/logs tail staging       →  live log stream
/debug logs staging      →  full incident report if unhealthy
```

---

## Plugin structure

```
.claude-plugin/
  plugin.json          ← manifest, MCP servers, userConfig
agents/
  requirements-analyst.md
  tech-designer.md
  developer.md
  reviewer.md
  debugger.md
skills/
  task/                ← /task commands
  branch/              ← /branch commands + scaffold templates
  pr/                  ← /pr commands
  test/                ← /test commands
  deploy/              ← /deploy commands
  review/              ← /review commands
  fix/                 ← /fix commands
  logs/                ← /logs commands + CloudWatch query library
  debug/               ← /debug commands
  cognito-auth/        ← auth scaffolding
  standards/           ← background: git, commit, quality rules
  react-standards/     ← background: React + TypeScript rules
  nodejs-standards/    ← background: Node.js architecture rules
  security-standards/  ← background: JWT, input validation, secrets rules
  logging-standards/   ← background: Pino, log fields, CloudWatch
hooks/
  hooks.json           ← hook definitions (call scripts below)
  scripts/
    tsc-check.sh           ← TypeScript error check
    console-guard.sh       ← console.log detection
    destructive-git-guard.sh ← blocks dangerous git commands
    session-summary.sh     ← end-of-session branch summary
```
