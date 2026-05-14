---
name: dev-review
description: Review code on the current branch against all standards. Generates a tracked REVIEW-<branch>.md with every finding. User picks which items to fix; each fix is applied and status updated. Usage — /dev-review [branch]
argument-hint: "[branch-name]"
arguments:
  - name: branch
    description: "Branch to review (default: current branch)"
user-invocable: true
context: fork
effort: medium
agent: code-reviewer
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(git *)
  - Bash(find *)
  - Bash(ls *)
  - Bash(grep *)
  - Bash(npm *)
  - Bash(npx *)
---

# Dev Review

Parse `$ARGUMENTS[0]` as the branch name, or use the current branch.

---

## Step 1 — Establish scope

```bash
BRANCH=${1:-$(git branch --show-current)}
echo "Reviewing branch: $BRANCH"

# Files changed vs develop (or main)
git diff develop...HEAD --name-only 2>/dev/null || git diff main...HEAD --name-only

# Quick sanity checks
npx tsc --noEmit 2>&1 | grep 'error TS' | head -20
npx eslint . --max-warnings 0 --format compact 2>&1 | head -30
```

Show the file list and any immediate type/lint errors before starting the full review.

---

## Step 2 — Full review

Read every changed file. Review against each standard below. Collect all findings before presenting them — do not interrupt the review to discuss individual items.

### Standards checklist

**Type safety** (type-safety skill)
- No use of catch-all types (`any`, untyped `object`) without a justification comment
- All exported function parameters and return types are explicit
- Type assertions used only with a guard check or justification comment above

**Error handling** (error-handling skill)
- All async operations have error handling — no unhandled rejections or swallowed exceptions
- Service layer throws typed, meaningful errors — not generic `Error("something went wrong")`
- Error handler / middleware is the single place that formats error responses

**API conventions** (api-conventions skill)
- All responses use the project's standard response envelope
- All input (body, path params, query params) is validated before use
- List endpoints use the project's standard pagination approach

**Security** (security-principles skill)
- Every authenticated endpoint enforces authentication
- Every mutating operation checks the caller owns/has access to the resource
- No secrets or credentials in source code
- User-supplied values are sanitised before use in queries or HTML rendering

**Testing** (see your testing layer skill)
- Every new function or behaviour has at least one test
- Tests mock at the system boundary (DB, HTTP, filesystem) — not internal implementation
- No skipped tests left in merged code

**Accessibility** (accessibility skill)
- All form inputs have an associated `<label>` or `aria-label`
- Interactive elements are keyboard reachable
- Error messages are linked to inputs via `aria-describedby`
- Images have meaningful `alt` text or `alt=""` if decorative

**Logging** (see your logging layer skill)
- Significant business events (create/update/delete) are logged
- No debug logging left in production code
- No PII (email, name, password, tokens) in log messages

**Conventional commits** (conventional-commit skill)
- Commit message follows `type(scope): description (#issue)`

**Stack-specific standards:** consult your installed layer skills for framework-specific items (e.g. React patterns, Express middleware, Prisma migration safety).

---

## Step 3 — Generate the review document

Write to `REVIEW-<branch>.md`:

```markdown
# Code Review — <branch>
_Date: <today>_
_Reviewer: Claude_

## Summary
- Files reviewed: <N>
- Issues found: <total> (<High: N> / <Medium: N> / <Low: N>)

## Review Items

| # | Issue | File | Line | Priority | Status | Reason |
|---|---|---|---|---|---|---|
| 1 | <description> | src/... | 42 | High | Open | |
| 2 | <description> | src/... | 17 | Medium | Open | |
| 3 | <description> | src/... | 88 | Low | Open | |

## Details

### Item 1 — <short title> · High
**File:** `src/...` line 42
**Standard violated:** error-handling — service throws `new Error()` instead of `NotFoundError`
**Current code:**
```ts
throw new Error('Not found')
```
**Expected:**
```ts
throw new NotFoundError('<Resource>', id)
```

### Item 2 — …
```

---

## Step 4 — Present and let the user choose

Show the summary table:

> **Review complete. Found <N> items:**
>
> | # | Issue | Priority | Status |
> |---|---|---|---|
> | 1 | … | High | Open |
> | 2 | … | Medium | Open |
> | 3 | … | Low | Open |
>
> Which items would you like to fix?
> - Type item numbers (e.g. `1 3 5`)
> - `all` — fix everything
> - `all high` — fix all High priority items
> - `skip <number> — <reason>` to mark an item as intentionally skipped

Wait for the user's response before touching any code.

---

## Step 5 — Fix selected items

For each selected item, in order:

1. Explain the fix in one sentence
2. Apply the fix (Edit or Write the file)
3. Run the relevant check:
   - TypeScript issue → `npx tsc --noEmit`
   - ESLint issue → `npx eslint <file> --max-warnings 0`
   - Test issue → `npx vitest run <test-file>`
4. Update the item's Status in `REVIEW-<branch>.md` to `Fixed`

For each skipped item:
- Record the skip reason in the Reason column
- Update Status to `Skipped`

Show progress after each fix:
```
✅ Item 1 fixed — NotFoundError now thrown correctly
⏭ Item 2 skipped — intentional use of console.error for CLI output
⏳ Item 3 — fixing…
```

---

## Step 6 — Final status

After all selected items are processed, update the REVIEW doc header:

```markdown
## Summary
- Files reviewed: <N>
- Issues found: <total>
- Fixed: <N> | Skipped: <N> | Open: <N>
- Status: ✅ Ready for PR / ⚠️ Items still open
```

Then:

> Review complete.
>
> Fixed: <N> · Skipped: <N> · Still open: <N>
>
> REVIEW-<branch>.md updated.
>
> Ready to create the PR?
> ```
> /pr create
> ```
