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

### Glob scope — no catch-all patterns

`paths:` globs are the *only* signal `stack-dispatcher` has. It matches them against the files being edited and takes **at most five layers**, ranked by specificity. So a glob like `**/*.ts` does not merely describe your layer — it enters your layer into a bidding war on every TypeScript file in every project, and pushes out the layer that file was actually about.

A **catch-all** is a glob whose only constraint is a file extension, free-floating anywhere in the tree: `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.py`, `**/*.vue`, `**/*.yaml`, `*.md`, `**/*`. Do not add one. Scope by directory or filename instead — the places that technology's code actually lives.

```yaml
# ✗ Before — Vault bids for a slot on every TS/JS/Python file in the repo
paths:
  - "**/*.ts"
  - "**/*.js"
  - "**/*.py"
  - "**/vault*"
  - "**/*secrets*"

# ✓ After — Vault loads where secrets handling actually lives
paths:
  - "**/vault*"
  - "**/vault/**"
  - "**/*secrets*"
  - "**/secrets/**"
  - "**/policies/*.hcl"
```

**The one exception:** a layer whose subject *is* that file format may claim it. `typescript-patterns` claims `**/*.ts`, `react-standards` claims `**/*.tsx`, `sketch` claims `**/*.sketch`. The test is whether the extension identifies the technology. `.sketch` files only exist in Sketch projects; `.ts` files exist in every TypeScript project whether or not it uses your library. If your layer is a *library or service* that merely happens to be written in a language, the language's extension is not yours to claim.

**Do not over-correct.** A layer that matches nothing fails silently — it never loads, and nothing reports it, the same invisible failure class as the `-maxdepth` bug described in [ADR 0001](docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md). Before narrowing, write down the filenames a real project using this technology would actually have, and check each one still matches. Watch for prefix collisions in particular — `**/use*.ts` also matches `user.repository.ts`, and `**/*ses*` also matches `session.ts`. If you cannot find a defensible narrow glob, **leave the broad one in place** and say so in the PR: a layer that loads too often is a nuisance, a layer that never loads is a silent hole.

Shared globs are a separate matter — see ADR 0001. When your layer competes with a sibling in the same category, **add** vendor-specific globs alongside the shared one and open the body with a scope line. Never strip a shared glob to win the collision.

### Eval files

If you add a `.eval.yaml`, its `skill_files:` must list **both** the `SKILL.md` and the companion detail `.md`. `layer-consultant` loads the detail file at runtime, so an eval listing only `SKILL.md` validates rules the runtime never reads. This was true of 95 of the first 100 eval files and hid at least one real contradiction between a `SKILL.md` and its detail file.

Assertions are literal, case-sensitive substring matches against generated output. Check each one adversarially before committing it:

- Can a **compliant** answer fail it? (`must_not_contain: "fetch("` also matches `refetch(`; `"res."` matches `features.`)
- Can it **ever** fire? (`must_not_contain: "Scan("` never matches `new ScanCommand(`)
- Does it test what the case name claims, or does it pass vacuously?
- Does the `must_not_contain` literal appear **in the layer's own guidance**? If the standards quote the anti-pattern by name, the case fires on any answer that reproduces that block. This broke `notion-01` (*"loose pages"* is the standards' own term, used 4×) and `error-handling` (`flatten()` left in as a quoted anti-pattern).

### A green case is not a working case

A passing assertion proves a token appeared. It does not prove the code is right.

`payment/braintree` sat at **3/3 green** while teaching a webhook handler that acknowledged before verifying the signature, a checkout form that ignored the payment response, and a route that charged `req.body.amount` unauthenticated. Its signature case asserted `must_contain: "signature"`, which matches inside the parameter name `bt_signature` — so it passed whether verification came before the acknowledgement or after.

So every case guarding a subtle rule must **discriminate**: write the correct implementation and the incorrect one the case targets, and score both. The case must score **1 on the first and 0 on the second**. If both score 1, the case is defective — even when green.

### Write the defect a second way

Scoring one wrong implementation is not enough, because you will write the one you already had in mind. That is the same blind spot that made the guard narrow in the first place.

**For every guard, write the same defect in a second idiomatic spelling before believing it.** Measured across two repair passes, the author's own probe reported clean every time while an adversarial re-probe found holes: 5 defective cases in the payment group, 13 in the secrets group. Every one had a single cause — *the guard matched one spelling of a pattern that has several*:

| Guard | Evasion that scored full marks |
|---|---|
| `req.json()` | `const { folder } = await request.json()` — different receiver, and destructuring leaves no `body.folder` |
| `console.log(result` | `logger.info("...", { result })` — a structured logger is not `console.log`, and shipped a live database password |
| `localStorage.getItem(` | `window.localStorage['auth_token']` — bracket access |
| `${Date.now()}` | `const ts = Date.now()` then `` `pi-${order.id}-${ts}` `` — a variable in the way |
| `res.status(400)` | `res.sendStatus(400)` — which does not contain it, so it failed **correct** code |

**Guard the property, not one syntax for expressing it.** Guard the request property being read, not `req.json()`. Guard the clock at its source, not one interpolation of it. Guard the trait key, not the caller's variable name.

### Draw positives from the guidance, not from memory

A `must_contain` must be a literal the layer's own text actually writes. Assertions invented from what the author assumed the standards said produced this class of failure:

- `cld-02` asserted `cloudinary.url(` while the layer mandates a **second** display path (`<AdvancedImage>`), so following its own React guidance scored 0/2
- `flagsmith-03` asserted `identity` against a detail file whose canonical call is `identify(` — which does not contain it
- `cld-03` asserted `userId` where the layer's own helper spells it `ownerId`
- `sm-02` asserted `SecretId:`, the TypeScript spelling, on a scenario the layer answers in Python (boto3 takes `SecretId=`)

Before committing, run the mechanical check: **every `must_contain` literal is present in that layer's `skill_files`, and no `must_not_contain` literal is.** Declare any deliberate exception in the case's `rationale`.

### Fix the guidance, not the test

When a case fails, the default repair is to the **standards**, not the assertion. Weakening a guard to reach green is how `braintree` got to 3/3.

Sometimes a failing case is telling you the guidance has a hole rather than a typo: `stripe-03` asked for a frontend payment form, and the layer prohibited raw card fields while shipping **no frontend example at all** — so the scenario asked for something the standards never showed how to build. The repair was to write the missing guidance, then draw the assertion from it.

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
- [ ] No catch-all glob (`**/*.ts`-class) unless the layer's subject *is* that file format
- [ ] Each glob was checked against realistic filenames, so the layer is not silently unroutable
- [ ] Standards are concrete and actionable (Claude can follow them without guessing)
- [ ] No duplicate content with `core/` (core covers universal principles; layers cover tech-specific implementation)
- [ ] Anti-patterns section explains *why*, not just *what*
- [ ] The stub `README.md` is deleted

---

## Questions?

Open an issue or start a discussion on GitHub. The maintainer responds within 48 hours.
