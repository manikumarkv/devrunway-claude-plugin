---
name: huly
description: Huly — workspace setup, issues, sprints, members, GitHub sync
user-invocable: false
stack: project-management/huly
paths:
  - "**/.huly/**"
  - "**/huly.config*"
---

Full standards in [huly.md](huly.md). Always-on summary:

**Workspace Setup:**
- Create one workspace per organization — not per project
- Create one Project per product or service team; use sub-projects for large products
- Invite members with appropriate roles: Owner, Member, or Guest

**Issues:**
- All work tracked as Huly issues — no work happens outside the system
- Required fields: Title, Assignee, Priority, and Component
- Use `#component` tags to link issues to code components
- Write acceptance criteria in the issue description before moving to "In Progress"

**Sprints:**
- Create sprints with fixed two-week start/end dates — no rolling sprints
- Sprint capacity set in story points; do not overbook beyond 80% of capacity
- Run sprint planning, review, and retrospective via Huly's built-in meeting notes

**GitHub Sync:**
- Connect Huly to GitHub via the GitHub integration in workspace Settings
- Prefix commit messages and PR titles with the Huly issue ID: `HLY-123: feat: add checkout`
- Huly auto-updates issue status when PRs are merged to main

**Reporting:**
- Use Huly's built-in velocity and burndown charts for sprint reviews
- Review "blocked" issues weekly — never let an issue stay blocked more than 2 days without escalation

**Never:**
- Create issues without an assignee and priority
- Close a sprint with more than 20% of committed issues incomplete — carry over with a note
- Use Huly as a documentation system — link to Notion/Confluence for docs

**Related skills:** `branch`, `conventional-commit`
