# GitHub Project Management Standards

## Label Taxonomy

Create these labels on every repo:

| Label | Color | Purpose |
|---|---|---|
| `type: bug` | #d73a4a | Something is broken |
| `type: feature` | #0075ca | New functionality |
| `type: chore` | #e4e669 | Maintenance, deps, config |
| `type: docs` | #0075ca | Documentation only |
| `priority: p0` | #b60205 | Critical — fix now |
| `priority: p1` | #e99695 | High — this sprint |
| `priority: p2` | #f9d0c4 | Normal — next sprint |
| `status: blocked` | #d93f0b | Waiting on something |
| `status: in-review` | #0052cc | PR open, awaiting review |
| `size: S` | #c5def5 | < 2h |
| `size: M` | #c5def5 | 2–8h |
| `size: L` | #c5def5 | 1–3 days |
| `size: XL` | #c5def5 | > 3 days (consider splitting) |

## Issue Template

`.github/ISSUE_TEMPLATE/feature.yml`:
```yaml
name: Feature request
about: New functionality
labels: ["type: feature"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem / motivation
  - type: textarea
    id: solution
    attributes:
      label: Proposed solution
  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance criteria
      value: |
        - [ ] Criterion 1
        - [ ] Criterion 2
```

Issue title format: `[Type] Short imperative description`
- `[Feature] Add JWT refresh endpoint`
- `[Bug] Cart total miscalculates when discount applied`

## Branch Naming

```
feat/123-add-jwt-refresh
fix/456-cart-total-miscalculation
chore/789-upgrade-react-19
docs/101-update-api-readme
```

Rules:
- Always prefix with issue number so `Closes #123` can auto-link
- Lowercase, hyphens, no spaces
- Keep the slug under 40 characters

## PR Convention

**Title:** follows conventional commit format
- `feat(auth): add JWT refresh endpoint (#123)`
- `fix(cart): correct discount calculation (#456)`

**Body template** (`.github/pull_request_template.md`):
```markdown
## Summary
<!-- What does this PR do? 2-3 bullets -->

## Changes
<!-- Key implementation decisions, files changed -->

## Test plan
- [ ] Unit tests pass (`npm test`)
- [ ] E2E tests pass for affected flows
- [ ] Manual smoke test on staging
- [ ] Screenshots attached (if UI change)

## Related
Closes #<issue-number>
```

**Branch protection rules:**
- Require 1 approval before merge
- Require status checks to pass (CI)
- Require branch to be up to date before merge
- Block force pushes

## Milestones

Naming: `v<major>.<minor>.<patch>` — semantic versioning.

```bash
gh api repos/:owner/:repo/milestones --method POST \
  -f title="v1.2.0" \
  -f due_on="2024-03-31T00:00:00Z" \
  -f description="Q1 release — auth improvements + payment integration"
```

Link milestone to CHANGELOG section before closing it.

## `gh` CLI Quick Reference

```bash
# Issues
gh issue list                              # all open issues
gh issue list --label "priority: p0"       # urgent issues only
gh issue list --assignee @me               # my issues
gh issue create --title "[Bug] ..." --label "type: bug,priority: p1"
gh issue close 123 --comment "Fixed in #456"

# PRs
gh pr create --draft --title "feat(auth): ..."   # open draft early
gh pr create --fill                              # use commit msg as title/body
gh pr list --author @me
gh pr review 456 --approve --body "LGTM"
gh pr merge 456 --squash --delete-branch

# CI
gh run list --workflow=ci.yml              # recent CI runs
gh run watch                              # watch current run
gh run view 789 --log-failed              # debug a failed run

# Releases
gh release create v1.2.0 --generate-notes --draft
```

## GitHub MCP Usage

When `mcp__git__*` tools are available, prefer them over `gh` CLI for:

```
mcp__git__get_issue        — fetch issue details
mcp__git__update_issue     — change labels, assignees, milestone
mcp__git__add_issue_comment — post a comment
mcp__git__get_pull_request — fetch PR details and review status
mcp__git__list_pull_requests — list open PRs
mcp__git__create_pull_request — open a new PR
```

Use `gh` CLI for operations not covered by the MCP (releases, workflow runs, repo settings).
