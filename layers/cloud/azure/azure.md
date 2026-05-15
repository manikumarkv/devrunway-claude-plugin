# Azure Standards

## Resource Naming Convention

```
{app}-{component}-{env}-{region-short}
Examples:
  myapp-api-prod-eus         (App Service)
  myapp-prod-rg              (Resource Group)
  myapp-prod-kv              (Key Vault)
  myappprodstor              (Storage Account — no hyphens, max 24 chars, lowercase)
  myapp-prod-func            (Function App)
```

## Bicep — Resource Group + App Service

```bicep
// infra/main.bicep
param appName string
param env string = 'prod'
param location string = resourceGroup().location

var tags = {
  Application: appName
  Environment: env
  CostCenter: 'engineering'
  Owner: 'platform-team'
}

// App Service Plan
resource plan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${appName}-${env}-plan'
  location: location
  tags: tags
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// App Service with Managed Identity
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: '${appName}-api-${env}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      healthCheckPath: '/health'
      appSettings: [
        {
          name: 'KEY_VAULT_URI'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
}

output appServicePrincipalId string = appService.identity.principalId
```

## Key Vault with RBAC

```bicep
// infra/keyvault.bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${appName}-${env}-kv'
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true     // use RBAC, not access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'   // private endpoint only in prod
  }
}

// Grant App Service identity read access to secrets
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appServicePrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'  // Key Vault Secrets User
    )
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}
```

## Storage Account with Private Endpoint

```bicep
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${toLower(appName)}${env}stor'
  location: location
  tags: tags
  sku: { name: 'Standard_ZRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}
```

## Azure Functions (Node.js v4)

```typescript
// src/functions/processOrder.ts
import { app, InvocationContext } from "@azure/functions";

app.serviceBusTopic("processOrder", {
  topicName: "orders",
  subscriptionName: "processor",
  connection: "ServiceBusConnection",   // references app setting, not conn string with key
  handler: async (message: unknown, context: InvocationContext): Promise<void> => {
    context.log("Processing order", { messageId: context.triggerMetadata?.messageId });
    // process...
  },
});
```

## DefaultAzureCredential (SDK)

```typescript
// Works in local dev (az login), CI (env vars), Azure (managed identity)
import { DefaultAzureCredential } from "@azure/identity";
import { SecretClient } from "@azure/keyvault-secrets";
import { BlobServiceClient } from "@azure/storage-blob";

const credential = new DefaultAzureCredential();

const kvClient = new SecretClient(process.env.KEY_VAULT_URI!, credential);
const secret = await kvClient.getSecret("database-password");

const blobClient = new BlobServiceClient(
  `https://${process.env.STORAGE_ACCOUNT}.blob.core.windows.net`,
  credential,
);
```

## Resource Lock (CLI)

```bash
# Prevent accidental deletion of production resource group
az lock create \
  --name "prod-delete-lock" \
  --resource-group "myapp-prod-rg" \
  --lock-type CanNotDelete
```

## Tagging Policy (Azure Policy)

```bash
# Enforce required tags via Azure Policy
az policy assignment create \
  --name "require-tags" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/96670d01-..." \
  --scope "/subscriptions/{subscriptionId}"
```

## Checklist

- [ ] All resources tagged with `Application`, `Environment`, `CostCenter`, `Owner`
- [ ] Production resource group has `CanNotDelete` lock
- [ ] App Services and Functions use system-assigned managed identity
- [ ] Key Vault has RBAC enabled, soft delete, and purge protection
- [ ] `DefaultAzureCredential` used in SDK code — no account keys in config
- [ ] Storage `allowBlobPublicAccess: false` and soft delete enabled
- [ ] Key Vault secrets referenced via `@Microsoft.KeyVault(...)` in app settings

## Common mistakes

| Mistake | Fix |
|---|---|
| Using access policies instead of RBAC on Key Vault | Enable `enableRbacAuthorization: true`; access policies are legacy and harder to audit at scale |
| Storing connection strings in `appSettings` Bicep parameters | Reference Key Vault secrets via `@Microsoft.KeyVault(SecretUri=...)` in app settings instead of embedding values in templates |
| Using the default Compute service account for VMs or App Services | Assign a dedicated system-assigned or user-assigned managed identity with the minimum required roles |
| Granting roles at subscription scope instead of resource scope | Scope role assignments to the specific resource (Key Vault, Storage Account) to follow least-privilege |
| Not enabling soft delete and purge protection on Key Vault | Without these, accidentally deleted secrets or vaults are permanently gone; both should be enabled in production |
| Allowing public network access on Storage Accounts | Set `publicNetworkAccess: 'Disabled'` and use private endpoints; `allowBlobPublicAccess: false` must also be set |
| Not locking the production resource group | Add a `CanNotDelete` lock to prevent accidental `az group delete` from destroying production resources |
| Deploying Bicep without reviewing the `what-if` diff | Run `az deployment group what-if` before every production deployment to catch unexpected resource replacements |
