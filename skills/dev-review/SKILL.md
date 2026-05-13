---
name: dev-review
description: Review code on the current branch against all standards. Generates a tracked REVIEW-<branch>.md with every finding. User picks which items to fix; each fix is applied and status updated. Usage — /dev-review [branch]
argument-hint: "[branch-name]"
arguments:
  - name: branch
    description: "Branch to review (default: current branch)"
user-invocable: true
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

**TypeScript**
- No `any` unless explicitly justified with a comment
- All function parameters and return types are explicit
- No non-null assertions (`!`) without a guard check above

**Error handling** (error-handling skill)
- All async controller handlers wrapped in `asyncHandler`
- Service methods throw typed `AppError` subclasses (NotFoundError, ForbiddenError, etc.) — not `new Error()`
- `errorHandler` middleware is the only place that touches `res.status(5xx)`

**API conventions** (api-conventions skill)
- All success responses use `ok()`, `created()`, `paginated()` helpers
- All `req.body`, `req.params`, `req.query` validated with Zod `.parse()` — never accessed directly
- Cursor pagination used on list endpoints with `buildNextCursor`

**Security** (security skill)
- Every route has `requireAuth` middleware
- Every mutating service method has ownership check: `if (resource.userId !== user.sub) throw new ForbiddenError()`
- No secrets or credentials in source code
- S3 keys are UUIDs, never user-supplied filenames
- `sanitize-html` or `DOMPurify` on any rendered HTML

**React standards** (react-standards skill)
- No `useEffect` for data fetching — use React Query hooks
- Lists have all 4 states: loading skeleton, empty, error, data
- Forms use react-hook-form + zodResolver + `setError` for server errors
- No prop drilling beyond 2 levels — use context or co-location

**Testing** (testing-standards skill)
- Every new function has at least one test
- Tests mock at the boundary (DB, HTTP) — not deep implementation
- No `describe.skip` or `it.skip` left in merged code
- `expect.assertions(N)` in async tests

**Accessibility** (accessibility skill)
- All form inputs have associated `<label>`
- Interactive elements are keyboard reachable
- Error messages are linked to inputs via `aria-describedby`
- Images have meaningful `alt` text

**Logging** (monitoring skill)
- Service-layer create/update/delete actions have a `logger.info` call
- No `console.log` in production code
- No PII (email, name, password) in log messages

**Conventional commits** (conventional-commit skill)
- Commit message follows `type(scope): description (#issue)`

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
