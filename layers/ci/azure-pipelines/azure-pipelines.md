# Azure Pipelines Standards

## Full Pipeline Structure

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - release/*
  paths:
    exclude:
      - "*.md"
      - docs/**

pr:
  branches:
    include:
      - main

variables:
  - group: "myapp-common"          # Key Vault-linked variable group
  - name: nodeVersion
    value: "20.x"
  - name: imageName
    value: "myapp"

stages:
  - stage: Build
    displayName: Build & Test
    jobs:
      - job: Build
        pool:
          vmImage: ubuntu-latest
        steps:
          - template: .azure/templates/node-setup.yml
            parameters:
              nodeVersion: $(nodeVersion)
          - template: .azure/templates/npm-cache.yml
          - script: npm ci
            displayName: Install dependencies
          - script: npm run build
            displayName: Build
          - script: npm test -- --ci --coverage
            displayName: Test
          - task: PublishCodeCoverageResults@2
            inputs:
              summaryFileLocation: coverage/cobertura-coverage.xml
          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: dist
              artifactName: app-dist

  - stage: DeployStaging
    displayName: Deploy to Staging
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployStaging
        environment: staging
        strategy:
          runOnce:
            deploy:
              steps:
                - template: .azure/templates/deploy-app-service.yml
                  parameters:
                    serviceConnection: "myapp-staging-sc"
                    appName: "myapp-staging"

  - stage: DeployProd
    displayName: Deploy to Production
    dependsOn: DeployStaging
    condition: succeeded()
    jobs:
      - deployment: DeployProd
        environment: production    # has approval gate configured in UI
        strategy:
          runOnce:
            deploy:
              steps:
                - template: .azure/templates/deploy-app-service.yml
                  parameters:
                    serviceConnection: "myapp-prod-sc"
                    appName: "myapp-prod"
```

## Reusable Templates

```yaml
# .azure/templates/node-setup.yml
parameters:
  - name: nodeVersion
    type: string
    default: "20.x"

steps:
  - task: NodeTool@0
    inputs:
      versionSpec: ${{ parameters.nodeVersion }}
    displayName: Use Node.js ${{ parameters.nodeVersion }}
```

```yaml
# .azure/templates/npm-cache.yml
steps:
  - task: Cache@2
    inputs:
      key: 'npm | "$(Agent.OS)" | package-lock.json'
      restoreKeys: |
        npm | "$(Agent.OS)"
        npm
      path: $(npm_config_cache)
    displayName: Cache npm packages
```

```yaml
# .azure/templates/deploy-app-service.yml
parameters:
  - name: serviceConnection
    type: string
  - name: appName
    type: string

steps:
  - task: DownloadBuildArtifacts@1
    inputs:
      artifactName: app-dist
      downloadPath: $(System.DefaultWorkingDirectory)
  - task: AzureWebApp@1
    inputs:
      azureSubscription: ${{ parameters.serviceConnection }}
      appType: webApp
      appName: ${{ parameters.appName }}
      package: $(System.DefaultWorkingDirectory)/app-dist
```

## Docker Image Build and Push

```yaml
- task: Docker@2
  displayName: Build and push image
  inputs:
    command: buildAndPush
    repository: $(imageName)
    dockerfile: Dockerfile
    containerRegistry: "myapp-acr-sc"    # service connection name
    tags: |
      $(Build.BuildId)
      latest
```

## Variable Groups and Key Vault

```yaml
variables:
  - group: "myapp-secrets"       # Linked to Azure Key Vault in Library settings
  # Access as: $(DatabasePassword), $(ApiKey), etc.
  # These are masked in logs automatically
```

## Passing Outputs Between Stages

```yaml
# In Build stage job:
- script: echo "##vso[task.setvariable variable=imageTag;isOutput=true]$(Build.BuildId)"
  name: setTag

# In DeployStaging stage:
variables:
  imageTag: $[stageDependencies.Build.Build.outputs['setTag.imageTag']]
```

## Environment + Approval Setup (UI)

1. Go to Pipelines → Environments → New environment
2. Name it `production`, add resource (App Service or Kubernetes)
3. Under Approvals and checks → Add approval → select required approvers
4. Pipeline `deployment` job referencing `environment: production` will pause for approval

## Conditional Steps

```yaml
# Only run on main branch
- script: npm run deploy:docs
  displayName: Publish docs
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))

# Always run cleanup, even if previous steps fail
- script: rm -rf temp/
  displayName: Cleanup temp
  condition: always()
```

## .NET Pipeline Example

```yaml
- task: DotNetCoreCLI@2
  displayName: Restore
  inputs:
    command: restore
    projects: "**/*.csproj"

- task: Cache@2
  inputs:
    key: 'nuget | "$(Agent.OS)" | **/*.csproj'
    restoreKeys: nuget | "$(Agent.OS)"
    path: $(NUGET_PACKAGES)
  displayName: Cache NuGet packages

- task: DotNetCoreCLI@2
  displayName: Build
  inputs:
    command: build
    arguments: --configuration Release --no-restore

- task: DotNetCoreCLI@2
  displayName: Test
  inputs:
    command: test
    arguments: --configuration Release --no-build --collect:"XPlat Code Coverage"
```

## Checklist

- [ ] `trigger` and `pr` blocks defined — no accidental runs on all branches
- [ ] Secrets sourced from variable groups linked to Key Vault
- [ ] `deployment` job type used for all environment deploys
- [ ] `production` environment has approval gate configured
- [ ] `condition: succeeded()` on deploy stages — failed builds never deploy
- [ ] Cache tasks use lockfile-based keys with `restoreKeys` fallback
- [ ] Reusable steps extracted to `.azure/templates/`
