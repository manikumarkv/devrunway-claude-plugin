---
name: branch
description: Manage git branches and scaffold new feature boilerplate. Usage — /my-dev-standards:branch <sub-command> [args]
argument-hint: <create|switch|list|delete|status> [args]
arguments:
  - name: subcommand
    description: "Sub-command: create, switch, list, delete, status"
  - name: args
    description: "For create: <ticket-number> <short-name> [frontend|backend|fullstack]. For switch/delete: <branch-name>"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(git *)
  - Bash(gh *)
  - Bash(ls *)
  - Bash(find *)
  - Bash(mkdir *)
---

# Branch Manager

Create branches following the team convention and optionally scaffold feature boilerplate.

Branch naming convention: `feature/<ticket>-<short-name>` for features, `fix/<ticket>-<short-name>` for bugs, `chore/<short-name>` for maintenance.

Sub-command is `$ARGUMENTS[0]`.

---

## `/branch create <ticket> <short-name> [type]`

Create a feature branch and optionally scaffold boilerplate.

**Arguments:**
- `ticket` — GitHub issue number (e.g. `42`)
- `short-name` — kebab-case slug (e.g. `user-profile`)
- `type` — `frontend`, `backend`, or `fullstack` (default: ask user or infer from tech design)

```bash
# Ensure on develop and up to date
git checkout develop && git pull origin develop

# Create branch
git checkout -b feature/$TICKET-$NAME
```

After creating the branch, ask: "Scaffold boilerplate? (frontend / backend / fullstack / skip)"

### Frontend scaffold

Read `skills/branch/scaffold-templates.md` for the full templates. Replace `$NAME` with PascalCase name, `$name` with camelCase.

Create these files under `src/features/<name>/`:
```
types.ts
api/<name>.api.ts
hooks/use<Name>.ts
components/<Name>/<Name>.tsx
components/<Name>/<Name>.test.tsx
components/<Name>/index.ts
index.ts
```

### Backend scaffold

Create these files:
```
src/types/<name>.types.ts
src/repositories/<name>.repository.ts
src/services/<name>.service.ts
src/controllers/<name>.controller.ts
```

Register the router in `src/app.ts` or `src/routes/index.ts` if it exists:
```typescript
import { <name>Router } from './controllers/<name>.controller';
app.use('/api/v1/<name>', <name>Router);
```

### Fullstack

Do both frontend and backend scaffolds.

After scaffolding, print:
```
✅ Branch: feature/<ticket>-<name>
✅ Scaffolded: <files created>

Next steps:
  1. Fill in types in src/features/<name>/types.ts
  2. Add Zod schema in src/types/<name>.types.ts
  3. Run: /task start <ticket>
```

---

## `/branch switch <branch-name-or-number>`

Switch to a branch. If argument looks like an issue number (digits only), find the branch for that issue:

```bash
# By issue number — find matching branch
git branch -a | grep "feature/$ARG" | head -1

# By branch name
git checkout $BRANCH_NAME
```

---

## `/branch list [filter]`

List branches. Optional filter: `feature`, `fix`, `mine`.

```bash
# All local branches sorted by recency
git branch --sort=-committerdate

# Remote branches
git branch -r --sort=-committerdate | head -20
```

Show current branch with `*` marker. Include last commit message and date.

---

## `/branch delete <branch-name>`

Delete a local branch (and optionally the remote).

```bash
# Safety check: not on the branch being deleted
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "$BRANCH" ]; then
  echo "Cannot delete current branch. Switch first."
  exit 1
fi

# Check if merged
git branch --merged develop | grep "$BRANCH"

git branch -d $BRANCH          # safe delete (merged only)
# git branch -D $BRANCH        # force (only if user confirms unmerged)
```

Ask before force-deleting an unmerged branch.

Optionally delete remote:
```bash
git push origin --delete $BRANCH
```

---

## `/branch status`

Show current branch status: uncommitted changes, commits ahead/behind develop, linked issue.

```bash
BRANCH=$(git branch --show-current)
AHEAD=$(git rev-list develop..HEAD --count)
BEHIND=$(git rev-list HEAD..develop --count)
UNCOMMITTED=$(git status --short | wc -l | tr -d ' ')

echo "Branch:       $BRANCH"
echo "Ahead:        $AHEAD commit(s)"
echo "Behind:       $BEHIND commit(s)"
echo "Uncommitted:  $UNCOMMITTED file(s)"

# Extract issue number from branch name and show issue title
TICKET=$(echo $BRANCH | grep -oE '[0-9]+' | head -1)
if [ -n "$TICKET" ]; then
  gh issue view $TICKET --json title,state -q '"#\(.number) \(.state): \(.title)"' 2>/dev/null
fi
```
