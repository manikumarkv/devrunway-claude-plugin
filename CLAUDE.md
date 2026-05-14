# devrunway Plugin

This repo IS the Claude Code plugin — not an app. Files here define skills, agents, and hooks that extend Claude Code for **any tech stack** via a modular layer system.

---

## Architecture

```
core/        ← always installed; universal SDLC for any stack
layers/      ← technology-specific layers; install only what you use
setup/       ← /setup wizard; generates stack.json + .mcp.json + install commands
```

### core/ — always active
| Directory | Purpose |
|---|---|
| `core/skills/` | ~32 universal slash commands + background reference skills |
| `core/agents/` | `code-reviewer`, `security-reviewer`, `debugger` |
| `core/hooks/` | `destructive-git-guard.sh`, `session-summary.sh` |

### layers/ — install what matches your stack
Each layer is a self-contained directory with its own skills and `stack:` frontmatter. Layers cover: frontend, backend, cloud, database, auth, CI, testing, logging, state, validation, design, and more.

**First time in a project?** Run `/setup` to configure your stack. It generates:
1. `stack.json` — declares which layers you use
2. `.mcp.json` — pre-configures MCP servers for your tools (Figma, GitHub, Jira, etc.)
3. `/install` commands — the exact layers to install

---

## Starting a session

```
/setup          ← first-time project setup (generates stack.json + .mcp.json)
/goal <task>    ← orient Claude for this session (Claude Code built-in)
```

---

## SDLC flow

```
/product-brainstorm → /product-plan → /product-tasks → /product-refine →
/dev-brainstorm → /dev-design → /dev-code → /dev-review → /pr create →
/deploy staging → /validate → /deploy prod
```

---

## Background skills (auto-load by stack)

Skills in `layers/` load automatically based on your `stack.json` and the files you touch. Examples:

| If your stack includes… | Skills that auto-load |
|---|---|
| React | `react-standards`, `composition-patterns`, `linting` |
| Zod | `zod-validation` |
| MSW | `msw-mocking` |
| Pino | `logging-standards` |
| Prisma | `database-sql` |
| Cognito | `cognito-auth`, `security-standards` |

Universal skills active for **all** stacks:
- `typescript-patterns` — strict TS, generics, type narrowing
- `error-handling` — typed error hierarchy, never swallow
- `api-conventions` — response envelopes, pagination, versioning
- `security-principles` — OWASP Top 10, input validation, secrets hygiene

---

## Review skills — run both before `/pr create`

| Command | Agent | What it checks |
|---|---|---|
| `/dev-review` | `code-reviewer` | TypeScript, error handling, tests, accessibility, logging, API conventions |
| `/security-review` | `security-reviewer` | OWASP Top 10, secrets scan, auth flows, IAM least-privilege, PII in logs |

---

## MCP auto-configuration

`/setup` generates `.mcp.json` for layers that have MCP support. Currently wired:

| Layer | MCP package | Env var |
|---|---|---|
| `design/figma` | `@figma/mcp-server` | `FIGMA_ACCESS_TOKEN` |
| `source-control/github` | `@modelcontextprotocol/server-github` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `project-management/jira` | `@modelcontextprotocol/server-jira` | `JIRA_API_TOKEN`, `JIRA_BASE_URL` |
| `project-management/linear` | `@linear/mcp-server` | `LINEAR_API_KEY` |

---

## Active hooks

| Hook | Trigger | What it does |
|---|---|---|
| `destructive-git-guard.sh` | Before every `git` command | Blocks `force push`, `reset --hard`, `branch -D` |
| `session-summary.sh` | Session end | Prints branch status and uncommitted changes |

---

## Layer status

See `docs/ROADMAP.md` for the full layer status table (✅ done / 🚧 stub / 📋 planned).

---

## Modifying this plugin

- Commit prefix: `chore(evolve):` or `chore(plugin):`
- Run `/evolve` at sprint end for evidence-based improvement recommendations
- To add a new layer: create `layers/<category>/<tech>/SKILL.md` with `stack:` frontmatter
- See `docs/ROADMAP.md` → "Contributing a new layer" for the full guide
