# Doppler Standards

## Install CLI

```bash
# macOS
brew install dopplerhq/cli/doppler

# Linux
(curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || wget -t 3 -qO- https://cli.doppler.com/install.sh) | sudo sh

# Verify
doppler --version
```

## Project setup

```bash
# Authenticate (interactive, browser-based)
doppler login

# Configure a project and environment for the current directory
doppler setup
# Select project: my-app
# Select config: dev

# Committed to repo (contains NO secrets):
# .doppler.yaml
```

```yaml
# .doppler.yaml (safe to commit — just project/config pointers)
setup:
  project: my-app
  config: dev
```

## Environments (configs)

```
my-app
├── dev      ← local development
├── stg      ← staging/preview
└── prd      ← production
```

```bash
# Create a new config
doppler configs create --project my-app --name stg

# List secrets in a config
doppler secrets --config prd

# Copy secrets from one config to another (bootstrap)
doppler secrets download --config dev --no-file --format json \
  | doppler secrets upload --config stg
```

## Local development — inject secrets at runtime

```bash
# Run any command with secrets injected as env vars
doppler run -- node dist/server.js
doppler run -- python manage.py runserver
doppler run -- npm run dev

# Use a non-default config
doppler run --config stg -- node dist/server.js

# Print resolved secrets (for debugging shape, never log in CI)
doppler run -- env | grep MY_APP
```

## Service tokens

Service tokens are scoped credentials for non-human access (CI, servers, containers).

```bash
# Create a service token via CLI
doppler configs tokens create --project my-app --config prd --name "prod-server" --max-reads 0

# Or via dashboard: Project → Configs → prd → Access → Service Tokens → Generate
```

```bash
# Use in any environment where the CLI is available
DOPPLER_TOKEN=dp.st.prd.xxxx doppler run -- node dist/server.js

# Or export and use
export DOPPLER_TOKEN=dp.st.prd.xxxx
doppler run -- node dist/server.js
```

## CI/CD — GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Doppler CLI
        uses: dopplerhq/cli-action@v3

      - name: Build and test with secrets
        env:
          DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}
        run: doppler run -- npm test

      - name: Deploy
        env:
          DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}
        run: doppler run -- ./scripts/deploy.sh
```

```yaml
# Alternative: use the official fetch action
      - name: Fetch secrets
        uses: dopplerhq/fetch-secrets@v2
        with:
          doppler-token: ${{ secrets.DOPPLER_TOKEN }}
          inject-env-vars: true

      - name: Use secrets
        run: echo "DB connected" # secrets available as env vars
```

## Docker / container integration

```dockerfile
# Dockerfile — DO NOT copy secrets into image
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
CMD ["node", "dist/server.js"]
```

```bash
# Inject secrets at container runtime via CLI sidecar pattern
docker run \
  -e DOPPLER_TOKEN=dp.st.prd.xxxx \
  my-app \
  sh -c "doppler run -- node dist/server.js"
```

```yaml
# docker-compose.yml
services:
  app:
    image: my-app
    environment:
      DOPPLER_TOKEN: ${DOPPLER_TOKEN}
    command: ["doppler", "run", "--", "node", "dist/server.js"]
```

## Kubernetes integration

```bash
# Install Doppler operator
kubectl apply -f https://github.com/DopplerHQ/kubernetes-operator/releases/latest/download/recommended.yaml

# Create service token secret
kubectl create secret generic doppler-token-secret \
  --namespace doppler-operator-system \
  --from-literal=serviceToken=dp.st.prd.xxxx
```

```yaml
# doppler-secret-sync.yaml
apiVersion: secrets.doppler.com/v1alpha1
kind: DopplerSecret
metadata:
  name: app-secrets
  namespace: default
spec:
  tokenSecret:
    name: doppler-token-secret
  managedSecret:
    name: app-secrets
    namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
        - name: app
          envFrom:
            - secretRef:
                name: app-secrets
```

## Node.js SDK — dynamic refresh

```typescript
// Use SDK only when hot-reload of secrets is required (e.g., rotation without restart)
// Otherwise, prefer CLI injection: `doppler run -- node dist/server.js`

import { DopplerSDK } from "@dopplerhq/node-sdk";

const doppler = new DopplerSDK({ accessToken: process.env.DOPPLER_TOKEN! });

interface AppSecrets {
  DATABASE_URL: string;
  JWT_SECRET: string;
  STRIPE_SECRET_KEY: string;
}

let _secrets: AppSecrets | null = null;
let _secretsLoadedAt = 0;
const CACHE_TTL_MS = 5 * 60 * 1000;

export async function getSecrets(): Promise<AppSecrets> {
  const now = Date.now();
  if (_secrets && now - _secretsLoadedAt < CACHE_TTL_MS) return _secrets;

  const response = await doppler.secrets.download("my-app", "prd", { format: "json" });
  _secrets = response as AppSecrets;
  _secretsLoadedAt = now;
  return _secrets;
}
```

## Python — subprocess injection pattern

```python
# For scripts that can't use the CLI wrapper, download secrets once
import subprocess
import json


def load_doppler_secrets(project: str, config: str) -> dict[str, str]:
    result = subprocess.run(
        ["doppler", "secrets", "download", "--project", project, "--config", config,
         "--no-file", "--format", "json"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


# At startup only — never per-request
if __name__ == "__main__":
    secrets = load_doppler_secrets("my-app", "prd")
    import os
    os.environ.update(secrets)
```

## Managing secrets

```bash
# Add or update a secret
doppler secrets set MY_API_KEY=sk_live_abc123

# Delete a secret
doppler secrets delete MY_OLD_KEY

# Rename a secret
doppler secrets rename OLD_NAME NEW_NAME

# Download to a .env file (for local tooling that requires a file)
doppler secrets download --no-file --format env > .env.local
# Add .env.local to .gitignore!

# Audit: view secret access log
doppler activity --project my-app
```

## Secret referencing (cross-config inheritance)

```bash
# Doppler supports "root" config inheritance
# Set a secret in the root config, reference it in child configs
# In the dashboard: Config → Computed → References

# Example: DATABASE_URL in dev overrides prd value
# prd/DATABASE_URL = postgresql://prod-host/myapp
# dev/DATABASE_URL = postgresql://localhost/myapp_dev
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Committing `.env` with real secrets | Add `.env` to `.gitignore`; use `doppler run --` |
| Using personal token in CI | Create a service token scoped to that config/project |
| Sharing service tokens across envs | One token per environment; rotate on offboarding |
| Calling Doppler SDK per request | Load once at startup; cache with TTL |
| Storing `DOPPLER_TOKEN` in `.doppler.yaml` | `.doppler.yaml` is for project/config only — store token in CI secrets |
| Docker image containing secrets | Never `COPY .env` — inject via `DOPPLER_TOKEN` env var at runtime |
| Logging env output in CI | `doppler run -- env` prints all secrets — never log it |
