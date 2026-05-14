# Railway Standards

---

## Project structure

Railway maps 1 service = 1 process. A typical full-stack app:

```
Railway Project: my-app
├── api          ← Node/Python/Go API service (from GitHub repo)
├── worker       ← Background job processor (same repo, different start command)
├── postgres     ← Managed Postgres service (Railway plugin)
└── redis        ← Managed Redis service (Railway plugin)
```

---

## railway.toml

```toml
# railway.toml — build and deploy configuration (commit this)

[build]
builder = "DOCKERFILE"           # or "NIXPACKS" (auto-detect) or "BUILDPACKS"
dockerfilePath = "Dockerfile"    # path to Dockerfile if using Docker builder

[deploy]
startCommand = "node dist/index.js"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
healthcheckPath = "/health"
healthcheckTimeout = 300         # seconds to wait for healthcheck on deploy

# For a worker service (no HTTP — disable health check)
# [deploy]
# startCommand = "node dist/worker.js"
# healthcheckPath = ""
```

---

## Environment variables

```bash
# Set a variable via CLI
railway variables set DATABASE_URL="postgres://..."

# Set from .env file
railway variables set < .env

# List all variables
railway variables

# Run a command with Railway env vars injected
railway run npm run db:migrate
```

**Referencing other Railway services:**
```bash
# In the Railway dashboard, Environment Variables section:
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
```

This injects the managed service URL automatically — no manual copy-paste.

**Shared variables (for values used by multiple services):**
```bash
# Set a shared variable in the project
railway variables --service shared set API_SECRET="my-secret"

# Reference in service env vars
API_SECRET=${{shared.API_SECRET}}
```

---

## Health check endpoint

Railway requires a health check endpoint for zero-downtime deploys:

```typescript
// src/routes/health.ts
import { Router } from 'express'

const router = Router()

router.get('/health', async (req, res) => {
  // Optionally check dependencies
  try {
    await db.query('SELECT 1')   // verify DB connection
    res.status(200).json({
      status: 'ok',
      timestamp: new Date().toISOString(),
    })
  } catch {
    res.status(503).json({ status: 'unhealthy', error: 'Database unreachable' })
  }
})

export default router
```

```python
# FastAPI
@app.get("/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}
```

Railway waits for the health check to pass before routing traffic to the new deployment.

---

## Database migrations

**Never run migrations in the start command.** Migrations can fail and prevent the service from starting.

Options:
1. **Pre-deploy hook** (recommended):
```toml
# railway.toml
[deploy]
startCommand = "node dist/index.js"

# Run before routing traffic to the new deploy
# (Railway Pro feature — use as release command)
```

2. **Separate run command**:
```bash
# Run migrations manually or in CI before deploy
railway run npx prisma migrate deploy
railway run python -m alembic upgrade head
```

3. **Startup check** (simple projects):
```typescript
// src/index.ts — run migrations at startup but fail gracefully
async function main() {
  await runMigrations()     // run and wait
  await startServer()       // only start after migrations succeed
}
```

---

## Private networking

Services in the same Railway project can communicate over a private network:

```bash
# Private hostname format: <service-name>.railway.internal
# Available on port 443 (HTTPS) within the project

# In your API service env vars:
WORKER_URL=https://worker.railway.internal
```

```typescript
// Call the worker service over private network
const response = await fetch('https://worker.railway.internal/process', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ jobId: '123' }),
})
```

**Always use private networking for service-to-service calls** — not the public `*.up.railway.app` URL.

---

## CLI commands

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Link a local project to a Railway project
railway link

# Deploy current directory
railway up

# Run a command with Railway environment variables
railway run npm run db:seed
railway run python manage.py createsuperuser

# Open service logs
railway logs

# Open the Railway dashboard
railway open

# List services
railway status

# SSH into a service (Pro feature)
railway shell
```

---

## CI/CD — GitHub integration

Railway auto-deploys when you push to the linked branch (default: `main`).

```yaml
# .github/workflows/deploy.yml — custom CI before Railway deploys
name: CI

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test
      # Railway deploys automatically after this workflow succeeds
      # Configure in Railway: Settings → Deploy on CI Success
```

Or run migrations in CI before Railway deploys:
```yaml
- name: Run migrations
  run: railway run npm run db:migrate
  env:
    RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

---

## Custom domains

```bash
# Add a custom domain via CLI
railway domain add api.example.com

# Railway generates a CNAME — add to DNS:
# api.example.com → <hash>.up.railway.app (CNAME)
```

Railway provisions a free TLS certificate via Let's Encrypt.

---

## Scaling

```toml
# railway.toml
[deploy]
numReplicas = 2    # horizontal scaling (Pro plan)
```

For auto-scaling, use Railway's **Autoscale** feature in the dashboard:
- Set min/max replicas
- Scale trigger: CPU or memory utilisation

---

## Common patterns

**Cron jobs (scheduled tasks):**
```
# Create a separate Railway service with a cron schedule
# Service type: Cron
# Schedule: 0 0 * * *  (midnight daily)
# Command: node dist/jobs/daily-cleanup.js
```

**Dockerfile with Railway:**
```dockerfile
# Railway reads your Dockerfile automatically
# Expose the PORT environment variable (Railway injects this)
EXPOSE ${PORT:-3000}
CMD ["node", "dist/index.js"]
```

```typescript
// Always use Railway's PORT env var — not a hardcoded port
const port = process.env.PORT ?? 3000
app.listen(port)
```
