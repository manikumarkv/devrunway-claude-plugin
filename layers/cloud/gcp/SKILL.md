---
name: gcp
description: GCP Cloud Run, Cloud Functions, Cloud SQL, Secret Manager, IAM service accounts
user-invocable: false
stack: cloud/gcp
paths:
  - "**/terraform/**"
  - "**/*.tf"
  - "**/cloudbuild.yaml"
  - "**/*.yaml"
  - "**/*gcp*"
  - "**/*google*"
---

Full standards in [gcp.md](gcp.md). Always-on summary:

**Cloud Run:**
- Deploy from container image in Artifact Registry — never from local Docker
- Set `--min-instances=1` for latency-sensitive services to avoid cold starts
- Use `--no-allow-unauthenticated` for internal services; frontend-facing services use IAP or load balancer
- Configure `--service-account` with a dedicated service account — never use the Compute default SA

**Cloud Functions (Gen 2):**
- Gen 2 only — Gen 1 is deprecated; uses Cloud Run under the hood
- Trigger via HTTP, Pub/Sub, or Eventarc (prefer Eventarc for event-driven)
- Set minimum instances to 0 for background/async, 1 for latency-sensitive

**Cloud SQL:**
- Connect via Cloud SQL Auth Proxy or connector library — never open public IP
- Use private IP with VPC peering in production
- Enable automated backups and point-in-time recovery (PITR)
- Use IAM database authentication where supported (PostgreSQL, MySQL)

**Secret Manager:**
- Store all secrets in Secret Manager — never in env vars, YAML, or source
- Access via SDK with Workload Identity — no service account key files
- Rotate secrets by creating new versions; applications load the latest version at startup

**IAM Service Accounts:**
- One service account per Cloud Run service / Function — principle of least privilege
- Use Workload Identity Federation for CI/CD — no long-lived JSON key files
- Grant roles at the resource level, not project level where possible

**Never:**
- Use the default Compute Engine service account for application workloads
- Store service account JSON key files in source control or CI secrets
- Enable public access to Cloud SQL instances
- Grant `roles/owner` or `roles/editor` to service accounts

**Related skills:** `security-principles`, `cdk`, `logging-standards`
