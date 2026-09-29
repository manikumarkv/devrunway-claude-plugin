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

All layers come bundled with the plugin. There is no per-layer install step. Claude Code does **not** register `layers/` as skills; the `layer-autoload` hook loads them (see "How layers load" below).

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

Layers load automatically when Claude reads or edits a file matching their `paths:` globs, filtered by your stack. Examples:

| If your stack includes… | Skills that auto-load |
|---|---|
| React | `react-standards`, `composition-patterns`, `linting` |
| Zod | `zod-validation` |
| MSW | `msw-mocking` |
| Pino | `logging-standards` |
| Prisma | `database-sql` |
| Cognito | `security-standards` |

Universal skills active for **all** stacks:
- `typescript-patterns` — strict TS, generics, type narrowing
- `error-handling` — typed error hierarchy, never swallow
- `api-conventions` — response envelopes, pagination, versioning
- `security-principles` — OWASP Top 10, input validation, secrets hygiene
- `naming-conventions` — database, payload, env var, and test naming; boundary names as contracts

### Layer skills that are commands, not background layers

Not everything under `layers/` auto-loads. Nine layer skills are `user-invocable: true` with **no `paths:`** — you invoke them by name and `stack-dispatcher` never routes to them (it reports them as `Unroutable`). Do not list these in the auto-load table above:

```
/cognito-auth   ← scaffold an AWS Cognito auth flow (frontend | backend | fullstack)
/scaffold       ← scaffold a React feature
/deploy  /validate  /logs  /feature-flag  /synthetic  /test-load  /test-smoke
```

---

## How layers load

Claude Code only registers `skills/<name>/SKILL.md`. Layers are loaded by the `layer-autoload` hook (`hooks/scripts/layer_autoload.py`, PostToolUse on `Read|Edit|Write|MultiEdit`):

1. It matches the touched file (relative to the project) against `layers/index.json`, the `paths:` globs of every background layer.
2. It skips layers that contradict the project's stack: `stack.json` first; for slots it doesn't set, `package.json` dependencies, or a non-Node manifest (`pyproject.toml`, `go.mod`, …) keeps npm-only layers out.
3. It injects the matching layers' `SKILL.md` body as `additionalContext`, with the absolute path of the detail file: at most 3 layers per call, each at most once per session, specific globs before extension-only ones.

**After adding or changing a layer's frontmatter, run `python3 scripts/build_layer_index.py`.** CI fails if `layers/index.json` is stale.

Registering all layers as skills was evaluated and rejected: plugin skills are listed in every session regardless of `paths:`, which added ~11k tokens per session for every user (#80).

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

The plugin itself bundles **no** MCP servers and asks for **no** tokens at install. `/setup` generates the project's `.mcp.json` for the tools you pick. Currently wired (package names being corrected in #75):

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

## Keep the product site in sync

The user-facing site at **`manikumarkv/devrunway`** (devrunway.dev, Vite + React) describes this plugin. After any change here that alters something a user can see (commands, agents, hooks, how layers load, `/setup` questions or output, MCP wiring, install steps, counts), update the site in the same piece of work and open a PR there too. Pure internals (CI scripts, eval fixtures, typo fixes in layer detail files) need no site change.

| Site file | Mirrors (plugin source of truth) |
|---|---|
| `src/data/docsData.ts` | commands (`skills/*/SKILL.md`), agents (`agents/*.md`), hooks (`hooks/hooks.json`, `hooks/scripts/`), glossary counts, version (`.claude-plugin/plugin.json`) |
| `src/data/pickerData.ts` | `/setup` questions and `.mcp.json` output (`skills/setup/SKILL.md`, `setup/stack.schema.json`), layer list |
| `src/sections/McpSection.tsx` | MCP servers and packages `/setup` writes |
| `src/sections/SubAgents.tsx`, `src/components/Picker.tsx`, `src/sections/Skills.tsx` | how layers load (`hooks/scripts/layer_autoload.py`) |
| `src/sections/Hero.tsx`, `HowItWorks.tsx`, `Install.tsx` | headline counts: commands, hooks, layers, evals, `/setup` questions |
| `src/sections/LayerCatalog.tsx` | layer categories under `layers/` |

Build the site (`npm ci && npm run build`) before pushing.

## Modifying this plugin

- Commit prefix: `chore(evolve):` or `chore(plugin):`
- Run `/evolve` at sprint end for evidence-based improvement recommendations
- To add a new layer: create `layers/<category>/<tech>/SKILL.md` with `stack:` frontmatter
- See `docs/ROADMAP.md` → "Contributing a new layer" for the full guide
