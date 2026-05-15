# Hooks Catalog

A catalog of safety, quality, and productivity hooks proposed for the plugin. Hooks attach to Claude Code events (`PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`, `SubagentStop`, `PreCompact`) and run as shell scripts.

**Selection model:** mirror the layer system. `/setup` adds a final screen asking which hook bundles the user wants (security, quality, frontend, backend, etc.). Each bundle installs its scripts under `hooks/scripts/` and registers them in `hooks/hooks.json`.

**Legend:** ✅ already shipped · 🆕 proposed new

---

## 1. Safety / Guard hooks (PreToolUse → block on risk)

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ destructive-git-guard | Bash | Blocks `push --force`, `reset --hard`, `branch -D`, `clean -fd` | All |
| ✅ destructive-rm-guard | Bash | Blocks `rm -rf` outside the project tree and on suspicious paths (`~`, `/`, env-resolved roots) | All |
| ✅ secrets-leak-guard | Write/Edit | Scans content for AWS keys, JWTs, Stripe keys, GitHub PATs, private keys — blocks the save | All |
| 🆕 env-file-write-guard | Write/Edit | Blocks accidental writes to `.env*` files; requires explicit `--allow-env-write` flag in user prompt | All |
| 🆕 prod-config-guard | Write/Edit | Warns + requires confirmation when editing files matching `*.prod.*`, `production.*`, `terraform/prod/**` | All |
| 🆕 migration-run-guard | Bash | Blocks `prisma migrate deploy` / `rails db:migrate` against non-localhost DATABASE_URL without explicit ack | Backend / DB stacks |
| 🆕 dependency-install-guard | Bash | Intercepts `npm/pnpm/yarn install <new-pkg>` — shows package name, weekly downloads, last-publish date before allowing | Node stacks |
| 🆕 force-deploy-guard | Bash | Blocks `vercel --prod`, `firebase deploy --only hosting:prod` etc. unless current branch is `main` and clean | Container/cloud stacks |
| 🆕 large-file-commit-guard | Bash (git add) | Blocks adding files >10MB (configurable) — protects repo size | All |

---

## 2. Code quality / lint (PostToolUse: Write|Edit)

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ tsc-check | Write/Edit (`*.ts`, `*.tsx`) | Runs `tsc --noEmit`, reports first 20 errors | TypeScript |
| ✅ console-guard | Write/Edit | Flags new `console.log` / `debugger` statements | All |
| ✅ eslint-on-save | Write/Edit (`*.ts`, `*.tsx`, `*.js`) | Runs `eslint --quiet` on the touched file only | TypeScript/JS |
| ✅ prettier-check | Write/Edit | Runs `prettier --check`; offers `--write` fix | All web |
| ✅ ruff-check | Write/Edit (`*.py`) | Runs `ruff check` on changed file | Python |
| ✅ black-format-check | Write/Edit (`*.py`) | Runs `black --check`; offers reformat | Python |
| ✅ mypy-check | Write/Edit (`*.py`) | Runs `mypy` on changed file | Python |
| ✅ gofmt-check | Write/Edit (`*.go`) | Runs `gofmt -l`; flags unformatted | Go |
| ✅ go-vet-check | Write/Edit (`*.go`) | Runs `go vet ./...` on the package | Go |
| 🆕 rustfmt-check | Write/Edit (`*.rs`) | Runs `cargo fmt -- --check` | Rust |
| 🆕 clippy-check | Write/Edit (`*.rs`) | Runs `cargo clippy --quiet -- -D warnings` | Rust |
| ✅ shellcheck | Write/Edit (`*.sh`) | Runs `shellcheck` on the file | Shell scripts |
| ✅ markdownlint | Write/Edit (`*.md`) | Runs `markdownlint` against project config | Docs |
| ✅ yaml-lint | Write/Edit (`*.yml`, `*.yaml`) | Runs `yamllint`; catches indentation/anchor errors | All |
| 🆕 sql-lint | Write/Edit (`*.sql`) | Runs `sqlfluff lint`; flags style violations | SQL |
| 🆕 terraform-fmt-check | Write/Edit (`*.tf`) | Runs `terraform fmt -check` | Terraform |
| 🆕 todo-tracker | Write/Edit | Counts new `TODO`/`FIXME`/`HACK` comments; prompts to file an issue | All |

---

## 3. Test & verification

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ focused-test-runner | PostToolUse Write/Edit | Detects which test file covers the edited source and runs only that test | All test stacks |
| 🆕 coverage-floor | Stop | Reads coverage report; warns if a touched file dropped below threshold (e.g. 80%) | All test stacks |
| 🆕 broken-import-check | PostToolUse Write/Edit | Greps for imports of the renamed/deleted symbol elsewhere in the repo | TS/Python |
| 🆕 circular-import-check | PostToolUse Write/Edit | Runs `madge --circular src/` after edits to import paths | TypeScript |
| 🆕 unused-export-check | Stop | Runs `ts-prune` or `knip`; warns about new orphan exports | TypeScript |
| 🆕 snapshot-change-warn | PostToolUse Write/Edit | Flags edits to `__snapshots__/` directories — usually a smell unless tests were rerun | Vitest/Jest |

---

## 4. Frontend / React

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ accessibility-lint | PostToolUse Write/Edit (`*.tsx`) | Runs `eslint-plugin-jsx-a11y` rules on the file | React |
| 🆕 bundle-size-budget | Stop | Runs `size-limit` or `bundlewatch`; flags pages over budget | React/Next |
| ✅ react-key-check | PostToolUse Write/Edit | Greps for `.map(... => <` without a `key=` prop | React |
| ✅ useEffect-deps-check | PostToolUse Write/Edit | ESLint exhaustive-deps run on changed file | React |
| 🆕 hardcoded-color-check | PostToolUse Write/Edit (`*.tsx`, `*.css`) | Flags hex colors outside the theme/tailwind config | Design-systems |
| 🆕 localhost-url-guard | PostToolUse Write/Edit | Flags hardcoded `http://localhost` in non-config files | Frontend |
| 🆕 i18n-missing-key | PostToolUse Write/Edit | Detects user-visible strings not wrapped in `t(...)` | i18n stacks |

---

## 5. Backend / API

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ auth-on-route-check | PostToolUse Write/Edit (`routes/**`, `controllers/**`) | Greps new route handlers — warns if no `requireAuth`/auth middleware | All backends |
| ✅ rate-limit-check | PostToolUse Write/Edit | Flags new public endpoint without rate-limit middleware | All backends |
| 🆕 openapi-sync-check | PostToolUse Write/Edit | When a route changes, checks `openapi.yaml`/`swagger.json` was also touched | REST stacks |
| 🆕 env-var-documented | PostToolUse Write/Edit | Detects new `process.env.X` reference; checks `.env.example` was updated | Node/Python |
| 🆕 error-handler-wrapper | PostToolUse Write/Edit | Flags async route handler missing `asyncHandler` wrapping or try/catch | Express |
| ✅ input-validation-check | PostToolUse Write/Edit | Flags new `req.body`/`req.query` access without preceding Zod/Yup `.parse()` | API + Zod/Yup |
| 🆕 n-plus-one-warn | PostToolUse Write/Edit | Flags `await` inside `.map`/`forEach` over DB results (likely N+1) | ORM stacks |

---

## 6. Database

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ no-select-star | PostToolUse Write/Edit (`*.sql`, ORM files) | Flags `SELECT *` outside of explicit-allowlist views | All DB |
| ✅ migration-down-required | PostToolUse Write (`migrations/**`) | Blocks/warns if new migration has no down/rollback path | All DB |
| 🆕 migration-naming-convention | PostToolUse Write | Enforces `YYYYMMDD_HHMMSS_snake_case.sql` (or framework convention) | All DB |
| 🆕 index-on-fk | PostToolUse Write | Detects new FK columns without an index | Postgres/MySQL |
| 🆕 prisma-generate-trigger | PostToolUse Write (`schema.prisma`) | Auto-runs `prisma generate` after schema edits | Prisma |
| 🆕 mongo-no-find-without-filter | PostToolUse Write/Edit | Flags `.find({})` / `.find()` without a filter | MongoDB |

---

## 7. Security

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| 🆕 secrets-scan-full | UserPromptSubmit | Runs `gitleaks detect` against the repo on session start; flags hits | All |
| ✅ sql-injection-pattern | PostToolUse Write/Edit | Flags string-concatenated SQL (`"SELECT ... " + var`) | All backends |
| ✅ xss-dangerous-html | PostToolUse Write/Edit | Flags `dangerouslySetInnerHTML` / `v-html` / `innerHTML =` introductions | Frontend |
| 🆕 eval-usage-block | PreToolUse Write | Blocks edits that introduce `eval(`, `new Function(`, `setTimeout("...")` | All |
| 🆕 crypto-deprecation-warn | PostToolUse Write/Edit | Flags `md5`, `sha1`, `Math.random()` for crypto, deprecated TLS | All |
| 🆕 npm-audit-on-install | PostToolUse Bash (`npm install`) | Runs `npm audit --audit-level=high` after install | Node |
| 🆕 license-check | PostToolUse Bash (`npm install`) | Blocks adding GPL-licensed deps in proprietary repos (configurable) | Node |
| ✅ pii-in-logs-warn | PostToolUse Write/Edit | Flags `logger.info(...)` calls with variables named `email`, `password`, `ssn`, etc. | All logging |
| 🆕 cors-permissive-warn | PostToolUse Write/Edit | Flags `cors({ origin: '*' })` and `Access-Control-Allow-Origin: *` introductions | All backends |

---

## 8. Git workflow

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ conventional-commit-check | PreToolUse Bash (`git commit`) | Validates commit message format `type(scope): subject` | All |
| 🆕 branch-naming-check | PreToolUse Bash (`git checkout -b`, `git switch -c`) | Enforces `feat/`, `fix/`, `chore/` prefixes with ticket numbers | All |
| ✅ no-commit-to-main | PreToolUse Bash (`git commit`) | Blocks commits to `main`/`master`/`develop` directly | All |
| 🆕 binary-file-commit-warn | PreToolUse Bash (`git add`) | Warns when adding binary files (images >1MB, archives, executables) | All |
| 🆕 gitignore-coverage | PostToolUse Write | Detects newly-created file types that should be gitignored (`.env`, `dist/`, `*.log`) | All |
| 🆕 commit-signing-check | PreToolUse Bash (`git commit`) | Warns if signing is not configured when policy requires it | All |

---

## 9. CI / Deploy

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ dockerfile-best-practices | PostToolUse Write/Edit (`Dockerfile`) | Flags `FROM *:latest`, root user, `ADD` instead of `COPY`, missing `HEALTHCHECK` | Docker |
| ✅ k8s-manifest-validate | PostToolUse Write/Edit (`*.yaml` in `k8s/`) | Runs `kubeval` / `kubeconform` | Kubernetes |
| 🆕 ci-syntax-check | PostToolUse Write/Edit (`.github/workflows/*.yml`) | Runs `actionlint` | GitHub Actions |
| 🆕 terraform-plan-warn | PostToolUse Write/Edit (`*.tf`) | Reminds to run `terraform plan` before commit; flags untracked state file | Terraform |
| 🆕 env-parity-check | PostToolUse Write/Edit (`.env.example`) | Compares with `.env.development`, `.env.staging` — flags drift | All |

---

## 10. Documentation

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| 🆕 adr-prompt-on-arch-change | PostToolUse Write/Edit (`src/architecture/**`, `infrastructure/**`) | Prompts: "this looks architectural — log an ADR via /adr?" | All |
| 🆕 readme-sync-on-cli | PostToolUse Write/Edit (CLI flag definitions) | When CLI flags change, prompts to update README usage block | CLI projects |
| 🆕 changelog-required | PreToolUse Bash (`git commit`) | Warns if user-facing change has no `CHANGELOG.md` entry | Released projects |
| ✅ confluence-ref-check | UserPromptSubmit | If prompt mentions "spec" / "RFC" / "design doc", surfaces matching Confluence/Notion pages via MCP | Confluence/Notion |

---

## 11. Productivity / DX

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| ✅ session-summary | Stop | Prints branch status, uncommitted changes at session end | All |
| ✅ todo-to-issue | PostToolUse Write/Edit | When a `TODO(ticket):` comment is added, offers to create the matching issue | GitHub/Jira/Linear |
| ✅ ticket-status-sync | PostToolUse Bash (`git commit`) | Parses ticket key from message; moves Jira/Linear ticket to "In progress" | Jira/Linear/GitLab |
| 🆕 jira-key-in-branch | PostToolUse Bash (`git checkout -b`) | Auto-prepends Jira ticket key to branch name based on current ticket | Jira |
| 🆕 focused-tests-only | PostToolUse Write/Edit | Suggests `vitest related <file>` command for fast feedback | Vitest |
| 🆕 diff-size-warn | PreToolUse Bash (`git commit`) | Warns when commit diff exceeds N lines (default 400) — encourages smaller commits | All |
| 🆕 stale-branch-warn | UserPromptSubmit | If current branch is >7 days behind main, warns at session start | All |

---

## 12. Cost / Performance

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| 🆕 npm-install-size-warn | PreToolUse Bash (`npm install <pkg>`) | Looks up package size; blocks if >1MB minified without ack | Node |
| 🆕 aws-cost-spike-guard | PostToolUse Write/Edit (`terraform/**`) | Flags instance-type upgrades (`t3.large → m5.4xlarge`) | AWS/Terraform |
| 🆕 expensive-query-warn | PostToolUse Write/Edit | Flags queries without LIMIT, full scans on indexed tables | SQL |
| 🆕 bundle-size-diff | Stop | After build, diffs bundle against last `main` build; flags >10% growth | Frontend |

---

## 13. Compliance / Governance

| Hook | Trigger | What it does | Applies to |
|---|---|---|---|
| 🆕 license-header-required | PostToolUse Write (new files) | Adds the project's standard license header if missing | Commercial repos |
| 🆕 pii-tag-enforce | PostToolUse Write/Edit (`*.schema.ts`, `models/**`) | Flags new PII-looking fields (`email`, `phone`, `ssn`) without `@pii` tag | GDPR-bound projects |
| 🆕 audit-log-required | PostToolUse Write/Edit (`services/**`) | Flags new mutating service methods without `auditLog(...)` call | Regulated industries |

---

## How the user picks them — selection model

`/setup` adds a final screen:

```
38. Hook bundles (multi-select — type comma-separated keys or "all" / "none")

  Safety bundle           (destructive-rm, secrets-leak, env-file, prod-config, large-file)
  Quality bundle          (eslint, prettier + language linters for selected backends)
  Test bundle             (focused-test-runner, coverage-floor, broken-import)
  Frontend bundle         (a11y, react-key, useEffect-deps, bundle-size) — auto-selected if frontend layer installed
  Backend bundle          (auth-on-route, rate-limit, openapi-sync, env-var-documented)
  Database bundle         (no-select-star, migration-down, prisma-generate)
  Security bundle         (secrets-scan, sql-injection, xss, npm-audit, pii-in-logs, cors-permissive)
  Git workflow bundle     (conventional-commit, branch-naming, no-commit-to-main)
  CI/Deploy bundle        (dockerfile, k8s-validate, ci-syntax, terraform-plan)
  Docs bundle             (adr-prompt, readme-sync, changelog-required)
  Productivity bundle     (todo-to-issue, ticket-status-sync, session-summary)
  Compliance bundle       (license-header, pii-tag, audit-log)
```

`/setup` writes the selected hook scripts to `hooks/scripts/` and registers them in `hooks/hooks.json` with the right matchers — exactly the way layer skills are installed today. Users can later run `/install hook <name>` or `/uninstall hook <name>` to manage individual hooks.

---

## Implementation priority

If we ship in phases, I'd suggest:

**Phase 1 — core safety + quality (highest ROI, lowest risk):**
1. destructive-rm-guard
2. secrets-leak-guard
3. eslint-on-save (TypeScript projects)
4. prettier-check
5. focused-test-runner
6. conventional-commit-check
7. no-commit-to-main

**Phase 2 — language-specific quality:**
8. ruff-check, black-format-check, mypy-check (Python)
9. gofmt-check, go-vet-check (Go)
10. shellcheck, yaml-lint, markdownlint

**Phase 3 — security + DB:**
11. sql-injection-pattern
12. xss-dangerous-html
13. pii-in-logs-warn
14. no-select-star
15. migration-down-required

**Phase 4 — stack-aware:**
16. auth-on-route-check, rate-limit-check, input-validation-check (backend)
17. accessibility-lint, react-key-check, useEffect-deps-check (frontend)
18. dockerfile-best-practices, k8s-manifest-validate (deploy)

**Phase 5 — productivity:**
19. todo-to-issue, ticket-status-sync (with Jira/Linear/GitHub Issues)
20. confluence-ref-check (Confluence/Notion lookup)

---

## Implementation notes

- All hooks read input via `jq` from the JSON Claude Code passes on stdin
- All hooks emit `{"continue": false, "stopReason": "..."}` to block, or `{"continue": true}` to allow
- For `PostToolUse` hooks, emitting `{"continue": true, "decision": "block", "reason": "..."}` lets Claude see the warning and react
- Heavy hooks (linters, type-checkers) should be runnable in `async: true` mode so they don't slow the loop
- Each hook script must be idempotent — Claude may retry the same Write/Edit if the hook prompts a fix
- The selection model mirrors layers: hooks live in `hooks/<bundle>/<hook>.sh`, registered via `hooks/<bundle>/hook.json` partials that `/setup` concatenates into the final `hooks/hooks.json`
