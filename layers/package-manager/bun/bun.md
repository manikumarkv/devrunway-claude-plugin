# Bun Standards

---

## What Bun replaces

Bun is a single toolkit that replaces multiple tools:

| Tool | Bun equivalent |
|---|---|
| Node.js | `bun run` / `bun src/index.ts` |
| npm / yarn / pnpm | `bun install` / `bun add` / `bun remove` |
| ts-node / tsx | `bun run file.ts` (native TypeScript) |
| Jest / Vitest | `bun test` |
| esbuild / Webpack | `bun build` |
| dotenv | Built-in — Bun loads `.env` automatically |

---

## bunfig.toml

```toml
# bunfig.toml — Bun's configuration file (commit this)

[install]
# Save exact versions (no ^ ranges added automatically)
exact = true

# Default registry
# registry = "https://registry.npmjs.org"

# Private registry for a scope
# [install.scopes]
# "@myorg" = { url = "https://npm.pkg.github.com/", token = "$NPM_TOKEN" }

[test]
# Timeout per test in milliseconds
timeout = 10000

# Coverage
coverage = false
# coverageThreshold = { line = 80, function = 80 }
```

---

## Installing dependencies

```bash
# Install all (reads package.json + bun.lockb)
bun install

# Add a dependency
bun add zod

# Add as devDependency
bun add -d vitest

# Add as optional dependency
bun add -o sharp

# Remove a dependency
bun remove lodash

# One-off run without installing
bunx cowsay hello

# Upgrade all packages to latest allowed by ranges
bun update

# Upgrade a specific package
bun update zod
```

---

## Running scripts and files

```bash
# Run a script from package.json
bun run dev
bun dev   # shorthand (if not a built-in command)

# Run a TypeScript file directly (no compilation step)
bun run src/index.ts

# Run with hot reload (restarts on file changes)
bun --hot src/server.ts

# Run with watch mode (restarts on any file change)
bun --watch src/index.ts

# Execute a remote package
bunx create-next-app my-app
```

---

## Testing with Bun

Bun has a built-in test runner compatible with Jest syntax:

```typescript
// *.test.ts
import { describe, it, expect, mock, beforeEach } from "bun:test";

describe("myFunction", () => {
  it("returns the expected value", () => {
    expect(myFunction(1)).toBe(2);
  });

  it("handles errors", () => {
    expect(() => myFunction(-1)).toThrow("Invalid input");
  });
});
```

```bash
# Run all tests
bun test

# Run a specific file
bun test src/user.test.ts

# Watch mode
bun test --watch

# Coverage
bun test --coverage
```

**Bun-specific test APIs:**
- `mock()` — replaces Jest's `jest.fn()`
- `spyOn()` — same as Jest's `jest.spyOn()`
- `mock.module()` — replaces Jest's `jest.mock()`

---

## Building

```bash
# Bundle for browser
bun build src/index.ts --outdir dist --target browser

# Bundle for Node.js (single executable)
bun build src/index.ts --outdir dist --target node

# Bundle for Bun runtime
bun build src/index.ts --outdir dist --target bun

# Minify
bun build src/index.ts --outdir dist --minify

# Watch mode (rebuilds on change)
bun build src/index.ts --outdir dist --watch
```

---

## Environment variables

Bun automatically loads `.env` files — no `dotenv` package needed:

```
Priority (highest to lowest):
1. .env.local
2. .env.{NODE_ENV}   (e.g. .env.production, .env.test)
3. .env
```

```typescript
// Access env vars — Bun loads them automatically
const port = process.env.PORT ?? "3000";
const dbUrl = process.env.DATABASE_URL;  // no dotenv.config() needed
```

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

```bash
# Install all workspaces
bun install

# Run a script in a specific workspace
bun run --cwd apps/api dev

# Run a script in all workspaces
bun run --filter '*' build
```

---

## CI

```bash
# Frozen install — errors if bun.lockb is out of date
bun install --frozen-lockfile

# Faster CI cache: cache ~/.bun/install/cache
```

Example GitHub Actions:
```yaml
- uses: oven-sh/setup-bun@v2
  with:
    bun-version: latest
- run: bun install --frozen-lockfile
- run: bun test --coverage
- run: bun run typecheck
```

---

## Compatibility notes

Most npm packages work with Bun. Exceptions:
- Native Node.js addons (`.node` files) — usually work via Bun's Node.js compat layer
- Some `vm` and `node:worker_threads` APIs — partial support
- Check [bun.sh/docs/runtime/nodejs-apis](https://bun.sh/docs/runtime/nodejs-apis) for the full compatibility table

When migrating from Node.js: swap `node src/index.js` → `bun run src/index.ts` and most things just work.
