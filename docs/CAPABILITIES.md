# devrunway — Plugin Capabilities

A capability brief intended as input for a website-design AI tool.

---

## One-line description

A Claude Code plugin that turns Claude into a stack-aware, standards-enforcing engineering teammate — covering the full software lifecycle from product brainstorm to production deploy, for any technology stack.

## Tagline candidates

- **"Production-ready code, on rails — for your exact stack."**
- **"A self-validating SDLC plugin for Claude Code."**
- **"Pick your stack. Get a senior engineer who knows it cold."**

---

## Who it's for

- Solo developers and small teams who want senior-engineer-grade rigor without writing their own conventions doc
- Engineering leads who want every contributor (human or AI) producing code that conforms to the same standards
- Agencies and consultancies juggling many tech stacks — switch projects, reload the right standards automatically
- Anyone building production software with AI assistance who's tired of generated code that "works" but doesn't follow the team's rules

---

## The five capability pillars

### 1. Full SDLC, end to end

One coherent workflow from idea to production. Each step is a slash command that produces a tracked artifact (markdown doc, GitHub issue, PR) the next step picks up.

```
/product-brainstorm  →  /product-plan  →  /product-tasks  →  /product-refine
                                                              ↓
/dev-brainstorm  →  /dev-design  →  /dev-code  →  /dev-review  →  /pr create
                                                              ↓
                                  /deploy staging  →  /validate  →  /deploy prod
```

Plus utility commands: `/branch`, `/task`, `/release`, `/security-review`, `/debug`, `/setup`, `/eval`, `/forge`, `/evolve`.

### 2. Stack configuration that adapts to *your* tools

`/setup` is a one-time wizard (35 questions across 6 screens) that asks what frontend, backend, database, auth, cloud, CI, etc. you use. It outputs:

- `stack.json` — your declared stack
- `.mcp.json` — MCP servers pre-wired for your tools (Figma, GitHub, Jira, Stripe, Sentry, ...)
- Install commands for the matching layer plugins

Result: Claude knows your stack on day one. No prompt engineering required.

### 3. 135 technology layers across 35 categories

Each layer is a self-contained skill bundle with code examples, "always do this / never do that" rules, and a test suite. Layers cover:

| Category | Example technologies |
|---|---|
| Frontend | React, Vue, Angular, Next.js |
| CSS / UI | Tailwind, styled-components, shadcn, MUI, Chakra |
| State | Zustand, Redux Toolkit, Jotai, Pinia |
| Backend | Node/Express, Python/FastAPI, Django, .NET |
| API style | REST, GraphQL, tRPC, gRPC |
| Validation | Zod, Yup, Valibot, Joi |
| Database | Postgres+Prisma, MongoDB, DynamoDB, SQLAlchemy |
| Auth | Cognito, Firebase, Auth0, Azure AD |
| Cloud | AWS, GCP, Azure |
| Logging | Pino, Winston, Morgan, Datadog, CloudWatch, Sentry |
| Testing | Vitest, Jest, Pytest, Playwright, Cypress, MSW |
| Payment | Stripe, PayPal, Braintree |
| Source control | GitHub, GitLab, Bitbucket, Azure DevOps |
| CI | GitHub Actions, GitLab CI, CircleCI, Azure Pipelines |
| Ticket management | GitHub Issues, Jira, GitLab Issues, Linear, Huly |
| Documentation | Confluence, Notion |
| ...and 20 more categories |

Layers auto-load based on the files you're touching — edit a `.tsx` file, the React layer's rules apply; edit a `.schema.ts` file, the Zod layer applies.

### 4. The eval harness — generated code that's **verified**, not just generated

This is the differentiator. Every layer ships with `.eval.yaml` test cases — concrete assertions like "code must contain `.safeParse(`" or "code must not contain `req.body.email`". These define what "correct code" means for that technology.

- **`/eval`** — runs the test suite for one skill, a category, or all 93 eval files
- **`/forge`** — automated TDD loop. Either patches a failing skill until its evals pass, or generates a brand-new skill from scratch with verified eval coverage. Never removes content; max 3 iterations per fix
- Output: tracked eval reports under `docs/evals/`

Net effect: the plugin's own standards are continuously validated. Same harness can validate generated code in your projects.

### 5. Stack-aware sub-agent architecture (context efficiency)

Heavy commands (`/dev-code`, `/dev-design`, `/eval`, `/forge`, `/dev-review`, `/security-review`) run in their own forked context windows. Within them, a `stack-dispatcher` agent:

- Scans `layers/` on disk to discover which technology layers are installed
- Matches each layer's path-glob patterns against the files being worked on
- Fans out to `layer-consultant` sub-agents in parallel
- Returns a concentrated rule set (≤300 lines) drawn only from the layers that apply right now

Result: your main conversation carries a few hundred tokens of rules instead of tens of thousands. Sessions stay coherent far longer before compaction.

---

## Built-in code review

Two review agents, both invoked before opening a PR:

| Command | Agent | What it checks |
|---|---|---|
| `/dev-review` | `code-reviewer` | TypeScript strictness, error handling, tests, accessibility, logging, API conventions |
| `/security-review` | `security-reviewer` | OWASP Top 10, secret detection, auth flows, IAM least-privilege, PII in logs |

Both produce tracked `REVIEW-<branch>.md` files. User picks which findings to fix; the agent applies them.

---

## Safety hooks

| Hook | Trigger | What it does |
|---|---|---|
| `destructive-git-guard` | Before any `git` command | Blocks `push --force`, `reset --hard`, `branch -D`, `rm -rf` |
| `tsc-check` | After Write/Edit | Type-checks TypeScript on save; flags errors |
| `console-guard` | After Write/Edit | Flags stray `console.log()` and `debugger` statements |
| `session-summary` | Session end | Prints branch status and uncommitted changes |

---

## MCP integrations (pre-wired)

`/setup` generates `.mcp.json` with servers for every tool in your stack. Currently wired (26 servers):

GitHub · GitLab · Bitbucket · Azure DevOps · Jira · Linear · Huly · Confluence · Notion · Figma · Sketch · Stripe · PayPal · Resend · SendGrid · Sentry · Datadog APM · Bugsnag · CloudWatch · Grafana Loki · Algolia · Elasticsearch · Typesense · Playwright · LaunchDarkly · PostHog · AWS AppConfig · Vault

---

## Quality numbers

- **135 layers** across 35 categories — full-stack coverage
- **93 eval files** with hundreds of assertion-based test cases
- **5 review agents** (code, security, debug, eval-runner, skill-forge)
- **4 active safety hooks**
- **26 pre-wired MCP integrations**

---

## What makes it different

1. **Stack-aware, not generic.** Most AI coding assistants give you their model's average opinion. This plugin gives you *your* stack's specific conventions.
2. **Verified, not just generated.** The eval harness is the quality gate — code is checked against assertion-based test cases, not vibes.
3. **Self-improving.** The forge loop fixes failing skills automatically. As you discover edge cases, you encode them as eval cases and the system keeps itself honest.
4. **Context-efficient at scale.** Sub-agent architecture means a 10-layer stack doesn't burn your context window. You can run long sessions without compaction destroying coherence.
5. **Open, not locked-in.** Layers are plain markdown + YAML. You can author your own, override a public layer with a company-specific one, share them via git.

---

## Suggested website sections (for the design tool)

1. **Hero** — tagline + one-liner + "Install" CTA
2. **The problem** — "AI code that works but doesn't follow your team's rules"
3. **How it works** — `/setup` → declare stack → standards auto-apply → verified output (3-step diagram)
4. **The 135 layers** — searchable/filterable grid by category
5. **The eval harness** — animated example of `must_contain` assertions catching a bug
6. **SDLC flow** — vertical timeline from `/product-brainstorm` to `/deploy prod`
7. **Sub-agent architecture** — small diagram showing main thread + dispatcher + consultants
8. **Safety** — hooks + reviewers + destructive-git-guard
9. **Integrations** — logos of the 26 MCP-wired tools
10. **For whom** — three personas: solo dev / engineering lead / agency
11. **Install** — copy-paste command + link to /setup walkthrough
12. **Footer** — GitHub, docs, roadmap

---

## Visual language suggestions

- **Color palette:** technical but warm — deep slate background, single accent color (electric green or cyan) for emphasis. Avoid generic "AI startup purple gradient"
- **Typography:** monospace for command names and code (JetBrains Mono / Berkeley Mono), clean sans for prose (Inter / Geist)
- **Imagery:** terminal output, file trees, eval pass/fail tables — not abstract AI brain illustrations
- **Tone:** confident and specific. The plugin earns trust by being precise — the website should mirror that
