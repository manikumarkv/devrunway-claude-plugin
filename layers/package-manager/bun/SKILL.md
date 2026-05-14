---
name: bun
description: Bun conventions — bun.lockb, bunfig.toml, workspace setup, bun run scripts, and compatibility with npm packages. Load when working with bun.lockb or bunfig.toml.
user-invocable: false
stack: package-manager/bun
paths:
  - "bun.lockb"
  - "bunfig.toml"
---

Full standards in [bun.md](bun.md). Always-on summary:

**Runtime + package manager:** Bun is both a runtime and package manager. When you use Bun, use `bun` for everything — don't mix `node` or `npm` commands.

**Lockfile:**
- `bun.lockb` is a binary lockfile — always commit it
- Never edit it manually; run `bun install` to regenerate

**Scripts:**
- `bun run <script>` — runs scripts from `package.json`
- `bun run src/index.ts` — runs a file directly (no compile step needed)
- `bun --hot src/index.ts` — hot reload during development
- `bunx <package>` — one-off execution (equivalent to npx)

**Workspaces:**
- Declared in `package.json` under `"workspaces"` (same as npm)
- Use `"workspace:*"` for cross-workspace deps

**Performance:**
- `bun install` is 10-25× faster than npm — ideal for CI
- Bun's test runner (`bun test`) is faster than Jest/Vitest — migrate if tests are slow

**Never:**
- Mix `npm install` or `yarn add` in a Bun project — will create a second lockfile
- Use `require()` when Bun supports native ES modules natively
- Assume all npm packages are Bun-compatible — most are, but check if native modules behave oddly

**Related skills:** CI layer (use `bun install --frozen-lockfile` in pipeline)
