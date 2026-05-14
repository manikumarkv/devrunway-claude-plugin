# Docker Standards

---

## Multi-stage Dockerfile (Node.js example)

```dockerfile
# ── Stage 1: Install dependencies ────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

# Copy only the lockfile first — maximises layer caching
COPY package.json package-lock.json ./
RUN npm ci --omit=dev


# ── Stage 2: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci                             # includes devDeps for build
COPY . .
RUN npm run build


# ── Stage 3: Production image ─────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Non-root user — required for production
RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 appuser

# Copy compiled output from builder; production deps from deps
COPY --from=builder --chown=appuser:nodejs /app/dist ./dist
COPY --from=deps    --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --chown=appuser:nodejs package.json ./

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
```

---

## Multi-stage Dockerfile (Python / FastAPI example)

```dockerfile
# ── Stage 1: Build dependencies ───────────────────────────────────────────────
FROM python:3.12-slim AS builder
WORKDIR /app

RUN pip install --no-cache-dir uv
COPY requirements.txt ./
RUN uv pip install --system --no-cache -r requirements.txt


# ── Stage 2: Production image ─────────────────────────────────────────────────
FROM python:3.12-slim AS runner
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Non-root user
RUN useradd --system --uid 1001 --no-create-home appuser

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --chown=appuser:appuser src/ ./src/

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import httpx; httpx.get('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## .dockerignore

```dockerignore
# Dependencies (rebuilt inside container)
node_modules
.venv
__pycache__
*.pyc
*.pyo

# Git
.git
.gitignore

# Environment files — never in image
.env
.env.*
!.env.example

# Build artifacts (rebuilt inside container)
dist
build
.next
out

# Dev tools
.vscode
.idea
*.md
README*

# Test files
**/*.test.ts
**/*.spec.ts
coverage
.nyc_output
cypress

# Logs
*.log
npm-debug.log*
```

---

## Layer caching — the most important optimisation

Docker rebuilds all layers below the first changed layer. Order matters:

```dockerfile
# ✅ Cache-friendly order
COPY package.json package-lock.json ./   # copy lockfile first
RUN npm ci                               # install — only reruns if lockfile changes
COPY . .                                 # copy source — changes every commit
RUN npm run build                        # rebuild only when source changes

# ❌ Cache-busting order
COPY . .                                 # changes every commit
RUN npm ci                               # reinstalls every commit even if deps unchanged
```

---

## docker-compose for local development

```yaml
# docker-compose.yml
version: '3.9'

services:
  api:
    build:
      context: .
      target: runner        # use the production stage
    ports:
      - "3000:3000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    volumes:
      - ./src:/app/src     # hot reload in dev only — remove in prod

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-app}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-localdevpassword}
      POSTGRES_DB: ${POSTGRES_DB:-appdb}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-app}"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres_data:
```

---

## Building and running

```bash
# Build the image
docker build -t myapp:latest .

# Build a specific stage (dev)
docker build --target builder -t myapp:dev .

# Run the container
docker run -p 3000:3000 --env-file .env myapp:latest

# Run with docker-compose
docker compose up            # start all services
docker compose up -d         # detached (background)
docker compose up api        # start only the api service
docker compose down          # stop and remove containers
docker compose down -v       # also remove volumes (wipes database)

# Rebuild after Dockerfile changes
docker compose up --build

# View logs
docker compose logs -f api

# Run a command in a running container
docker compose exec api sh
docker compose exec db psql -U app appdb
```

---

## Image versioning

```bash
# Tag with git commit SHA for traceability
IMAGE_TAG=$(git rev-parse --short HEAD)
docker build -t myapp:${IMAGE_TAG} -t myapp:latest .
docker push myapp:${IMAGE_TAG}
docker push myapp:latest
```

In CI, always tag with the commit SHA — `latest` is never a reliable reference.

---

## Security rules

```dockerfile
# ✅ Pin exact versions
FROM node:20.18.0-alpine3.20

# ✅ No root
USER appuser

# ✅ Minimal install — no extras
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
 && rm -rf /var/lib/apt/lists/*   # clean up in the SAME RUN layer

# ❌ These bake secrets into the image (visible in docker history)
ENV DATABASE_URL=postgres://user:password@host/db
ARG API_KEY=abc123
```

**Secrets at runtime, never at build time:**
- Pass secrets via environment variables at container start (`docker run --env-file .env`)
- In orchestrators, use Kubernetes Secrets, AWS Secrets Manager, or Vault — never `ENV` in Dockerfile

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `FROM node:latest` | Pin to `node:20-alpine` or exact version |
| Running as root | `RUN adduser appuser` then `USER appuser` |
| `COPY . .` before `RUN npm ci` | Copy lockfile first; install; then copy source |
| No `.dockerignore` | `node_modules` gets copied into the image — 10× larger image |
| No HEALTHCHECK | Orchestrators can't detect if the app crashed inside the container |
| `ENV SECRET_KEY=...` in Dockerfile | Use `--env-file` at runtime; never bake secrets into the image |
| Multi-line `RUN` without cleanup | Each `RUN` creates a layer — chain with `&&` and clean up in the same command |
