# AWS CDK Standards

---

## Stack boundaries

Split by lifecycle, not by service. Resources that deploy together belong in the same stack.

| Stack | Contains |
|---|---|
| `AuthStack` | Cognito User Pool, App Client, Identity Pool |
| `DatabaseStack` | RDS/Aurora, DynamoDB tables, SSM parameter exports |
| `ApiStack` | Lambda, API Gateway, IAM roles — depends on DatabaseStack |
| `FrontendStack` | S3 bucket, CloudFront distribution, Route 53 record |
| `MonitoringStack` | CloudWatch alarms, SNS topics, dashboards |

**Share between stacks via SSM, not cross-stack references.**
Cross-stack refs create a deploy-order coupling that blocks independent updates.

```ts
// DatabaseStack — export via SSM
new ssm.StringParameter(this, 'TableNameParam', {
  parameterName: '/myapp/prod/orders-table-name',
  stringValue: ordersTable.tableName,
})

// ApiStack — import from SSM (no direct dependency)
const tableName = ssm.StringParameter.valueForStringParameter(
  this, '/myapp/prod/orders-table-name'
)
```

---

## Project structure

```
infra/
├── bin/
│   └── app.ts              # CDK app entry — instantiates stacks
├── lib/
│   ├── auth-stack.ts
│   ├── database-stack.ts
│   ├── api-stack.ts
│   ├── frontend-stack.ts
│   └── monitoring-stack.ts
├── constructs/             # Reusable L3 constructs
│   ├── SecureLambda.ts
│   └── ApiGatewayWithAuth.ts
├── cdk.json
└── tsconfig.json
```

```ts
// infra/bin/app.ts
const app = new cdk.App()
const env = { account: process.env.CDK_ACCOUNT, region: process.env.CDK_REGION }

new AuthStack(app, 'AuthStack', { env })
new DatabaseStack(app, 'DatabaseStack', { env })
new ApiStack(app, 'ApiStack', { env })
new FrontendStack(app, 'FrontendStack', { env })
```

---

## Always use L2 constructs

```ts
// ❌ L1 — raw CloudFormation, verbose, no defaults
new s3.CfnBucket(this, 'Bucket', {
  bucketEncryption: { serverSideEncryptionConfiguration: [...] },
  publicAccessBlockConfiguration: { blockPublicAcls: true, ... },
})

// ✅ L2 — sensible defaults, type-safe
const bucket = new s3.Bucket(this, 'Bucket', {
  encryption: s3.BucketEncryption.S3_MANAGED,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  removalPolicy: RemovalPolicy.RETAIN,
  versioned: true,
})
```

---

## Lambda

```ts
// infra/constructs/SecureLambda.ts
import * as lambda from 'aws-cdk-lib/aws-lambda'
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs'

export class SecureLambda extends nodejs.NodejsFunction {
  constructor(scope: Construct, id: string, props: nodejs.NodejsFunctionProps) {
    super(scope, id, {
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,    // Graviton — cheaper + faster
      memorySize: 256,
      timeout: cdk.Duration.seconds(30),
      tracing: lambda.Tracing.ACTIVE,              // X-Ray
      insightsVersion: lambda.LambdaInsightsVersion.VERSION_1_0_229_0,
      bundling: {
        minify: true,
        sourceMap: true,
        target: 'node20',
      },
      ...props,
    })
  }
}
```

**Grant specific permissions — no wildcards:**

```ts
// ❌
fn.addToRolePolicy(new iam.PolicyStatement({
  actions: ['dynamodb:*'],
  resources: ['*'],
}))

// ✅
table.grantReadWriteData(fn)

// ✅ — or explicit if grantX method doesn't exist
fn.addToRolePolicy(new iam.PolicyStatement({
  actions: ['dynamodb:GetItem', 'dynamodb:PutItem', 'dynamodb:UpdateItem'],
  resources: [table.tableArn],
}))
```

---

## API Gateway

```ts
const api = new apigateway.RestApi(this, 'Api', {
  restApiName: 'myapp-api',
  defaultCorsPreflightOptions: {
    allowOrigins: apigateway.Cors.ALL_ORIGINS,     // tighten in prod
    allowMethods: apigateway.Cors.ALL_METHODS,
    allowHeaders: ['Content-Type', 'Authorization'],
  },
  deployOptions: {
    stageName: props.environment,
    tracingEnabled: true,
    loggingLevel: apigateway.MethodLoggingLevel.INFO,
    dataTraceEnabled: false,                         // never in prod — logs req bodies
    metricsEnabled: true,
  },
})

// Every route requires auth — set default at API level
const cognitoAuthorizer = new apigateway.CognitoUserPoolsAuthorizer(this, 'Auth', {
  cognitoUserPools: [userPool],
})

const defaultMethodOptions: apigateway.MethodOptions = {
  authorizer: cognitoAuthorizer,
  authorizationType: apigateway.AuthorizationType.COGNITO,
}

// Only /health is public
const health = api.root.addResource('health')
health.addMethod('GET', healthIntegration)          // no auth

const orders = api.root.addResource('orders')
orders.addMethod('GET', listOrdersIntegration, defaultMethodOptions)
orders.addMethod('POST', createOrderIntegration, defaultMethodOptions)
```

---

## DynamoDB

```ts
const table = new dynamodb.Table(this, 'OrdersTable', {
  tableName: `myapp-orders-${props.environment}`,
  partitionKey: { name: 'pk', type: dynamodb.AttributeType.STRING },
  sortKey: { name: 'sk', type: dynamodb.AttributeType.STRING },
  billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
  encryption: dynamodb.TableEncryption.AWS_MANAGED,
  pointInTimeRecovery: true,
  removalPolicy: props.environment === 'prod'
    ? RemovalPolicy.RETAIN
    : RemovalPolicy.DESTROY,
})

table.addGlobalSecondaryIndex({
  indexName: 'GSI1',
  partitionKey: { name: 'gsi1pk', type: dynamodb.AttributeType.STRING },
  sortKey: { name: 'gsi1sk', type: dynamodb.AttributeType.STRING },
})
```

---

## Secrets — SSM only

```ts
// ❌ Stack parameter — visible in CloudFormation console
new cdk.CfnParameter(this, 'DbPassword', { noEcho: true })

// ✅ SSM SecureString — encrypted, auditable
const dbPassword = ssm.StringParameter.valueForSecureStringParameter(
  this, '/myapp/prod/db-password'
)

// ✅ Secrets Manager — for rotation
const secret = secretsmanager.Secret.fromSecretNameV2(
  this, 'DbSecret', 'myapp/prod/db'
)
```

---

## Tagging

Tag everything — required for cost allocation and ownership:

```ts
// infra/bin/app.ts
cdk.Tags.of(app).add('Project', 'myapp')
cdk.Tags.of(app).add('Owner', 'engineering')

// Per-stack environment tag
cdk.Tags.of(apiStack).add('Environment', 'production')
```

---

## Removal policies

| Resource | Dev | Prod |
|---|---|---|
| DynamoDB tables | `DESTROY` | `RETAIN` |
| S3 buckets | `DESTROY` | `RETAIN` |
| RDS clusters | `DESTROY` | `RETAIN` (+ snapshot) |
| Lambda functions | `DESTROY` | `DESTROY` (stateless) |
| CloudWatch logs | `DESTROY` | `DESTROY` (retention set) |

---

## Never

- `--require-approval never` in a production deploy without an environment approval gate
- Wildcard IAM actions (`dynamodb:*`, `s3:*`) — grant specific actions
- Hard-code account IDs or region strings — use `Stack.of(this).account` / `.region`
- Cross-stack references for values that change independently — use SSM
- Deploy CDK without `cdk diff` review in CI
- `RemovalPolicy.DESTROY` on stateful resources in production
