# Serverless Framework Standards

## serverless.yml Structure

```yaml
# serverless.yml
service: myapp-api

frameworkVersion: "3"

params:
  default:
    memorySize: 512
    timeout: 29
  prod:
    memorySize: 1024
    timeout: 29

provider:
  name: aws
  runtime: nodejs20.x
  region: ${opt:region, 'us-east-1'}
  stage: ${opt:stage, 'dev'}
  memorySize: ${param:memorySize}
  timeout: ${param:timeout}
  logRetentionInDays: 30
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:GetItem
            - dynamodb:PutItem
            - dynamodb:UpdateItem
            - dynamodb:DeleteItem
            - dynamodb:Query
          Resource:
            - !GetAtt OrdersTable.Arn
            - !Sub "${OrdersTable.Arn}/index/*"
  environment:
    STAGE: ${self:provider.stage}
    REGION: ${self:provider.region}
    DB_PASSWORD: ${ssm:/myapp/${self:provider.stage}/db-password}
    LOG_LEVEL: ${param:logLevel, 'info'}

functions:
  createOrder:
    handler: src/handlers/orders.create
    description: Create a new order
    events:
      - http:
          method: post
          path: /orders
          cors: true
          authorizer:
            name: jwtAuthorizer
            resultTtlInSeconds: 300

  getOrder:
    handler: src/handlers/orders.get
    events:
      - http:
          method: get
          path: /orders/{id}
          cors: true
          authorizer:
            name: jwtAuthorizer

  processOrderQueue:
    handler: src/handlers/queue.processOrder
    timeout: 120              # longer timeout for queue processing
    reservedConcurrency: 10  # throttle to avoid overwhelming downstream
    events:
      - sqs:
          arn: !GetAtt OrderQueue.Arn
          batchSize: 10
          functionResponseType: ReportBatchItemFailures

  jwtAuthorizer:
    handler: src/handlers/authorizer.handler

plugins:
  - serverless-offline
  - serverless-esbuild

custom:
  esbuild:
    bundle: true
    minify: true
    sourcemap: true
    target: node20
  serverless-offline:
    httpPort: 3000
    lambdaPort: 3002

resources:
  Resources:
    OrdersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: myapp-${self:provider.stage}-orders
        BillingMode: PAY_PER_REQUEST
        PointInTimeRecoverySpecification:
          PointInTimeRecoveryEnabled: true
        AttributeDefinitions:
          - AttributeName: pk
            AttributeType: S
          - AttributeName: sk
            AttributeType: S
        KeySchema:
          - AttributeName: pk
            KeyType: HASH
          - AttributeName: sk
            KeyType: RANGE

    OrderQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: myapp-${self:provider.stage}-orders.fifo
        FifoQueue: true
        ContentBasedDeduplication: true
        RedrivePolicy:
          deadLetterTargetArn: !GetAtt OrderDLQ.Arn
          maxReceiveCount: 3

    OrderDLQ:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: myapp-${self:provider.stage}-orders-dlq.fifo
        FifoQueue: true
```

## Handler Pattern

```typescript
// src/handlers/orders.ts
import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { z } from "zod";

const CreateOrderSchema = z.object({
  productId: z.string().uuid(),
  quantity: z.number().int().positive(),
});

export const create: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const body = JSON.parse(event.body ?? "{}");
    const parsed = CreateOrderSchema.safeParse(body);

    if (!parsed.success) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "Validation failed", details: parsed.error.flatten() }),
      };
    }

    const order = await orderService.create(parsed.data);
    return {
      statusCode: 201,
      body: JSON.stringify({ data: order }),
    };
  } catch (err) {
    console.error("Failed to create order", { err });
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
};
```

## SQS Batch Handler with Partial Failure Reporting

```typescript
// src/handlers/queue.ts
import { SQSHandler, SQSBatchResponse } from "aws-lambda";

export const processOrder: SQSHandler = async (event): Promise<SQSBatchResponse> => {
  const failures: SQSBatchResponse["batchItemFailures"] = [];

  await Promise.all(
    event.Records.map(async (record) => {
      try {
        const payload = JSON.parse(record.body);
        await orderService.process(payload);
      } catch (err) {
        console.error("Failed to process record", { messageId: record.messageId, err });
        failures.push({ itemIdentifier: record.messageId });
      }
    }),
  );

  return { batchItemFailures: failures };
};
```

## Lambda Layers

```yaml
# serverless.yml — define a layer
layers:
  sharedDeps:
    path: layers/shared-deps
    description: Shared node_modules
    compatibleRuntimes:
      - nodejs20.x
    retain: false

functions:
  myFunc:
    handler: src/handler.main
    layers:
      - !Ref SharedDepsLambdaLayer
```

## Serverless Offline

```bash
# Install
npm install --save-dev serverless-offline

# Run
npx sls offline --stage dev
# HTTP: http://localhost:3000
# Lambda: http://localhost:3002

# With environment overrides
npx sls offline --stage dev --env LOG_LEVEL=debug
```

## Deployment Commands

```bash
# Deploy full stack to staging
npx sls deploy --stage staging --verbose

# Deploy a single function (fast)
npx sls deploy function -f createOrder --stage staging

# View deployed resources
npx sls info --stage staging

# Remove stack (be careful in prod)
npx sls remove --stage dev

# Review CloudFormation diff before prod deploy
npx sls diff --stage prod
```

## Checklist

- [ ] `stage` derived from `--stage` CLI option, not hardcoded
- [ ] Secrets referenced via SSM / Secrets Manager — not in `serverless.yml`
- [ ] IAM statements follow least-privilege (specific actions and resources)
- [ ] SQS consumers use `ReportBatchItemFailures` for partial batch failure handling
- [ ] DLQ configured on all SQS queues
- [ ] `serverless-offline` in devDependencies, not dependencies
- [ ] Production deployments run from CI — not local machines
