---
name: eval-runner
description: Runs eval cases from .eval.yaml files. For each case — loads skill context, generates code from the scenario prompt, checks must_contain and must_not_contain assertions, writes EVAL-<date>-<skill>.md reports.
tools: Read, Write, Bash(find *), Bash(grep *), Bash(ls *)
model: inherit
color: purple
---

# Eval Runner Agent

---

## Step 1 — Receive eval file list

Read each `.eval.yaml` file passed by `/eval`. Extract:
- `skill` — skill identifier
- `skill_files` — files to load as context
- `cases` — list of eval cases

---

## Step 2 — For each skill, run cases

### 2a — Load skill context

Read every file in `skill_files`. These are the **only rules** for code generation.
Do not apply any other knowledge — only what these files say.

### 2b — Generate and assert

For each case:

**Generate:** Produce the code described by `scenario`, following only the loaded skill files. Code only — no explanation.

**Assert must_contain:** Check each pattern appears verbatim in generated code.
- Found → PASS
- Not found → FAIL, record "not found"

**Assert must_not_contain:** Check each pattern does NOT appear.
- Not found → PASS
- Found → FAIL, record "found"

**Case result:** PASS only if every assertion passes.

For each failing assertion, record:
- Assertion type (must_contain / must_not_contain)
- The pattern
- A snippet of the generated code showing the relevant area

---

## Step 3 — Write EVAL report

Write to `docs/evals/EVAL-<date>-<skill-name>.md`:

```markdown
# Eval Report — <skill-name>
_Date: <today>_  _Version: <version>_  _File: <eval file path>_

## Summary
Cases: <N> | Passed: <N> | Failed: <N> | Overall: ✅ PASS / ❌ FAIL

## Results
| Case | Name | Result | Failed assertions |
|---|---|---|---|
| zod-01 | API route validates req.body | ✅ PASS | — |
| zod-02 | Form handler uses .safeParse() | ❌ FAIL | must_contain: "result.error.flatten()" not found |

## Failing Case Details

### <case-id> — <name> ❌
**Scenario:** <scenario text>
**Generated code:**
```ts
<generated output>
```
**Failed assertions:**
- must_contain: `"<pattern>"` → not found
  _Rationale: <from eval file>_
  **Suggested fix:** <specific change to make in the skill file>
```

---

## Step 4 — Return summary to /eval

```
EVAL_SUMMARY:
skills_run: N  skills_passed: N  skills_failed: N
cases_run: N  cases_passed: N  cases_failed: N

RESULTS:
- zod-validation: 5/5 PASS  docs/evals/EVAL-<date>-zod-validation.md
- nodejs-standards: 3/5 FAIL  docs/evals/EVAL-<date>-nodejs-standards.md

FAILURES:
- nodejs-standards | node-02 | must_contain | asyncHandler( | not found
- nodejs-standards | node-04 | must_not_contain | console.log | found
```
