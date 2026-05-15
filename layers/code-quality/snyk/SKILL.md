---
name: snyk
description: Snyk CLI scan, CI integration, .snyk ignore file, fix PRs, container scanning
user-invocable: false
stack: code-quality/snyk
paths:
  - "**/.snyk"
  - "**/package.json"
  - "**/Dockerfile"
  - "**/*.tf"
  - "**/.github/workflows/*.yml"
---

Full standards in [snyk.md](snyk.md). Always-on summary:

**CLI Scan:**
- Run `snyk test` for open-source deps, `snyk code test` for SAST, `snyk container test` for images
- Use `--severity-threshold=high` in CI — fail only on high/critical by default
- Pass `--json` for machine-readable output; pipe to `snyk-to-html` for reports

**CI Integration:**
- Run Snyk on every PR; block merge on high/critical vulnerabilities
- Use `SNYK_TOKEN` environment variable — never hardcode the token
- Add `snyk monitor` in the main branch pipeline to track project inventory

**.snyk Ignore File:**
- Use `.snyk` to ignore false positives — always include a reason and expiry date
- Never ignore entire packages — ignore specific vulnerability IDs
- Review and clean up `.snyk` ignores quarterly

**Fix PRs:**
- Enable Snyk's automated fix PRs in the Snyk UI for dependency upgrades
- Review fix PRs for breaking changes before merging — Snyk does not validate semver compatibility
- Pin transitive dependencies with `overrides` (npm) or `resolutions` (yarn) only as a last resort

**Container Scanning:**
- Test the final image: `snyk container test my-image:tag --file=Dockerfile`
- Use a minimal base image (`distroless`, `alpine`) to reduce attack surface
- Fix OS-layer vulns by updating base image, not by adding ignore rules

**Infrastructure as Code:**
- Run `snyk iac test` on Terraform, Helm, and CloudFormation
- Fix misconfigurations (open security groups, public S3 buckets) before merge

**Never:**
- Ignore vulnerabilities without a reason comment and expiry date
- Run Snyk with a personal API token in CI — use a service account token
- Skip `snyk monitor` — without it, new vulns in existing deps go undetected

**Related skills:** `security-principles`, `pipeline`, `cdk`
