---
name: release
description: Create a semantic version release — reads conventional commits since last tag, determines semver bump, updates package.json, writes CHANGELOG.md, tags, and publishes a GitHub Release. Usage — /release [patch|minor|major|auto]
argument-hint: "[patch|minor|major|auto]"
arguments:
  - name: bump
    description: "Force a specific bump type, or 'auto' to derive from commits (default: auto)"
user-invocable: true
allowed-tools:
  - Read
  - Edit
  - Bash(git *)
  - Bash(gh *)
  - Bash(npm *)
  - Bash(node *)
  - Bash(cat *)
  - Bash(grep *)
---

# Release

Parse `$ARGUMENTS[0]` as the bump type (`patch` | `minor` | `major` | `auto`, default `auto`).

---

## Step 1 — Confirm branch and state

```bash
git branch --show-current
git status --short
git log -1 --format="%H %s"
```

- Must be on `main` (or `master`). If not: abort and tell the user.
- Must have no uncommitted changes. If dirty: abort.

---

## Step 2 — Find last release and commits since then

```bash
# Last version tag
LAST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "Last release: ${LAST_TAG:-none}"

# All commits since last tag (or all commits if no tag)
if [ -n "$LAST_TAG" ]; then
  git log "${LAST_TAG}..HEAD" --pretty=format:"%H %s" --no-merges
else
  git log --pretty=format:"%H %s" --no-merges | tail -50
fi
```

Group commits by type:
- `feat:` or `feat(…):` commits
- `fix:` or `fix(…):` commits
- `perf:`, `refactor:`, `docs:`, `chore:` commits
- Any commit with `!` suffix or `BREAKING CHANGE:` footer

---

## Step 3 — Determine semver bump

If `$ARGUMENTS[0]` is `patch`, `minor`, or `major` — use that directly.

If `auto`:
| Commit types found | Bump |
|---|---|
| Any `BREAKING CHANGE` or `feat!` or `fix!` | `major` |
| Any `feat:` (no breaking) | `minor` |
| Only `fix:`, `perf:`, `docs:`, `chore:` | `patch` |
| No conventional commits at all | Ask the user which bump type to use |

Read current version from `package.json`:
```bash
node -p "require('./package.json').version"
```

Calculate new version:
- `1.2.3` + `patch` → `1.2.4`
- `1.2.3` + `minor` → `1.3.0`
- `1.2.3` + `major` → `2.0.0`
- If no existing version, start at `0.1.0` for minor, `0.0.1` for patch.

Show the user:
> Current version: `1.2.3`
> Bump type: `minor` (because 3 `feat:` commits found)
> New version: `1.3.0`
>
> Commits to include:
> - feat(orders): add cursor pagination
> - feat(auth): add requireGroup middleware
> - fix(deploy): handle missing DIST_ID gracefully
>
> Proceed? (yes / change bump type / cancel)

Wait for confirmation.

---

## Step 4 — Update `package.json`

```bash
npm version <new-version> --no-git-tag-version
```

This updates `package.json` and `package-lock.json` without creating a git tag yet.

---

## Step 5 — Update `CHANGELOG.md`

Prepend a new section to `CHANGELOG.md` (create the file if it doesn't exist):

```markdown
## [<new-version>] — <YYYY-MM-DD>

### Breaking Changes
- <commit subject> (<short-sha>)

### Features
- <commit subject> (<short-sha>)

### Bug Fixes
- <commit subject> (<short-sha>)

### Other Changes
- <commit subject> (<short-sha>)
```

Rules:
- Only include sections that have entries (omit empty sections)
- Strip the `feat:` / `fix:` prefix from the subject line
- Include the 7-char short SHA in parentheses
- Link the SHA to the GitHub commit URL if the remote URL is known

---

## Step 6 — Commit, tag, and push

```bash
# Stage the version bump and changelog
git add package.json package-lock.json CHANGELOG.md

git commit -m "chore(release): v<new-version>"

# Create annotated tag
git tag -a "v<new-version>" -m "Release v<new-version>"

# Push commit and tag
git push origin main
git push origin "v<new-version>"
```

---

## Step 7 — Create GitHub Release

```bash
gh release create "v<new-version>" \
  --title "v<new-version>" \
  --notes "$(cat <<'EOF'
## What's changed

### Features
- <feat entries>

### Bug Fixes
- <fix entries>

### Breaking Changes
- <breaking entries if any>

**Full changelog:** <GITHUB_REPO_URL>/compare/<LAST_TAG>...v<NEW_VERSION>
EOF
)"
```

---

## Step 8 — Done

> ✅ Released `v<new-version>`
>
> - `package.json` updated
> - `CHANGELOG.md` updated
> - Git tag `v<new-version>` pushed
> - GitHub Release created: <release-url>
>
> Next: notify stakeholders / update release notes in your communication channel.
