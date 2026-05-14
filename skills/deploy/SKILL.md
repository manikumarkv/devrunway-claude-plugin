---
name: deploy
description: Deploy to AWS with pre-flight checks, check deployment status, or rollback. Usage — /devrunway:deploy <staging|prod> OR /devrunway:deploy <status|rollback> [env]
argument-hint: <staging|prod|status|rollback> [env]
arguments:
  - name: subcommand
    description: "staging|prod to deploy, 'status' to check, 'rollback' to revert"
  - name: env
    description: "For status/rollback: staging or prod"
user-invocable: true
effort: high
allowed-tools:
  - Bash(git *)
  - Bash(npm *)
  - Bash(npx *)
  - Bash(aws *)
  - Bash(curl *)
  - Bash(jq *)
---

# Deploy to AWS

## Configuration — resolve these before running any command

Before executing any command, look up the real values for these placeholders:

| Placeholder | Where to find it |
|---|---|
| `<project>` | `package.json` → `.name` field (strip any `@scope/` prefix, e.g. `@acme/api` → `api`) |
| `<DIST_ID>` | CloudFormation: `aws cloudformation describe-stacks --stack-name <project>-$ENV --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" --output text` — or SSM: `aws ssm get-parameter --name "/<project>/$ENV/cloudfront/distribution-id" --query Parameter.Value --output text` |
| `<domain>` | SSM: `aws ssm get-parameter --name "/<project>/$ENV/domain" --query Parameter.Value --output text` — or CDK stack outputs / Route53 hosted zone name |

Resolve all three at the start of every run. If any value cannot be found, **stop immediately** and tell the user which placeholder is missing and how to set it (SSM put-parameter or CDK output export).

---

**Sub-command dispatch:**
- `$ARGUMENTS[0]` = `staging` or `prod` → run deploy for that environment
- `$ARGUMENTS[0]` = `status` → run status check for `$ARGUMENTS[1]` (default: staging)
- `$ARGUMENTS[0]` = `rollback` → run rollback for `$ARGUMENTS[1]`

---

## `/deploy <staging|prod>`

### 1. Production gate

If environment is `prod`, immediately ask the user to confirm:
```
⚠️  You are about to deploy to PRODUCTION.
Current branch: <branch>
Last commit: <message>

Type 'yes' to continue.
```
Do not proceed until user types `yes`.

### 2. Pre-flight checks

Run in order, stopping immediately on any failure:

**Git state:**
```bash
git status --short
git branch --show-current
git log -1 --format="%H %s"
```
- Uncommitted changes → **abort**
- Deploying to `prod` and branch is not `main` → warn and require explicit confirmation

**TypeScript:**
```bash
npx tsc --noEmit
```
Any error → **abort**

**Lint:**
```bash
npx eslint . --max-warnings 0
```
Any error → **abort**

**Tests:**
```bash
npm test -- --passWithNoTests
```
Any failure → **abort**

**AWS credentials:**
```bash
aws sts get-caller-identity
aws configure get region
```
Invalid → abort, instruct user to run `aws sso login`

**SSM parameters:**
```bash
aws ssm get-parameters-by-path --path "/<project>/$ENV/" --query "Parameters[*].Name"
```
List any missing required parameters. Missing → abort.

### 3. Pre-flight summary

```
Pre-Flight Checks
=================
Git:          ✅ Clean — <branch> @ <short-sha>
TypeScript:   ✅
Lint:         ✅
Tests:        ✅
AWS:          ✅ account <id>, region <region>
SSM params:   ✅

Target: <env>
Proceed? (yes/no)
```

Wait for `yes`.

### 4. Deploy

**Infrastructure (CDK):**
```bash
cd infra
npm run build
npx cdk deploy --all --context env=$ENV --require-approval never
```

**Frontend (if `dist/` or `build/` exists):**
```bash
npm run build
aws s3 sync dist/ s3://<project>-$ENV-frontend-bucket/ \
  --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "index.html"
aws s3 cp dist/index.html s3://<project>-$ENV-frontend-bucket/ \
  --cache-control "no-cache"
aws cloudfront create-invalidation --distribution-id <DIST_ID> --paths "/*"
```

### 5. Post-deploy verification

```bash
curl -sf https://api-$ENV.<domain>/health | jq .
```

Check CloudWatch for errors in the last 5 minutes:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/<project>-$ENV \
  --start-time $(date -d '5 minutes ago' +%s000 2>/dev/null || date -v-5M +%s000) \
  --filter-pattern '"level":"error"'
```

If health check fails or CloudWatch has errors — notify the user immediately. Do NOT auto-rollback.

### 6. Deployment summary

```
Deployment Complete ✅
======================
Environment:  <env>
Branch:       <branch>
Commit:       <sha> — <message>
Deployed at:  <timestamp>

Next steps:
- Run: /deploy status <env>  — monitor health
- If prod: post in Slack #deployments
```

---

## `/deploy status [env]`

Check the current health of an environment. Default env: `staging`.

```bash
ENV=${ENV:-staging}

# Health endpoint
echo "=== Health Check ==="
curl -sf https://api-$ENV.<domain>/health | jq . || echo "❌ Health endpoint unreachable"

# Recent errors (last 15 min)
echo ""
echo "=== Recent Errors (last 15 min) ==="
START=$(date -d '15 minutes ago' +%s000 2>/dev/null || date -v-15M +%s000)
aws logs filter-log-events \
  --log-group-name /aws/lambda/<project>-$ENV \
  --start-time $START \
  --filter-pattern '"level":"error"' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' | jq -s 'length' | xargs -I{} echo "Error count: {}"

# Lambda metrics (p95 latency)
echo ""
echo "=== Lambda p95 Latency (last 15 min) ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=<project>-$ENV \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-15M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 900 \
  --statistics p95 \
  --output table
```

Print a health summary:
```
Status: $ENV — <timestamp>
============================
API Health:    ✅ / ❌
Error count:   N (last 15 min)
p95 Latency:   <N>ms

Overall: 🟢 Healthy / 🟡 Degraded / 🔴 Unhealthy
```

---

## `/deploy rollback <env>`

Roll back to the previous Lambda version and/or CloudFront distribution.

```bash
ENV=$1  # staging or prod

# Confirm
echo "⚠️  Rolling back $ENV. This will revert Lambda to the previous published version."
echo "Type 'yes' to confirm."
```

Wait for `yes`.

```bash
# Roll back Lambda function aliases
FUNCTION_NAME="<project>-$ENV"
CURRENT_VERSION=$(aws lambda get-alias \
  --function-name $FUNCTION_NAME \
  --name live \
  --query FunctionVersion --output text)

PREV_VERSION=$((CURRENT_VERSION - 1))

aws lambda update-alias \
  --function-name $FUNCTION_NAME \
  --name live \
  --function-version $PREV_VERSION

echo "Lambda rolled back from v$CURRENT_VERSION → v$PREV_VERSION"

# CloudFront: list last 2 distributions and invalidate
aws cloudfront create-invalidation \
  --distribution-id <DIST_ID> \
  --paths "/*"
```

After rollback:
```
Rollback Complete
=================
Environment: <env>
Lambda:      v<current> → v<prev>
CloudFront:  cache invalidated

Run: /deploy status <env>  — verify rollback is healthy
```

Remind user: if rollback does not resolve the issue, run `/debug logs` to investigate.
