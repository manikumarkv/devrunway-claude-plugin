---
name: eval
description: Run eval cases for one skill, a category, or all skills. Finds .eval.yaml files, delegates to eval-runner agent, presents pass/fail summary, and offers to iterate on failing skills. Usage — /eval [skill-name|category|all]
argument-hint: "[skill-name | category | all]"
arguments:
  - name: target
    description: "Skill name (e.g. zod-validation), category (e.g. validation), or 'all' (default)"
user-invocable: true
context: fork
effort: high
agent: eval-runner
allowed-tools:
  - Read
  - Write
  - Bash(find *)
  - Bash(ls *)
  - Bash(grep *)
---

# Eval

Run the plugin's eval harness. Developer tool for the plugin author — not for end users.

Parse `$ARGUMENTS[0]` as `target` (skill name | category | `all`, default `all`).

---

## Step 1 — Discover eval files

Find all `.eval.yaml` files matching the target:

- `all` → `find layers skills agents -name "*.eval.yaml" | sort`
- skill name → `find layers skills agents -name "*.eval.yaml" | xargs grep -l "^skill: $TARGET"`
- category → `find layers skills agents -path "*/$TARGET*/*.eval.yaml"`

**Search `layers skills agents`, never bare `find .`.** Those three directories hold
every eval file — 109, 3 and 2 respectively. A bare `find .` also descends into
`.claude/worktrees/`, where git worktrees keep a full copy of the tree for each
checked-out branch. That doubled discovery to 227 files and scored half the suite
against whatever branch a worktree happened to be parked on, silently reporting
results for guidance that is not on the current branch. `.claude/` is gitignored,
but `find` does not read `.gitignore`.

Verify the count before a full run — `all` should discover **114** files today. A
number near 227 means the worktree copies are being scored again.

If a discovered path contains `/.claude/`, stop and report it rather than scoring
it. A stale worktree is not a second opinion; it is an old branch wearing the same
filenames.

If none found:
> No eval files found for "$TARGET". Check that the skill name matches the `skill:` field in an .eval.yaml file, or that the category path exists.

---

## Step 2 — Delegate to eval-runner

Pass the list of discovered eval files to the `eval-runner` agent. The agent will:
1. Read each skill's files to load context
2. Generate code for each scenario prompt
3. Check all must_contain and must_not_contain assertions
4. Write `docs/evals/EVAL-<date>-<skill>.md` reports
5. Return a structured summary

---

## Step 3 — Present summary

> **Eval complete — <N> skills, <P> passed, <F> failed**
>
> | Skill | Cases | Passed | Failed | Report |
> |---|---|---|---|---|
> | zod-validation | 5 | 5 | 0 | docs/evals/EVAL-<date>-zod-validation.md |
> | nodejs-standards | 5 | 3 | 2 | docs/evals/EVAL-<date>-nodejs-standards.md |
>
> **Failing assertions:**
> | Skill | Case | Type | Pattern | Result |
> |---|---|---|---|---|
> | nodejs-standards | node-02 | must_contain | asyncHandler( | not found |
> | nodejs-standards | node-04 | must_not_contain | console.log | found |

---

## Step 4 — Offer to iterate

If any failures:

> Found <F> failing cases. Options:
> - `fix <skill-name>` — update that skill to make its failing cases pass
> - `fix all` — update all failing skills
> - `show <case-id>` — show the full generated code for a case
> - `skip` — exit without fixing

For each skill being fixed:
1. Read the failing case + failed assertions from the EVAL report
2. Identify the specific missing or ambiguous rule in SKILL.md or .md file
3. Propose the edit (new example, stronger prohibition, clearer rule)
4. Apply it with Edit
5. Re-run those specific cases to confirm they now pass
6. Commit: `chore(eval): fix <skill-name> — <what was missing>`
