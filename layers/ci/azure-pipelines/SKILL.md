---
name: azure-pipelines
description: Azure Pipelines YAML — stages, jobs, service connections, environments, approvals, caching
user-invocable: false
stack: ci/azure-pipelines
paths:
  - "**/azure-pipelines.yml"
  - "**/.azure/*.yml"
  - "**/azure-pipelines/**"
  - "**/.pipelines/**"
---

Full standards in [azure-pipelines.md](azure-pipelines.md). Always-on summary:

**YAML Structure:**
- Use `stages` → `jobs` → `steps` hierarchy — never put steps directly at pipeline root
- Separate `Build`, `Test`, `Deploy-Staging`, `Deploy-Prod` stages with explicit `dependsOn`
- Define reusable templates in `.azure/templates/` and reference with `template:` key

**Service Connections:**
- Reference service connections by name in `azureSubscription`, `dockerRegistryServiceConnection`
- Never embed credentials in YAML — use variable groups linked to Azure Key Vault
- Scope service connections to specific pipelines in Project Settings

**Environments and Approvals:**
- Create named `environments` in Azure DevOps UI (e.g., `staging`, `production`)
- Add approval gates on `production` environment — required before deploy job runs
- Use `deployment` job type (not `job`) for environment-aware deploys

**Caching:**
- Cache npm/pip/nuget with `Cache@2` task using a lockfile-based key
- Always include a `restoreKeys:` fallback so partial cache hits are used
- Cache at the job level, not stage level

**Variables:**
- Use variable groups for shared secrets — link groups to Key Vault
- Use `$[stageDependencies...]` for passing outputs between stages
- Prefix secret variables with `secret_` and mark with `isSecret: true`

**Never:**
- Hardcode credentials or connection strings in YAML
- Use `condition: always()` on deploy steps — failed builds must not deploy
- Skip environment resources for production deployments
- Run deployment jobs without a `strategy` block (use `runOnce` at minimum)

**Related skills:** `pipeline`, `deploy`, `security-principles`
