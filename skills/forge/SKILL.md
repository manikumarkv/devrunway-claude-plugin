---
name: forge
description: Automated TDD loop for skill files. Fix a failing skill until its eval passes, or generate a verified new skill from scratch. Usage — /forge [skill-name | new <technology> | all]
argument-hint: "[skill-name | new <technology> | all]"
arguments:
  - name: target
    description: "Skill name to fix, 'new <technology>' to generate from scratch, or 'all' to fix every failing skill"
user-invocable: true
context: fork
effort: high
agent: skill-forge
allowed-tools:
  - Read
  - Write
  - Bash(find *)
  - Bash(ls *)
  - Bash(grep *)
---

# Forge

Automated TDD loop that writes and self-validates skill files. Plugin-author tool — not for end users.

Parse `$ARGUMENTS` as one of:
- `<skill-name>` — fix a specific skill's failing eval cases
- `new <technology>` — generate a brand new skill + eval from scratch
- `all` — fix every skill that has failing eval cases

---

## Mode A — Fix existing skill (`/forge <skill-name>`)

1. Find the skill's .eval.yaml file:
   `find . -name "*.eval.yaml" | xargs grep -l "^skill: $TARGET"`

2. Delegate to `skill-forge` agent in **FIX** mode, passing:
   - The .eval.yaml path
   - The SKILL.md path (first entry in skill_files)
   - Mode: fix

3. Present the result:

> **Forge complete — <skill-name>**
>
> Iterations: N | Final status: ✅ All passing / ⚠️ N cases still failing
>
> Changes made:
> - Added `asyncHandler(` code example to §Route handlers
> - Added ❌ Never block for `console.log` pattern
>
> Committed: `chore(forge): fix nodejs-standards — asyncHandler example missing`

If still failing after 3 iterations:
> ⚠️ Could not auto-fix these cases — human review needed:
> | Case | Assertion | Why it's hard to auto-fix |

---

## Mode B — Generate new skill (`/forge new <technology>`)

1. Validate that no skill already exists for this technology:
   `find layers/ -name "SKILL.md" | xargs grep -li "$TECHNOLOGY"`

2. If found:
   > A skill for "$TECHNOLOGY" already exists at `<path>`. Use `/forge <skill-name>` to fix it instead.

3. Delegate to `skill-forge` agent in **GENERATE** mode, passing:
   - Technology name
   - Mode: generate

4. Present the result:

> **Forge complete — <technology> (new)**
>
> Created:
> - `layers/<category>/<technology>/SKILL.md`
> - `layers/<category>/<technology>/<technology>.eval.yaml`
>
> Eval: N cases, all passing ✅
> Committed: `chore(forge): add <technology> skill with N verified eval cases`

---

## Mode C — Fix all failing (`/forge all`)

1. Run all evals to find failures:
   `find . -name "*.eval.yaml" | sort`

2. Delegate to `skill-forge` agent in **ALL** mode.

3. Present summary:

> **Forge all — complete**
>
> | Skill | Before | After | Iterations |
> |---|---|---|---|
> | nodejs-standards | 3/5 | 5/5 ✅ | 2 |
> | react-standards | 4/5 | 5/5 ✅ | 1 |
> | prisma | 2/4 | 2/4 ⚠️ | 3 |
>
> Auto-fixed: N skills | Still failing: N skills | Committed: N changes
