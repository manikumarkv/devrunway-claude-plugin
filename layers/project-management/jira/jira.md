# Jira Workflow Standards

---

## Issue hierarchy

```
Epic
  └─ Story          (user-facing feature, ~1 sprint)
       ├─ Task      (technical work needed to complete the story)
       └─ Bug       (defect found in a story)
  └─ Bug            (standalone defect, no parent story)
  └─ Spike          (research/investigation, time-boxed)
```

**Rules:**
- Stories and Bugs must link to an Epic — orphaned issues make planning impossible
- Spikes output a decision or a set of follow-up stories — they should produce something
- Sub-tasks are only for very short parallel work within one story; prefer breaking into separate stories

---

## Issue creation checklist

### Story template

```
Summary: As a [user type], I can [action] so that [benefit]

Description:
## Context
<Why does this need to exist? What problem does it solve?>

## Acceptance Criteria
- [ ] Given [precondition], when [action], then [outcome]
- [ ] Given [precondition], when [action], then [outcome]
- [ ] Edge cases handled: [list]

## Out of scope
<Explicitly state what this story does NOT cover>

## Technical notes
<Link to design doc, ADR, or relevant tech decisions>
```

**Required fields before sprint:**
- [ ] Summary (≤80 characters)
- [ ] Epic link
- [ ] Story Points estimate
- [ ] Acceptance Criteria (at least 2 criteria)
- [ ] Assignee (or unassigned if to be picked up in sprint)
- [ ] Fix Version (if targeting a specific release)

### Bug template

```
Summary: [Component] - [Behaviour] when [Condition]
e.g. "Checkout - Total shows $0 when promo code is applied"

Description:
## Steps to reproduce
1. Go to...
2. Click...
3. Observe...

## Expected behaviour
<What should happen>

## Actual behaviour
<What actually happens>

## Environment
- Browser/OS:
- Version/Build:
- User account (if relevant):

## Severity
Critical / High / Medium / Low

## Attachments
<Screenshots, logs, Loom recordings>
```

---

## Useful JQL queries

```jql
-- My current sprint work
assignee = currentUser() AND sprint in openSprints() AND status != Done ORDER BY updated DESC

-- Sprint board for a project
project = MYPROJ AND sprint in openSprints() ORDER BY status ASC, priority DESC

-- Unestimated backlog items (need refinement)
project = MYPROJ AND status = Backlog AND "Story Points" is EMPTY ORDER BY created DESC

-- Everything blocking a release
project = MYPROJ AND fixVersion = "v2.1.0" AND status != Done ORDER BY priority DESC

-- Issues linked as blocking
issue in linkedIssues("MYPROJ-123", "is blocked by")

-- Bugs created this sprint (team quality metric)
project = MYPROJ AND issuetype = Bug AND created >= startOfWeek(-1) ORDER BY created DESC

-- All overdue issues
project = MYPROJ AND due < now() AND status != Done ORDER BY due ASC

-- Recently updated (what's active right now)
project = MYPROJ AND updated >= -1d AND status in ("In Progress", "In Review")

-- Unassigned in current sprint
project = MYPROJ AND sprint in openSprints() AND assignee is EMPTY

-- My issues across all projects
assignee = currentUser() AND status != Done ORDER BY updated DESC
```

---

## Status workflow

```
Backlog → To Do → In Progress → In Review → Done
                       ↓
                    Blocked   (use flagging + comment with blocker, not a custom status)
```

**Transition rules:**
- `To Do → In Progress`: when you actually start coding, not when you plan to
- `In Progress → In Review`: when PR is open — add PR link to the issue
- `In Review → Done`: when PR is merged AND deployed to the target environment
- Do not skip statuses — boards rely on them for metrics

**Flagging (Blocked):**
- Use the flag icon (🚩) to mark an issue as blocked — don't create a "Blocked" status
- Add a comment: `Blocked by MYPROJ-999: waiting on design approval`
- Raise in standup the same day you flag it

---

## Branch and commit naming

```bash
# Branch naming — always include the Jira key
feature/MYPROJ-123-add-promo-code-support
fix/MYPROJ-456-checkout-total-zero-bug
chore/MYPROJ-789-upgrade-node-20
spike/MYPROJ-101-evaluate-elasticsearch

# Commit messages — include key in body or footer
git commit -m "feat(checkout): add promo code validation

Implements the discount calculation logic for percentage and flat-rate promo codes.

Closes MYPROJ-123"

# PR title — key at the start
[MYPROJ-123] Add promo code support to checkout
```

The GitHub for Jira app detects the issue key in branch names, commit messages, and PR titles — and automatically links them to the issue's Development panel.

---

## Labels and components

**Labels** — cross-cutting concerns (apply to any issue type):
```
security          — requires security review
performance       — has performance implications
tech-debt         — addresses existing technical debt
a11y              — accessibility improvement
breaking-change   — changes the public API or contract
data-migration    — requires a database migration
```

**Components** — code areas (set per-project in Jira Settings):
```
frontend
backend-api
database
auth
infrastructure
```

Use both: a single issue can have label `security` and component `auth`.

---

## Story point estimation guide

| Points | Complexity | Example |
|--------|------------|---------|
| 1 | Trivial — obvious, well-understood | Fix a typo, update a config value |
| 2 | Small — straightforward, low risk | Add a new field to a form, add a new API parameter |
| 3 | Medium — some complexity or unknowns | Add a new API endpoint with validation and tests |
| 5 | Large — significant work or design decisions | New feature with multiple components and API changes |
| 8 | Very large — consider breaking down | Complex feature spanning frontend + backend + DB |
| 13 | Epic-level — must be broken down before sprint | Rewrite auth system |

> Anything estimated at 13 or higher must be split before it enters a sprint.

---

## Sprint ceremonies — Jira prep

**Sprint planning:**
- Product Owner: all stories in the top of backlog are refined, estimated, and have acceptance criteria
- Developer: verify the story is clear; raise questions before accepting it into the sprint
- Move accepted stories from Backlog to `To Do` in the sprint

**Refinement (before planning):**
- Go through the top 20 backlog items
- Estimate unestimated items
- Break down any item > 8 points
- Remove or archive items that are no longer relevant

**Sprint review:**
- Demo completed stories (status = Done, verified in staging)
- Move incomplete stories back to Backlog with a comment on what remains

---

## GitHub ↔ Jira integration

Install: **GitHub for Jira** (available in the Atlassian Marketplace)

After installation:
- Commits mentioning an issue key appear in the issue's Development panel
- PRs linked to an issue show build status and review status
- Deployments (via GitHub Actions with environment annotations) appear under the issue's Releases panel

```yaml
# .github/workflows/ci.yml — add environment to deployments for Jira visibility
jobs:
  deploy-staging:
    environment:
      name: staging
      url: https://staging.yourapp.com
```

---

## MCP integration

When the Jira MCP server is configured (via `/setup`), Claude can:
- List issues in a sprint: `list my current sprint issues`
- Create issues: `create a story for the login rate limiting feature`
- Update status: `move MYPROJ-123 to In Review`
- Search with JQL: `find all unestimated backlog items`

Configuration in `.mcp.json`:
```json
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-jira"],
      "env": {
        "JIRA_API_TOKEN": "${JIRA_API_TOKEN}",
        "JIRA_BASE_URL":  "${JIRA_BASE_URL}",
        "JIRA_EMAIL":     "${JIRA_EMAIL}"
      }
    }
  }
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Stories without Epic links | Every story links to an Epic — enforce in workflow rules |
| Moving issues to In Progress before starting | In Progress = actively coding right now |
| No Acceptance Criteria | At minimum: one "happy path" + one "failure" criterion |
| Story points = hours | Points measure complexity and risk, not time |
| Reopening a Done issue | Create a new Bug with a link to the original story |
| Giant 13-point stories in a sprint | Break into smaller stories (≤5 points) before sprint planning |
| Decisions in Jira comments | Put decisions in an ADR or Confluence; link from the issue |
