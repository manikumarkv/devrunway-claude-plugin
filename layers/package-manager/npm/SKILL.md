---
name: npm
description: npm conventions — package.json structure, script naming, lockfile discipline, dependency types, audit, and workspace patterns. Load when working with package.json or npm scripts.
user-invocable: false
stack: package-manager/npm
paths:
  - "package.json"
  - "package-lock.json"
  - ".npmrc"
  - "**/package.json"
---

Full standards in [npm.md](npm.md). Always-on summary:

**package.json:**
- `engines` field is required — declare the minimum Node.js version your code needs
- `files` field controls what gets published — be explicit; never rely on `.npmignore`
- `exports` over `main` for new packages — enables subpath imports and dual CJS/ESM

**Script naming — use these exact names:**
- `dev` — local development server
- `build` — production build
- `test` — run all tests (used by CI)
- `lint` — run linter (read-only, no fixes)
- `format` — run formatter with auto-fix
- `typecheck` — type check without emitting (CI gate)

**Dependency types:**
- `dependencies` — runtime only (what your app needs to run)
- `devDependencies` — tooling only (bundlers, linters, test runners)
- `peerDependencies` — for library authors; never for apps

**Lockfile:**
- Always commit `package-lock.json` — it's the source of truth for reproducible builds
- Never edit it manually
- Use `npm ci` in CI, not `npm install` — it respects the lockfile exactly

**Never:**
- `npm install -g <package>` in application code or CI (use `npx` instead)
- Commit `node_modules/`
- Use `^` ranges in `peerDependencies` — be exact or use `>=`
- Skip `npm audit` — run it in CI with `--audit-level=high`

**Related skills:** `ci` layer (npm ci in pipeline), `secrets/env-only` (never in package.json)
