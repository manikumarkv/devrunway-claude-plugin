---
name: pipeline
description: CI/CD pipeline standards — GitHub Actions workflows, branch protection, required checks, deployment gates. Load when creating or reviewing pipeline configuration.
user-invocable: false
---

Full standards in [pipeline.md](pipeline.md). Always-on summary:

**Branch strategy:**
- `main` → production only, protected, no direct push
- `develop` → staging, protected, all PRs merge here first
- `feature/<ticket>-<slug>` → individual features
- `fix/<ticket>-<slug>` → bug fixes

**Required checks before merge:**
1. TypeScript — `tsc --noEmit` passes
2. Lint — `eslint .` zero errors
3. Unit tests — all pass, coverage ≥ 80%
4. Build — `npm run build` succeeds

**Deployment gates:**
- `develop` merge → auto-deploy to staging
- `main` merge → auto-deploy to production (after manual approval)
- Never deploy from a feature branch directly

**Never:**
- Push directly to `main` or `develop`
- Merge a PR with failing checks
- Deploy without running tests
- Store secrets in workflow files — use GitHub Secrets
