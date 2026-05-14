---
name: railway
description: Railway deployment conventions — service configuration, environment variables, health checks, Procfile, and private networking. Load when deploying to Railway.
user-invocable: false
stack: container/railway
paths:
  - "railway.json"
  - "railway.toml"
  - "Procfile"
---

Full standards in [railway.md](railway.md). Always-on summary:

**Service setup:**
- Each process (API, worker, scheduler) is a separate Railway service — not a process in one container
- Use Railway's built-in database services (Postgres, Redis, MongoDB) instead of DIY — they handle backups and failover
- Connect services via Railway's private network: `${{Postgres.DATABASE_URL}}` — not public URLs

**Environment variables:**
- Reference other services: `DATABASE_URL=${{Postgres.DATABASE_URL}}`
- Use Railway's shared variables for values common across services
- `railway.toml` for build config; never for secrets

**Health check:**
- Set `healthcheckPath = "/health"` — Railway restarts the service if it fails
- Your `/health` endpoint must return `200` within the timeout

**Deploy:**
- Railway auto-deploys on push to the linked branch
- Use `railway run <command>` for one-off commands (migrations, seeding)
- `railway logs` for live log streaming

**Never:**
- Put secrets in `railway.toml` — use Railway dashboard environment variables
- Use the public URL for service-to-service communication — use private network (`*.railway.internal`)
- Run database migrations as part of the start command — use a separate deploy command or pre-deploy hook

**Related skills:** `container/docker` (Railway uses your Dockerfile), `secrets/env-only`
