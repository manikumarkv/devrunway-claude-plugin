---
name: validate
description: Validate a deployed feature by comparing error rates, checking analytics events fired, scanning Sentry, and producing a ship-green or rollback-recommended verdict. Usage — /validate <issue-number> [--env prod|staging]
argument-hint: "<issue-number> [--env prod|staging]"
arguments:
  - name: issue
    description: "GitHub issue number for the feature being validated"
  - name: env
    description: "Environment to validate (default: prod)"
user-invocable: true
stack: cloud/awscontext: fork
effort: medium
allowed-tools:
  - Read
  - Write
  - Bash(aws *)
  - Bash(gh *)
  - Bash(curl *)
  - Bash(find *)
  - Bash(grep *)
  - Bash(date *)
  - Bash(node *)
  - Bash(jq *)
---

# Validate

Parse `$ARGUMENTS[0]` as the GitHub issue number.
Parse `--env` as the target environment (default: `prod`).

Run this immediately after a production deploy to confirm the feature worked. Re-run at 1h and 24h post-deploy for full confidence.

---

## Step 1 — Load feature context

```bash
# Fetch the issue
gh issue view <number> --json title,body,milestone,labels,comments

# Find the product plan for expected outcomes
find docs/product-plans/ -name "*.md" | xargs grep -l "#<number>" 2>/dev/null | head -1

# Find the refinement doc for acceptance criteria
find docs/product-tasks/ -name "<number>-refined.md" | head -1

# Find the deploy tag to anchor the time window
git tag --sort=-creatordate | grep -E 'v[0-9]|deploy' | head -5
```

Extract from the docs:
- **Acceptance criteria** — what must be true for this feature to be "done"
- **Expected analytics events** — any events mentioned in the plan (e.g. `order_created`, `checkout_started`)
- **Expected API endpoints** — what the feature added or changed
- **Deploy timestamp** — when it went live (from the git tag or last GitHub release)

Summarise:
> **Validating #<number>: <title>**
> Environment: `<env>`
> Deploy time: `<timestamp>`
>
> I'll check: error rate delta · CloudWatch logs · expected behaviours
> This will take about 60 seconds.

---

## Step 2 — Error rate comparison

Compare error rate in the 2 hours before the deploy vs 2 hours after.

```bash
ENV=<env>
PROJECT=$(node -p "require('./package.json').name" 2>/dev/null || echo "myapp")

# Detect deploy time from latest git tag
DEPLOY_TIME=$(git log -1 --format=%ct $(git tag --sort=-creatordate | head -1))
BEFORE_START=$(( DEPLOY_TIME - 7200 ))000   # 2h before
BEFORE_END=${DEPLOY_TIME}000
AFTER_START=${DEPLOY_TIME}000
AFTER_END=$(( DEPLOY_TIME + 7200 ))000       # 2h after

echo "=== Error rate BEFORE deploy ==="
aws logs filter-log-events \
  --log-group-name "/aws/lambda/${PROJECT}-${ENV}" \
  --start-time $BEFORE_START \
  --end-time $BEFORE_END \
  --filter-pattern '"level":"error"' \
  --query 'events | length(@)' \
  --output text 2>/dev/null || echo "0"

echo "=== Error rate AFTER deploy ==="
aws logs filter-log-events \
  --log-group-name "/aws/lambda/${PROJECT}-${ENV}" \
  --start-time $AFTER_START \
  --end-time $AFTER_END \
  --filter-pattern '"level":"error"' \
  --query 'events | length(@)' \
  --output text 2>/dev/null || echo "0"

echo "=== New error types (after only) ==="
aws logs filter-log-events \
  --log-group-name "/aws/lambda/${PROJECT}-${ENV}" \
  --start-time $AFTER_START \
  --end-time $AFTER_END \
  --filter-pattern '"level":"error"' \
  --query 'events[*].message' \
  --output text 2>/dev/null \
  | head -10
```

Flag as ❌ if: error count after > error count before × 1.5 (50% increase), or any new error type appears that wasn't in the before window.

---

## Step 3 — Feature-specific log check

Check that the new feature's code paths were actually hit:

```bash
# Look for log entries from the new feature (by issue number, endpoint, or function name)
aws logs filter-log-events \
  --log-group-name "/aws/lambda/${PROJECT}-${ENV}" \
  --start-time $AFTER_START \
  --end-time $AFTER_END \
  --filter-pattern "\"#<number>\"" \
  --query 'events[*].message' \
  --output text 2>/dev/null | head -10

# Also check for the new API endpoints
aws logs filter-log-events \
  --log-group-name "/aws/lambda/${PROJECT}-${ENV}" \
  --start-time $AFTER_START \
  --end-time $AFTER_END \
  --filter-pattern '"/api/v1/<resource>"' \
  --query 'events | length(@)' \
  --output text 2>/dev/null
```

Flag as ⚠️ if the feature's endpoints show zero log entries after deploy — it shipped but no one has used it yet, or there is a routing error.

---

## Step 4 — Latency check

```bash
# p95 latency for the new endpoints in the post-deploy window
aws logs filter-log-events \
  --log-group-name "/aws/lambda/${PROJECT}-${ENV}" \
  --start-time $AFTER_START \
  --end-time $AFTER_END \
  --filter-pattern '{ $.duration > 0 }' \
  --query 'events[*].message' \
  --output text 2>/dev/null \
  | node -e "
const lines = require('fs').readFileSync('/dev/stdin','utf8').trim().split('\n')
const durations = lines.map(l => { try { return JSON.parse(l).duration } catch(e) {} }).filter(Boolean)
durations.sort((a,b)=>a-b)
const p = (arr,pct) => arr[Math.floor(arr.length*pct/100)]||0
console.log('p50:', p(durations,50).toFixed(0)+'ms')
console.log('p95:', p(durations,95).toFixed(0)+'ms')
console.log('p99:', p(durations,99).toFixed(0)+'ms')
  "
```

Flag as ❌ if p95 > SLO threshold (check `docs/slo/SLO.md` if it exists, otherwise use 500ms default).

---

## Step 5 — API health check

```bash
DOMAIN=$(aws ssm get-parameter --name "/<project>/${ENV}/domain" --query Parameter.Value --output text 2>/dev/null)

curl -sf "https://api-${ENV}.${DOMAIN}/health" | jq . || echo "❌ health endpoint unreachable"

# Test the new endpoint (read-only check)
# Replace with the actual endpoint from the dev-design doc
curl -sf -H "x-health-check: true" \
  "https://api-${ENV}.${DOMAIN}/api/v1/<resource>" | jq '.success' || echo "endpoint check failed"
```

---

## Step 6 — Acceptance criteria check

Go through each AC from the refinement doc and verify status:

For each acceptance criterion:
- Mark ✅ if it can be verified from logs/API responses
- Mark ⚠️ if it requires manual user testing
- Mark ❌ if there is evidence it is NOT met

> **Acceptance criteria review:**
> - [✅] API returns 201 on successful creation (verified: 23 creation logs in post-deploy window)
> - [⚠️] UI shows empty state when list is empty (requires browser check)
> - [✅] Returns 403 when accessing other user's resource (error logs show ForbiddenError fired correctly)

---

## Step 7 — Verdict and report

**Verdict logic:**
| Signal | Verdict |
|---|---|
| Error rate increased > 50% OR new error types | 🔴 **ROLLBACK RECOMMENDED** |
| p95 latency exceeded SLO threshold | 🔴 **ROLLBACK RECOMMENDED** |
| Health endpoint unreachable | 🔴 **ROLLBACK RECOMMENDED** |
| Any AC marked ❌ | 🟡 **SHIP WITH ISSUES** |
| Feature endpoints show 0 hits (possible routing bug) | 🟡 **INVESTIGATE** |
| All checks pass, some AC need manual verify | 🟢 **SHIP GREEN** |
| All checks pass, all AC verified | 🟢 **CONFIRMED HEALTHY** |

Write to `docs/validation/<issue>-<date>.md`:

```markdown
# Validation Report — #<number> <title>
_Date: <today> · Environment: <env> · Deploy: <timestamp>_

## Verdict: 🟢 SHIP GREEN / 🟡 SHIP WITH ISSUES / 🔴 ROLLBACK RECOMMENDED

## Signal Summary

| Check | Result | Notes |
|---|---|---|
| Error rate delta | +3% (within threshold) | ✅ |
| New error types | None | ✅ |
| Feature endpoint hits | 47 requests | ✅ |
| p95 latency | 210ms (SLO: 500ms) | ✅ |
| Health endpoint | 200 OK | ✅ |

## Acceptance Criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | <ac> | ✅ | 23 creation events in logs |
| 2 | <ac> | ⚠️ | Requires manual browser test |

## Recommended Actions

<If ROLLBACK: step-by-step rollback instructions>
<If SHIP WITH ISSUES: what to monitor and when to escalate>
<If SHIP GREEN: what to watch in the next 24h>

## Next validation
- Run `/validate <number>` again in 24 hours to confirm sustained health
- If feature flag enabled: consider rolling out to 100% now
```

---

## Step 8 — Present verdict

> ## Validation complete: <verdict emoji> <verdict>
>
> **3 of 3 automated checks passed.**
> **5 of 6 acceptance criteria verified** (1 needs manual browser test)
>
> Report saved to `docs/validation/<issue>-<date>.md`
>
> <If rollback needed:>
> Run immediately: `/deploy rollback prod`

**Related skills — apply together:**
- `deploy` — run `/validate` automatically after every prod deploy
- `logs` — deeper log investigation if error rate check raises a flag
- `feature-flag` — if validating a flagged feature, disable the flag instead of rolling back
- `slo` — SLO thresholds are the benchmark for the latency and error rate checks
- `dora` — failed validations that trigger rollback are recorded as change failures in DORA metrics
