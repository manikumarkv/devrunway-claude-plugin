---
name: pnpm
description: pnpm conventions — workspace setup, .npmrc, filtering, catalog version alignment, and strict dependency isolation. Load when working with pnpm-workspace.yaml or pnpm-lock.yaml.
user-invocable: false
stack: package-manager/pnpm
paths:
  - "pnpm-workspace.yaml"
  - "pnpm-lock.yaml"
  - ".npmrc"
---

Full standards in [pnpm.md](pnpm.md). Always-on summary:

**Workspace:**
- Declare packages in `pnpm-workspace.yaml`, not `package.json`
- Cross-workspace deps use `workspace:*` — never a version number
- Root `package.json` must be `"private": true`

**Dependency isolation (pnpm's key feature):**
- pnpm uses a content-addressable store + symlinks — packages can only import what they declare
- Never rely on hoisted packages; if something imports without declaring it, fix the `package.json`
- `shamefully-hoist=true` in `.npmrc` disables isolation — avoid it; it defeats the purpose

**Commands:**
- `pnpm install` — install all packages
- `pnpm add <pkg> --filter <workspace>` — add to a specific package
- `pnpm --filter <workspace> run <script>` — run script in one package
- `pnpm -r run <script>` — run script in all packages (recursive)
- `pnpm dlx <pkg>` — one-off run without installing (like npx)

**Lockfile:**
- Always commit `pnpm-lock.yaml`
- Use `pnpm install --frozen-lockfile` in CI

**Never:**
- Mix `npm install` or `yarn add` commands in a pnpm project — corrupts the lockfile
- Use `shamefully-hoist=true` as a permanent fix — it hides a missing declaration
- Commit `.pnpm-store/` or `node_modules/`

**Related skills:** CI layer (frozen-lockfile in pipeline), `secrets/env-only`
