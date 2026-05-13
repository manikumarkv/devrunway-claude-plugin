---
name: conventional-commit
description: Conventional commit message standards — type/scope/description format, breaking changes, when to use each type. Load when writing commit messages or reviewing git history.
user-invocable: false
---

Full standards in [conventional-commit.md](conventional-commit.md). Always-on summary:

**Format:** `<type>(<scope>): <description>`

**Types:**
- `feat` — new feature (triggers minor version bump)
- `fix` — bug fix (triggers patch version bump)
- `chore` — maintenance, deps, config (no version bump)
- `refactor` — code change that neither fixes a bug nor adds a feature
- `test` — adding or updating tests
- `docs` — documentation only
- `perf` — performance improvement
- `ci` — CI/CD pipeline changes
- `build` — build system or dependency changes

**Rules:**
- Description is lowercase, imperative mood: "add order form" not "added" or "adds"
- Scope is the feature or layer: `feat(orders):`, `fix(auth):`, `chore(deps):`
- Breaking change: add `!` after type or `BREAKING CHANGE:` footer
- Body explains *why*, not *what* — the diff already shows what changed
- 72-char limit on subject line

**Never:**
- Vague messages: "fix", "WIP", "stuff", "updates"
- Past tense: "fixed the login bug"
- Mixing unrelated changes in one commit

**Related skills — apply together:**
- `pipeline` — CI checks commit message format on every PR
- `security` — never commit secrets even in a "chore" commit
