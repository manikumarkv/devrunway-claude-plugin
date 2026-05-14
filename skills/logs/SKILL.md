---
name: logs
description: Query CloudWatch logs — health check, recent errors, live tail, or keyword search. Usage — /devrunway:logs <health|errors|tail|search> [env] [args]
argument-hint: "<health|errors|tail|search> [staging|prod] [keyword|window]"
arguments:
  - name: subcommand
    description: "health, errors, tail, or search"
  - name: env
    description: "staging or prod (default: staging)"
  - name: extra
    description: "Keyword for search, or time window like '1h' or '30m'"
user-invocable: true
allowed-tools:
  - Bash(aws logs *)
  - Bash(aws cloudwatch *)
  - Bash(aws sts *)
  - Bash(jq *)
  - Bash(date *)
---

# Log Inspector

Query CloudWatch logs for the current project. See `skills/logs/cloudwatch-queries.md` for the full query library.

Sub-command is `$ARGUMENTS[0]`. Environment is `$ARGUMENTS[1]` (default: `staging`).

Log group convention: `/aws/lambda/<project>-<env>`

---

## Prerequisites

Verify AWS access before any query:
```bash
aws sts get-caller-identity && aws configure get region
```

If this fails, instruct user to run `aws sso login`.

---

## `/logs health [env]`

Full health check for an environment. Default window: last 1 hour.

```bash
ENV=${ENV:-staging}
START=$(date -d '1 hour ago' +%s000 2>/dev/null || date -v-1H +%s000)
LOG_GROUP="/aws/lambda/<project>-$ENV"

# --- Error count ---
echo "=== Errors (last 1h) ==="
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --start-time $START \
  --filter-pattern '"level":"error"' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' \
  | jq -s 'group_by(.err.message // .msg) | map({ error: .[0].err.message // .[0].msg, count: length }) | sort_by(-.count)'

# --- 4xx/5xx HTTP errors ---
echo ""
echo "=== HTTP Error Codes ==="
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --start-time $START \
  --filter-pattern '"statusCode":5' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' | jq -s 'length' | xargs echo "5xx count:"

# --- Auth failures ---
echo ""
echo "=== Auth Failures (401/403) ==="
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --start-time $START \
  --filter-pattern '"statusCode":401 OR "statusCode":403' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' | jq -s 'length' | xargs echo "Auth failure count:"

# --- Latency ---
echo ""
echo "=== Lambda p95 Latency ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=<project>-$ENV \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 \
  --statistics p95 p99 \
  --output table
```

Print health summary using thresholds from `cloudwatch-queries.md`:
```
Log Health Check — <env> — last 1h
====================================
Status: 🟢 Healthy / 🟡 Degraded / 🔴 Unhealthy

Errors:  N total
  5xx:             N
  4xx:             N
  Auth (401/403):  N

Top errors:
  1. <error type> — N occurrences
  2. ...

Latency p95: <N>ms  p99: <N>ms
```

---

## `/logs errors [env] [window]`

Show recent errors grouped by type. Default window: `1h`.

Parse window argument: `1h`, `30m`, `2h`, etc.

```bash
# Convert window to milliseconds ago
# e.g. '1h' → date -v-1H (BSD) or date -d '1 hour ago' (GNU)

aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-$ENV" \
  --start-time $START \
  --filter-pattern '"level":"error"' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' \
  | jq -s 'group_by(.err.message // .msg) | map({ error: .[0].err.message // .[0].msg, count: length, sample: .[0] }) | sort_by(-.count)'
```

Print each error group: count, message, sample log entry with requestId and userId.

---

## `/logs tail [env]`

Stream the last 20 log entries and follow new ones. Shows all levels.

```bash
ENV=${ENV:-staging}
START=$(date -d '5 minutes ago' +%s000 2>/dev/null || date -v-5M +%s000)

aws logs tail "/aws/lambda/<project>-$ENV" \
  --follow \
  --format short \
  --since 5m 2>/dev/null \
|| \
aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-$ENV" \
  --start-time $START \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' | tail -20
```

Note: `aws logs tail --follow` requires AWS CLI v2. Fallback to polling the last 20 entries.

---

## `/logs search <keyword> [env] [window]`

Search for a keyword in logs. Useful for tracing a specific error, requestId, userId, or action.

```bash
KEYWORD="$1"
ENV=${ENV:-staging}
WINDOW=${WINDOW:-1h}

aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-$ENV" \
  --start-time $START \
  --filter-pattern "\"$KEYWORD\"" \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' | head -30
```

Print: number of matches found, then each matching log line formatted as:
```
[<timestamp>] <level> — <action> — <message>
  requestId: <id>  userId: <id>
```

If no matches: "No log entries found containing '$KEYWORD' in $ENV (last $WINDOW)."
