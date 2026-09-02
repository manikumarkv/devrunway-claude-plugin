# Neon Branching in CI

A Neon branch is a copy-on-write clone of the database — schema, data, and history — created in seconds. That makes an isolated database per pull request or per test run practical, which in turn makes migration testing meaningful for the first time.

It also makes it trivially easy to create branches faster than you delete them. Most of this document is about lifecycle.

**Scope boundaries.** This layer holds the CI rules. For the branch-type decision tree, full CLI reference, and console/API equivalents, use the official `neon-postgres-branches` skill. For connection strings, driver choice, and migration mechanics see the `neon` layer. For workflow structure, job dependencies, and branch protection see your CI platform layer.

---

## 1. Choosing the branch type

| Type | Use for | Created with |
|---|---|---|
| Normal | Migration validation, integration tests, preview environments | `neon branches create --parent <parent>` |
| Schema-only | Any workflow where the parent holds PII or is subject to a compliance constraint | `neon branches create --parent <parent> --schema-only` |

**Default to a normal branch for migration validation.** The whole value of testing a migration against a branch is that it carries real row shapes, real volumes, and real edge cases. A migration that passes against an empty schema tells you the SQL parses, not that it works.

**Schema-only branches are independent root branches.** They have no parent and no shared history. Two consequences that break CI flows if you don't know them:

- `neon branches reset --parent` **does not apply** to a schema-only branch. A pipeline built around reset-from-parent silently breaks the day someone switches the branch type for privacy reasons.
- They do not track the parent's later schema changes. A long-lived schema-only dev branch drifts and has to be recreated, not reset.

If production holds PII and you still need real data shapes, derive CI branches from an anonymised branch rather than reaching for schema-only. See `data-governance`.

---

## 2. Branch-per-PR lifecycle

```yaml
# .github/workflows/pr-database.yml
name: PR database branch

on:
  pull_request:
    types: [opened, reopened, synchronize, closed]

jobs:
  create:
    if: github.event.action != 'closed'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create or reuse the PR branch
        env:
          NEON_API_KEY: ${{ secrets.NEON_API_KEY }}
        run: |
          npx neonctl branches create \
            --name "preview/pr-${{ github.event.number }}" \
            --parent main \
            --expires-at "$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ)" \
            || echo "branch already exists — reusing"

  cleanup:
    if: github.event.action == 'closed'
    runs-on: ubuntu-latest
    steps:
      - name: Delete the PR branch
        if: always()
        env:
          NEON_API_KEY: ${{ secrets.NEON_API_KEY }}
        run: npx neonctl branches delete "preview/pr-${{ github.event.number }}" || true
```

**Rules:**

- **Delete on merge *and* on close-without-merge.** In GitHub Actions both arrive as `pull_request: closed`, so one handler covers both — but a workflow keyed on `merged == true` covers only half. Abandoned PRs are the ones that leak.
- **Name deterministically from the PR number** — `preview/pr-1234`. A re-run then reuses the existing branch instead of creating `preview/pr-1234-2`. Tolerate the "already exists" error rather than failing the job.
- **Cleanup runs `if: always()`** so a failed test job still releases the branch.
- **Never run branch creation on `pull_request_target`** for fork PRs — see §5.

---

## 3. Expiry is the backstop, and it is not optional

**Set `--expires-at` on every branch you create in CI, even when you have a delete step.**

A delete step does not run when:

- the job is cancelled (a new push supersedes the run, or someone hits cancel)
- the runner is evicted or the job times out
- the workflow file is edited and the cleanup job is renamed while PRs are open
- the PR is closed while CI is disabled or the workflow is failing for an unrelated reason

Every one of those leaves a branch behind, and nothing else cleans it up. Orphaned CI branches are the most common source of an unexpected Neon bill — not query volume, not compute size.

Prefer declaring the lifetime once, declaratively, over repeating `--expires-at` at each call site:

```ts
// neon.ts — TTL and compute profile live in version control
export default defineConfig({
  branch: (b) => ({
    ttl: b.name.startsWith('preview/') ? '7d' : undefined,
    protected: b.isDefault,
  }),
})
```

A per-command flag is forgotten in the one workflow nobody reviewed. A rule in `neon.ts` applies to every branch the project creates.

---

## 4. Branch-per-test-run

- Create an ephemeral branch at pipeline start, delete it at the end. Name it from the run ID, not the branch name, so concurrent runs on the same git branch do not collide.
- **Never share one database across parallel test jobs.** Shared test state produces failures that depend on job scheduling — they pass on re-run, so they get marked flaky and ignored, and they are the hardest class of CI failure to diagnose.
- Do not disable scale-to-zero on CI branches. They are idle almost all the time; suspension is the behaviour you want.
- Prefer creating from a small seeded parent rather than from production when the tests do not need production volume — branch creation is fast either way, but a smaller parent keeps storage and egress down.

---

## 5. Secrets and fork pull requests

- `NEON_API_KEY` comes from CI secrets. Never inline in workflow YAML, never in a committed `.env`.
- **Mask the branch connection string.** It contains a password. Never `echo` it, never pass it as a plain job output, never print it in a debug step.

```yaml
# ✅ register the value as a secret with the runner before using it
- run: |
    URL=$(npx neonctl connection-string "preview/pr-${{ github.event.number }}" --pooled)
    echo "::add-mask::$URL"
    echo "DATABASE_URL=$URL" >> "$GITHUB_ENV"
```

- **Fork PRs must not receive the API key.** `pull_request` does not expose secrets to forks, which is the safe default. `pull_request_target` runs in the base repository's context *with* secrets and checks out untrusted code — using it to create Neon branches hands a fork author your database API key. If preview branches for fork PRs are genuinely required, gate them behind a manual approval environment.
- Scope the API key to the single project it needs. See `secret-scanning`.

---

## 6. Migration gating

Run migrations against the PR's own branch, on the **unpooled** connection string, before the PR is allowed to merge:

```yaml
- name: Apply migrations to the PR branch
  env:
    DATABASE_URL_UNPOOLED: ${{ env.DATABASE_URL_UNPOOLED }}
  run: DATABASE_URL=$DATABASE_URL_UNPOOLED npx prisma migrate deploy
```

- **The parent must be production, or a branch of it.** A migration validated against an empty database does not exercise the failure modes that matter: a backfill that times out at real row counts, a `NOT NULL` added to a column with existing nulls, an index build that locks a large table.
- **A failed migration fails the PR.** It is not a warning — it is the check that stands between the migration and production.
- See the `neon` layer for why the unpooled string is mandatory: a pooled migration fails intermittently rather than cleanly.
- For destructive changes, verify the expand/contract sequence on the branch, not just the forward migration.

---

## Avoid

| Avoid | Why it costs you | Instead |
|---|---|---|
| Relying on a delete step with no expiry | Cancelled jobs and dead runners skip cleanup entirely; nothing else reclaims the branch | `--expires-at` or `ttl` in `neon.ts` as a backstop |
| Cleanup keyed on `merged == true` | Abandoned PRs never merge, so their branches are never deleted | Handle `closed`, which covers both outcomes |
| Cleanup without `if: always()` | A failed test job leaves its branch behind — exactly when you create the most branches | `if: always()` on the cleanup step |
| Non-deterministic branch names | Every re-run creates another branch for the same PR | Derive the name from the PR number |
| Creating fork-PR branches via `pull_request_target` | Runs untrusted code with your secrets in scope; leaks the Neon API key | `pull_request`, or a manually approved environment |
| `echo`ing a connection string for debugging | The password lands in job logs, which are readable by anyone with repository access and are retained | `::add-mask::` before any use |
| Validating migrations against an empty database | Passes for migrations that will time out or fail on real data | Branch from production |
| One shared CI database across parallel jobs | Order-dependent failures that pass on re-run and get dismissed as flake | One ephemeral branch per run |
| Designing a pipeline around `reset --parent` for schema-only branches | Schema-only branches are root branches — reset does not apply, so the flow breaks when the type changes | Recreate the branch instead of resetting |
| Disabling scale-to-zero on CI branches | Bills continuous compute for a database that is idle between runs | Leave suspension enabled |

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Branch created in CI but the workflow has no cleanup job at all | Add cleanup on `closed` plus an expiry. Every created branch needs a defined end. |
| `--expires-at` computed once and hardcoded as a literal date | It silently stops expiring anything after that date passes. Compute it relative to now, or use `ttl` in `neon.ts`. |
| `neon branches delete` failing the pipeline when the branch is already gone | Tolerate the error (`|| true`). A cleanup step should be idempotent. |
| Reusing the production branch for PR previews to "save cost" | Preview traffic mutating production is not a cost saving. Branch it. |
| Reset-from-parent blocked and nobody knows why | Reset is blocked while the target has children, and is unavailable for up to 24h after the parent is restored from a snapshot. Delete children first. |
| Migrations applied to the preview branch only after the app deploys against it | Migrate first, then deploy. The reverse gives you a preview running against a schema it does not expect. |
| Test suite pointed at a long-lived shared "ci" branch | One branch per run. A shared branch accumulates state and couples unrelated pipelines. |
| API key with account-wide scope stored in a public repository's secrets | Scope the key to one project, and never expose secrets to fork workflows. |
