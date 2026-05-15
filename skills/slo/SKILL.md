---
name: slo
description: Define Service Level Objectives and error budgets. Generates docs/slo/SLO.md, updates MonitoringStack with CloudWatch composite alarms for error budget burn rate, and creates a dashboard. Usage — /slo <define|status|budget>
argument-hint: "define | status | budget [--service <name>]"
arguments:
  - name: subcommand
    description: "'define' to set SLOs interactively, 'status' to check current SLO health, 'budget' to see remaining error budget"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(aws *)
  - Bash(find *)
  - Bash(ls *)
  - Bash(grep *)
  - Bash(date *)
  - Bash(node *)
---

# SLO — Service Level Objectives

Parse `$ARGUMENTS[0]` as `define` | `status` | `budget` (default: `status`).

---

## `/slo define`

Interactive session to define SLOs. The output drives CloudWatch alarms and the error budget.

### Step 1 — Understand current baselines

```bash
# What are we actually seeing in production today?
PROJECT=$(node -p "require('./package.json').name" 2>/dev/null || echo "myapp")
END=$(date +%s000)
START=$(( $(date +%s) - 86400 ))000   # last 24h

echo "=== Current error rate (24h) ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 5XXError \
  --dimensions Name=ApiName,Value="${PROJECT}-api" \
  --start-time $(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 --statistics Average \
  --query 'Datapoints[0].Average' --output text 2>/dev/null

echo "=== Current p99 latency (24h) ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name IntegrationLatency \
  --dimensions Name=ApiName,Value="${PROJECT}-api" \
  --start-time $(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 --statistics p99 \
  --query 'Datapoints[0].p99' --output text 2>/dev/null
```

Show the user what baseline performance looks like before asking them to commit to targets.

### Step 2 — Guide the SLO conversation

Ask one question at a time:

> **Availability SLO**
> Current measured availability: ~99.X%
>
> What availability SLO do you want to commit to?
> - 99.9% = "three nines" — allows 8.7 hours downtime/year
> - 99.5% = "two and a half nines" — allows 43.8 hours/year
> - 99.0% = "two nines" — allows 87.6 hours/year
>
> (Tip: set your SLO ~0.1% below your actual baseline so you have breathing room)

Wait for answer, then:

> **Latency SLO**
> What p95 response time should users always experience?
> - 200ms — fast, requires well-optimised queries
> - 500ms — good baseline for most APIs
> - 1000ms — acceptable for complex operations
>
> This SLO applies to: all API endpoints / specific endpoints?

Then:

> **Error rate SLO**
> What maximum request error rate is acceptable?
> - 0.1% — very strict, requires robust error handling
> - 0.5% — good default for most SaaS
> - 1.0% — more lenient, suitable for early-stage products

Then:

> **Window**
> SLO compliance is measured over a rolling:
> - 30 days (standard — most teams use this)
> - 7 days (tighter feedback, noisier)
> - 90 days (smoother, slower feedback)

### Step 3 — Calculate error budgets

From the user's answers, calculate:

```
Error budget (availability) = (1 - SLO) × window_minutes
  Example: (1 - 0.999) × 43200 = 43.2 minutes downtime allowed per 30 days

Error budget (error rate) = SLO_error_rate × total_requests_per_window
  Example: 0.005 × 2,000,000 = 10,000 failed requests allowed per 30 days
```

Show the user:
> **Your error budgets:**
> - Availability: 43.2 minutes of downtime per 30-day window
> - Error rate: ~333 failed requests per day (at current traffic)
> - Latency: p95 must stay ≤ 500ms — no budget concept, this is a binary SLO

### Step 4 — Write the SLO document

Write (or update) `docs/slo/SLO.md`:

```markdown
# Service Level Objectives
_Last updated: <today>_
_Service: <project-name>_

## SLO Definitions

### SLO 1 — Availability
**Target:** 99.5% of requests succeed (non-5xx) over any 30-day window
**Error budget:** 43.8 hours of allowed downtime per 30 days
**Measurement:** `(1 - 5xxRate)` from API Gateway metrics, 1-minute resolution
**Source metric:** `AWS/ApiGateway:5XXError`

### SLO 2 — Latency
**Target:** p95 response time ≤ 500ms over any 30-day window
**Error budget:** N/A (binary — either in compliance or not)
**Measurement:** p95 of `IntegrationLatency` from API Gateway
**Source metric:** `AWS/ApiGateway:IntegrationLatency`

### SLO 3 — Request error rate
**Target:** ≤ 0.5% of requests return an application error over any 30-day window
**Error budget:** ~333 failed requests per day (at current baseline traffic of ~66k req/day)
**Measurement:** ratio of 5xx responses to total responses
**Source metric:** `AWS/ApiGateway:5XXError` / `AWS/ApiGateway:Count`

## Burn Rate Alerts

| Burn Rate | What it means | Alert action |
|---|---|---|
| 14.4× | Budget exhausted in 2h if sustained | Page on-call immediately |
| 6× | Budget exhausted in 5h if sustained | Slack alert, investigate now |
| 1× | Burning at exactly SLO rate | Monitor — no action yet |

## Compliance Window
Rolling 30-day window. Reset: no reset — rolling means always looking back 30 days.

## Escalation Policy
- Burn rate ≥ 14.4×: Page on-call (PagerDuty/OpsGenie) · Declare incident
- Burn rate ≥ 6×: Post in #engineering-alerts · Assign DRI within 30 minutes
- Burn rate ≥ 1× for 4h: Engineering team Slack alert · Review next business day

## Freeze policy
When error budget is < 10% remaining:
- No new feature deploys to production
- Only bug fixes and rollbacks allowed
- Reset requires post-mortem and budget replenishment
```

### Step 5 — Wire up monitoring alarms

Implement burn rate alarms in your monitoring infrastructure. Consult your **cloud layer skill** for the specific implementation.

**If using AWS CDK**, append to your monitoring stack:

```ts
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch'
import * as actions from 'aws-cdk-lib/aws-cloudwatch-actions'

// ─── Error budget burn rate alarms ───────────────────────────────────────────

// 5xx error rate — 5-minute window
const errorRateAlarm = new cloudwatch.Alarm(this, 'ErrorRateHigh', {
  alarmName: `${projectName}-${env}-error-rate-high`,
  metric: new cloudwatch.MathExpression({
    expression: 'errors / requests * 100',
    usingMetrics: {
      errors: new cloudwatch.Metric({
        namespace: 'AWS/ApiGateway',
        metricName: '5XXError',
        dimensionsMap: { ApiName: `${projectName}-api` },
        statistic: 'Sum',
        period: cdk.Duration.minutes(5),
      }),
      requests: new cloudwatch.Metric({
        namespace: 'AWS/ApiGateway',
        metricName: 'Count',
        dimensionsMap: { ApiName: `${projectName}-api` },
        statistic: 'Sum',
        period: cdk.Duration.minutes(5),
      }),
    },
  }),
  threshold: 0.5,           // SLO error rate %
  evaluationPeriods: 3,
  comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
  alarmDescription: 'Error rate exceeds SLO — check /logs errors prod',
  treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
})

// p95 latency alarm
const latencyAlarm = new cloudwatch.Alarm(this, 'LatencyHigh', {
  alarmName: `${projectName}-${env}-latency-high`,
  metric: new cloudwatch.Metric({
    namespace: 'AWS/ApiGateway',
    metricName: 'IntegrationLatency',
    dimensionsMap: { ApiName: `${projectName}-api` },
    statistic: 'p95',
    period: cdk.Duration.minutes(5),
  }),
  threshold: 500,           // SLO latency ms
  evaluationPeriods: 3,
  comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
  alarmDescription: 'p95 latency exceeds SLO',
})

// Composite alarm — SLO breach (either condition)
const sloBreachAlarm = new cloudwatch.CompositeAlarm(this, 'SLOBreach', {
  compositeAlarmName: `${projectName}-${env}-slo-breach`,
  alarmRule: cloudwatch.AlarmRule.anyOf(errorRateAlarm, latencyAlarm),
  alarmDescription: 'SLO breach — immediate action required',
})

// Wire to SNS for alerting
sloBreachAlarm.addAlarmAction(new actions.SnsAction(alertTopic))

// ─── CloudWatch Dashboard ─────────────────────────────────────────────────────

new cloudwatch.Dashboard(this, 'SLODashboard', {
  dashboardName: `${projectName}-${env}-slo`,
  widgets: [[
    new cloudwatch.GraphWidget({
      title: 'Error Rate % (SLO: ≤0.5%)',
      left: [/* errorRateAlarm.metric */],
      leftAnnotations: [{ value: 0.5, label: 'SLO', color: '#ff0000' }],
      width: 12,
    }),
    new cloudwatch.GraphWidget({
      title: 'p95 Latency (SLO: ≤500ms)',
      left: [latencyAlarm.metric],
      leftAnnotations: [{ value: 500, label: 'SLO', color: '#ff0000' }],
      width: 12,
    }),
  ]],
})
```

---

## `/slo status`

Check current SLO health against the defined targets in `docs/slo/SLO.md`.

```bash
# Read SLO targets from the doc
cat docs/slo/SLO.md 2>/dev/null | grep -E 'Target:|threshold'

# Current metrics (last 30 days)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 5XXError \
  --start-time <30-days-ago> --end-time <now> \
  --period 2592000 --statistics Average ...
```

Present a live compliance table:

> **SLO Status — 30-day rolling window**
>
> | SLO | Target | Current | Budget remaining | Status |
> |---|---|---|---|---|
> | Availability | 99.5% | 99.87% | 91% budget left | ✅ |
> | p95 Latency | ≤ 500ms | 210ms | — | ✅ |
> | Error rate | ≤ 0.5% | 0.13% | 74% budget left | ✅ |

---

## `/slo budget`

Show error budget consumption with trend.

> **Error budget — current 30-day window**
>
> Availability:  ██████████░░░░░░░░░░  47% consumed (23 of 43.8 min used)
> Error rate:    ████░░░░░░░░░░░░░░░░  21% consumed (2,100 of 10,000 errors used)
>
> At current burn rate, budget exhausted in: **never** (burning below 1×)
>
> Days remaining in window: 18

**Related skills — apply together:**
- `monitoring` — SLO alarms supplement (not replace) the existing Lambda/DynamoDB alarms
- `cdk` — MonitoringStack hosts the SLO dashboard and composite alarm constructs
- `validate` — post-deploy validation checks against SLO thresholds
- `test-load` — load test thresholds should match SLO targets
- `dora` — SLO breaches that trigger rollbacks are DORA "change failure" events
- `deploy` — when error budget < 10%, freeze all feature deploys
