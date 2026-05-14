# Yarn Standards

---

## Setup — Yarn Berry (v4)

```bash
# Enable Corepack (ships with Node 18+)
corepack enable

# Set Berry as the version for this project
yarn set version stable

# Creates .yarn/releases/yarn-*.cjs and updates .yarnrc.yml
```

```yaml
# .yarnrc.yml — commit this file
yarnPath: .yarn/releases/yarn-4.x.x.cjs
nodeLinker: node-modules   # or 'pnp' — choose one and document why
```

`.yarn/releases/` should always be committed — it pins the Yarn binary for the entire team.

---

## Linker strategy

| Linker | Pros | Cons | Choose when |
|---|---|---|---|
| `node-modules` | Drop-in; IDE/tooling compat | Slower, duplicates deps | Migrating from npm/pnpm; complex dep trees |
| `pnp` | Fastest installs; strict isolation | Requires editor PnP plugin; some tools break | Greenfield; strict dependency discipline |

**Configuring PnP:**
```yaml
# .yarnrc.yml
yarnPath: .yarn/releases/yarn-4.x.x.cjs
nodeLinker: pnp
```

Editor setup for PnP (VS Code):
```bash
yarn dlx @yarnpkg/sdks vscode
```

---

## Zero-install strategy

Zero-install commits the Yarn cache so `yarn install` isn't needed after clone.

```yaml
# .yarnrc.yml with zero-install
enableGlobalCache: false
```

```gitignore
# .gitignore — zero-install (commit the cache)
.yarn/*
!.yarn/cache
!.yarn/patches
!.yarn/plugins
!.yarn/releases
!.yarn/sdks
!.yarn/versions

# .gitignore — NOT zero-install (don't commit the cache)
.yarn/*
!.yarn/patches
!.yarn/plugins
!.yarn/releases
!.yarn/sdks
!.yarn/versions
.pnp.*
```

**Zero-install trade-offs:**
- ✅ `yarn install` not required after clone — fast onboarding
- ✅ Reproducible without npm registry access
- ❌ Large PRs — every dep change includes cache files
- Choose zero-install for teams that prioritise onboarding speed

---

## Workspaces

```json
// Root package.json
{
  "name": "my-monorepo",
  "private": true,
  "workspaces": ["apps/*", "packages/*"]
}
```

```json
// packages/ui/package.json
{
  "name": "@myapp/ui",
  "dependencies": {
    "@myapp/utils": "workspace:^"
  }
}
```

- `workspace:^` — resolves to local package; replaced with `^version` on publish
- `workspace:~` — resolves to local; replaced with `~version`
- `workspace:*` — resolves to local; replaced with exact version

**Running scripts across workspaces:**
```bash
# Run build in all workspaces (in parallel)
yarn workspaces foreach -A --parallel run build

# Run in topological order (respects deps)
yarn workspaces foreach -A --topological run build

# Run in a specific workspace
yarn workspace @myapp/api run dev

# Run in workspaces that depend on @myapp/ui
yarn workspaces foreach --recursive --from @myapp/ui run test
```

---

## Common commands

```bash
# Install all dependencies
yarn

# Add a dependency to current package
yarn add zod
yarn add -D vitest          # devDependency
yarn add -P react           # peerDependency

# Add to a specific workspace
yarn workspace @myapp/api add express

# Remove a dependency
yarn remove lodash

# Run a script
yarn run dev
yarn dev   # shorthand

# One-off execution (no global install)
yarn dlx create-next-app my-app

# Upgrade packages interactively
yarn upgrade-interactive

# Check for outdated packages
yarn outdated

# Security audit
yarn npm audit --all
```

---

## CI — immutable install

```bash
# CI must use --immutable — errors if yarn.lock would be updated
yarn install --immutable
```

Example GitHub Actions:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'yarn'
- run: yarn install --immutable
- run: yarn workspaces foreach -A run typecheck
- run: yarn workspaces foreach -A run test
```

---

## Constraints — enforce rules across workspaces

Yarn Constraints enforce rules across all packages in a monorepo:

```javascript
// .yarn/constraints.pro (Prolog-style rules)

% All workspaces must have a license field
gen_enforced_field(WorkspaceCwd, 'license', 'MIT').

% All workspaces must use the same version of TypeScript
gen_enforced_dependency(WorkspaceCwd, 'typescript', '^5.5.0', devDependencies) :-
  workspace_has_dependency(WorkspaceCwd, 'typescript', _, devDependencies).
```

```bash
# Check constraints
yarn constraints

# Fix auto-fixable constraint violations
yarn constraints --fix
```

---

## Patches — modifying node_modules

When you need to patch a dependency instead of waiting for upstream:

```bash
# Create a patch for a package
yarn patch <package-name>

# Edit the patched copy, then apply
yarn patch-commit <path-printed-above>
```

This creates `.yarn/patches/<package>.patch` — commit it. The patch applies automatically on `yarn install`.
