---
name: serverless
description: Serverless Framework — serverless.yml, Lambda, API Gateway, layers, offline dev
user-invocable: false
stack: container/serverless
paths:
  - "**/serverless.yml"
  - "**/serverless.yaml"
  - "**/serverless.ts"
  - "**/.serverless/**"
  - "**/handler*.ts"
  - "**/handler*.js"
---

Full standards in [serverless.md](serverless.md). Always-on summary:

**serverless.yml Structure:**
- Define `provider.stage` using `${opt:stage, 'dev'}` — never hardcode environment names
- Set `provider.region`, `provider.runtime`, `memorySize:`, and `timeout:` globally under `provider:`
- Use `iamRoleStatements:` under `provider.iam` to grant least-privilege Lambda permissions
- Use `params:` block (SFW v3+) for environment-specific values

**Lambda Functions:**
- Each function has a single responsibility — no mega-handlers
- Set function-level `timeout` only when it differs from the global default
- Use `environment:` at the provider level for shared vars; function level for overrides
- Reference SSM or Secrets Manager values with `${ssm:/myapp/${self:provider.stage}/db-password}`

**API Gateway:**
- Define `http` events with explicit `method`, `path`, `cors`, and `authorizer`
- Enable CORS at the API Gateway level — not just in Lambda code
- Use `private: true` on internal endpoints

**Layers:**
- Package shared dependencies (large node_modules) as a Lambda layer
- Reference layers by logical name within the same service or by ARN for cross-service
- Layers count toward the 250 MB deployment package limit

**Offline Development:**
- Use `serverless-offline` plugin for local HTTP testing
- Use `serverless-dynamodb-local` or localstack for local AWS service mocks
- Run offline with `npx sls offline --stage dev`

**Deployment:**
- Deploy with `--stage` flag always: `sls deploy --stage prod`
- Use `sls deploy function -f <name>` for fast single-function updates (avoids full CloudFormation update)
- Never deploy to production from a local machine — use CI/CD

**Never:**
- Hardcode AWS account IDs or region strings — use `${aws:accountId}` and `${self:provider.region}`
- Store secrets in `serverless.yml` — use SSM Parameter Store or Secrets Manager references
- Deploy without reviewing the CloudFormation changeset for production

**Related skills:** `cdk`, `security-principles`, `logging-standards`
