---
name: gitlab
description: GitLab workflow standards — merge requests, CI/CD integration, branch strategy, issue conventions, and GitLab Flow. Load when working with GitLab.
user-invocable: false
stack: source-control/gitlab
paths:
  - ".gitlab-ci.yml"
  - ".gitlab/**"
---

Full standards in [gitlab.md](gitlab.md). Always-on summary:

**Merge Requests:**
- Titles: same format as commit messages — `feat(checkout): add promo code support`
- Always fill in the MR description template: What, Why, Testing, Screenshots
- Mark as `Draft:` when work is in progress — remove Draft when ready for review
- Assign a reviewer before requesting review — don't leave it unassigned
- Squash commits on merge for feature branches; preserve history for hotfixes

**Branch strategy (GitLab Flow):**
- `main` → production (always deployable)
- Feature branches: `feature/GLB-123-short-description` from `main`
- Hotfixes: `hotfix/GLB-456-critical-bug` from the affected production tag
- No long-lived `develop` branch — merge to `main` with feature flags for incomplete work

**Issues:**
- Every MR links to a GitLab issue via `Closes #123` or `Resolves #123` in the description
- Milestones = releases or sprints; Labels = type + area + priority
- Use Quick Actions in issue comments: `/assign @username`, `/due 2025-06-01`, `/label ~bug`

**Protected branches:**
- `main` must be protected: no force-push, Maintainers only can merge, CI must pass
- Tag protection: all release tags (`v*`) require Maintainer to create

**Never:**
- Merge without at least one approval (configure in Project Settings → Merge requests)
- Force-push to `main` or release branches
- Close issues without a reference to the MR that fixed them

**Related skills:** `ci/gitlab-ci` (pipeline config), `core/conventional-commit`
