---
name: jira
description: Jira workflow standards — issue types, JQL queries, sprint management, GitHub integration, and MCP tool usage. Load when working with Jira.
user-invocable: false
stack: project-management/jira
paths:
  - ".mcp.json"
  - "jira*"
  - ".jira*"
---

Full standards in [jira.md](jira.md). Always-on summary:

**Issue types and fields:**
- Epic → Story → Task/Bug — never create Stories without linking to an Epic
- Every issue needs: Summary (≤80 chars), Description (user-story format for stories), Acceptance Criteria, Story Points, and a linked Epic
- Use Labels for cross-cutting concerns (`security`, `performance`, `tech-debt`); Components for code areas
- Fix Version links issues to a release — set it when moving to In Progress, not at creation

**JQL — useful queries:**
- My current work: `assignee = currentUser() AND sprint in openSprints() AND status != Done`
- Unestimated in backlog: `project = MYPROJ AND status = Backlog AND "Story Points" is EMPTY ORDER BY created DESC`
- Blocking issues: `issue in linkedIssues("MYPROJ-123", "is blocked by")`
- Overdue: `project = MYPROJ AND due < now() AND status != Done`

**Sprint workflow:**
- Statuses: `Backlog → To Do → In Progress → In Review → Done`
- Move to In Progress only when you start work — not when you plan to
- Link the Jira issue to your PR using the issue key in the branch name or PR title: `MYPROJ-123`
- Add the issue key to commit messages: `feat(checkout): add promo code validation [MYPROJ-456]`

**Estimation:**
- Use Fibonacci: 1, 2, 3, 5, 8, 13 — anything > 8 should be broken down
- Story points measure complexity + uncertainty, not hours

**GitHub integration:**
- Install the GitHub for Jira app — it auto-links commits, PRs, and deployments to issues
- Branch naming: `feature/MYPROJ-123-short-description`, `fix/MYPROJ-456-bug-name`

**Never:**
- Create issues without an Epic link — epics are the unit of planning
- Use Jira comments for decisions — link to the ADR or Confluence page instead
- Reopen Done issues — create a new bug instead

**Related skills:** `source-control/github`, `core/conventional-commit`
