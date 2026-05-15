---
name: bitbucket
description: Bitbucket — PR conventions, branch permissions, Bitbucket Pipelines, Jira integration, merge strategies
user-invocable: false
stack: source-control/bitbucket
paths:
  - "**/bitbucket-pipelines.yml"
  - "**/.bitbucket/**"
---

Full standards in [bitbucket.md](bitbucket.md). Always-on summary:

**Pull Requests:**
- PR title: `{type}: {description}` — mirrors Jira ticket title when possible
- Required: at least 2 approvals, CI passing, no unresolved tasks
- Link to Jira: include the issue key (`PROJ-123`) in the PR title or description — Bitbucket auto-links
- Use PR templates stored in `.bitbucket/pull-request-template.md`

**Branch Permissions:**
- Protect `main` and `develop` with branch restrictions: no direct pushes, no force pushes, no deletes
- Require a minimum of 2 approvals; reset approvals on new commits
- Require passing builds before merge

**Bitbucket Pipelines:**
- YAML at `bitbucket-pipelines.yml` in repo root
- Use `pipelines.branches.main` for deploy triggers; `pipelines.pull-requests` for PR checks
- Store secrets in Repository Variables or Workspace Variables — never in YAML

**Jira Integration:**
- Enable the Jira Software integration in workspace settings
- Smart commits: `git commit -m "PROJ-123 #comment Fixed the checkout bug #time 2h"`
- Transition Jira issues from commits: `PROJ-123 #done` closes the issue on merge

**Merge Strategies:**
- Use "Squash merge" for feature branches — clean main history
- Use "Merge commit" for release branches — preserves full history
- Never "Fast-forward only" on a team repo — loses merge context

**Never:**
- Push directly to `main` or `develop`
- Use personal passwords for Pipelines — use App Passwords or Repository Access Tokens
- Disable "Require passing builds" on protected branches
- Leave unresolved tasks in a PR — resolve or explicitly decline

**Related skills:** `conventional-commit`, `branch`, `pipeline`
