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
3. Run the project's type checker and linter (detected from `package.json` or `stack.json`)
4. Apply the full review checklist (type safety, error handling, security, API conventions, tests, code quality)
5. Save a formal `REVIEW-<branch>.md` document with BLOCKER / WARNING / SUGGESTION findings
6. Print the file path and verdict

After review completes, if blockers are found: "Run `/fix all` to fix mechanical issues, then address manual blockers before opening a PR."

---

## `/review fix`

Apply only mechanical, safe, automated fixes. Does NOT delegate to the reviewer agent.

Run these in order:

Detect the project's linter and formatter from `package.json` or `stack.json`, then run:

```bash
# 1. Auto-fix linter violations (ESLint, Ruff, etc.)
# e.g. npx eslint . --fix  |  ruff check --fix .

# 2. Format all source files (Prettier, Black, etc.)
# e.g. npx prettier --write "src/**/*"  |  black src/

# 3. Run type checker — surface errors but do NOT auto-fix
# e.g. npx tsc --noEmit  |  mypy src/  |  pyright
```

After running, summarize:
```
Auto-fix Results
================
Linter --fix:   N rules auto-fixed
Formatter:      N files reformatted
Type checker:   N errors remain (must fix manually)

Files changed:
  <list of modified files>

Next: commit the formatting changes, then fix any remaining type errors manually.
```

Do NOT attempt to fix type errors automatically — surface them so the developer can address them.
