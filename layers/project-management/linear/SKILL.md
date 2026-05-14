---
name: linear
description: Linear workflow standards — issue conventions, cycles, projects, label system, GitHub sync, and keyboard shortcuts. Load when working with Linear.
user-invocable: false
stack: project-management/linear
paths:
  - ".mcp.json"
  - "linear*"
---

Full standards in [linear.md](linear.md). Always-on summary:

**Issue conventions:**
- Title: imperative verb phrase — "Add promo code support to checkout" (not "Promo code")
- Priority: `Urgent` for blocking production, `High` for current cycle goals, `Medium` for planned, `No priority` for backlog ideas
- Estimate in points: 1 (trivial), 2 (small), 3 (medium), 5 (large) — anything > 5 gets split
- Every issue needs a team, priority, and at least one label before entering a cycle

**Labels:**
- Type labels: `feature`, `bug`, `chore`, `spike` — one per issue
- Area labels: `frontend`, `backend`, `infra`, `design` — one per issue
- Status labels: `blocked`, `needs-design`, `needs-review` — optional, situational
- Never create labels that duplicate Linear's built-in status workflow

**Cycles (sprints):**
- Cycle length: 2 weeks, starting Monday
- Mid-cycle: if > 30% of issues are not started, flag in standup — don't wait until the end
- Unfinished issues auto-roll to next cycle; add a comment explaining why

**Projects:**
- Projects are for multi-cycle initiatives that span teams (e.g., "Payments V2", "Mobile App")
- Every project needs an Owner, a target date, and a status (Planned / In Progress / Completed)
- Issues in a project still belong to a team's cycle

**GitHub sync:**
- Install Linear's GitHub integration — it auto-links PRs and commits to issues
- Branch convention: `username/issue-id-short-description` (Linear can auto-create this)
- PR title format: `ENG-123 Add promo code support` — Linear auto-updates issue status when PR is opened/merged

**Never:**
- Close issues without a completion comment if they were significant work
- Create duplicate labels — search before creating
- Start a cycle with unestimated issues

**Related skills:** `project-management/jira` (enterprise alternative), `source-control/github`, `core/conventional-commit`
