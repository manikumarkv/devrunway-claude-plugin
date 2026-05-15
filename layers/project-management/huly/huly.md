# Huly Standards

## Workspace Structure

```
Organization Workspace
├── Projects/
│   ├── Platform Team        — infra, DX, APIs
│   ├── Frontend Team        — web app, design system
│   └── Mobile Team          — iOS / Android
├── Members                  — all org members
├── Integrations/
│   └── GitHub               — repo sync
└── Settings
    ├── Roles & Permissions
    └── Notifications
```

## Project Configuration

Each project should configure:

| Setting | Value |
|---|---|
| Identifier prefix | Short code (e.g., `PLT`, `FE`, `MOB`) |
| Issue statuses | Backlog → To Do → In Progress → In Review → Done → Cancelled |
| Priority levels | Urgent, High, Medium, Low |
| Components | List of code/product components |
| Estimation | Story points (1, 2, 3, 5, 8, 13) |

## Issue Lifecycle

```
1. Created (Backlog)
   ↓ Triage: set Priority + Component
2. To Do (Ready for sprint)
   ↓ Sprint planning: assign + estimate
3. In Progress
   - Branch created: {prefix}-{id}-short-description
   - Commit prefix: PLT-123: feat: ...
4. In Review
   - PR opened, Huly auto-links
5. Done
   - PR merged → Huly auto-moves issue
```

## Issue Template (Description)

```markdown
## Context
<!-- Why is this issue needed? What problem does it solve? -->

## Acceptance Criteria
- [ ] AC1: ...
- [ ] AC2: ...
- [ ] AC3: ...

## Technical Notes
<!-- Architecture decisions, edge cases, API contracts -->

## Design Reference
<!-- Link to Figma/XD/Sketch screen -->

## Out of Scope
<!-- Explicitly list what is NOT included -->
```

## Sprint Setup

```
Sprint naming: Sprint {N} — {YYYY-MM-DD} to {YYYY-MM-DD}
Example:       Sprint 24 — 2025-05-05 to 2025-05-16

Sprint events (add to Huly meeting notes):
  Sprint Planning  — Day 1 morning (2h)
  Daily Standup    — Every day (15min) — async if distributed
  Sprint Review    — Last day (1h)
  Retrospective    — Last day after review (1h)
```

Capacity planning:
- Measure team velocity from last 3 sprints
- Book 80% of velocity as sprint commitment
- Reserve 20% for unplanned work and bugs

## GitHub Integration Setup

1. Workspace Settings → Integrations → GitHub
2. Install the Huly GitHub App on the organization
3. Select repositories to sync
4. Configure:
   - Commit linking: `PLT-123` in commit message → links to issue PLT-123
   - PR linking: PR title starts with `PLT-123:` → links and moves issue to "In Review"
   - Merge trigger: merging to `main` → moves issue to "Done"

## Branch Naming with Huly

```bash
# Branch format
{project-prefix}/{issue-id}-{short-description}

# Examples
plt/PLT-123-add-oauth-provider
fe/FE-456-redesign-checkout-button
mob/MOB-789-fix-push-notification-crash
```

## Commit Message Format

```
PLT-123: feat: add OAuth provider support

- Implement Google OAuth via MSAL
- Add redirect URI configuration
- Update user model for OAuth fields
```

## Labels / Tags

```
Component tags (prefix with #):
  #api       — backend API changes
  #frontend  — React/Angular UI
  #infra     — infrastructure, Terraform, CDK
  #db        — database migrations
  #ci        — CI/CD pipelines
  #dx        — developer experience

Cross-cutting tags:
  #security  — security-related work
  #perf      — performance optimization
  #a11y      — accessibility
  #breaking  — breaking changes
```

## Reporting and Reviews

**Sprint Review agenda (Huly Meeting Notes template):**
```markdown
## Sprint {N} Review — {date}

### Completed (velocity: X points)
- [ ] List completed issues

### Carried Over
- [ ] List issues not completed + reason

### Metrics
- Velocity: X points (target: Y)
- Bug count opened: X
- Bug count closed: X

### Demo
- Demo 1: {assignee} shows {feature}
- Demo 2: ...
```

**Retrospective (Start/Stop/Continue):**
```markdown
## Sprint {N} Retrospective

### Start doing
-

### Stop doing
-

### Continue doing
-

### Action items
- [ ] Owner: Action by {date}
```

## Blocked Issue Escalation

If an issue is blocked for more than 2 days:
1. Tag the blocker with `blocked-by: {issue-id or external}`
2. Post in team Slack channel `#team-{name}` with `@here`
3. If not resolved within 2 more days — escalate to engineering lead

## Checklist

- [ ] Project identifier prefix configured (e.g., `PLT-`)
- [ ] Issue statuses match the defined lifecycle
- [ ] GitHub integration installed and repos connected
- [ ] All issues have Priority + Assignee + Component before sprint
- [ ] Sprint capacity set at 80% of average velocity
- [ ] Sprint review and retrospective meeting notes created
- [ ] Blocked issues reviewed weekly in team standup

## Common mistakes

| Mistake | Fix |
|---|---|
| Not configuring the project identifier prefix | Without a prefix (e.g., `PLT-`), commit messages and PR titles can't auto-link to Huly issues |
| Skipping triage — no Priority or Component set before sprint | Issues without Priority and Component cannot be meaningfully scheduled; complete triage in the backlog before sprint planning |
| Committing directly to `main` without a branch linked to an issue | Create a branch named `{prefix}/{id}-description` so Huly can auto-track progress and move the issue to "In Review" on PR open |
| Over-committing in sprint planning (100% of velocity) | Book only 80% of average velocity to leave room for unplanned bugs and interruptions |
| Leaving blocked issues unescalated for more than 2 days | Tag the blocker, post in the team Slack channel, and escalate to the lead if not resolved within 4 days total |
| Not holding a retrospective after each sprint | Retrospectives drive continuous improvement; schedule it immediately after the sprint review while context is fresh |
| Using ad-hoc status names instead of the defined lifecycle | Stick to the configured statuses (Backlog → To Do → In Progress → In Review → Done → Cancelled) for reliable automation |
