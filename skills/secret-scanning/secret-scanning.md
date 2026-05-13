# Secret Scanning Standards

---

## What to scan for

### AWS credentials

```bash
# Access key ID pattern
grep -rn 'AKIA[0-9A-Z]\{16\}' --include='*.ts' --include='*.js' --include='*.json' --include='*.env' --include='*.yml' .

# Secret access key (often paired with access key)
grep -rni 'aws_secret_access_key\s*=\s*["\x27][^"\x27]\+' .
grep -rni 'secretAccessKey\s*:\s*["\x27][^"\x27]\+' .
```

### Database connection strings

```bash
# Postgres with password in URL
grep -rn 'postgres://[^:]\+:[^@]\+@' .
grep -rn 'postgresql://[^:]\+:[^@]\+@' .
grep -rn 'DATABASE_URL\s*=\s*["\x27]postgres' .
```

### API keys and tokens

```bash
# Generic API key patterns
grep -rni 'api[_-]key\s*[=:]\s*["\x27][a-zA-Z0-9_\-]\{16,\}' .
grep -rni 'token\s*[=:]\s*["\x27][a-zA-Z0-9_\-]\{20,\}' .

# JWT secrets
grep -rni 'jwt[_-]secret\s*[=:]\s*["\x27][^"\x27]\+' .
grep -rni 'JWT_SECRET\s*=' .
```

### Private keys

```bash
grep -rn 'BEGIN RSA PRIVATE KEY' .
grep -rn 'BEGIN EC PRIVATE KEY' .
grep -rn 'BEGIN OPENSSH PRIVATE KEY' .
```

### Cognito and AWS service IDs

```bash
# User pool IDs (eu-west-1_XXXXXXXXX pattern) hardcoded in source
grep -rn 'us-[a-z]\+-[0-9]_[A-Za-z0-9]\{9\}' --include='*.ts' --include='*.js' .

# Cognito app client IDs (26 char alphanumeric) hardcoded in source
grep -rn 'clientId\s*:\s*["\x27][a-z0-9]\{26\}["\x27]' .
```

### Committed .env files

```bash
# Find .env files tracked by git
git ls-files | grep -E '\.env$|\.env\.'

# Find .env files anywhere in working tree
find . -name '.env' -not -path './.git/*'
find . -name '.env.*' -not -name '.env.example' -not -path './.git/*'
```

---

## Scan git history (most important)

A file deleted in a later commit is still in the history. Always scan history.

```bash
# Scan entire git history for AWS key patterns
git log --all --full-history -p | grep -n 'AKIA[0-9A-Z]\{16\}'

# Scan history for any line containing 'password' or 'secret' being added
git log --all -p --diff-filter=A | grep -n 'password\|secret\|token\|api_key' | grep '^\+' | grep -v 'password_hash\|bcrypt\|placeholder\|example\|TODO'

# Check if .env was ever tracked
git log --all -- '*.env' --oneline
git log --all -- '.env' --oneline
```

---

## Automated scanning — gitleaks

Install and run locally:

```bash
# Install (macOS)
brew install gitleaks

# Scan working tree
gitleaks detect --source . --verbose

# Scan git history
gitleaks detect --source . --log-opts="--all" --verbose

# Output report
gitleaks detect --source . --report-format json --report-path gitleaks-report.json
```

Add to CI:

```yaml
# .github/workflows/ci.yml
- name: Scan for secrets
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## GitHub native secret scanning

Enable in the repository settings:

```
GitHub repo → Settings → Security → Secret scanning → Enable
         → Push protection → Enable (blocks pushes containing known secret patterns)
```

Push protection stops a secret before it lands in history — more effective than scanning after the fact.

Supported patterns include: AWS keys, GitHub tokens, Stripe keys, Twilio, SendGrid, and 200+ others.

---

## If a secret is found

### Step 1 — Rotate immediately

Assume the secret is compromised the moment it touches git, even in a private repo.

```bash
# AWS — rotate via console or CLI
aws iam create-access-key --user-name <user>
aws iam delete-access-key --access-key-id <old-key> --user-name <user>

# Cognito — rotate app client secret
aws cognito-idp describe-user-pool-client --user-pool-id <pool-id> --client-id <client-id>
# Regenerate in AWS Console: Cognito → User pools → App clients → Edit → Regenerate secret
```

### Step 2 — Remove from git history

**Deleting the file and committing does NOT remove it from history.**

```bash
# Install git-filter-repo (preferred over BFG or filter-branch)
pip install git-filter-repo

# Remove a specific file from all history
git filter-repo --path .env --invert-paths

# Remove lines matching a pattern from all history
git filter-repo --replace-text <(echo 'AKIAIOSFODNN7EXAMPLE==>REMOVED_KEY')

# Force push (coordinate with team — everyone must re-clone)
git push origin --force --all
git push origin --force --tags
```

### Step 3 — Audit for unauthorized use

```bash
# AWS CloudTrail — check for API calls using the compromised key
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<key-id> \
  --start-time $(date -v-7d +%Y-%m-%dT%H:%M:%SZ)

# Check CloudWatch logs for unusual patterns
aws logs filter-log-events \
  --log-group-name /aws/lambda/<function-name> \
  --filter-pattern "ERROR"
```

### Step 4 — Prevent recurrence

```bash
# Verify .gitignore has .env entries
cat .gitignore | grep -E '\.env'

# Add if missing
echo '.env' >> .gitignore
echo '.env.local' >> .gitignore
echo '.env.*.local' >> .gitignore
echo '.env.production' >> .gitignore
```

Ensure `.env.example` exists with all required variables but no real values:

```bash
# Good .env.example
DATABASE_URL=
COGNITO_USER_POOL_ID=
COGNITO_CLIENT_ID=
AWS_REGION=us-east-1
S3_BUCKET=
ALLOWED_ORIGINS=
SENTRY_DSN=
```

---

## Pre-commit hook — block secrets before they land

```bash
# .husky/pre-commit (if using Husky)
#!/bin/sh
npx gitleaks protect --staged --verbose
```

Or using the hooks already in the plugin — add to `hooks/scripts/`:

```bash
#!/usr/bin/env bash
# hooks/scripts/secret-guard.sh
# Blocks commits containing known secret patterns

STAGED=$(git diff --cached --diff-filter=ACM -U0)

if echo "$STAGED" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "❌ Possible AWS access key detected in staged changes. Remove before committing."
  exit 1
fi

if echo "$STAGED" | grep -qE '(password|secret|api_key)\s*[:=]\s*["\x27][^"\x27]{8,}'; then
  echo "⚠️  Possible credential in staged changes. Verify it is not a real secret."
fi

exit 0
```

---

## .gitignore baseline for this stack

```
# Secrets and environment
.env
.env.local
.env.*.local
.env.production
.env.staging
*.pem
*.key
*.p12
*.pfx

# AWS
.aws/credentials

# Build outputs
dist/
build/
.next/
out/

# Dependencies
node_modules/

# IDE
.vscode/settings.json
.idea/

# Test and coverage
coverage/
playwright-report/
test-results/

# CDK
cdk.out/
cdk.context.json
```
