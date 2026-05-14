# GitHub Advanced Security (GHAS) Standards

---

## Dependabot configuration

```yaml
# .github/dependabot.yml
version: 2

updates:
  # npm / Node.js
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "UTC"
    open-pull-requests-limit: 10
    # Group minor + patch updates to reduce PR noise
    groups:
      minor-and-patch:
        update-types:
          - "minor"
          - "patch"
    # Label PRs for easy filtering
    labels:
      - "dependencies"
      - "automated"
    # Reviewers for dependency PRs
    reviewers:
      - "your-team-slug"
    # Ignore specific packages (e.g., locked to a version for a reason)
    ignore:
      - dependency-name: "some-locked-package"
        versions: ["2.x"]

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns:
          - "*"

  # Docker (if applicable)
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "docker"
      - "dependencies"
```

---

## CodeQL scanning

```yaml
# .github/workflows/codeql.yml
name: CodeQL

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  schedule:
    - cron: '30 1 * * 1'   # Weekly on Monday 01:30 UTC — catches new CVEs

jobs:
  analyze:
    name: Analyze (${{ matrix.language }})
    runs-on: ubuntu-latest
    permissions:
      actions:       read
      contents:      read
      security-events: write

    strategy:
      fail-fast: false
      matrix:
        language: ['javascript-typescript']   # add 'python', 'java', etc. as needed
        # Use 'javascript-typescript' for JS/TS projects (not 'javascript' alone)

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Initialise CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          queries: security-extended   # more thorough than security-and-quality

      - name: Build (for compiled languages)
        # For JS/TS — CodeQL auto-builds. For Java/C# etc., add build steps here.
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:${{ matrix.language }}"
```

---

## Secret scanning (repository settings)

Enable via GitHub Settings → Code Security:

```
✅ Secret scanning              — alerts when known secret patterns are detected
✅ Push protection              — blocks pushes that contain secrets before they land
✅ Secret scanning alerts       — notifies admins when secrets are found in history
```

### Custom patterns

```yaml
# Add to repository or organisation-level secret scanning
# Settings → Code Security → Secret scanning → Custom patterns

# Example: internal API key pattern
Name: Internal API Key
Pattern: MYAPP_[A-Za-z0-9]{32}
Secret group: 1

# Example: database connection string
Name: DB Connection String
Pattern: postgresql://[^:]+:[^@]+@[^/]+/\S+
```

### What to do when a secret is detected

1. **Revoke** the exposed secret immediately — do not wait
2. **Rotate** — generate a new secret and update all services that use it
3. **Remove** from git history using `git filter-repo` (not `git filter-branch`)
4. **Audit** — check access logs to determine if the secret was used maliciously

```bash
# Remove a file from git history (requires git-filter-repo)
pip install git-filter-repo
git filter-repo --path path/to/secrets.env --invert-paths
git push --force-with-lease origin main
```

---

## Branch protection rules

```
Repository Settings → Branches → Add rule → Branch name pattern: main

✅ Require a pull request before merging
  ✅ Require approvals: 1 (or 2 for production branches)
  ✅ Dismiss stale pull request approvals when new commits are pushed
  ✅ Require review from Code Owners

✅ Require status checks to pass before merging
  ✅ Require branches to be up to date before merging
  Status checks to require:
    - ci / lint
    - ci / test
    - CodeQL / Analyze (javascript-typescript)

✅ Require signed commits
✅ Require linear history                    (no merge commits — rebase only)
✅ Include administrators                    (admins follow the same rules)
✅ Restrict who can push to matching branches
   Allowed: release team role only
```

---

## CODEOWNERS

```
# .github/CODEOWNERS
# Format: <pattern> <GitHub username or team>

# Global default
*                         @org/engineering-leads

# Security-sensitive files require security team review
.github/workflows/        @org/devops
.github/dependabot.yml    @org/devops
src/auth/                 @org/security-team
src/middleware/auth*      @org/security-team
infra/                    @org/devops

# Database migrations require DBA review
**/migrations/            @org/dba-team
prisma/schema.prisma      @org/dba-team
```

---

## Security policy

```markdown
<!-- SECURITY.md -->
# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 2.x     | ✅        |
| 1.x     | ❌        |

## Reporting a vulnerability

**Do NOT open a public GitHub issue for security vulnerabilities.**

Report vulnerabilities via:
- GitHub Private Vulnerability Reporting (preferred): Security tab → Report a vulnerability
- Email: security@yourcompany.com (PGP key: [link])

Response SLA:
- Acknowledgement within 48 hours
- Initial assessment within 7 days
- Fix or mitigation within 30 days for critical issues
```

---

## Dependency review (PRs)

```yaml
# .github/workflows/dependency-review.yml
name: Dependency Review

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  dependency-review:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          # Fail if new deps have HIGH or CRITICAL CVEs
          fail-on-severity: high
          # Block packages with incompatible licences
          deny-licenses: AGPL-3.0, GPL-2.0, GPL-3.0
          comment-summary-in-pr: always
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| CodeQL only on schedule, not PRs | Add `pull_request` trigger — PRs should be blocked on CodeQL pass |
| Auto-merge all Dependabot PRs | Read the changelog for major bumps; test before merging |
| No branch protection on `main` | Require PRs, signed commits, and status checks |
| Disabling push protection to unblock a commit | Rotate the secret immediately — never bypass push protection |
| No CODEOWNERS for sensitive paths | Add `src/auth/`, `.github/workflows/`, `infra/` to CODEOWNERS |
| `security-and-quality` CodeQL suite | Use `security-extended` — more rules, more coverage |
| Secrets left in git history after rotation | Remove with `git filter-repo`; force-push; notify all contributors to re-clone |
