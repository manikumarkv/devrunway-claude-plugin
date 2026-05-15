# Contributing to devrunway

devrunway is built around a modular layer system. Each layer teaches Claude the standards for one specific technology. Community contributions are how stub layers become real.

---

## What to contribute

Three ways to contribute:

**1. Improve an existing layer** — All 135 layers are implemented, but every layer can get sharper. Common improvements:
- Add more code examples for edge cases
- Expand the "Common mistakes" table
- Update for a new major version of the library
- Add a missing pattern you hit in production

**2. Add a new layer** — A technology that devrunway doesn't cover yet. Check [docs/ROADMAP.md](docs/ROADMAP.md) and open an issue before building so we can agree on the path and avoid duplication.

**3. Add a new layer category** — If you need a category that doesn't exist (e.g. `layers/analytics/`), open an issue first so we can agree on the naming convention before you build.

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
2. **Key patterns** — the 10-15 most important patterns Claude must know, with working code examples
3. **Testing** — how to write tests for code using this tech
4. **Common mistakes table** — always the last section, in this format:

```markdown
## Common mistakes

| Mistake | Fix |
|---|---|
| Doing X the wrong way | Do Y instead |
| Forgetting to Z | Always Z because ... |
```

Length guide: 200–600 lines. Enough to be authoritative, short enough to fit in context.

---

## Step-by-step guide

### Adding a new layer

1. **Open an issue** proposing the layer — include the technology, the `layers/<category>/<tech>/` path, and why it's not covered by an existing layer.

2. **Fork the repo** and create a branch:
   ```bash
   git checkout -b feat/layer-jest
   ```

3. **Create the layer directory** with the two required files:
   ```bash
   mkdir -p layers/testing/unit/jest
   # Create SKILL.md and jest-standards.md
   ```

4. **Test it locally** — open a project that uses this tech, load the plugin, and verify Claude follows the standards when editing files matching `paths:`

5. **Submit a PR** with:
   - Title: `feat(layer): add jest-standards`
   - Description: what patterns the layer covers, what you tested it on
   - At least one example of Claude applying the standard correctly

### Improving an existing layer

1. **Fork the repo** and create a branch: `fix/layer-react-signals` or `feat/layer-zod-async`
2. **Edit the relevant `.md` file** — make your changes, keep the "Common mistakes" table at the end
3. **Submit a PR** with:
   - Title: `fix(layer): add async refinement pattern to zod-validation`
   - Description: what was missing or wrong, link to official docs if relevant

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

## Questions?

Open an issue or start a discussion on GitHub. The maintainer responds within 48 hours.
