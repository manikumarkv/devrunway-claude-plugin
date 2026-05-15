# Azure DevOps Standards

## Repository Setup

```bash
# Clone with SSH (preferred over HTTPS for CI)
git clone git@ssh.dev.azure.com:v3/myorg/MyProject/myapp-api

# Set default branch
az repos update \
  --repository myapp-api \
  --organization https://dev.azure.com/myorg \
  --project MyProject \
  --default-branch main
```

## Branch Policy Configuration (CLI)

```bash
ORG="https://dev.azure.com/myorg"
PROJECT="MyProject"
REPO_ID=$(az repos show --repository myapp-api --org $ORG --project $PROJECT --query id -o tsv)

# Minimum reviewers (2)
az repos policy min-reviewers create \
  --org $ORG --project $PROJECT \
  --repository-id $REPO_ID \
  --branch main \
  --blocking true \
  --enabled true \
  --minimum-approver-count 2 \
  --reset-on-source-push true \
  --allow-downvotes false

# Required linked work item
az repos policy work-item-linking create \
  --org $ORG --project $PROJECT \
  --repository-id $REPO_ID \
  --branch main \
  --blocking true \
  --enabled true

# Comment resolution required
az repos policy comment-required create \
  --org $ORG --project $PROJECT \
  --repository-id $REPO_ID \
  --branch main \
  --blocking true \
  --enabled true

# Build validation (link to primary pipeline)
az repos policy build create \
  --org $ORG --project $PROJECT \
  --repository-id $REPO_ID \
  --branch main \
  --blocking true \
  --enabled true \
  --build-definition-id $PIPELINE_ID \
  --queue-on-source-update-only false \
  --manual-queue-only false \
  --display-name "CI Build"
```

## PR Template

```markdown
<!-- .azuredevops/pull_request_template.md -->
## Description
<!-- What changed and why? -->

## Type of change
- [ ] Bug fix (`fix:`)
- [ ] New feature (`feat:`)
- [ ] Breaking change (`feat!:` / `fix!:`)
- [ ] Refactor / chore (`chore:`, `refactor:`)
- [ ] Documentation (`docs:`)

## Work item(s)
<!-- Link automatically or manually: AB#1234 -->
Closes AB#

## Test plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Tested manually in staging

## Checklist
- [ ] PR title follows conventional commit format
- [ ] No secrets or credentials in the diff
- [ ] Breaking changes documented
- [ ] All reviewer comments resolved
```

## Work Item Linking in Commits

```bash
# Single work item
git commit -m "feat: add payment method selection AB#1234"

# Multiple work items
git commit -m "fix: correct order total rounding AB#1234 AB#1235"

# Also works in PR description:
# Closes AB#1234
# Related to AB#1235
```

## Azure DevOps CLI — Common Operations

```bash
# List PRs
az repos pr list --org $ORG --project $PROJECT --repository myapp-api --status active

# Create a PR
az repos pr create \
  --org $ORG --project $PROJECT \
  --repository myapp-api \
  --title "feat: add OAuth provider AB#1234" \
  --description "Implements Google OAuth via MSAL. Closes AB#1234." \
  --source-branch feat/PLT-123-oauth \
  --target-branch main \
  --reviewers "user@example.com" "team@example.com"

# List work items in a sprint
az boards query \
  --org $ORG --project $PROJECT \
  --wiql "SELECT [System.Id],[System.Title],[System.State] FROM WorkItems WHERE [System.IterationPath] = 'MyProject\\Sprint 24' AND [System.AssignedTo] = @me"

# Transition a work item
az boards work-item update --id 1234 --state "In Progress" --org $ORG --project $PROJECT
```

## Service Connections (PAT Scopes)

| Use Case | Required Scope |
|---|---|
| Read repos | Code (Read) |
| Clone + push | Code (Read & Write) |
| Trigger pipelines | Build (Read & Execute) |
| Manage work items | Work Items (Read & Write) |
| Publish packages | Packaging (Read & Write) |

- Create service connections under Project Settings → Service Connections
- Use "Workload Identity Federation" for Azure subscriptions — no client secrets
- Set the connection to "Grant access permission to all pipelines" only for shared connections

## Pipeline Security

```yaml
# Use variable groups for secrets — not pipeline variables
variables:
  - group: "myapp-production-secrets"   # linked to Key Vault

# Never:
variables:
  DB_PASSWORD: "my-secret"              # ❌ plaintext in YAML
```

```bash
# Create a variable group
az pipelines variable-group create \
  --org $ORG --project $PROJECT \
  --name "myapp-production-secrets" \
  --variables DB_HOST=db.internal LOG_LEVEL=info \
  --authorize true

# Link to Key Vault
az pipelines variable-group create \
  --org $ORG --project $PROJECT \
  --name "myapp-keyvault-secrets" \
  --authorize true \
  --provider-type AzureKeyVault \
  --provider-name myapp-prod-kv \
  --service-endpoint "myapp-prod-sc"
```

## Boards Configuration

```
Area paths (mirror teams/services):
  MyProject
  ├── Platform Team
  │   ├── API
  │   └── Infrastructure
  └── Frontend Team

Iteration paths (sprints):
  MyProject
  ├── Sprint 24 (2025-05-05 → 2025-05-16)
  └── Sprint 25 (2025-05-19 → 2025-05-30)

Work item types:
  Epic → Feature → User Story → Task
                              → Bug
```

Auto-transition rules (Boards → Settings → Rules):
- PR created → move story to "In Review"
- PR merged to main → move story to "Done"
- Build fails on main → create a bug automatically (optional)

## CODEOWNERS (Azure DevOps style)

Azure DevOps does not natively support GitHub's CODEOWNERS, but you can approximate it:
1. Create reviewer policies per path in branch policies
2. Or use a pipeline step that assigns reviewers based on changed paths

```yaml
# .azure/auto-reviewers.yml (used in a PR pipeline)
- pattern: "src/api/**"
  reviewers:
    - backend-team
- pattern: "infra/**"
  reviewers:
    - infra-team
```

## Checklist

- [ ] Branch policies enforced on `main`: min 2 reviewers, build passing, work item linked, comments resolved
- [ ] PR template in `.azuredevops/pull_request_template.md`
- [ ] Secrets in variable groups linked to Key Vault — not pipeline variables
- [ ] Service connections scoped to minimum required permissions
- [ ] Workload Identity Federation used for Azure service connections — no client secrets
- [ ] Work items linked via `AB#{id}` in all commit messages and PRs
- [ ] Boards area and iteration paths match team structure
