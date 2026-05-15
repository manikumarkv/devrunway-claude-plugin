---
name: doppler
description: Doppler secrets management — CLI sync, SDK usage, environments, service tokens, and CI/CD integration
user-invocable: false
stack: secrets/doppler
paths:
  - "**/.doppler.yaml"
  - "**/doppler.yaml"
  - "**/*.env*"
  - "**/Dockerfile*"
  - "**/.github/workflows/*.yml"
  - "**/*.sh"
---

Full standards in [doppler.md](doppler.md). Always-on summary:

**Project setup:**
- Configure project + environment with `doppler setup`; commit `.doppler.yaml` (no secrets in it)
- Use separate configs per environment: `dev`, `stg`, `prd` — never share service tokens across envs
- Service tokens are scoped to one project/config — use them in CI, containers, and servers

**Local development:**
- Run apps with `doppler run -- <your-command>` — secrets injected as env vars, nothing stored locally
- Never commit `.env` files with real secrets; use `doppler run -- dotenv -e .env.example` for shape

**CI/CD:**
- Store the service token as a CI secret (`DOPPLER_TOKEN`); use `doppler run --` in pipeline steps
- For GitHub Actions, use `doppler/fetch-secrets@v1` or `doppler run --` with the token env var

**SDK usage (Node.js):**
- Use `@dopplerhq/node-sdk` only when dynamic refresh is needed; otherwise prefer CLI injection
- Fetch once at startup; don't fetch per-request

**Security:**
- Never log the `DOPPLER_TOKEN` or any secret values
- Rotate service tokens via the Doppler dashboard on team member offboarding
- Use `doppler secrets download --no-file` in scripts; pipe to `jq` rather than writing to disk

**Never:**
- Never commit service tokens — they are runtime secrets, not configuration
- Never use personal tokens in CI — always use service tokens
- Never use the root/dev config service token in production

**Related skills:** security-principles, logging-standards, pipeline
