---
name: azure
description: Azure resource groups, App Service, Functions, Storage, Key Vault, Managed Identity
user-invocable: false
stack: cloud/azure
paths:
  - "**/bicep/**"
  - "**/*.bicep"
  - "**/arm/**"
  - "**/terraform/**"
  - "**/*.tf"
  - "**/azure.yaml"
  - "**/*azure*"
---

Full standards in [azure.md](azure.md). Always-on summary:

**Resource Groups:**
- One resource group per environment per application — `{app}-{env}-rg` naming
- Tag every resource: `Environment`, `Application`, `CostCenter`, `Owner`
- Use resource locks on production resource groups (`CanNotDelete`)

**App Service:**
- Use App Service Plan with at least `P1v3` for production; `B1` acceptable for dev/staging
- Enable managed identity — never store connection strings with credentials
- Configure health check endpoint; set `WEBSITES_ENABLE_APP_SERVICE_STORAGE=false` for containers

**Azure Functions:**
- Use isolated worker model (.NET 8) or Node.js v4 programming model
- Store secrets in Key Vault; reference via `@Microsoft.KeyVault(SecretUri=...)` in app settings
- Set `FUNCTIONS_EXTENSION_VERSION=~4`; pin runtime version explicitly

**Storage:**
- Enable soft delete for blobs (7 days minimum) and containers
- Use private endpoints for production storage — disable public access
- Assign `Storage Blob Data Contributor` role via RBAC — never use account keys in application code

**Key Vault:**
- One Key Vault per environment; `{app}-{env}-kv` naming
- Enable purge protection and soft delete on all vaults
- Grant access via RBAC (`Key Vault Secrets User`) — never use access policies

**Managed Identity:**
- Use system-assigned identity for single-resource, user-assigned for shared access patterns
- Grant least-privilege RBAC roles at resource scope — never at subscription scope
- Use `DefaultAzureCredential` in SDKs — works in local dev (CLI), CI (env vars), and Azure (managed identity)

**Never:**
- Store account keys or connection strings with credentials in app settings or code
- Use `Owner` or `Contributor` roles for application identities
- Deploy to production without a resource lock
- Mix environments in a single resource group

**Related skills:** `security-principles`, `cdk`, `logging-standards`
