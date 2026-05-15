# devrunway Plugin

This repo IS the Claude Code plugin — not an app. Files here define skills, agents, and hooks that extend Claude Code for **any tech stack** via a modular layer system.

---

## Architecture

```
skills/      ← universal slash commands + background reference skills (auto-discovered by Claude Code)
agents/      ← code-reviewer, security-reviewer, stack-dispatcher, layer-consultant
hooks/       ← hook scripts + hooks.json registration
layers/      ← 135 technology-specific layers (auto-load by paths: globs)
setup/       ← stack.schema.json (validation schema for stack.json)
```

All 135 layer skills come bundled with the plugin. There is no per-layer install step — the `stack-dispatcher` agent reads `stack.json` and the files you edit at runtime and loads only the relevant layer detail files into a sub-agent.

**First time in a project?** Run `/setup` to configure your stack. It generates:
1. `stack.json` — declares which technologies you use
2. `.mcp.json` — pre-configures MCP servers for your tools (Figma, GitHub, Jira, etc.)

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

## Sub-agent context management

Heavy skills (`/dev-code`, `/dev-design`, `/eval`, `/forge`, `/dev-review`, `/security-review`) declare `context: fork` in their frontmatter. They run in **their own context window** and return concise summaries to the main thread — so multi-thousand-line layer standards files never bloat your session.

Within a forked skill, layer standards are loaded on demand via two agents:

| Agent | Role |
|---|---|
| `stack-dispatcher` | Scans `layers/*/*/SKILL.md` on disk, matches each layer's `paths:` globs against the files being worked on, and fans out to consultants in parallel |
| `layer-consultant` | Loads one layer's detail file (e.g. `react-standards.md`), distills the rules relevant to the question, returns ≤60 lines |

**Runtime source of truth:** whichever `layers/<category>/<tech>/SKILL.md` files exist on disk are the installed layers. `stack.json` is install-time only — the dispatcher does not consult it at runtime.

**Pattern:** when you write a new skill that consumes layer standards, do not Read `layers/*/*/*.md` files inline. Instead, call `stack-dispatcher` via the Task tool with `task` + `target_files`, and use the rule set it returns.

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
