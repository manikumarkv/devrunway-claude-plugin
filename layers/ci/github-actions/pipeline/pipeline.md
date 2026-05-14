# CI/CD Pipeline Standards

---

## Branch strategy

| Branch | Purpose | Protection |
|---|---|---|
| `main` | Production | Required: PR + approval + all checks |
| `develop` | Staging | Required: PR + all checks |
| `feature/<ticket>-<slug>` | New features | None (push freely) |
| `fix/<ticket>-<slug>` | Bug fixes | None |
| `hotfix/<ticket>-<slug>` | Prod hotfixes | Merge to `main` AND `develop` |

**Never push directly to `main` or `develop`.** PRs only.

---

## GitHub Actions workflows

### CI — runs on every PR to `develop` or `main`

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [develop, main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - run: npm ci

      - name: TypeScript
        run: npx tsc --noEmit

      - name: Lint
        run: npx eslint . --max-warnings 0

      - name: Unit tests
        run: npx vitest run --coverage
        env:
          COVERAGE_THRESHOLD: 80

      - name: Build
        run: npm run build
```

### Deploy to staging — runs on merge to `develop`

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy — Staging

on:
  push:
    branches: [develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - run: npm ci

      - name: Build
        run: npm run build
        env:
          VITE_API_URL: ${{ secrets.STAGING_API_URL }}

      - name: Deploy frontend
        run: aws s3 sync dist/ s3://${{ secrets.STAGING_BUCKET }} --delete
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ secrets.AWS_REGION }}

      - name: Invalidate CloudFront
        run: aws cloudfront create-invalidation --distribution-id ${{ secrets.STAGING_DIST_ID }} --paths "/*"
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ secrets.AWS_REGION }}

      - name: Deploy API (CDK)
        run: npx cdk deploy ApiStack --require-approval never --context env=staging
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ secrets.AWS_REGION }}
```

### Deploy to production — runs on merge to `main`, requires approval

```yaml
# .github/workflows/deploy-prod.yml
name: Deploy — Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production       # ← requires manual approval in GitHub Environments
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - run: npm ci

      - name: Build
        run: npm run build
        env:
          VITE_API_URL: ${{ secrets.PROD_API_URL }}

      - name: Deploy frontend
        run: aws s3 sync dist/ s3://${{ secrets.PROD_BUCKET }} --delete
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ secrets.AWS_REGION }}

      - name: Invalidate CloudFront
        run: aws cloudfront create-invalidation --distribution-id ${{ secrets.PROD_DIST_ID }} --paths "/*"
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ secrets.AWS_REGION }}

      - name: Deploy API (CDK)
        run: npx cdk deploy ApiStack --require-approval never --context env=prod
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ secrets.AWS_REGION }}
```

---

## Branch protection rules

Configure in GitHub → Settings → Branches → Add rule.

### `main`
```
✅ Require a pull request before merging
  ✅ Require approvals: 1
  ✅ Dismiss stale pull request approvals when new commits are pushed
✅ Require status checks to pass before merging
  Required checks:
    - check / TypeScript
    - check / Lint
    - check / Unit tests
    - check / Build
✅ Require branches to be up to date before merging
✅ Do not allow bypassing the above settings
```

### `develop`
```
✅ Require a pull request before merging
✅ Require status checks to pass before merging
  Required checks: (same as main)
✅ Require branches to be up to date before merging
```

---

## GitHub Environments

Set up in GitHub → Settings → Environments.

### `staging`
- No approval required
- Secrets: `STAGING_API_URL`, `STAGING_BUCKET`, `STAGING_DIST_ID`, `AWS_*`

### `production`
- Required reviewers: [tech lead or yourself]
- Deployment branches: `main` only
- Secrets: `PROD_API_URL`, `PROD_BUCKET`, `PROD_DIST_ID`, `AWS_*`

---

## Secrets management

| What | Where | Never |
|---|---|---|
| AWS credentials | GitHub Secrets | In workflow files |
| API keys | GitHub Secrets | In `.env` committed to git |
| Cognito client IDs | GitHub Secrets or SSM | Hard-coded |
| Public env vars (API URL) | GitHub Secrets | `.env` committed to git |

**Access pattern in CDK:**

```ts
// Read from SSM at deploy time — never hard-code
const dbPassword = ssm.StringParameter.valueForSecureStringParameter(
  this, 'DbPassword', '/myapp/prod/db-password'
)
```

---

## Deployment gates

```
feature/fix branch
       ↓  PR → develop
   develop ──→ auto-deploy to staging
       ↓  PR → main (requires approval)
     main ──→ deploy to production (requires environment approval)
```

- Hotfixes: branch from `main`, PR to `main` AND `develop`
- Never deploy from a feature branch
- Never merge a PR with failing checks
- Always run `npm run build` before deploying — catch build failures early

---

## PR template

Create `.github/pull_request_template.md`:

```markdown
## What
<!-- One-sentence description -->

## Why
<!-- Ticket link or reason -->

## Checklist
- [ ] `tsc --noEmit` passes locally
- [ ] `eslint .` zero errors
- [ ] Tests pass, coverage ≥ 80%
- [ ] `npm run build` succeeds
- [ ] No secrets committed
- [ ] Reviewed diff for unintended changes
```

---

## Never

- Push directly to `main` or `develop`
- Merge with failing CI checks
- Store secrets in workflow files — use GitHub Secrets or AWS SSM
- Deploy from a feature branch
- Skip manual approval gate for production
- Use `--force` push on protected branches
