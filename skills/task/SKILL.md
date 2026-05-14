---
name: task
description: Manage GitHub Issues — create, update, list, view, close, and start work on stories or tasks. Usage — /devrunway:task <sub-command> [args]
argument-hint: <create|update|list|view|close|start> [args]
arguments:
  - name: subcommand
    description: "Sub-command: create, update, list, view, close, start"
  - name: args
    description: Additional arguments (issue number, title, body text, labels, etc.)
user-invocable: true
allowed-tools:
  - Read
  - Bash(gh *)
  - Bash(git *)
  - mcp__git__create_issue
  - mcp__git__get_issue
  - mcp__git__list_issues
  - mcp__git__update_issue
  - mcp__git__add_issue_comment
---

# Task Manager

Manage GitHub Issues for stories, features, and bug reports.

> **MCP preferred:** When the `github` MCP is active, use `mcp__git__*` tools (e.g. `mcp__git__create_issue`, `mcp__git__list_issues`) instead of `gh` CLI — they are more reliable with long bodies and structured data. Fall back to `gh` CLI if MCP tools are unavailable.

Sub-command is `$ARGUMENTS[0]`. Remaining words are `$ARGUMENTS` minus the first token.

---

## `/task create [title]`

Create a new GitHub issue in the current repository. Prompt the user for any missing fields.

```bash
# Detect repo from git remote
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)

gh issue create \
  --repo "$REPO" \
  --title "$TITLE" \
  --body "$BODY" \
  --label "$LABELS"
```

**Body template to fill in:**
```markdown
## Description
<what needs to be built and why>

## User Story
As a <role>, I want <action> so that <benefit>.

## Acceptance Criteria
- [ ] <specific, testable condition>
- [ ] Unit tests written and passing (coverage ≥ 80%)
- [ ] Playwright E2E test covers the happy path
- [ ] Bruno API collection updated (if BE changes)
- [ ] `tsc --noEmit` passes, ESLint passes, no `console.log`

## Estimate
<1 | 2 | 3 | 5 | 8> story points
```

After creating, print the issue URL and suggest: "Run `/branch create <issue-number> <short-name>` to start work."

---

## `/task update <issue-number> [field=value ...]`

Update an existing issue. Supported fields: `title`, `body`, `label`, `milestone`, `assignee`.

```bash
gh issue edit $ISSUE_NUMBER \
  --repo "$REPO" \
  [--title "..." | --add-label "..." | --remove-label "..." | --add-assignee "..."]
```

Show the updated issue after editing.

---

## `/task list [filter]`

List open issues. Optional filter: `mine`, `label:<name>`, `milestone:<name>`.

```bash
# All open
gh issue list --repo "$REPO" --state open --limit 20

# Assigned to me
gh issue list --repo "$REPO" --assignee "@me" --state open

# By label
gh issue list --repo "$REPO" --label "$FILTER" --state open
```

Format output as a table: `#  |  Title  |  Labels  |  Assignee  |  Points`.

---

## `/task view <issue-number>`

Show full issue details including comments.

```bash
gh issue view $ISSUE_NUMBER --repo "$REPO" --comments
```

---

## `/task close <issue-number> [reason]`

Close an issue. Reason defaults to `completed`; use `not-planned` if explicitly stated.

```bash
gh issue close $ISSUE_NUMBER --repo "$REPO" --reason "${REASON:-completed}"
```

---

## `/task start <issue-number>`

Start work on an issue: assign it to yourself, add the `in-progress` label, then offer to create a branch.

```bash
ME=$(gh api user --jq .login)
gh issue edit $ISSUE_NUMBER \
  --repo "$REPO" \
  --add-assignee "$ME" \
  --add-label "in-progress"

gh issue view $ISSUE_NUMBER --repo "$REPO" --json title,number \
  | jq -r '"Issue #\(.number): \(.title)"'
```

After assigning, prompt: "Run `/branch create $ISSUE_NUMBER <short-name>` to create the feature branch."
