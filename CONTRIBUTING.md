# Contributing to devrunway

devrunway is built around a modular layer system. Each layer teaches Claude the standards for one specific technology. Community contributions are how stub layers become real.

---

## What to contribute

The best place to start is a stub layer — any layer marked `🫥 Stub` in [docs/ROADMAP.md](docs/ROADMAP.md). Examples:

- `layers/frontend/vue/` — Vue 3 + Pinia standards
- `layers/backend/python-fastapi/` — FastAPI + Pydantic standards
- `layers/testing/unit/jest/` — Jest mock patterns
- `layers/css/styled-components/` — styled-components conventions

---

## Layer structure

Every layer is a directory under `layers/<category>/<tech>/`. A minimal layer has two files:

```
layers/testing/unit/jest/
  SKILL.md          ← frontmatter + always-on summary
  jest-standards.md ← full detailed standards doc
```

---

## SKILL.md format

```yaml
---
name: jest-standards
description: Jest testing patterns — mock patterns, timer mocks, module mocking, coverage thresholds. Load when working with Jest tests.
user-invocable: false
stack: testing/unit/jest
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"
  - "jest.config.*"
---

Full standards in [jest-standards.md](jest-standards.md). Always-on quick-reference:

**Test structure:**
- Use `describe` blocks to group related tests
- One assertion per test where possible
- Prefer `it('should ...')` over `test('does ...')`

**Mocking:**
- `jest.mock('./module')` at file top
- `jest.spyOn(obj, 'method').mockReturnValue(val)` for partial mocks
- `jest.clearAllMocks()` in `afterEach`
- Never mock what you own

**Coverage:**
- Thresholds in `jest.config.ts`: `{ branches: 80, functions: 85, lines: 85 }`
- Coverage report: `--coverage --coverageReporters=lcov`
```

### Required frontmatter fields

| Field | Required | Notes |
|---|---|---|
| `name` | ✅ | Unique identifier, kebab-case |
| `description` | ✅ | One line — what it teaches Claude, what files it loads on |
| `user-invocable` | ✅ | `false` for background skills, `true` for slash commands |
| `stack` | ✅ | `<category>/<tech>` — matches the directory path under `layers/` |
| `paths` | ✅ | Glob patterns for files that trigger auto-load |
| `mcp` | Optional | Only if this layer has an MCP server (see below) |

### `mcp:` field (optional)

If your technology has an MCP server, declare it so `/setup` can auto-generate `.mcp.json`:

```yaml
mcp:
  package: "@modelcontextprotocol/server-postgres"
  env:
    POSTGRES_CONNECTION_STRING: "postgresql://user:pass@host:5432/db"
```

---

## Companion .md file

The companion `.md` file is the full standards document. It should cover:

1. **Setup / config** — how to configure the tool in a project
2. **Key patterns** — the 10-15 most important patterns Claude must know
3. **Anti-patterns** — what NOT to do (with brief reason)
4. **Testing** — how to write tests for code using this tech
5. **Examples** — short, concrete code snippets

Length guide: 200–600 lines. Enough to be authoritative, short enough to fit in context.

---

## Step-by-step guide

1. **Find a stub** in [docs/ROADMAP.md](docs/ROADMAP.md) or open an issue to propose a new one

2. **Fork the repo** and create a branch:
   ```bash
   git checkout -b feat/layer-jest
   ```

3. **Remove the stub README** and create the two skill files:
   ```bash
   rm layers/testing/unit/jest/README.md
   # Create SKILL.md and jest-standards.md
   ```

4. **Test it locally** — open a project that uses this tech, load the plugin, and verify Claude follows the standards when editing files matching `paths:`

5. **Submit a PR** with:
   - Title: `feat(layer): add jest-standards`
   - Description: what patterns the layer covers, what you tested it on
   - At least one example of Claude applying the standard correctly

---

## Quality bar

A layer PR will be merged when:

- [ ] `SKILL.md` has all required frontmatter fields
- [ ] `paths:` globs correctly match the tech's file types
- [ ] Standards are concrete and actionable (Claude can follow them without guessing)
- [ ] No duplicate content with `core/` (core covers universal principles; layers cover tech-specific implementation)
- [ ] Anti-patterns section explains *why*, not just *what*
- [ ] The stub `README.md` is deleted

---

## Adding a new layer category

If you need a category that doesn't exist yet (e.g. `layers/analytics/`), open an issue first so we can agree on the naming convention before you build.

---

## Questions?

Open an issue or start a discussion on GitHub. The maintainer responds within 48 hours.
