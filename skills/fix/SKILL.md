---
name: fix
description: Apply mechanical auto-fixes to the codebase — lint errors, formatting, or run all fixers. Never touches business logic. Usage — /my-dev-standards:fix <lint|format|types|all>
argument-hint: "<lint|format|types|all>"
arguments:
  - name: subcommand
    description: "lint — ESLint auto-fix. format — Prettier. types — show TS errors (can't auto-fix). all — lint + format then show types."
user-invocable: true
effort: low
allowed-tools:
  - Bash(npx eslint *)
  - Bash(npx prettier *)
  - Bash(npx tsc *)
  - Bash(git *)
---

# Auto-Fix

Apply safe, mechanical automated fixes. Never modifies business logic or tests.

Sub-command is `$ARGUMENTS[0]`. Defaults to `all` if omitted.

---

## `/fix lint`

Auto-fix ESLint violations that have fixers.

```bash
npx eslint . --fix --format compact 2>&1
```

After running, show:
- How many rules were auto-fixed
- Any remaining errors that need manual attention (print file:line:message)

---

## `/fix format`

Reformat all TypeScript/TSX/JSON/CSS files with Prettier.

```bash
npx prettier --write "src/**/*.{ts,tsx,json,css}" 2>&1
```

Show list of reformatted files. If no files changed, confirm "Already formatted correctly."

---

## `/fix types`

Show TypeScript errors. TypeScript errors cannot be auto-fixed — they are listed here for the developer to fix manually.

```bash
npx tsc --noEmit 2>&1
```

Format the output as a clear list:
```
TypeScript Errors (N)
=====================
src/path/file.ts:42 — TS2345: Argument of type 'string' is not assignable to...
src/path/other.ts:17 — TS2551: Property 'foo' does not exist on type 'Bar'
```

If 0 errors: "No TypeScript errors."

---

## `/fix all`

Run all fixers in sequence.

```bash
# 1. ESLint auto-fix
echo "=== ESLint --fix ==="
npx eslint . --fix --format compact 2>&1

# 2. Prettier
echo ""
echo "=== Prettier ==="
npx prettier --write "src/**/*.{ts,tsx,json,css}" 2>&1

# 3. TypeScript (report only)
echo ""
echo "=== TypeScript ==="
npx tsc --noEmit 2>&1
```

Final summary:
```
Fix Results
===========
ESLint:     N violations fixed, N remaining (manual)
Prettier:   N files reformatted
TypeScript: N errors (need manual fix)

Changed files:
  <git status --short output>

If TypeScript errors remain, fix them manually then run: /fix types
```

Suggest: "Commit the formatting fixes separately from logic changes for cleaner history."
