---
name: deps
description: Audit and update project dependencies. Check for outdated packages and security vulnerabilities, then update safely with tests after each batch. Usage — /deps check OR /deps update [patch|minor|major|all]
argument-hint: "check | update [patch|minor|major|all]"
arguments:
  - name: subcommand
    description: "'check' to audit only, 'update' to interactively update"
  - name: scope
    description: "For update: 'patch' (safe), 'minor' (breaking-free), 'major' (breaking), 'all' (everything)"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(npm *)
  - Bash(npx *)
  - Bash(git *)
  - Bash(grep *)
  - Bash(cat *)
---

# Deps

Parse `$ARGUMENTS[0]` as `check` or `update`. For `update`, parse `$ARGUMENTS[1]` as scope (`patch` | `minor` | `major` | `all`, default `patch`).

---

## `/deps check`

Run a full dependency health audit and report — no changes made.

### 1. Security vulnerabilities

```bash
npm audit --json 2>/dev/null | node -e "
const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
const vulns = d.vulnerabilities || {};
const counts = { critical: 0, high: 0, moderate: 0, low: 0 };
Object.values(vulns).forEach(v => counts[v.severity] = (counts[v.severity]||0)+1);
console.log(JSON.stringify(counts));
console.log('Affected packages:', Object.keys(vulns).join(', '));
"
```

### 2. Outdated packages

```bash
npm outdated --json 2>/dev/null | node -e "
const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8') || '{}');
Object.entries(d).forEach(([pkg, info]) => {
  const bumpType = info.current.split('.')[0] !== info.latest.split('.')[0] ? 'MAJOR'
    : info.current.split('.')[1] !== info.latest.split('.')[1] ? 'minor'
    : 'patch';
  console.log(bumpType.padEnd(7), pkg.padEnd(40), info.current, '->', info.latest);
});
" | sort
```

### 3. Licence audit

```bash
npx license-checker --summary --onlyAllow 'MIT;ISC;Apache-2.0;BSD-2-Clause;BSD-3-Clause;CC0-1.0;Unlicense;0BSD' 2>/dev/null \
  || echo "license-checker not installed — run: npm install -g license-checker"
```

### 4. Report

Present a summary table:

> **Dependency Health Report**
>
> 🔴 Security vulnerabilities: `N critical · N high · N moderate · N low`
> 📦 Outdated packages: `N patch · N minor · N MAJOR`
> ⚖️ License issues: `N (non-approved license)`
>
> | Package | Current | Latest | Bump | CVE |
> |---|---|---|---|---|
> | express | 4.18.0 | 4.21.0 | patch | — |
> | aws-sdk | 2.x | 3.x | MAJOR | — |
> | lodash | 4.17.15 | 4.17.21 | patch | CVE-2021-23337 |
>
> Run `/deps update patch` to apply safe patches, or `/deps update all` to review everything.

---

## `/deps update [scope]`

Interactive, test-gated update flow. Never updates everything blindly.

### 1. Build the update list

```bash
npm outdated --json 2>/dev/null
npm audit --json 2>/dev/null
```

Filter by scope:
- `patch` — only packages where only the patch segment changes (`1.2.3` → `1.2.4`)
- `minor` — patch + minor updates (`1.2.x` → `1.3.x`)
- `major` — all of the above + major version bumps
- `all` — everything including security-flagged packages regardless of version

### 2. Group into batches

Group updates into low-risk batches:
1. **Security patches** — packages with CVEs, patch-only updates
2. **Dev dependency patches** — test tools, linters, type packages  
3. **Runtime patches** — production dependency patch updates
4. **Minor updates** — if scope allows
5. **Major updates** — one at a time, each requires explicit confirmation

### 3. Process each batch

For each batch:

> **Batch N: <description>**
> Packages: `express@4.21.0`, `zod@3.23.0`, `vitest@2.1.0`
>
> Update these? (yes / skip / update one at a time)

If yes:
```bash
npm install <pkg1>@<version> <pkg2>@<version> ...

# Run full test suite after each batch
npm test -- --passWithNoTests
npx tsc --noEmit
```

If tests pass:
```bash
git add package.json package-lock.json
git commit -m "chore(deps): update <list> to latest patch"
```

If tests fail:
> ❌ Tests failed after updating `<pkg>`. Options:
> - `revert` — undo this batch (`git restore package.json package-lock.json && npm ci`)
> - `investigate` — show the test failure and let me try to fix it
> - `skip` — mark this package as needing manual attention

### 4. Major version updates — one at a time

For each major version bump:

> **Major update: `aws-cdk-lib` `2.x` → `3.x`**
>
> ⚠️ This is a breaking change. Before updating:
> 1. Check the migration guide: `https://github.com/aws/aws-cdk/releases`
> 2. This will likely require code changes after installation
>
> Proceed with this major update? (yes / skip / show changelog)

If yes:
```bash
npm install <pkg>@latest
npx tsc --noEmit   # show breaking type errors first
npm test
```

Show all TypeScript errors before attempting fixes. Ask: "Fix these errors automatically, or handle manually?"

### 5. Final summary

> **Dependency update complete**
>
> ✅ Updated: `express@4.21.0`, `zod@3.23.0` (5 packages)
> ⏭ Skipped: `aws-cdk-lib` (major — manual review needed)
> ❌ Failed: `vitest@2.x` (test failures — see above)
>
> Commits created: 2
> Remaining to action: 1 major, 1 failed

---

## Renovate config (add to repo root)

When setting up a new project, write `renovate.json` to automate future dependency PRs:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:base"],
  "schedule": ["every weekend"],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true,
      "automergeType": "pr"
    },
    {
      "matchUpdateTypes": ["minor"],
      "groupName": "minor dependencies",
      "schedule": ["on monday"]
    },
    {
      "matchUpdateTypes": ["major"],
      "dependencyDashboardApproval": true
    },
    {
      "matchDepTypes": ["devDependencies"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true
    }
  ],
  "vulnerabilityAlerts": {
    "enabled": true,
    "schedule": ["at any time"]
  },
  "prConcurrentLimit": 5
}
```

**Related skills — apply together:**
- `secret-scanning` — after any dependency update, re-run secret scan (new package may introduce dotenv quirks)
- `pipeline` — `npm audit --audit-level=high` should be a CI gate on every PR
- `packages` — approved package list is the baseline; updates to unapproved categories need justification
