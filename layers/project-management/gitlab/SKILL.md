---
name: gitlab-issues
description: GitLab Issues, Milestones, Epics, Boards — issue templates, labels, weights, iterations, MR-issue links. Load when working with GitLab issue tracking.
user-invocable: false
stack: project-management/gitlab
paths:
  - ".mcp.json"
  - ".gitlab/issue_templates/**"
  - ".gitlab/merge_request_templates/**"
  - ".gitlab-ci.yml"
---

Full standards in [gitlab-issues.md](gitlab-issues.md). Always-on summary:

**Issue conventions:**
- Title: imperative — "Add promo code to checkout" (not "promo code support")
- Description uses the appropriate template under `.gitlab/issue_templates/` — never submit a blank issue
- Required fields: description, acceptance criteria, weight (story points), labels, milestone
- Assign to one person — co-assignees blur ownership

**Labels (scoped):**
- Use scoped labels for mutual exclusion: `priority::high`, `status::in-progress`, `type::bug`
- Free labels for cross-cutting: `security`, `performance`, `tech-debt`
- Maintain a project-level label policy in `.gitlab/labels.yml`

**Epics and milestones:**
- Group-level Epics for multi-issue initiatives spanning >1 milestone
- Milestones map to releases or sprints — set due dates and burn down
- Every issue belongs to a milestone before it goes to In Progress

**Boards and iterations:**
- One board per team workflow — columns map to scoped `status::*` labels
- Iterations replace sprints — auto-rolling cadence with a fixed length

**MR-issue linking:**
- Branch name carries the issue id: `feat/123-promo-code-validation`
- Use `Closes #123` or `Refs #123` in MR description — closing keyword auto-closes on merge
- Commit messages reference issue: `feat(checkout): add promo code validation (#123)`

**MCP usage:**
- When the `gitlab` MCP is active, prefer `mcp__gitlab__*` tools over `glab` CLI
- Fall back to `glab` CLI if MCP unavailable

**Never:**
- Submit issues without a template
- Use free labels where a scoped label fits — breaks board filtering
- Manually close issues that an MR could close via keyword

**Related skills:**
- `source-control/gitlab` for branching and MR workflow
- `ci/gitlab-ci` for pipeline configuration
