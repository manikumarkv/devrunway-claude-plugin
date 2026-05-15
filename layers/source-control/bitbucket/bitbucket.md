# Bitbucket Standards

## PR Template

```markdown
<!-- .bitbucket/pull-request-template.md -->
## PROJ-XXX: [Ticket title here]
<!-- Replace PROJ-XXX with the Jira issue key -->

## Summary
<!-- What changed and why? -->

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Refactor / chore
- [ ] Documentation

## Test plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Tested manually in staging: [link to env]

## Checklist
- [ ] PR title includes Jira issue key (`PROJ-123: feat: ...`)
- [ ] No secrets or credentials in the diff
- [ ] Database migrations are reversible
- [ ] Breaking changes flagged with `breaking:` label
- [ ] All PR tasks resolved or declined with a comment
```

## Bitbucket Pipelines

```yaml
# bitbucket-pipelines.yml
image: node:20-alpine

definitions:
  caches:
    npm: ~/.npm

  steps:
    - step: &install-and-test
        name: Install and Test
        caches:
          - npm
        script:
          - npm ci
          - npm run lint
          - npm test -- --ci --coverage
        artifacts:
          - coverage/**

    - step: &build
        name: Build
        caches:
          - npm
        script:
          - npm ci
          - npm run build
        artifacts:
          - dist/**

    - step: &deploy-staging
        name: Deploy to Staging
        deployment: staging
        script:
          - pipe: atlassian/aws-elastic-beanstalk-deploy:0.7.3
            variables:
              AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
              AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
              AWS_DEFAULT_REGION: us-east-1
              APPLICATION_NAME: myapp
              ENVIRONMENT_NAME: myapp-staging
              ZIP_FILE: dist.zip

    - step: &deploy-prod
        name: Deploy to Production
        deployment: production
        trigger: manual    # require manual trigger in prod
        script:
          - pipe: atlassian/aws-elastic-beanstalk-deploy:0.7.3
            variables:
              AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
              AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
              AWS_DEFAULT_REGION: us-east-1
              APPLICATION_NAME: myapp
              ENVIRONMENT_NAME: myapp-production
              ZIP_FILE: dist.zip

pipelines:
  pull-requests:
    "**":
      - step: *install-and-test

  branches:
    main:
      - step: *install-and-test
      - step: *build
      - step: *deploy-staging
      - step: *deploy-prod

    "release/*":
      - step: *install-and-test
      - step: *build
```

## Secrets and Variables

```
Repository Settings → Repository Variables:
  - AWS_ACCESS_KEY_ID        (secured ✓)
  - AWS_SECRET_ACCESS_KEY    (secured ✓)
  - DATABASE_URL             (secured ✓)

Workspace Settings → Workspace Variables (shared across repos):
  - SONAR_TOKEN              (secured ✓)
  - SLACK_WEBHOOK_URL        (secured ✓)

Deployment Variables (per environment):
  Staging:
    - API_URL = https://api-staging.example.com
  Production:
    - API_URL = https://api.example.com
```

## Branch Permissions (REST API)

```bash
# Set branch restrictions via Bitbucket REST API
BB_WORKSPACE="my-workspace"
BB_REPO="myapp-api"
BB_TOKEN="your-app-password"

# No direct pushes to main
curl -s -X POST \
  "https://api.bitbucket.org/2.0/repositories/${BB_WORKSPACE}/${BB_REPO}/branch-restrictions" \
  -H "Content-Type: application/json" \
  -u "your-username:${BB_TOKEN}" \
  -d '{
    "kind": "push",
    "pattern": "main",
    "users": [],
    "groups": []
  }'

# Require minimum 2 approvals
curl -s -X POST \
  "https://api.bitbucket.org/2.0/repositories/${BB_WORKSPACE}/${BB_REPO}/branch-restrictions" \
  -H "Content-Type: application/json" \
  -u "your-username:${BB_TOKEN}" \
  -d '{
    "kind": "require_approvals_to_merge",
    "pattern": "main",
    "value": 2
  }'

# Require passing builds
curl -s -X POST \
  "https://api.bitbucket.org/2.0/repositories/${BB_WORKSPACE}/${BB_REPO}/branch-restrictions" \
  -H "Content-Type: application/json" \
  -u "your-username:${BB_TOKEN}" \
  -d '{
    "kind": "require_passing_builds_to_merge",
    "pattern": "main",
    "value": 1
  }'
```

## Jira Integration — Smart Commits

```bash
# Transition and comment
git commit -m "PROJ-123 #in-progress Starting checkout redesign"

# Log time
git commit -m "PROJ-123 #time 1h 30m Refactored payment validation logic"

# Close issue on merge
git commit -m "PROJ-123 #done Fix applied — squash merging to main"

# Multiple issues in one commit
git commit -m "PROJ-123 PROJ-124 #done Fix shared validation bug"
```

Jira transitions must match the workflow transition names configured in Jira (case-insensitive):
- `#start` or `#in-progress` — moves to "In Progress"
- `#review` — moves to "In Review"
- `#done` or `#close` — moves to "Done"

## Merge Strategies

| Branch type | Merge strategy | Reason |
|---|---|---|
| Feature → develop | Squash | Clean linear history |
| Hotfix → main | Merge commit | Preserve hotfix context |
| Release → main | Merge commit | Full release history |
| Develop → main | Merge commit | Integration point preserved |

Configure in Repository Settings → Branching model → Merge strategies.

## App Passwords (CI/CD Auth)

1. Account Settings → App Passwords → Create App Password
2. Label: `{service}-ci`
3. Scopes: Repositories (Read), Pull Requests (Read), Pipelines (Read, Write)
4. Store in Pipelines Repository Variables — never in code

Never use your personal Bitbucket password in CI.

## Atlassian Access / SSO

If using Atlassian Access:
- Enforce SSO for all workspace members
- Disable username+password login for managed accounts
- Use SCIM provisioning to sync users from your IdP (Okta, Azure AD)

## Checklist

- [ ] Branch restrictions set on `main`: no direct push, no force push, no delete
- [ ] Min 2 approvals required with "reset on new commits" enabled
- [ ] Passing builds required before merge
- [ ] PR template at `.bitbucket/pull-request-template.md`
- [ ] All secrets in Repository or Workspace Variables (secured)
- [ ] Jira integration enabled — `PROJ-XXX` in all commit messages
- [ ] App Passwords used for CI — not personal passwords
- [ ] Merge strategy configured per branch type

## Common mistakes

| Mistake | Fix |
|---|---|
| Using personal Bitbucket passwords in CI pipelines | Create App Passwords with minimum required scopes (Repositories Read, Pipelines Write) and store them as secured repository variables |
| Storing secrets as unsecured pipeline variables | Mark every secret variable as "Secured" in Repository Settings → Repository Variables — unsecured values appear in plain text in the UI |
| Not setting "Reset approvals on new commits" | Without this, a stale approval from an earlier version remains valid after new code is pushed; enable it in branch restriction settings |
| Triggering a production deployment step without a `trigger: manual` gate | Set `trigger: manual` on the production step so a human must explicitly approve before artifacts go live |
| Jira smart commit transitions using wrong workflow names | Transition names must match your Jira workflow exactly (case-insensitive); test with `#done` vs the actual transition name configured in Jira |
| Committing secrets to the repository and relying on later deletion | Git history retains deleted secrets; rotate the credential immediately and use Bitbucket's push rules to block secret patterns |
| Skipping the squash merge strategy for feature branches | Without squash, dozens of WIP commits pollute the main branch history; configure squash in Repository Settings → Branching model |
