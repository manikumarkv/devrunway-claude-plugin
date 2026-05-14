---
name: gitlab-ci
description: GitLab CI/CD conventions — .gitlab-ci.yml structure, stages, rules, caching, artifacts, and environment deployments. Load when working with .gitlab-ci.yml.
user-invocable: false
stack: ci/gitlab-ci
paths:
  - ".gitlab-ci.yml"
  - ".gitlab/**"
---

Full standards in [gitlab-ci.md](gitlab-ci.md). Always-on summary:

**Pipeline structure:**
- Define `stages` explicitly — order matters; jobs in the same stage run in parallel
- Standard stages: `validate` → `test` → `build` → `deploy`
- Use `rules` not `only`/`except` — `rules` is more expressive and GitLab's recommended approach

**Caching:**
- Cache `node_modules`, `.venv`, or build cache between jobs — speeds up pipeline by 2-5×
- Cache key must include the lockfile hash: `key: files: [package-lock.json]`
- Don't cache `dist/` or build artifacts — use GitLab Artifacts for those

**Artifacts:**
- Upload test results and coverage reports as artifacts with `expire_in`
- Artifacts are passed between stages — use to pass build output to deploy stage
- JUnit reports go in `reports: junit` — GitLab shows pass/fail in the MR

**Variables:**
- Project-level CI/CD variables for secrets (Settings → CI/CD → Variables)
- Mark secrets as `Masked` and `Protected` (only available on protected branches)
- Never put secrets in `.gitlab-ci.yml` — they appear in job logs

**Never:**
- `only: master` — use `rules: if: '$CI_COMMIT_BRANCH == "main"'` instead
- Skip `needs:` for jobs that depend on earlier stage artifacts — specify dependencies explicitly
- Use a pipeline without a `validate` or `lint` stage — catch errors before running tests

**Related skills:** Your package manager layer (install command), `container/docker` (building images in CI)
