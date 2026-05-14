# my-dev-standards Plugin

This repo IS the Claude Code plugin — not an app. Files here define skills, agents, and hooks that extend Claude Code for React + Node.js + AWS teams.

---

## What's here

| Directory | Purpose |
|---|---|
| `skills/` | 30+ user-invocable slash commands + background reference skills |
| `agents/` | Specialized sub-agents: `code-reviewer`, `security-reviewer`, `debugger` |
| `hooks/` | Automatic quality enforcement on every Write/Edit/Bash |
| `templates/` | Starter configs for new projects (mcp.json, etc.) |

---

## Starting a session

Use `/goal <what you're building today>` to orient Claude and stay focused across long sessions. This is a Claude Code built-in — no skill needed.

---

## SDLC flow

Each command reads the previous command's output. Run linearly:

```
/product-brainstorm → /product-plan → /product-tasks → /product-refine →
/dev-brainstorm → /dev-design → /dev-code → /dev-review → /pr create →
/deploy staging → /validate → /deploy prod
```

---

## Background skills (auto-load — no command needed)

These are always active and apply to every file you touch:

- `react-standards` — React patterns, hooks, component structure
- `typescript-patterns` — type safety, generics, strict mode
- `error-handling` — AppError hierarchy, asyncHandler, errorHandler
- `api-conventions` — response envelopes, cursor pagination, Zod validation
- `logging-standards` — Pino setup, what/when/never to log, PII rules
- `database-sql` — Prisma patterns, migrations, seeders
- `linting` — ESLint v9 flat config, Prettier, lint-staged
- `security-standards` — OWASP, Cognito, IAM, input validation

---

## Review skills — run both before `/pr create`

| Command | Agent | What it checks |
|---|---|---|
| `/dev-review` | `code-reviewer` | TypeScript, React, error handling, tests, accessibility, logging, API conventions |
| `/security-review` | `security-reviewer` | OWASP Top 10, secrets scan, Cognito auth, IAM least-privilege, PII in logs |

---

## MCP tools

| Tool prefix | Source | Prefer over |
|---|---|---|
| `mcp__git__*` | GitHub MCP | `gh` CLI |
| `mcp__figma__*` | Figma MCP | Manual design export |

When GitHub MCP is active, `mcp__git__get_issue`, `mcp__git__update_issue`, `mcp__git__add_issue_comment` are preferred over `gh` CLI equivalents.

---

## Active hooks

| Hook | Trigger | What it does |
|---|---|---|
| `tsc-check.sh` | After every `.ts`/`.tsx` write | Runs `tsc --noEmit`, blocks if errors |
| `console-guard.sh` | After every `.ts`/`.tsx` write | Blocks `console.*` in production code |
| `destructive-git-guard.sh` | Before every `git` command | Blocks `force push`, `reset --hard`, `branch -D` |
| `session-summary.sh` | Session end | Prints branch status and uncommitted changes |

---

## Modifying this plugin

- Commit prefix: `chore(evolve):` or `chore(plugin):`
- Run `/evolve` at sprint end for evidence-based improvement recommendations based on REVIEW and DEBUG report history
