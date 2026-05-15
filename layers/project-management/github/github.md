# GitHub Issues/Projects Standards

## Issue Templates

```yaml
# .github/ISSUE_TEMPLATE/bug_report.yml
name: Bug Report
description: Report a bug or unexpected behavior
labels: ["type/bug", "status/needs-triage"]
body:
  - type: markdown
    attributes:
      value: "Please fill in as much detail as possible."

  - type: textarea
    id: description
    attributes:
      label: What happened?
      description: A clear description of the bug.
    validations:
      required: true

  - type: textarea
    id: steps
    attributes:
      label: Steps to reproduce
      placeholder: |
        1. Go to '...'
        2. Click on '...'
        3. See error
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected behavior
    validations:
      required: true

  - type: input
    id: version
    attributes:
      label: Version / environment
      placeholder: "v1.2.3 / Chrome 120 / macOS Sonoma"

  - type: dropdown
    id: priority
    attributes:
      label: Priority
      options: [Critical, High, Medium, Low]
    validations:
      required: true
```

```yaml
# .github/ISSUE_TEMPLATE/feature_request.yml
name: Feature Request
description: Suggest a new feature or improvement
labels: ["type/feature", "status/needs-triage"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem statement
      description: What problem does this solve?
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed solution
    validations:
      required: true

  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance criteria
      placeholder: |
        - [ ] User can do X
        - [ ] System responds with Y within Z ms
    validations:
      required: true
```

## PR Template

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->
## Summary
<!-- 1-3 bullet points describing what changed and why -->

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Refactor / chore

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manually tested in staging

## Checklist
- [ ] PR title follows conventional commit format (`feat:`, `fix:`, etc.)
- [ ] Linked to issue: Closes #
- [ ] No secrets or credentials in the diff
- [ ] Documentation updated (if applicable)
```

## Labels Configuration

```yaml
# .github/labels.yml
- name: "type/bug"
  color: "d73a4a"
  description: "Something isn't working"

- name: "type/feature"
  color: "0075ca"
  description: "New feature or improvement"

- name: "type/chore"
  color: "e4e669"
  description: "Maintenance, refactor, or technical debt"

- name: "type/docs"
  color: "0075ca"
  description: "Documentation only"

- name: "priority/critical"
  color: "b60205"
  description: "Must fix immediately — production impacted"

- name: "priority/high"
  color: "e11d48"
  description: "Fix in current sprint"

- name: "priority/medium"
  color: "f97316"
  description: "Fix in next sprint"

- name: "priority/low"
  color: "fbbf24"
  description: "Nice to have"

- name: "status/needs-triage"
  color: "d0d0d0"
  description: "Not yet reviewed"

- name: "status/in-progress"
  color: "0052cc"
  description: "Being actively worked on"

- name: "status/blocked"
  color: "e4e669"
  description: "Waiting on external dependency"

- name: "status/in-review"
  color: "5319e7"
  description: "PR open, awaiting review"
```

## Auto-Labeling on PRs

```yaml
# .github/labeler.yml — used with actions/labeler
frontend:
  - changed-files:
    - any-glob-to-any-file: ["src/components/**", "src/pages/**", "src/styles/**"]

backend:
  - changed-files:
    - any-glob-to-any-file: ["src/api/**", "src/services/**", "src/models/**"]

infrastructure:
  - changed-files:
    - any-glob-to-any-file: ["infra/**", "*.tf", "*.bicep"]

ci:
  - changed-files:
    - any-glob-to-any-file: [".github/workflows/**"]

docs:
  - changed-files:
    - any-glob-to-any-file: ["docs/**", "*.md"]
```

```yaml
# .github/workflows/label.yml
name: Label PRs
on:
  pull_request:

jobs:
  label:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/labeler@v5
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```

## Stale Issue Bot

```yaml
# .github/workflows/stale.yml
name: Close stale issues and PRs
on:
  schedule:
    - cron: "0 6 * * 1"   # every Monday at 6am UTC

jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v9
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          stale-issue-message: |
            This issue has been inactive for 60 days. It will be closed in 7 days
            unless there is further activity. Comment if this is still relevant.
          close-issue-message: "Closed due to 67 days of inactivity."
          stale-issue-label: "status/stale"
          days-before-stale: 60
          days-before-close: 7
          exempt-issue-labels: "priority/critical,priority/high,status/blocked"
          stale-pr-message: "This PR has been inactive for 30 days."
          days-before-pr-stale: 30
          days-before-pr-close: 7
```

## CODEOWNERS

```
# .github/CODEOWNERS
# Global reviewers
*                   @org/platform-team

# Frontend
src/components/     @org/frontend-team
src/pages/          @org/frontend-team

# API
src/api/            @org/backend-team
src/services/       @org/backend-team

# Infrastructure
infra/              @org/infra-team
*.tf                @org/infra-team
*.bicep             @org/infra-team

# CI/CD
.github/            @org/devops-team
```

## Milestone Usage

```bash
# Create a milestone via GitHub CLI
gh api repos/:owner/:repo/milestones \
  --method POST \
  -f title="v1.3.0" \
  -f due_on="2025-06-01T00:00:00Z" \
  -f description="Checkout redesign + performance improvements"

# Assign an issue to a milestone
gh issue edit 42 --milestone "v1.3.0"

# List open issues in a milestone
gh issue list --milestone "v1.3.0" --state open
```

## Checklist

- [ ] Issue templates in `.github/ISSUE_TEMPLATE/` (YAML form format)
- [ ] PR template in `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] Labels synced from `.github/labels.yml` — no ad-hoc label creation
- [ ] `labeler.yml` configured for auto-labeling by changed file paths
- [ ] `CODEOWNERS` covers all critical paths
- [ ] Stale bot configured for issues (60 days) and PRs (30 days)
- [ ] All PRs require at least 1 review (configured in branch protection rules)
