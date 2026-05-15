---
name: aws-appconfig
description: AWS AppConfig — feature flag configuration, deployment strategy, Lambda extension, polling
user-invocable: false
stack: feature-flags/aws-appconfig
paths:
  - "**/*.ts"
  - "**/*.js"
  - "**/*.py"
  - "**/*appconfig*"
  - "**/*feature-flag*"
  - "**/*featureFlag*"
---

Full standards in [aws-appconfig.md](aws-appconfig.md). Always-on summary:

**Configuration Structure:**
- Use a dedicated AppConfig Application per service, Environment per stage (dev/staging/prod)
- Store feature flags as a JSON freeform configuration profile — keep the schema flat
- Version control the JSON source alongside code; deploy via CDK/Terraform, not the console

**Lambda Extension:**
- Use the AWS AppConfig Lambda extension layer — avoids direct API calls on every invocation
- The extension caches config and refreshes in the background every `pollIntervalSeconds`
- Access via HTTP: `http://localhost:2772/applications/{app}/environments/{env}/configurations/{profile}`

**Deployment Strategy:**
- Use `AppConfig.AllAtOnce` for feature flags (flags are safe to toggle instantly)
- Use `Linear10PercentEvery1Minute` or `Canary10Percent20Minutes` for application configuration changes
- Require a deployment validator (Lambda) for production config changes

**Polling:**
- Non-Lambda: use the AppConfig SDK with a cache TTL of 30–60 seconds
- Lambda: extension handles caching — never call `GetConfiguration` directly in the handler
- Always handle the case where AppConfig is unreachable — fall back to the last known config or a safe default

**Never:**
- Store secrets or connection strings in AppConfig — use Secrets Manager
- Poll AppConfig on every request — always cache with a TTL
- Deploy configuration changes without a rollback strategy
- Use AppConfig as a primary data store — it is a configuration and feature flag service

**Related skills:** `feature-flag`, `cdk`, `security-principles`
