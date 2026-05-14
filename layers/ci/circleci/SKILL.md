---
name: circleci
description: CircleCI conventions — config.yml structure, orbs, workflows, caching, workspaces, and environment variables. Load when working with .circleci/config.yml.
user-invocable: false
stack: ci/circleci
paths:
  - ".circleci/config.yml"
  - ".circleci/**"
---

Full standards in [circleci.md](circleci.md). Always-on summary:

**Config structure:**
- Use `version: 2.1` — enables orbs, commands, and executors
- Define reusable `executors` for consistent runtime environments
- Use `orbs` for standard integrations (node, aws-cli, docker) — don't reinvent them

**Jobs and workflows:**
- `workflows` orchestrate jobs; `jobs` define the work
- Use `requires` to declare dependencies between jobs — parallel by default
- `filters` to control which branches/tags trigger a job

**Caching:**
- Cache by lockfile hash: `- v1-deps-{{ checksum "package-lock.json" }}`
- Prefix cache keys with a version (`v1-`) — lets you bust cache by bumping version
- Separate caches for different languages/tools in the same workflow

**Workspaces:**
- Persist build artifacts between jobs with `persist_to_workspace` / `attach_workspace`
- More reliable than re-installing dependencies in every job

**Contexts:**
- Group secrets into Contexts (Settings → Contexts) — share across projects and orgs
- Restrict contexts to specific branches using branch filters

**Never:**
- Hardcode secrets in `config.yml` — use Environment Variables or Contexts
- Skip adding `restore_cache` before `save_cache` — always restore first
- Run all jobs sequentially when they can be parallel

**Related skills:** Your package manager layer (install commands), `container/docker` (building images)
