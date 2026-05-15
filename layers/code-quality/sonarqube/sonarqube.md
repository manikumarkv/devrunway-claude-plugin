# SonarQube / SonarCloud Standards

## sonar-project.properties

```properties
# sonar-project.properties
sonar.projectKey=my-org_myapp-api
sonar.organization=my-org                    # SonarCloud only
sonar.projectName=MyApp API
sonar.projectVersion=1.0

# Sources
sonar.sources=src
sonar.tests=src
sonar.test.inclusions=**/*.test.ts,**/*.spec.ts,**/*.test.tsx
sonar.exclusions=\
  **/node_modules/**,\
  **/dist/**,\
  **/coverage/**,\
  **/*.d.ts,\
  **/migrations/**,\
  **/__mocks__/**

# Coverage
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.typescript.tsconfigPath=tsconfig.json

# Encoding
sonar.sourceEncoding=UTF-8
```

```properties
# Python project
sonar.projectKey=my-org_myapp-py
sonar.organization=my-org
sonar.sources=src
sonar.tests=tests
sonar.python.coverage.reportPaths=coverage.xml
sonar.python.version=3.11
sonar.exclusions=**/migrations/**,**/__pycache__/**
```

## GitHub Actions (SonarCloud)

```yaml
# .github/workflows/sonar.yml
name: SonarCloud Analysis

on:
  push:
    branches: [main, develop]
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  sonarcloud:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0              # full history for blame info

      - uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install and test (with coverage)
        run: |
          npm ci
          npm test -- --coverage --coverageReporters=lcov

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # for PR decoration
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        with:
          args: >
            -Dsonar.pullrequest.key=${{ github.event.pull_request.number }}
            -Dsonar.pullrequest.branch=${{ github.head_ref }}
            -Dsonar.pullrequest.base=${{ github.base_ref }}
```

## Azure Pipelines Integration

```yaml
# azure-pipelines.yml (snippet)
- task: SonarCloudPrepare@1
  displayName: Prepare SonarCloud analysis
  inputs:
    SonarCloud: "SonarCloud"          # service connection name
    organization: "my-org"
    scannerMode: CLI
    configMode: file                   # uses sonar-project.properties

- script: npm test -- --coverage --coverageReporters=lcov
  displayName: Test with coverage

- task: SonarCloudAnalyze@1
  displayName: Run SonarCloud analysis

- task: SonarCloudPublish@1
  displayName: Publish SonarCloud results
  inputs:
    pollingTimeoutSec: 300

- task: sonarcloud-buildbreaker@2     # fails the pipeline if quality gate fails
  displayName: Check quality gate
  inputs:
    SonarCloud: "SonarCloud"
    organization: "my-org"
```

## Self-Hosted SonarQube (Scanner CLI)

```bash
# Download and run scanner
export SONAR_TOKEN=your_token
export SONAR_HOST_URL=https://sonar.example.com

sonar-scanner \
  -Dsonar.projectKey=myapp-api \
  -Dsonar.sources=src \
  -Dsonar.host.url=$SONAR_HOST_URL \
  -Dsonar.login=$SONAR_TOKEN \
  -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
```

## Quality Gate Configuration (UI)

Recommended quality gate conditions for new code:
| Metric | Operator | Value |
|---|---|---|
| Coverage | is less than | 80% |
| Duplicated Lines | is greater than | 3% |
| Maintainability Rating | is worse than | A |
| Reliability Rating | is worse than | A |
| Security Rating | is worse than | A |
| Security Hotspots Reviewed | is less than | 100% |

## Issue Suppression (Use Sparingly)

```typescript
// Suppress a specific rule with a reason comment
// NOSONAR — intentional use of eval for template engine sandboxing (security review: 2025-01-15)
const result = eval(sandboxedTemplate); // NOSONAR
```

```python
# Python
result = eval(template)  # NOSONAR — sandboxed template engine, reviewed 2025-01-15
```

Rules:
- Always add a comment on the same line explaining why
- Prefer fixing the issue; suppress only when the rule is a confirmed false positive
- Document suppression in code review

## .NET Integration

```xml
<!-- Install dotnet-sonarscanner -->
<!-- .github/workflows/sonar.yml -->
```

```bash
dotnet sonarscanner begin \
  /k:"myapp-dotnet" \
  /o:"my-org" \
  /d:sonar.host.url="https://sonarcloud.io" \
  /d:sonar.login="$SONAR_TOKEN" \
  /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"

dotnet build
dotnet test --collect:"XPlat Code Coverage" -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=opencover

dotnet sonarscanner end /d:sonar.login="$SONAR_TOKEN"
```

## Checklist

- [ ] `sonar-project.properties` committed, with exclusions for generated files
- [ ] `SONAR_TOKEN` in CI secrets — never in source
- [ ] Coverage generated in the same CI job as the scanner run
- [ ] `fetch-depth: 0` on git checkout (full history required)
- [ ] Quality gate check step added — pipeline fails on gate failure
- [ ] PR analysis enabled with `pullrequest.*` properties
- [ ] No NOSONAR suppressions without explanatory comments

## Common mistakes

| Mistake | Fix |
|---|---|
| Using `fetch-depth: 1` (default) on git checkout | SonarQube needs full git history for blame and new-code detection; always set `fetch-depth: 0` |
| Not generating coverage before the scanner runs | Coverage must be produced in the same CI job as the scan; a missing `lcov.info` or `coverage.xml` results in 0% coverage reported |
| Missing `sonar.exclusions` for generated and test files | Without exclusions, Sonar counts generated migrations and test mocks against coverage and duplications metrics |
| Using `NOSONAR` without an explanatory comment | Bare `// NOSONAR` suppresses without accountability; add reason and review date: `// NOSONAR — false positive, reviewed 2025-01-15` |
| Not adding the quality gate check step in the pipeline | The scan task always succeeds; you must add `sonarcloud-buildbreaker` or `sonar qualitygate wait` to fail the pipeline on gate failure |
| Running analysis on feature branches without PR decoration | Without `sonar.pullrequest.*` properties, Sonar cannot post inline comments on PRs |
| Committing `SONAR_TOKEN` to source code | Store the token in CI secrets and reference via `${{ secrets.SONAR_TOKEN }}`; a leaked token allows anyone to post analysis to your project |
