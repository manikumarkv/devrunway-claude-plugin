# npm Standards

---

## package.json structure

```json
{
  "name": "@scope/package-name",
  "version": "1.0.0",
  "description": "One sentence.",
  "engines": { "node": ">=20.0.0" },
  "type": "module",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "require": "./dist/index.cjs"
    }
  },
  "files": ["dist", "README.md"],
  "scripts": {
    "dev": "...",
    "build": "...",
    "test": "...",
    "lint": "eslint .",
    "format": "prettier --write .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {},
  "devDependencies": {}
}
```

**Required fields for any app:**
- `name` — kebab-case, scoped if publishable (`@org/name`)
- `version` — semver; increment on every release
- `engines.node` — minimum Node.js version your code is tested against
- `scripts.test` — CI runs this; it must exit non-zero on failure

---

## Dependency types

| Type | When to use | Examples |
|---|---|---|
| `dependencies` | Required at runtime | `express`, `react`, `zod` |
| `devDependencies` | Tooling and test-only | `vitest`, `eslint`, `typescript` |
| `peerDependencies` | Library declares what host app must supply | React component libraries declaring `react` |
| `optionalDependencies` | App works without it | Platform-specific native bindings |

**Rules:**
- Apps rarely need `peerDependencies` — that's for published libraries
- Never put a runtime import in `devDependencies` — it will fail in production
- Pin exact versions for internal tooling that everyone must stay in sync on

---

## Version ranges

| Range | Meaning | When to use |
|---|---|---|
| `^1.2.3` | `>=1.2.3 <2.0.0` | Most dependencies |
| `~1.2.3` | `>=1.2.3 <1.3.0` | When minor bumps break you |
| `1.2.3` | Exact | Internal packages, critical deps |
| `>=1.2.3` | Any version above | Peer deps (wide compatibility) |

**Never use `*` or `latest`** — breaks reproducibility.

---

## Lockfile discipline

`package-lock.json` records the exact version tree installed. Treat it like source code.

```bash
# Development: use npm install (updates lock when package.json changes)
npm install

# CI: always use npm ci — it respects the lockfile exactly and errors on mismatch
npm ci

# After pulling changes that updated package.json:
npm install   # resolves and updates lockfile, then commit the result
```

**Rules:**
- Always commit `package-lock.json`
- Never edit it manually
- If it conflicts in a PR, resolve by running `npm install` on the merged `package.json`
- `npm ci` is faster than `npm install` in CI — it deletes `node_modules` and rebuilds from lockfile

---

## Script conventions

Use exactly these names so CI, tooling, and onboarding are predictable:

```json
{
  "scripts": {
    "dev": "node --watch src/index.js",
    "build": "tsc -p tsconfig.build.json",
    "start": "node dist/index.js",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint . --max-warnings 0",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "clean": "rm -rf dist node_modules/.cache"
  }
}
```

**Pre/post hooks:**
```json
{
  "scripts": {
    "prepare": "husky",
    "prepublishOnly": "npm run build && npm test"
  }
}
```
- `prepare` — runs after `npm install` and before `npm publish`; good for Husky setup
- `prepublishOnly` — last gate before publishing to npm registry

---

## .npmrc configuration

```ini
# .npmrc (commit this file)

# Exact versions — no ^ ranges added automatically
save-exact=true

# Fail install if lockfile is out of date (use with npm 7+)
# Useful in CI to catch forgotten lockfile updates
# ci=true  ← use npm ci command instead; this flag does something different

# Private registry (if using Verdaccio, Nexus, GitHub Packages)
# @scope:registry=https://npm.pkg.github.com
# //npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

**Never put auth tokens in `.npmrc` as literals** — use `${ENV_VAR}` references.

---

## Security — npm audit

```bash
# Check for known vulnerabilities (run in CI)
npm audit --audit-level=high

# Auto-fix safe updates
npm audit fix

# Upgrade breaking changes (review manually)
npm audit fix --force
```

Set `--audit-level=high` in CI — low and moderate vulnerabilities exist in almost every project and will cause noise. High and critical are actionable.

Add to CI pipeline:
```yaml
- run: npm audit --audit-level=high
```

---

## Monorepo workspaces

```json
{
  "name": "my-monorepo",
  "private": true,
  "workspaces": ["apps/*", "packages/*"]
}
```

```bash
# Install all workspaces
npm install

# Run a script in a specific workspace
npm run build --workspace=packages/ui

# Run a script in all workspaces
npm run test --workspaces --if-present

# Add a dependency to a specific workspace
npm install zod --workspace=apps/api
```

**Workspace rules:**
- Root `package.json` must be `"private": true`
- Internal cross-package deps: use `"@scope/package": "*"` and let npm workspace resolve
- Shared devDependencies (eslint, typescript) live at the root, not in each package

---

## Publishing checklist

Before `npm publish`:

- [ ] `version` bumped (`npm version patch|minor|major`)
- [ ] `files` field lists exactly what should ship
- [ ] `main`/`exports` points to the compiled `dist/`, not `src/`
- [ ] `prepublishOnly` script runs build + tests
- [ ] `CHANGELOG.md` updated
- [ ] `.npmignore` OR `files` field in use (not both — use `files`, it's the allowlist)

```bash
# Dry run — see exactly what will be published
npm pack --dry-run

# Publish to registry
npm publish --access public   # scoped packages need --access public
```
