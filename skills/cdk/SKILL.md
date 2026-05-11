---
name: cdk
description: AWS CDK standards — stack structure, construct patterns, environment config, security defaults, deployment. Load when writing or reviewing CDK infrastructure code.
user-invocable: false
---

Full standards in [cdk.md](cdk.md). Always-on summary:

**Stack structure:** one stack per logical boundary (ApiStack, FrontendStack, DatabaseStack, AuthStack). Share via SSM or stack outputs — not cross-stack references.

**Construct rules:**
- L2 constructs always (never L1 CfnXxx unless no L2 exists)
- Removal policy: `RETAIN` for databases in prod, `DESTROY` for ephemeral resources
- Always tag: `environment`, `project`, `owner`

**Security defaults:**
- Lambda: no wildcard IAM (`*`) — grant specific actions on specific resources
- S3: `blockPublicAccess: BlockPublicAccess.BLOCK_ALL`
- API Gateway: auth required on every route except `/health`
- Secrets: SSM SecureString or Secrets Manager — never stack parameters

**Never:**
- `--require-approval never` in prod CI without explicit env gate
- Hard-code account IDs or region strings — use `Stack.of(this).account`
- `cdk destroy` in CI on non-ephemeral environments
