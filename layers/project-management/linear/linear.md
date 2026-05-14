# Linear Workflow Standards

---

## Issue anatomy

```
Title:      Add promo code support to checkout
Team:       Engineering
Priority:   High
Estimate:   3 points
Cycle:      Cycle 24 (current)
Labels:     feature, frontend, backend
Project:    Payments V2 (if applicable)
Assignee:   @yourname

Description:
## Context
<Why does this need to exist?>

## What
<Specific behaviour being added or changed>

## Acceptance Criteria
- [ ] User can enter a promo code at checkout
- [ ] Valid code applies the discount; invalid code shows error
- [ ] Promo codes are case-insensitive
- [ ] Expired codes are rejected with a clear message

## Out of scope
<What this does NOT cover>

## Links
Design: [Figma link]
ADR:    [Decision doc link]
```

---

## Priority guide

| Priority | When to use |
|----------|-------------|
| Urgent   | Production is broken or blocked; customer-facing data issue |
| High     | Must ship this cycle; blocks another team or upcoming launch |
| Medium   | Planned for this cycle; important but not blocking |
| Low      | Nice to have; backlog candidate for future cycles |
| No Priority | Idea / exploration — not yet committed |

**Rule:** If you're unsure between Urgent and High, it's High. True Urgent issues are rare.

---

## Estimation guide

| Points | Complexity |
|--------|------------|
| 1 | Trivial — config change, copy update, small bug fix |
| 2 | Small — one component, clear requirement, low risk |
| 3 | Medium — frontend + backend change, some design needed |
| 5 | Large — multi-component, DB change, or significant uncertainty |
| ? | Break it down — issues > 5 must be split before entering a cycle |

---

## Label system

**Type (one required):**
- `feature` — new capability
- `bug` — defect against existing behaviour
- `chore` — tech debt, refactor, dependency update
- `spike` — research / proof of concept

**Area (one required):**
- `frontend`
- `backend`
- `infra`
- `design`
- `data`

**Situational (optional):**
- `blocked` — waiting on something external
- `needs-design` — can't start without design sign-off
- `security` — has security implications; needs security review
- `breaking-change` — changes public API or contract

---

## Cycle workflow

**Cycle planning (Monday, start of cycle):**
1. Product prioritises the top of the backlog
2. Team pulls issues into the cycle — total estimate should not exceed team velocity
3. Every issue entering the cycle must have: estimate, label, assignee (or explicitly unassigned)

**Mid-cycle health check (Thursday / Friday):**
- If > 30% of issues are still in `Todo` or `In Progress` without movement, raise a flag
- Move blocked issues back to the backlog with a comment; don't let them sit silently

**Cycle close (Friday, end of cycle):**
- All `Done` issues are automatically archived
- Unfinished issues roll to next cycle — add a short comment: "Partial progress: [what's done]; remaining: [what's left]"
- Retro: what slowed us down? What should we pull less of next cycle?

---

## Status workflow

```
Backlog → In Progress → In Review → Done
              ↓
           Cancelled   (with reason in comment)
```

**Status meanings:**
- `Backlog` — prioritised but not in a cycle yet
- `Todo` — in the cycle, not yet started
- `In Progress` — actively being worked on
- `In Review` — PR open, waiting for review or merge
- `Done` — shipped (merged + deployed to prod for user-facing issues)
- `Cancelled` — won't do; always add a comment explaining why

---

## GitHub integration

**Setup:** Linear Settings → Integrations → GitHub

After setup:
- Commits and PRs containing the issue ID (`ENG-123`) auto-link to the issue
- Opening a PR moves the issue to `In Review`
- Merging the PR moves the issue to `Done` (configurable per workflow)

**Branch naming (Linear can auto-generate):**
```
feature/yourname/ENG-123-add-promo-code-checkout
fix/yourname/ENG-456-promo-total-calculation
chore/yourname/ENG-789-upgrade-stripe-sdk
```

**PR title:**
```
ENG-123 Add promo code support to checkout
```

**Commit messages:**
```
feat(checkout): add promo code validation

Implements discount calculation for percentage and flat-rate promo codes.
Expired and invalid codes return descriptive error messages.

ENG-123
```

---

## Projects

Projects are for multi-cycle, multi-team initiatives:

```
Project:  Payments V2
Owner:    @payments-lead
Status:   In Progress
Target:   2025-09-01

Milestones:
  ✅  M1: Core payment flow (Cycle 22)
  🔄  M2: Promo codes + discounts (Cycle 24–25)
  📋  M3: Subscription billing (Cycle 26+)

Description:
Upgrade our payment system to support promo codes, subscriptions,
and multi-currency checkout. Requires frontend, backend, and data changes.
```

**Project rules:**
- At least one milestone with a target date before launch
- Weekly status update on the project (Green / Yellow / Red)
- Link all relevant issues to the project — even if the issue also belongs to a team cycle

---

## Keyboard shortcuts (reference)

| Action | Shortcut |
|--------|----------|
| Create new issue | `C` |
| Search | `/` or `Ctrl+K` |
| Assign to me | `A` then `Me` |
| Change priority | `P` |
| Change status | `S` |
| Add label | `L` |
| Move to cycle | `Shift+C` |
| Open issue | `Enter` |
| Back | `Esc` |

---

## MCP integration

When the Linear MCP server is configured (via `/setup`), Claude can:
- List current cycle issues: `show my cycle issues`
- Create issues: `create a bug for the checkout total calculation`
- Update status: `mark ENG-123 as done`
- Search issues: `find all blocked issues in the current cycle`

Configuration in `.mcp.json`:
```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "@linear/mcp-server"],
      "env": {
        "LINEAR_API_KEY": "${LINEAR_API_KEY}"
      }
    }
  }
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Issues without estimates in a cycle | Estimate before pulling into a cycle — unestimated issues break velocity tracking |
| Using `Done` before it's deployed to production | Done = shipped; use `In Review` while the PR is open |
| Stale blocked issues with no comment | Add a comment when blocking; flag in standup the same day |
| Creating new labels instead of reusing | Search existing labels first — label sprawl makes filtering useless |
| Issues without a type label | Every issue needs `feature`, `bug`, `chore`, or `spike` |
| Projects without a target date | No target date = no accountability — always set one |
