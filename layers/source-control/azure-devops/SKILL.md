---
name: azure-devops
description: Azure DevOps — repos, PRs, branch policies, pipelines, work items linking
user-invocable: false
stack: source-control/azure-devops
paths:
  - "**/azure-pipelines.yml"
  - "**/.azure/**"
  - "**/.pipelines/**"
---

Full standards in [azure-devops.md](azure-devops.md). Always-on summary:

**Repositories:**
- One repo per service/product — avoid mega-repos unless using a monorepo strategy with CODEOWNERS
- Default branch: `main`; protect with branch policies
- Use `.gitignore` tailored to the tech stack; never commit build artifacts, secrets, or IDE configs

**Pull Requests:**
- PR title format: `{type}: {description}` (conventional commit style)
- Required: at least 2 reviewers, build passing, and work item linked
- Link work items with `#AB{item-id}` in the PR description or commit message
- Use PR templates (`.azuredevops/pull_request_template.md`)

**Branch Policies (configure in Repo Settings):**
- Require a minimum of 2 reviewers on `main`
- Require linked work items
- Block self-approval
- Require builds to pass (link to the primary CI pipeline)
- Enable "Reset votes on new pushes" — reviewers must re-approve after force push

**Pipelines:**
- Use YAML pipelines stored in the repo — not the classic (visual) designer
- Reference pipeline YAML from `azure-pipelines.yml` at repo root
- Use service connections for external resources — never store credentials in pipeline variables directly

**Work Items Linking:**
- All commits on feature branches reference a work item: `git commit -m "feat: add checkout #AB123"`
- Sprints managed in Azure Boards — use `@` mentions and AB links in PRs for traceability
- Boards transition work items automatically when PR is completed (configure in Area Settings)

**Never:**
- Push directly to `main` — all changes via PR
- Use personal access tokens (PATs) with broad scope — scope to specific resources
- Merge with unresolved PR comments
- Run pipelines with credentials stored as plain pipeline variables — use variable groups or Key Vault

**Related skills:** `pipeline`, `conventional-commit`, `azure-pipelines`
