# CloudWatch Logging Standards

## Log group retention — always set

Every LogGroup must have a retention policy. CloudWatch keeps logs forever by default, which is expensive and a compliance risk.

```ts
// CDK — set retention on every LogGroup
import { LogGroup, RetentionDays } from 'aws-cdk-lib/aws-logs'

const logGroup = new LogGroup(this, 'AppLogGroup', {
  logGroupName: '/app/my-service/prod',
  retention: RetentionDays.ONE_MONTH,   // minimum; adjust per data policy
  removalPolicy: RemovalPolicy.DESTROY, // don't orphan on stack delete
})
```

Retention tiers to use by environment:

| Environment | Retention |
|---|---|
| Development | `ONE_WEEK` |
| Staging | `TWO_WEEKS` |
| Production | `ONE_MONTH` — `THREE_MONTHS` for compliance; `ONE_YEAR` for audit logs |

Lambda functions auto-create their log group — use `aws_lambda.Function` retention prop or a separate `LogRetention` construct to set it:

```ts
const fn = new Function(this, 'MyFunction', {
  // ...
  logRetention: RetentionDays.ONE_MONTH,
})
```

## Log group naming

Consistent naming makes Insights cross-service queries possible.

| Source | Pattern | Example |
|---|---|---|
| Lambda | `/aws/lambda/<service>/<function>` | `/aws/lambda/orders/process-payment` |
| ECS / App | `/app/<service>/<environment>` | `/app/users-api/prod` |
| API Gateway | `/aws/api-gateway/<api-name>/<stage>` | `/aws/api-gateway/main-api/prod` |
| RDS | `/aws/rds/instance/<id>/error` | (auto-created by RDS) |

## Structured JSON — mandatory

CloudWatch Insights parses structured JSON automatically. Unstructured text requires regex filters, which are error-prone and expensive.

```json
// Good — Insights can filter on any field
{
  "timestamp": "2024-01-15T10:30:00.000Z",
  "level": "info",
  "service": "orders",
  "requestId": "abc-123",
  "userId": "usr_456",
  "action": "order.created",
  "orderId": "ord_789",
  "message": "Order created"
}

// Bad — unstructured; Insights can only full-text search
2024-01-15 10:30:00 INFO Order created by user 456, order id 789
```

Use Pino (`src/lib/logger.ts`) — it emits JSON by default. Never `console.log` in production.

## Required fields in every log line

These must be present in every log entry. Pino + `pino-http` provide most automatically.

| Field | Set by | Example |
|---|---|---|
| `timestamp` | Pino | `"2024-01-15T10:30:00.000Z"` |
| `level` | Pino | `"info"` |
| `service` | Logger init | `"orders-api"` |
| `requestId` | `pino-http` | `"abc-123"` |
| `message` | Call site | `"Order created"` |

Add contextual fields:
- `userId` — on all authenticated requests
- `action` — on every log line (e.g. `"order.created"`, `"auth.signIn"`)
- `orderId`, `productId`, etc. — relevant domain IDs

## CloudWatch Insights queries

Save these in CloudWatch Insights as named queries for the team.

### Error investigation
```
fields @timestamp, @message, requestId, userId, action
| filter level = "error"
| sort @timestamp desc
| limit 100
```

### Slow request detection
```
fields @timestamp, path, method, responseTime, requestId
| filter responseTime > 3000
| sort responseTime desc
| limit 50
```

### 5xx error rate
```
fields @timestamp, path, statusCode, requestId, userId
| filter statusCode >= 500
| stats count() as errorCount by bin(5m)
```

### Auth failure spike
```
fields @timestamp, action, maskedEmail, reason, attempt
| filter action = "auth.signIn" and level = "warn"
| stats count() as failures by bin(5m)
| sort @timestamp desc
```

### Errors by user
```
fields @timestamp, userId, action, @message
| filter level = "error" and ispresent(userId)
| stats count() as errorCount by userId
| sort errorCount desc
| limit 20
```

### P99 response time
```
fields @timestamp, responseTime
| filter ispresent(responseTime)
| stats pct(responseTime, 99) as p99, pct(responseTime, 95) as p95, avg(responseTime) as avg by bin(5m)
```

## Metric filters and alarms

Create a CloudWatch Metric Filter to count errors, then alarm on the metric.

```ts
import { MetricFilter, FilterPattern, Metric } from 'aws-cdk-lib/aws-logs'
import { Alarm, ComparisonOperator, TreatMissingData } from 'aws-cdk-lib/aws-cloudwatch'
import { SnsAction } from 'aws-cdk-lib/aws-cloudwatch-actions'

// Create metric filter
const errorMetricFilter = new MetricFilter(this, 'ErrorMetricFilter', {
  logGroup,
  filterPattern: FilterPattern.stringValue('$.level', '=', 'error'),
  metricNamespace: 'MyApp/Orders',
  metricName: 'ErrorCount',
  metricValue: '1',
  unit: Unit.COUNT,
})

// Alarm: > 5 errors in any 5-minute window
const errorAlarm = new Alarm(this, 'ErrorAlarm', {
  metric: errorMetricFilter.metric({ period: Duration.minutes(5), statistic: 'sum' }),
  threshold: 5,
  evaluationPeriods: 1,
  comparisonOperator: ComparisonOperator.GREATER_THAN_THRESHOLD,
  treatMissingData: TreatMissingData.NOT_BREACHING,
  alarmDescription: 'More than 5 errors in 5 minutes',
})

errorAlarm.addAlarmAction(new SnsAction(alertTopic))
```

Standard alarms to create per service:

| Alarm | Threshold | Period |
|---|---|---|
| Error count | > 5 | 5 min |
| 5xx rate | > 1% of requests | 5 min |
| P99 latency | > 3000ms | 5 min |
| Lambda duration | > 80% of timeout | 5 min |
| Lambda throttles | > 0 | 1 min |

## PII — never in logs

Never log personally identifiable information. Redact at the logger level so it can't slip through.

```ts
// src/lib/logger.ts — redact list
export const logger = pino({
  redact: {
    paths: [
      'email', 'password', 'token', 'accessToken', 'refreshToken',
      'authorization', 'cookie', 'secret', 'apiKey',
      'req.headers.authorization', 'req.headers.cookie',
      'body.password', 'body.email', 'body.creditCard',
    ],
    censor: '[REDACTED]',
  },
})
```

At the call site, use IDs not values:

```ts
// Good
logger.info({ userId: user.id, action: 'user.updated' }, 'User updated')

// Bad — PII in logs
logger.info({ email: user.email, name: user.name }, 'User updated')
```

## Cross-account log shipping

For centralised logging across multiple AWS accounts (e.g. dev/staging/prod into a security account):

1. Create a Kinesis Data Stream in the destination account
2. Create a CloudWatch Logs Subscription Filter on the source log group
3. The filter streams matching logs to Kinesis
4. Kinesis delivers to the destination (S3, OpenSearch, Splunk, etc.)

```ts
import { CfnSubscriptionFilter } from 'aws-cdk-lib/aws-logs'

new CfnSubscriptionFilter(this, 'LogShipping', {
  logGroupName: logGroup.logGroupName,
  destinationArn: kinesisStream.streamArn,
  filterPattern: '{ $.level = "error" }', // only ship errors cross-account
})
```

## Lambda-specific patterns

```ts
// In Lambda handler — include requestId from context
export const handler = async (event: APIGatewayEvent, context: Context) => {
  const reqLogger = logger.child({
    requestId: context.awsRequestId,
    functionName: context.functionName,
  })

  reqLogger.info({ action: 'handler.start', path: event.path }, 'Request received')
  // ...
}
```

Cold start logging — log cold start once, not on every invocation:

```ts
let isColdStart = true

export const handler = async (event: APIGatewayEvent, context: Context) => {
  if (isColdStart) {
    logger.info({ action: 'lambda.coldStart', functionName: context.functionName }, 'Cold start')
    isColdStart = false
  }
  // ...
}
```
