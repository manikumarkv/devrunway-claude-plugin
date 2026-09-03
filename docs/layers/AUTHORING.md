# Authoring a layer

Read this before writing any layer under `layers/`. It is the shared contract every
layer-authoring session works from, so that a session starting cold produces a layer
consistent with the rest without re-deriving conventions.

Companion: one brief per layer in [`briefs/`](briefs/). The brief is the *spec* — what this
particular layer must contain. This file is the *format* — how every layer is shaped.

---

## 1. What a layer is

A layer is a directory holding standards for one technology, routed to the model by file
pattern. It is loaded on demand by `stack-dispatcher`, never ambiently.

```
layers/<category>/<tech>/
  SKILL.md          frontmatter + a short always-on summary
  <tech>.md         the full standards — what layer-consultant actually reads
  <tech>.eval.yaml  executable proof the standards work
```

All three files are required. A layer without an eval is unverified; a layer without a
detail file has nowhere to put the substance.

## 2. How a layer gets loaded

```
/dev-code, /dev-design, /dev-review, /security-review, /eval, /forge
   → the skill forks into its own context
   → calls stack-dispatcher with { task, target_files }
   → find layers -name SKILL.md -mindepth 3
   → reads each layer's `paths:` frontmatter, glob-matches the target files
   → caps at 5 layers, most specific globs first
   → spawns one layer-consultant per match, in parallel
   → each reads the detail .md and returns ≤60 lines
```

Three consequences that constrain how you write a layer:

- **The 5-layer cap is real.** If more than five layers match a file, the least specific are
  dropped silently. This is the single most important constraint below.
- **A layer without `paths:` is never routed.** It is reported as `Unroutable` and skipped.
- **The consultant returns ≤60 lines.** The detail file can be long, but it must be
  *skimmable* — headed sections, tables, short rules — so a consultant can extract the
  relevant slice without reading linearly.

## 3. Globs: split by file role, not by topic

This is where mobile layers differ from most existing ones, and where they will go wrong if
written carelessly.

A Flutter app is entirely `.dart` files. A layer globbing `**/*.dart` matches every file in
the project, so it competes for the 5-slot cap on *every* dispatch and crowds out the
specific layers that actually apply.

```yaml
# ✅ role-based — matches only the files this layer has rules for
paths:
  - "**/providers/*.dart"
  - "**/*_providers.dart"
  - "**/application/**/*.dart"

# ❌ topic-based — matches everything, wins nothing, evicts better layers
paths:
  - "**/*.dart"
```

Rules:

- Every glob names a **directory role** (`providers/`, `services/`, `pages/`, `widgets/`,
  `models/`, `router/`, `l10n/`, `test/`) or a **specific filename shape**
  (`*_providers.dart`, `pubspec.yaml`, `*.arb`).
- Two layers should not claim the same role. If they do, they are one layer.
- Exactly one layer — `mobile/flutter` — may carry a broad fallback glob, because something
  has to answer for a Dart file in no recognised directory. Nothing else may.
- Prefer three narrow globs over one wide one.

## 4. `SKILL.md`

```markdown
---
name: <tech>
description: <One line naming the topics, ending "Load when working with X.">
user-invocable: false
stack: <category>/<tech>
paths:
  - "**/providers/*.dart"
  - "**/*_providers.dart"
---

Full standards in [<tech>.md](<tech>.md). Always-on summary:

**<Topic>:**
- <Rule, imperative, one line, specific enough to act on>
- <Rule>

**<Topic>:**
- <Rule>
```

- `description` is what the dispatcher reads when deciding relevance. Name the concrete
  topics, not a category.
- `user-invocable: false` for every layer. A layer is not a slash command.
- The summary is **10–20 lines**. It is the fallback when the consultant is not run — it must
  be useful alone, and it must not contradict the detail file.

## 5. The detail file

The substance. Structure for retrieval, not for reading start to finish.

- Open with a scope paragraph: what this layer covers, and explicitly what it does not,
  naming the neighbouring layer that does.
- Numbered `##` sections, one concern each.
- State the rule first, in bold, then the reason. A rule without its reason gets discarded
  the first time it is inconvenient.
- Show correct code. Show the wrong version only where the wrong version is what a competent
  developer writes by default — otherwise it is noise.
- Tables for anything with a decision axis (which store, which policy, which API level).
- No prose paragraph longer than four lines.

## 6. The eval

The eval runner reads the scenario, generates code with the skill loaded, and asserts on
**the generated code** — not on prose. Assertions are therefore code tokens.

```yaml
skill: <tech>
skill_files:
  - layers/<category>/<tech>/SKILL.md
version: 1

cases:
  - id: <tech>-01
    name: "<What this proves, as a claim>"
    scenario: |
      <A concrete task, one paragraph. End with "Use the <tech> skill rules.">
    must_contain:
      - "<code token that only appears if the rule was followed>"
    must_not_contain:
      - "<the token of the default wrong answer>"
    rationale: |
      <Why this rule exists and what breaks without it. Two or three lines.>
```

- **Minimum three cases per layer**, one per rule that is genuinely non-obvious.
- Assert on tokens that discriminate. `"Paged"` proves the state shape was used;
  `"class"` proves nothing.
- `must_not_contain` is where the value is: it catches the default wrong answer. Prefer a
  pair — assert the right token appears *and* the wrong one does not.

**Choosing an assertion — the discrimination test.** Before writing an assertion, picture
both the ideal answer and the default wrong answer. The assertion must separate them. An
assertion that appears in *correct* code for unrelated reasons fails every run and is worse
than no assertion, because it makes the eval untrustworthy rather than merely incomplete.

```yaml
# ❌ `dynamic` appears in EVERY correct freezed factory —
#    `factory X.fromJson(Map<String, dynamic> json)` — so this never passes
must_not_contain: ["dynamic"]

# ✅ these appear only in the hand-written parser the rule forbids
must_not_contain: ["json['_id']", "as String"]
```

Three further traps:

- **An assertion is a literal code token, never a description.** `must_not_contain:
  ["connection held past dispose"]` asserts nothing — no generated file contains that
  string, so the case passes unconditionally and proves nothing. If you cannot name a token,
  the rule is not eval-testable; state it in the detail file and drop the case.
- **Substrings match inside longer identifiers.** `"String status"` also matches a field
  named `statusLabel`. Prefer a token with a boundary — a full declaration, an annotation,
  or a call with its parenthesis.
- **`must_not_contain` also matches comments.** A generated answer that *mentions* the wrong
  approach in a comment while doing the right thing will fail. Assert on tokens that only
  appear in executable code.

The eval tables in `briefs/` are **sketches of intent, not literal assertions**. Several
were written before this section existed and contain prose. Treat a brief's assertion as
"prove this rule was followed" and choose the discriminating token yourself.

**Verify before committing.** Run the eval — either `/eval <tech>` or the `eval-runner`
agent — and confirm every case passes against code generated from `SKILL.md` alone. A
failing case means one of two things, in this order: the standards are unclear (fix the
layer), or the assertion does not discriminate (fix the eval). Never commit an unrun eval.
The `rationale` is read by whoever triages a future failure — write it for them.

## 7. Checklist before committing

- [ ] `SKILL.md`, `<tech>.md` and `<tech>.eval.yaml` all present
- [ ] Frontmatter complete: `name`, `description`, `user-invocable: false`, `stack`, `paths`
- [ ] Globs are role-based and claimed by no other layer
- [ ] Summary is 10–20 lines and consistent with the detail file
- [ ] Detail file opens with scope boundaries naming neighbouring layers
- [ ] ≥3 eval cases, each asserting on code tokens, each with a rationale
- [ ] `/eval <tech>` passes
- [ ] `stack-dispatcher` returns this layer for a representative target file, and does not
      return it for an unrelated one

**Shared status tables are not yours to edit.** `docs/layers/README.md` and
`docs/ROADMAP.md` are updated by whoever is coordinating the build, not by the layer author.
Several parallel authors writing the same two files produces merge noise and half-staged
commits — the first three builds each had to hand-stage isolated blobs to work around it.
Report your layer as done; let the coordinator flip the row.

Commit prefix: `feat(layer):` for a new layer, `chore(plugin):` for tooling around it.

---

## 8. Layers vs slash commands

Not everything in the Flutter catalogue is a layer. A layer routes by file glob, which only
works for guidance you trigger by *editing code*.

| Kind | Lives in | Routed by | Frontmatter |
|---|---|---|---|
| Layer | `layers/<cat>/<tech>/` | `paths:` globs, via dispatcher | `user-invocable: false` |
| Command | `skills/<name>/` | The user typing `/<name>` | `user-invocable: true` |

Anything with no file context — build failure triage, store submission, certificate setup,
a device-testing checklist — is a command. Its brief lives in `briefs/` alongside the
layers, and says so at the top.
