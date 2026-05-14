---
name: pr
description: Manage GitHub Pull Requests — create, merge, list, view, close, checkout, and check status. Usage — /devrunway:pr <sub-command> [args]. If first arg is a branch name (not a keyword), defaults to create.
argument-hint: <create|merge|list|view|close|checkout|checks|update> [args]
arguments:
  - name: subcommand
    description: "Sub-command or target branch for create (backward-compat)"
  - name: args
    description: "PR number, branch name, or other args"
user-invocable: true
allowed-tools:
  - Read
  - Bash(git *)
  - Bash(gh *)
  - mcp__git__create_pull_request
  - mcp__git__get_pull_request
  - mcp__git__list_pull_requests
  - mcp__git__merge_pull_request
  - mcp__git__get_pull_request_status
  - mcp__git__get_pull_request_files
  - mcp__git__get_pull_request_reviews
  - mcp__git__update_pull_request_branch
---

# PR Manager

Manage GitHub Pull Requests across the full lifecycle.

> **MCP preferred:** When the `github` MCP is active, use `mcp__git__*` tools (e.g. `mcp__git__create_pull_request`, `mcp__git__merge_pull_request`) instead of `gh` CLI. Fall back to `gh` CLI if MCP tools are unavailable.

**Sub-command dispatch:** `$ARGUMENTS[0]` is checked against known keywords below. If it matches, run that sub-command. If it does not match (or is a branch name like `develop`), treat as `/pr create $ARGUMENTS` — backward compatible with the old single-arg usage.

Known keywords: `create`, `merge`, `list`, `view`, `close`, `checkout`, `checks`, `update`

---

## `/pr create [target-branch]`

Create a GitHub PR from the current branch. Target branch defaults to `develop`.

### 1. Gather context

```bash
git branch --show-current
git log develop..HEAD --oneline
git diff develop...HEAD --stat
git status --short
```

Warn if there are uncommitted changes and ask whether to commit first.

### 2. Parse branch info

From the branch name (`feature/<ticket>-<desc>` or `fix/<ticket>-<desc>`):
- Extract ticket ID for the `Closes #N` footer
- Derive PR type: `feat` for feature branches, `fix` for fix branches
- Extract scope from the description segment

Target branch = `$ARGUMENTS` after the `create` keyword (or entire `$ARGUMENTS` if used backward-compat), defaulting to `develop`.

### 3. Read the diff

Use `git diff <target>...HEAD` to understand what changed. Read key changed files as needed.

### 4. Compose the PR

**Title:** `<type>(<scope>): <short summary ~50 chars>`

**Body:**
```
## What
<2-3 sentences describing what this PR does>

## Why
<motivation — link to the issue or business reason>

## Changes
- <key change 1>
- <key change 2>

## How to Test
1. <step>
2. <step>

## Screenshots
<!-- Add before/after screenshots if there are UI changes -->

## Checklist
- [ ] `tsc --noEmit` passes
- [ ] `eslint .` passes
- [ ] All tests pass
- [ ] No `console.log` in production code
- [ ] No hardcoded secrets

Closes #<issue-number>
```

### 5. Push and create

```bash
git push -u origin $(git branch --show-current)
gh pr create \
  --title "<title>" \
  --body "<body>" \
  --base <target-branch> \
  --assignee @me
```

Print the PR URL. Remind user to add reviewers with `gh pr edit <n> --add-reviewer <handle>`.

---

## `/pr merge <pr-number> [--squash|--rebase|--merge]`

Merge a PR after confirming its checks pass.

```bash
# Check status first
gh pr checks $PR_NUMBER

# If all pass, merge (default: squash)
gh pr merge $PR_NUMBER --squash --delete-branch
# or --rebase / --merge based on flag
```

If checks are failing, print the failures and abort. Do NOT merge with failing checks.

After merge, offer: "Switch back to develop and pull? (y/n)"

---

## `/pr list [filter]`

List open PRs. Optional filters: `mine`, `review-requested`, `draft`.

```bash
# All open PRs
gh pr list --state open --limit 20

# Assigned to me
gh pr list --assignee "@me" --state open

# Review requested from me
gh pr list --search "review-requested:@me" --state open
```

Format: `#N | Title | Author | Status | Checks`

---

## `/pr view <pr-number>`

Show full PR details including description, checks, and review status.

```bash
gh pr view $PR_NUMBER --comments
gh pr checks $PR_NUMBER
gh pr reviews $PR_NUMBER 2>/dev/null || true
```

---

## `/pr close <pr-number> [reason]`

Close a PR without merging.

```bash
gh pr close $PR_NUMBER --comment "${REASON:-Closing without merging}"
```

---

## `/pr checkout <pr-number>`

Check out a PR's branch locally for review or testing.

```bash
gh pr checkout $PR_NUMBER
```

Print the branch name and suggest running `/review run` to audit the code.

---

## `/pr checks <pr-number>`

Show CI/CD check status for a PR.

```bash
gh pr checks $PR_NUMBER --watch 2>/dev/null || gh pr checks $PR_NUMBER
```

Summarize: passing ✅, failing ❌, pending ⏳ counts. If failing, print the failed check names.

---

## `/pr update <pr-number>`

Update a PR: sync with base branch (rebase or merge).

```bash
# Update branch with latest from base
gh pr update-branch $PR_NUMBER
```

If `gh pr update-branch` is not available:
```bash
BASE=$(gh pr view $PR_NUMBER --json baseRefName -q .baseRefName)
git fetch origin $BASE
git rebase origin/$BASE
git push --force-with-lease
```
