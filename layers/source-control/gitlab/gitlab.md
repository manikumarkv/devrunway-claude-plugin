# GitLab Workflow Standards

---

## Branch strategy (GitLab Flow)

```
main  ←  always production-ready; protected
  │
  ├─ feature/GLB-123-add-promo-codes    (feature branch — merge to main)
  ├─ feature/GLB-456-search-refactor
  ├─ hotfix/GLB-789-payment-crash       (from production tag — urgent fix)
  └─ release/v2.1.0                     (optional release branch)
```

**Rules:**
- Never commit directly to `main`
- Feature branches live max 1-2 days; longer work uses feature flags
- Hotfixes branch from the production tag, not from `main` (in case `main` has unreleased work)

---

## Merge Request conventions

### Title format
```
feat(checkout): add promo code support       ← feature
fix(orders): correct total calculation       ← bug fix
chore(deps): upgrade stripe to v14           ← dependency
docs(api): document order endpoints          ← documentation
refactor(auth): extract token validation     ← refactor
```

### Description template (`.gitlab/merge_request_templates/Default.md`)

```markdown
## What
<!-- What does this MR change? -->

## Why
<!-- Why is this change needed? Link to the issue: Closes #123 -->

## Type of change
- [ ] Feature
- [ ] Bug fix
- [ ] Refactor (no feature change)
- [ ] Documentation

## Testing
<!-- How did you test this? -->
- [ ] Unit tests added/updated
- [ ] Manual test steps: ...

## Screenshots
<!-- If UI changes, include before/after screenshots -->

## Checklist
- [ ] Code reviewed by self before requesting review
- [ ] Tests pass in CI
- [ ] No secrets or PII in code or logs
- [ ] Closes #[issue number]
```

---

## Labels

**Type (one required):**
- `~feature` — new capability
- `~bug` — defect
- `~chore` — maintenance, deps, refactor
- `~docs` — documentation only
- `~spike` — research

**Area (one required):**
- `~frontend` `~backend` `~infra` `~database` `~design`

**Priority:**
- `~priority::critical` — blocking production
- `~priority::high` — must ship this sprint
- `~priority::medium` — planned
- `~priority::low` — nice to have

**Status:**
- `~blocked` — waiting on something
- `~needs-review` — MR open, needs reviewer attention

---

## Issue conventions

```markdown
<!-- Issue title: imperative verb phrase -->
Add promo code support to checkout

<!-- Description -->
## Context
Users have been requesting promo codes for 3 months.

## Acceptance Criteria
- [ ] User can enter a code at checkout
- [ ] Valid codes apply discounts
- [ ] Invalid/expired codes show errors

## Out of scope
- Admin interface for creating promo codes (separate issue)
```

**Quick Actions in comments:**
```
/assign @username               assign issue
/milestone %"Sprint 12"        set milestone
/label ~bug ~backend            add labels
/due 2025-06-01                 set due date
/estimate 3h                    set time estimate
/spend 2h                       log time spent
/close                          close issue
/reopen                         reopen issue
```

---

## GitLab Flow — working on a feature

```bash
# 1. Create branch from main
git fetch origin
git checkout -b feature/GLB-123-add-promo-codes origin/main

# 2. Work and commit
git add src/checkout/promo-codes.ts
git commit -m "feat(checkout): add promo code validation [GLB-123]"

# 3. Push and create MR
git push -u origin feature/GLB-123-add-promo-codes

# 4. In GitLab UI:
#    - Create MR: source = feature/GLB-123, target = main
#    - Mark as Draft if not ready
#    - Fill description template
#    - Assign reviewer
#    - Add label ~feature ~backend

# 5. After approval, merge with squash
# 6. Branch auto-deleted (enable in Project Settings)
# 7. GitLab auto-closes GLB-123 via "Closes #123" in description
```

---

## Protected branch settings

```
Project Settings → Repository → Protected Branches

Branch: main
  ✅ No one can push (except Maintainers with "Allowed to merge")
  ✅ No one can force push
  Allowed to merge: Maintainers
  Allowed to push: No one

Branch: release/*
  ✅ No force push
  Allowed to merge: Maintainers
  Allowed to push: Maintainers

Tag: v*
  ✅ Protected
  Allowed to create: Maintainers
```

---

## Merge request settings

```
Project Settings → Merge requests

✅ Squash commits when merging (default: optional per MR)
✅ Delete source branch by default
✅ Require approval from code owners (if CODEOWNERS file exists)
✅ Pipelines must succeed before merge can happen
  Minimum approvals: 1

Merge method: Merge commit with semi-linear history
  (keeps history readable without full rebases)
```

---

## CODEOWNERS

```
# .gitlab/CODEOWNERS
# Format: path  @user  or  @group

[Default]
*                               @engineering-leads

[Security]
src/auth/                       @security-team
src/middleware/auth*            @security-team
.gitlab-ci.yml                  @devops

[Database]
db/migrations/                  @dba-team
```

---

## Hotfix workflow

```bash
# 1. Find the production tag
git tag | grep v2

# 2. Branch from the tag (not from main — main may have unreleased features)
git checkout -b hotfix/GLB-789-payment-crash v2.1.0

# 3. Fix and commit
git commit -m "fix(payments): prevent crash when card is declined [GLB-789]"

# 4. Create MR targeting main (and the release branch if applicable)
# 5. After merge to main, tag a new release
git tag v2.1.1
git push origin v2.1.1

# 6. Deploy from the tag
```

---

## GitLab CI/CD integration

```yaml
# .gitlab-ci.yml — see ci/gitlab-ci layer for full config

# Merge request pipelines — run on every MR push
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG

# Auto DevOps alternatives
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Long-lived feature branches (> 2 days) | Use feature flags; merge small increments daily |
| MR without description | Fill the template — reviewers shouldn't have to guess what changed |
| Merging without CI passing | Enforce in Protected Branches settings |
| No issue linked to MR | Add `Closes #123` to description — closes the issue automatically |
| Force-pushing to `main` | Never — enable branch protection to prevent it |
| Hotfix from `main` instead of production tag | Branch from the production tag when `main` has unreleased changes |
