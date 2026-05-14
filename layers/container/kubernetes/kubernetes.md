# Kubernetes Standards

---

## Deployment

```yaml
# k8s/deployments/api.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: production
  labels:
    app: api
    version: "1.0.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge:       1   # one extra pod during rollout
      maxUnavailable: 0   # never kill a pod before the new one is ready
  template:
    metadata:
      labels:
        app: api
    spec:
      # Security: don't auto-mount service account token
      automountServiceAccountToken: false

      # Graceful shutdown
      terminationGracePeriodSeconds: 60

      containers:
        - name: api
          image: registry.example.com/api:1.0.0   # NEVER :latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000

          # ── Resource limits (always required) ─────────────────────────────
          resources:
            requests:
              cpu:    "100m"
              memory: "256Mi"
            limits:
              cpu:    "500m"
              memory: "512Mi"

          # ── Probes ────────────────────────────────────────────────────────
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 3000
            initialDelaySeconds: 5
            periodSeconds:       10
            failureThreshold:    3

          livenessProbe:
            httpGet:
              path: /health/live
              port: 3000
            initialDelaySeconds: 15
            periodSeconds:       20
            failureThreshold:    3

          startupProbe:
            httpGet:
              path: /health/ready
              port: 3000
            failureThreshold:  30
            periodSeconds:     10

          # ── Security context ──────────────────────────────────────────────
          securityContext:
            runAsNonRoot:             true
            runAsUser:                1000
            readOnlyRootFilesystem:   true
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]

          # ── Environment ───────────────────────────────────────────────────
          env:
            - name: NODE_ENV
              value: production
            - name: PORT
              value: "3000"
            # From ConfigMap
            - name: DATABASE_HOST
              valueFrom:
                configMapKeyRef:
                  name: api-config
                  key: database-host
            # From Secret
            - name: DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: api-secrets
                  key: database-password

          # Writable tmp dir (when readOnlyRootFilesystem: true)
          volumeMounts:
            - name: tmp
              mountPath: /tmp

      volumes:
        - name: tmp
          emptyDir: {}
```

---

## Service

```yaml
# k8s/services/api.yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: production
spec:
  selector:
    app: api
  ports:
    - port:       80
      targetPort: 3000
      protocol:   TCP
  type: ClusterIP   # Internal only; use Ingress for external traffic
```

---

## Ingress

```yaml
# k8s/ingress/api.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect:       "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer:                 "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.yourapp.com
      secretName: api-tls-cert
  rules:
    - host: api.yourapp.com
      http:
        paths:
          - path:     /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
```

---

## ConfigMap and Secret

```yaml
# k8s/configs/api-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: production
data:
  database-host:  "postgres.production.svc.cluster.local"
  database-port:  "5432"
  database-name:  "app_production"
  redis-host:     "redis.production.svc.cluster.local"
  log-level:      "info"
```

```yaml
# k8s/secrets/api-secrets.yaml — do NOT commit real values; use sealed-secrets or external secret manager
apiVersion: v1
kind: Secret
metadata:
  name: api-secrets
  namespace: production
type: Opaque
# Values are base64-encoded: echo -n 'value' | base64
data:
  database-password: <base64-encoded-password>
  jwt-secret:        <base64-encoded-secret>
```

```bash
# Create secret imperatively (not stored in git)
kubectl create secret generic api-secrets \
  --from-literal=database-password="$(cat /path/to/password)" \
  --namespace=production
```

---

## HorizontalPodAutoscaler

```yaml
# k8s/hpa/api.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind:       Deployment
    name:       api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type:               Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type:               Utilization
          averageUtilization: 80
```

---

## PodDisruptionBudget

```yaml
# k8s/pdb/api.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
  namespace: production
spec:
  minAvailable: 1   # always keep at least 1 pod running during node drains
  selector:
    matchLabels:
      app: api
```

---

## Health endpoints (Node.js example)

```typescript
// src/routes/health.ts
import { Router } from 'express'
import { db } from '../lib/db'
import { redis } from '../lib/redis'

const router = Router()

// Readiness — are we ready to accept traffic?
router.get('/health/ready', async (_req, res) => {
  try {
    await db.$queryRaw`SELECT 1`     // check DB connection
    await redis.ping()               // check Redis connection
    res.json({ status: 'ready' })
  } catch (err) {
    res.status(503).json({ status: 'not ready', error: (err as Error).message })
  }
})

// Liveness — are we running (not deadlocked)?
router.get('/health/live', (_req, res) => {
  // Minimal check — just that the process is responding
  res.json({ status: 'alive', uptime: process.uptime() })
})

export { router as healthRouter }
```

---

## Helm chart structure

```
helm/
  myapp/
    Chart.yaml
    values.yaml          ← defaults
    values.production.yaml
    values.staging.yaml
    templates/
      deployment.yaml
      service.yaml
      ingress.yaml
      configmap.yaml
      hpa.yaml
      pdb.yaml
      _helpers.tpl       ← shared template helpers
```

```yaml
# helm/myapp/values.yaml
replicaCount: 2
image:
  repository: registry.example.com/api
  tag:        "1.0.0"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu:    "100m"
    memory: "256Mi"
  limits:
    cpu:    "500m"
    memory: "512Mi"

autoscaling:
  enabled:                        true
  minReplicas:                    2
  maxReplicas:                    10
  targetCPUUtilizationPercentage: 70

ingress:
  enabled: true
  host:    api.yourapp.com
```

```bash
# Deploy with Helm
helm upgrade --install api ./helm/myapp \
  -f helm/myapp/values.production.yaml \
  --namespace production \
  --set image.tag="${IMAGE_TAG}" \
  --atomic            # rollback on failure
  --timeout 5m
```

---

## kubectl — day-to-day commands

```bash
# Pod status
kubectl get pods -n production
kubectl describe pod api-7d4b6c5f8-abc12 -n production

# Logs
kubectl logs api-7d4b6c5f8-abc12 -n production --follow
kubectl logs -l app=api -n production --tail=100

# Exec into a pod
kubectl exec -it api-7d4b6c5f8-abc12 -n production -- /bin/sh

# Rolling restart (pick up new ConfigMap values)
kubectl rollout restart deployment/api -n production

# Rollout status
kubectl rollout status deployment/api -n production

# Rollback
kubectl rollout undo deployment/api -n production

# Scale manually (use HPA for production)
kubectl scale deployment/api --replicas=5 -n production

# Port-forward for debugging
kubectl port-forward svc/api 3000:80 -n production
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `image: myapp:latest` | Pin to a specific tag or digest — `latest` makes rollbacks impossible |
| No resource `requests` or `limits` | Node scheduling fails; limits prevent noisy neighbours |
| `replicas: 1` in production | Single replica = zero availability during restarts — set `minReplicas: 2` |
| `livenessProbe` without `readinessProbe` | Without readiness, traffic hits pods that aren't ready yet |
| Running as root | `runAsNonRoot: true` — most apps don't need root |
| Secrets in ConfigMap or in the YAML | Use K8s Secrets or an external secret manager (Vault, AWS Secrets Manager) |
| No `PodDisruptionBudget` | Node drains kill all pods of a service simultaneously |
| `maxUnavailable: 1` in rolling update | Set to 0 for zero-downtime — wait for new pod before killing old one |
