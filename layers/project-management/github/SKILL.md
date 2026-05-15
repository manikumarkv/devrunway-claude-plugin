---
name: github
description: GitHub Issues/Projects — issue templates, project boards, milestones, labels, auto-labeling
user-invocable: false
stack: project-management/github
paths:
  - "**/.github/ISSUE_TEMPLATE/**"
  - "**/.github/PULL_REQUEST_TEMPLATE*"
  - "**/.github/workflows/*.yml"
  - "**/.github/labels.yml"
---

Full standards in [github.md](github.md). Always-on summary:

**Issue Templates:**
- Provide templates for Bug Report, Feature Request, and Technical Debt — plain issues are discouraged
- Templates live in `.github/ISSUE_TEMPLATE/` as YAML files (form-based) or Markdown
- Include required fields: description, steps to reproduce, expected vs actual (bugs), acceptance criteria (features)

**Labels:**
- Maintain a canonical label set in `.github/labels.yml` — sync with `actions/github-script` or `label-sync`
- Label taxonomy: `type/*` (bug, feature, chore), `priority/*` (critical, high, medium, low), `status/*` (blocked, in-review, needs-triage)
- Auto-apply labels on PRs using `actions/labeler` based on changed file paths

**Project Boards:**
- Use GitHub Projects v2 — not the legacy Projects (kanban only)
- Standard columns: Backlog → Ready → In Progress → In Review → Done
- Link issues to milestones for release tracking

**Milestones:**
- One milestone per release — include a due date and release notes description
- Close the milestone when all linked issues are resolved
- Use milestone progress as the release readiness signal

**Auto-Labeling and Automation:**
- Auto-assign reviewers on PR open using `CODEOWNERS`
- Auto-close stale issues after 60 days of inactivity using `actions/stale`
- Auto-move issues to "In Progress" when a branch is created linking to the issue

**Never:**
- Create issues without a label — triage immediately
- Merge PRs without at least one required reviewer approval
- Close milestones with open issues — resolve or move them first

**Related skills:** `branch`, `conventional-commit`, `pipeline`
