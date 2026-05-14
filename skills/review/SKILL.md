---
name: review
description: Code review the current branch or run mechanical auto-fixes. 'run' delegates to the reviewer agent for a thorough standards audit. 'fix' applies only automated corrections (eslint --fix, prettier). Usage — /devrunway:review [run|fix]
argument-hint: "[run|fix]"
arguments:
  - name: subcommand
    description: "run (default) — full code review via reviewer agent. fix — mechanical auto-fixes only."
user-invocable: true
allowed-tools:
  - Bash(npx eslint *)
  - Bash(npx prettier *)
  - Bash(npx tsc *)
  - Bash(git *)
context: fork
agent: code-reviewer
---

# Code Review

Sub-command is `$ARGUMENTS[0]`. Defaults to `run` if omitted.

---

## `/review run` (default)

Delegate to the **code-reviewer** agent for a full standards audit of the current branch.

The reviewer agent will:
1. Run `git diff develop...HEAD` to find all changed files
2. Read each changed file in full
3. Run `npx tsc --noEmit` and `npx eslint .`
4. Apply the full review checklist (TypeScript, React, Node.js, security, AWS, tests, code quality)
5. Save a formal `REVIEW-<branch>.md` document with BLOCKER / WARNING / SUGGESTION findings
6. Print the file path and verdict

After review completes, if blockers are found: "Run `/fix all` to fix mechanical issues, then address manual blockers before opening a PR."

---

## `/review fix`

Apply only mechanical, safe, automated fixes. Does NOT delegate to the reviewer agent.

Run these in order:

```bash
# 1. Auto-fix ESLint rule violations
npx eslint . --fix 2>&1

# 2. Format with Prettier
npx prettier --write "src/**/*.{ts,tsx}" 2>&1

# 3. Check TypeScript (cannot auto-fix, but show errors)
npx tsc --noEmit 2>&1
```

After running, summarize:
```
Auto-fix Results
================
ESLint --fix:   N rules auto-fixed
Prettier:       N files reformatted
TypeScript:     N errors remain (must fix manually)

Files changed:
  <list of modified files>

Next: commit the formatting changes, then fix any remaining TypeScript errors manually.
```

Do NOT attempt to fix TypeScript errors automatically — surface them so the developer can address them.
