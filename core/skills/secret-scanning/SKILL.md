---
name: secret-scanning
description: Scan the codebase for accidentally committed secrets, tokens, keys, and credentials. Load when reviewing code before PR, auditing a repository, or investigating a suspected leak.
user-invocable: false
---

Full standards in [secret-scanning.md](secret-scanning.md). Always-on summary:

**Scan for:**
- AWS keys (`AKIA[0-9A-Z]{16}`, `aws_secret_access_key`)
- Cognito credentials (client IDs, pool IDs in hardcoded strings)
- JWT secrets and signing keys
- Database connection strings with passwords (`postgres://user:password@`)
- API keys in any form (`api_key`, `apiKey`, `API_KEY` assigned a value)
- Private keys (`-----BEGIN RSA PRIVATE KEY-----`)
- `.env` files with real values committed to git history

**Immediate actions if found:**
1. Rotate the credential immediately — assume it is compromised
2. Remove from git history with `git filter-repo` (not just delete the file)
3. Check CloudTrail / access logs for unauthorized use
4. Add to `.gitignore` and `.env.example`

**Prevention:**
- `.env` always in `.gitignore` — never committed
- Use `process.env.VAR` in code, never literals
- GitHub secret scanning enabled on the repo (Settings → Security)
- `npm audit` in CI catches dependency vulnerabilities too

**Related skills — apply together:**
- `security` — secrets in SSM/Secrets Manager, never hardcoded
- `pipeline` — secret scanning runs in CI before build
- `conventional-commit` — a "fix: remove accidental key" commit does not erase history
