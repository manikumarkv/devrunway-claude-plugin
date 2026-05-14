---
name: env-only
description: Environment variable conventions — .env discipline, .env.example, startup validation, and separation by environment. Load when working with .env files or environment variable access.
user-invocable: false
stack: secrets/env-only
paths:
  - ".env*"
  - "**/config/env*"
---

Full standards in [env-only.md](env-only.md). Always-on summary:

**The golden rule:** Secret values live only in environment variables. Never in source code, config files, or version control.

**.env file discipline:**
- `.env` — never committed; contains real secrets for local dev
- `.env.example` — always committed; contains keys with placeholder values
- `.env.test` — committed only if it contains no real secrets (use fake values)
- `.env.production` — never exists as a file; production vars live in the deployment platform

**Validation at startup:**
- Validate all required env vars at app startup — fail loudly if any are missing
- Never read `process.env.VAR` scattered across the codebase — centralise in one config module
- A missing env var at startup is better than a cryptic runtime error at 3 AM

**Access pattern:**
- One `config.ts` / `config.py` / `config.go` file that reads and validates all env vars
- Every other file imports from `config`, never from `process.env` directly

**Never:**
- Hardcode secrets, API keys, or connection strings in source code
- Log env var values (even in debug mode — they end up in log aggregators)
- Use the same secret in multiple environments
- Commit `.env.local` or any file with real values

**Related skills:** `secret-scanning` (detect committed secrets), your cloud/secrets layer for production secret management
