---
name: docker
description: Docker conventions — multi-stage Dockerfile, .dockerignore, non-root user, health checks, and docker-compose for local development. Load when working with Dockerfiles or docker-compose files.
user-invocable: false
stack: container/docker
paths:
  - "Dockerfile"
  - "Dockerfile.*"
  - ".dockerignore"
  - "docker-compose*.yml"
  - "docker-compose*.yaml"
---

Full standards in [docker.md](docker.md). Always-on summary:

**Dockerfile — required patterns:**
- Multi-stage builds: `deps` → `builder` → `runner` — never ship build tools to production
- Pin base image versions: `node:20-alpine` not `node:latest`
- `COPY --chown=node:node` before `USER node` — non-root user is required
- `HEALTHCHECK` instruction — tells the orchestrator when the container is ready

**.dockerignore — always include:**
```
node_modules
.git
.env
dist
*.md
```

**Layer caching:**
- `COPY package*.json ./` then `RUN npm ci` BEFORE `COPY . .` — package install layer is cached unless lockfile changes

**docker-compose (local dev):**
- Services map 1:1 to processes: `api`, `db`, `redis`, `worker`
- Always declare `healthcheck` and `depends_on: condition: service_healthy`
- Never hardcode credentials in `docker-compose.yml` — use `env_file: .env`

**Never:**
- `FROM node:latest` or any `:latest` tag in production images
- Run as root in production containers (`USER root` or no `USER`)
- Store secrets in environment variables baked into the image (`ENV SECRET=...`)
- `RUN apt-get install` without `--no-install-recommends` and cleanup in the same `RUN`

**Related skills:** Your CI layer (building and pushing images), your cloud layer (ECS/Cloud Run/k8s deployment)
