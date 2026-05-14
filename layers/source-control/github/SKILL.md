---
name: github-projects
description: GitHub project management standards — issue templates, label taxonomy, milestone conventions, gh CLI patterns, PR workflow. Load when managing GitHub issues, PRs, or projects.
user-invocable: false
stack: source-control/github
mcp:
  package: "@modelcontextprotocol/server-github"
  env:
    GITHUB_PERSONAL_ACCESS_TOKEN: "github.com → Settings → Developer settings → Personal access tokens → Fine-grained → Create"
paths:
  - ".github/**"
  - "*.md"
---

Full standards in [github-projects.md](github-projects.md). Always-on summary:

**Issue labels:** `type: bug`, `type: feature`, `type: chore`, `priority: p0/p1/p2`, `status: blocked`, `size: S/M/L/XL`

**Branch naming:** `feat/123-short-description`, `fix/456-what-broke` — always include issue number

**PR title:** follows conventional commit format — `feat(auth): add JWT refresh endpoint`

**Auto-close:** use `Closes #123` in PR body to auto-close linked issue on merge

**Milestones:** name as `v1.2.0`, set due date from sprint end, link to CHANGELOG section

**`gh` CLI patterns:**
- `gh issue list --label "priority: p0"` — view urgent issues
- `gh pr create --draft` — open draft PR early
- `gh run list --workflow=ci.yml` — check pipeline status

**MCP:** when GitHub MCP is active, prefer `mcp__git__*` tools over `gh` CLI for issue/PR operations
