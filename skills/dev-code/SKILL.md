---
name: dev-code
description: Execute a dev-design plan step by step with user confirmation between each step. Creates branch, updates ticket, implements DB/backend/tests/frontend/E2E/logging sequentially. Offers to trigger /dev-review on completion. Usage — /dev-code <issue-number> [or design doc path]
argument-hint: "<issue-number> [or docs/dev-tech-designs/<ticket>-design.md]"
arguments:
  - name: input
    description: "GitHub issue number, or path to the design doc"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(git *)
  - Bash(gh *)
  - Bash(npm *)
  - Bash(npx *)
  - Bash(ls *)
  - Bash(find *)
  - Bash(grep *)
---

# Dev Code

Parse `$ARGUMENTS[0]` as either a GitHub issue number or a design doc path.

---

## Step 0 — Load the design plan

```bash
# Find the design doc
find docs/dev-tech-designs/ -name "<number>-design.md" | head -1
```

Read the full design doc. Extract:
1. All phases and their steps (in order)
2. The issue number and title
3. The branch naming convention (from conventional-commit skill: `feat/<number>-<slug>`)

Show the full plan to the user before doing anything:

> **Executing plan for #<number>: <title>**
>
> I'll work through these phases one step at a time. You'll confirm before each step runs.
>
> **Phases:**
> - Phase 1: Database (2 steps)
> - Phase 2: Backend types (1 step)
> - Phase 3: Repository (1 step)
> - Phase 4: Service (1 step)
> - Phase 5: Controller & routes (2 steps)
> - Phase 6: Unit tests (3 steps)
> - Phase 7: Frontend types & API hooks (2 steps)
> - Phase 8: Frontend components (3 steps)
> - Phase 9: Screen / page (1 step)
> - Phase 10: Playwright E2E (1 step)
> - Phase 11: Logging (1 step)
>
> **Before I start:** I'll create the branch and update the ticket status.
>
> Ready? (yes / update the plan first)

If the user says "update the plan first" — stop and let them edit the design doc. They resume by running `/dev-code <number>` again.

---

## Execution rules (apply to every step)

1. **Announce before acting:** Before each step, say: `▶ Step <X.Y> — <description>`
2. **Execute the step** as described in the design doc
3. **Show what was produced:** list created/edited files, show key code snippets (not full files)
4. **Wait for confirmation:** after each step, print:
   ```
   ✅ Step <X.Y> complete.
   → Next: Step <X.Z> — <description>
   Continue? (yes / skip / review plan / stop)
   ```
5. **Handle responses:**
   - `yes` — proceed to next step
   - `skip` — skip this step, record it was skipped, move to next
   - `review plan` — stop and tell user to edit `docs/dev-tech-designs/<number>-design.md`, then re-run `/dev-code <number>`
   - `stop` — stop here, summarise what was done, what remains

Never run the next step without explicit confirmation.

---

## Pre-execution: Branch & ticket

Before Phase 1, always run these two setup steps:

### Setup Step A — Create branch

```bash
# Derive slug from issue title
gh issue view <number> --json title --jq '.title' \
  | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | cut -c1-40

git checkout develop 2>/dev/null || git checkout main
git pull
git checkout -b feat/<number>-<slug>
```

Show the branch name. Wait for confirmation.

### Setup Step B — Update ticket status

```bash
gh issue edit <number> --add-label "in-progress"
gh issue comment <number> --body "🚀 Development started on branch \`feat/<number>-<slug>\`"
```

Wait for confirmation before Phase 1.

---

## Phase execution

Execute each phase and its steps exactly as written in the design doc.

### Key rules per phase type:

**Database steps:**
- Append the Prisma model to `prisma/schema.prisma` — never overwrite the whole file
- Run `npx prisma migrate dev --name <descriptive-name>` and show output
- Run `npx prisma generate`
- If migration needs an env var (DATABASE_URL), pause and ask the user to confirm it is set

**Backend steps:**
- Follow error-handling skill: asyncHandler, AppError hierarchy, Zod `.parse()` on all inputs
- Follow api-conventions skill: ok(), created(), paginated() helpers
- Follow security skill: requireAuth on every route, ownership check in service layer

**Test steps:**
- Create test files alongside source files
- Follow testing-standards skill: one describe per function, mock at the boundary
- Run tests after creating them: `npx vitest run <test-file>` — show pass/fail

**Frontend steps:**
- Follow react-standards and composition-patterns skills
- 4-state lists: loading skeleton, empty state, error state, data
- Forms: react-hook-form + zodResolver, server errors via setError
- Run `npx tsc --noEmit` after each FE file to catch type errors immediately

**Playwright steps:**
- Follow playwright skill: page objects, role-based selectors
- Run `npx playwright test <spec>` — show results

**Logging steps:**
- Use the Pino logger already wired in the project
- Log at service layer: `logger.info({ userId, resourceId, action }, 'description')`
- Never log passwords, tokens, or full request bodies

---

## Post-execution — Commit

After all steps (or when the user says done):

```bash
git add -p   # show what's staged
git status
```

> Here's what I built:
> - <list of created/modified files>
>
> Commit message I'll use:
> `feat(<scope>): <description> (#<number>)`
>
> Commit and push? (yes / edit message / no)

If yes:
```bash
git add <specific files only — no -A>
git commit -m "feat(<scope>): <description> (#<number>)"
git push -u origin feat/<number>-<slug>
```

---

## Completion — offer dev-review

> All steps complete for #<number>.
>
> **Built:**
> - Phase 1–11 executed (or list which were skipped)
> - Branch: `feat/<number>-<slug>`
> - Commit pushed
>
> Run code review now?
> ```
> /dev-review
> ```
> (yes / no)

If yes, trigger `/dev-review`. If no, remind them to run it before creating the PR.
