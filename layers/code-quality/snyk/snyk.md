# Snyk Standards

## CLI Setup

```bash
npm install -g snyk
snyk auth                    # interactive — opens browser
# Or non-interactive:
export SNYK_TOKEN=your_token
snyk auth $SNYK_TOKEN
```

## Scan Commands

```bash
# Open-source dependency scan
snyk test --severity-threshold=high

# SAST (static code analysis)
snyk code test

# Container image scan
snyk container test myapp:latest --file=Dockerfile --severity-threshold=high

# Infrastructure as Code scan
snyk iac test infra/ --severity-threshold=high

# Output JSON for reporting
snyk test --json | snyk-to-html -o snyk-report.html
```

## GitHub Actions Integration

```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  pull_request:
  push:
    branches: [main]

jobs:
  snyk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Snyk — open-source dependencies
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --fail-on=upgradable

      - name: Run Snyk — SAST
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          command: code test
          args: --severity-threshold=high

      - name: Run Snyk — container
        uses: snyk/actions/docker@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          image: myapp:${{ github.sha }}
          args: --severity-threshold=high

      - name: Snyk monitor (main branch only)
        if: github.ref == 'refs/heads/main'
        run: snyk monitor --project-name=myapp-api
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

## .snyk Ignore File

```yaml
# .snyk
version: v1.25.0
ignore:
  SNYK-JS-LODASH-567746:
    - "*":
        reason: >
          False positive — we use lodash.get which is not affected.
          Review by: 2025-09-01
        expires: "2025-09-01T00:00:00.000Z"
        created: "2025-03-01T00:00:00.000Z"
  SNYK-JS-AXIOS-6032459:
    - "*":
        reason: >
          Upgrade blocked by breaking API change in v1.x.
          Tracked in JIRA: PLAT-1234. Review by: 2025-06-01
        expires: "2025-06-01T00:00:00.000Z"
        created: "2025-03-01T00:00:00.000Z"
patch: {}
```

## Container Scanning Best Practices

```dockerfile
# Use minimal base images
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
CMD ["dist/server.js"]
```

```bash
# Scan and check base image recommendations
snyk container test gcr.io/distroless/nodejs20-debian12 --file=Dockerfile
# Snyk suggests a better base image if one exists with fewer vulns
```

## Snyk IaC — Terraform

```bash
snyk iac test infra/ \
  --severity-threshold=medium \
  --report \
  --target-name=myapp-infrastructure
```

Common findings Snyk IaC catches:
- S3 buckets with public access enabled
- Security groups with `0.0.0.0/0` ingress
- RDS instances without encryption at rest
- Lambda functions without tracing enabled
- Missing resource tags

## Snyk Monitor (Inventory Tracking)

```bash
# Run on every main branch merge — tracks new vulns in existing dependencies
snyk monitor \
  --project-name=myapp-api \
  --org=my-snyk-org \
  --tags=env=prod,team=platform
```

## PR Status Check Configuration

In Snyk UI (Organization Settings → Integrations → GitHub):
1. Enable "Fail open source PRs" for High and Critical
2. Enable "Fail IaC PRs" for High and Critical
3. Enable automated fix PRs for Direct dependencies
4. Set re-test frequency to "Daily"

## Checklist

- [ ] `SNYK_TOKEN` in CI secrets — not hardcoded
- [ ] `snyk test` runs on every PR with `--severity-threshold=high`
- [ ] `snyk monitor` runs on main branch merges
- [ ] `.snyk` ignore entries have `reason` and `expires` fields
- [ ] Container scan uses `--file=Dockerfile` to get base image analysis
- [ ] `snyk iac test` runs on infrastructure changes
- [ ] Automated fix PRs enabled in Snyk UI
