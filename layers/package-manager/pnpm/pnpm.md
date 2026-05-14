# pnpm Standards

---

## Workspace setup

```yaml
# pnpm-workspace.yaml
packages:
  - "apps/*"
  - "packages/*"
  - "tools/*"
```

```json
// Root package.json
{
  "name": "my-monorepo",
  "private": true,
  "scripts": {
    "dev": "pnpm -r --parallel run dev",
    "build": "pnpm -r run build",
    "test": "pnpm -r run test",
    "lint": "pnpm -r run lint",
    "typecheck": "pnpm -r run typecheck"
  },
  "devDependencies": {
    "typescript": "5.5.0"
  }
}
```

---

## .npmrc

```ini
# .npmrc — commit this file

# Strict dependency isolation (default in pnpm, be explicit)
# Packages can only import what's in their package.json
node-linker=isolated

# Exact versions — no ^ added automatically
save-exact=true

# Hoisting rules — only hoist specific packages that require it (e.g. eslint plugins)
# public-hoist-pattern[]=*eslint*
# public-hoist-pattern[]=*prettier*

# Private registry (if applicable)
# @scope:registry=https://npm.pkg.github.com
# //npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

**Never set `shamefully-hoist=true`** as a blanket fix. It disables pnpm's core feature (strict isolation). Instead, identify which package has a missing declaration and add it properly.

---

## Cross-workspace dependencies

```json
// packages/ui/package.json
{
  "name": "@myapp/ui",
  "dependencies": {
    "@myapp/utils": "workspace:*"   // ← workspace: prefix, not a version
  }
}
```

`workspace:*` resolves to the exact local package. On publish, pnpm replaces `workspace:*` with the current version number.

---

## Catalog — version alignment

Catalogs keep a single version of shared deps across all workspaces:

```yaml
# pnpm-workspace.yaml
packages:
  - "apps/*"
  - "packages/*"

catalog:
  react: "^18.3.0"
  typescript: "5.5.0"
  zod: "^3.23.0"
```

```json
// Any workspace's package.json
{
  "dependencies": {
    "react": "catalog:",      // resolves to ^18.3.0 from catalog
    "zod": "catalog:"
  }
}
```

**Catalog rules:**
- Put all shared dependencies in the catalog
- Never manually duplicate version numbers across packages when using a catalog
- Run `pnpm install` after editing the catalog to update `pnpm-lock.yaml`

---

## Filtering — run scripts in specific packages

```bash
# Run in a specific package (by name)
pnpm --filter @myapp/ui run build

# Run in a package and all its dependencies
pnpm --filter @myapp/ui... run build

# Run in all packages that depend on @myapp/ui
pnpm --filter ...@myapp/ui run test

# Run in packages changed since main branch
pnpm --filter "[main]" run test

# Run in all packages, ignore failures
pnpm -r --no-bail run lint
```

---

## Installing dependencies

```bash
# Install all (root + all workspaces)
pnpm install

# Add to root
pnpm add -w <package>

# Add to a specific workspace
pnpm add <package> --filter @myapp/api

# Add as devDependency to a workspace
pnpm add -D <package> --filter @myapp/api

# One-off run without installing globally
pnpm dlx create-next-app
```

---

## CI — frozen lockfile

```bash
# CI must use --frozen-lockfile — errors if pnpm-lock.yaml is stale
pnpm install --frozen-lockfile

# Security audit
pnpm audit --audit-level=high
```

Example GitHub Actions step:
```yaml
- uses: pnpm/action-setup@v4
  with:
    version: 9
- run: pnpm install --frozen-lockfile
- run: pnpm audit --audit-level=high
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Running `npm install` in a pnpm repo | Use `pnpm install` — mixing package managers corrupts lockfile |
| `Cannot find module` for a transitive dep | Add the dep explicitly to the package's `package.json` |
| `shamefully-hoist=true` added to fix above | Identify the missing dep, declare it properly, remove the flag |
| Version mismatch between workspaces | Use `catalog:` to enforce a single version |
| Committing `node_modules` | Add to `.gitignore`; pnpm's store is in `~/.pnpm-store` |
