---
name: kubernetes
description: Kubernetes standards — Deployments, Services, ConfigMaps, resource limits, HPA, Helm, and security contexts. Load when working with Kubernetes.
user-invocable: false
stack: container/kubernetes
paths:
  - "k8s/**"
  - "kubernetes/**"
  - "helm/**"
  - "**/*.yaml"
  - "**/*.yml"
---

Full standards in [kubernetes.md](kubernetes.md). Always-on summary:

**Resource definitions:**
- Every Deployment must have `requests` and `limits` for CPU and memory — no unbounded containers
- Always set `replicas: 2` minimum for production workloads — a single replica has no availability guarantee
- Use `RollingUpdate` strategy with `maxSurge: 1` and `maxUnavailable: 0` for zero-downtime deploys

**Probes:**
- `readinessProbe` — gates traffic; must be set on every container serving traffic
- `livenessProbe` — restarts unhealthy containers; use a lightweight health endpoint
- `startupProbe` — for slow-starting containers; prevents liveness killing them during init
- Never set `livenessProbe` without `readinessProbe` — a buggy liveness check will restart healthy pods

**Security:**
- Run containers as non-root: `securityContext.runAsNonRoot: true`, `runAsUser: 1000`
- `readOnlyRootFilesystem: true` where possible
- Set `allowPrivilegeEscalation: false`
- Never mount the service account token unless the pod needs K8s API access (`automountServiceAccountToken: false`)

**Configuration:**
- Env vars from ConfigMap for non-sensitive config; from Secret for sensitive values
- Never hardcode secrets in YAML — use Kubernetes Secrets or external secret managers (Vault, AWS Secrets Manager)
- Use `secretKeyRef` to inject from Secrets; don't mount the whole Secret as a volume unless all keys are needed

**Scaling:**
- Use HorizontalPodAutoscaler (HPA) with CPU or custom metrics — never scale manually in production
- Set `PodDisruptionBudget` (`minAvailable: 1`) for critical services

**Never:**
- Use `latest` tag for images — pin to a specific digest or version tag
- Run as root in the container unless absolutely required
- Put sensitive data in ConfigMap — use Secrets
- Set `resources.limits` without `resources.requests` — limits without requests cause scheduling issues

**Related skills:** `container/docker` (image building), `ci/github-actions` or `ci/gitlab-ci` (CD pipeline)
