# CloudWatch Query Reference

Standard queries used by `/logs` and the `debugger` agent.

## Log Group Naming

Convention: `/aws/lambda/<project>-<env>`

Examples:
- `/aws/lambda/myapp-staging`
- `/aws/lambda/myapp-prod`

---

## Error Rate Query

Filter all error-level log entries in a time window:

```bash
START=$(date -d "$WINDOW ago" +%s000 2>/dev/null || date -v-${WINDOW_BSD} +%s000)

aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-<env>" \
  --start-time $START \
  --filter-pattern '"level":"error"' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson'
```

## Group Errors by Type

```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-<env>" \
  --start-time $START \
  --filter-pattern '"level":"error"' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' \
  | jq -s 'group_by(.err.message // .msg) | map({ error: .[0].err.message // .[0].msg, count: length, sample: .[0] }) | sort_by(-.count)'
```

## Search by Keyword

```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-<env>" \
  --start-time $START \
  --filter-pattern '"<KEYWORD>"' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' | head -20
```

## Filter by User ID

```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-<env>" \
  --start-time $START \
  --filter-pattern '{ $.userId = "<USER_ID>" }' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson'
```

## Filter by Request ID

```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-<env>" \
  --start-time $START \
  --filter-pattern '{ $.requestId = "<REQUEST_ID>" }' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson'
```

## Auth Failures (401/403)

```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/<project>-<env>" \
  --start-time $START \
  --filter-pattern '"statusCode":401 OR "statusCode":403' \
  --query 'events[*].message' --output text \
  | jq -R 'try fromjson' | jq -s 'length' | xargs -I{} echo "Auth failures: {}"
```

## Lambda Latency (p95/p99)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=<project>-<env> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 \
  --statistics p95 p99 Maximum \
  --output table
```

## Lambda Error Count

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=<project>-<env> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 \
  --statistics Sum \
  --output table
```

## Lambda Throttles

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Throttles \
  --dimensions Name=FunctionName,Value=<project>-<env> \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --period 300 \
  --statistics Sum \
  --output table
```

---

## Health Thresholds

| Signal | Healthy | Degraded | Unhealthy |
|---|---|---|---|
| Error rate | < 0.1% | 0.1–1% | > 1% |
| p95 latency | < 500ms | 500ms–2s | > 2s |
| Auth failures | None | Isolated | Widespread |
| 5xx errors | None | < 5 | Any spike |
| Throttles | 0 | 1–5 | > 5 |
