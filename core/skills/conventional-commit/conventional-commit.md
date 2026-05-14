# Conventional Commit Standards

---

## Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Subject line rules:**
- Lowercase, imperative mood ("add", "fix", "remove" — not "added", "fixes", "removed")
- No period at the end
- Max 72 characters
- Scope is optional but recommended — use the feature name or layer

---

## Types

| Type | When to use | Version bump |
|---|---|---|
| `feat` | New user-facing feature | Minor (`1.0.0` → `1.1.0`) |
| `fix` | Bug fix | Patch (`1.0.0` → `1.0.1`) |
| `chore` | Maintenance: deps, config, tooling | None |
| `refactor` | Code restructure — no behaviour change | None |
| `test` | Adding or updating tests | None |
| `docs` | Documentation only | None |
| `perf` | Performance improvement | Patch |
| `ci` | CI/CD workflow changes | None |
| `build` | Build system, bundler, package manager | None |
| `revert` | Reverts a previous commit | Depends |

---

## Scope

Scope is the area of the codebase affected. Use the feature name, layer, or package:

```
feat(orders): add cursor pagination to list endpoint
fix(auth): handle expired token refresh
chore(deps): bump data-fetching library to latest stable
refactor(repositories): extract shared pagination helper
test(orders): add missing error state test for OrderForm
ci(pipeline): add dependency audit step to CI workflow
```

Common scopes for your stack:

| Scope | When to use |
|---|---|
| `auth` | Authentication, tokens, login/logout flows |
| `orders`, `users`, `[feature]` | Feature-specific changes |
| `api` | API layer, routes, controllers |
| `db` | Schema changes, migrations, repositories |
| `infra` | Infrastructure as code, cloud resources |
| `ui` | Shared components, design system |
| `deps` | Dependency updates |
| `config` | Configuration files |

---

## Body

The body explains **why** the change was made, not what — the diff shows what.

```
feat(orders): add real-time status updates via WebSocket

Previously the order list required a manual refresh to show status
changes. Customers were missing delivery notifications because they
weren't refreshing the page.

WebSocket connection established on mount, closes on unmount.
Falls back to polling every 30s if WS unavailable.
```

Use the body when:
- The reason for the change isn't obvious from the description
- There are trade-offs or alternatives you considered
- The change has side effects worth noting

---

## Breaking changes

Add `!` after the type/scope, and add a `BREAKING CHANGE:` footer:

```
feat(api)!: change pagination from offset to cursor

BREAKING CHANGE: the `page` and `pageSize` query params are removed.
Use `cursor` and `limit` instead. Existing clients must update their
pagination logic before upgrading.
```

Or footer-only (no `!`):

```
refactor(auth): remove legacy token refresh endpoint

BREAKING CHANGE: /api/v1/auth/refresh-token removed.
Use Amplify SDK's automatic token refresh instead.
```

---

## Multi-line and footers

```
fix(orders): prevent double-submission on slow networks

The submit button was not disabled during the pending state, allowing
users to click multiple times and create duplicate orders.

Closes #142
Reviewed-by: Jane Smith
```

Common footers:
- `Closes #<issue>` — links and closes the GitHub issue
- `Fixes #<issue>` — same as Closes
- `Refs #<issue>` — references without closing
- `Co-authored-by: Name <email>`
- `BREAKING CHANGE: <description>`

---

## Examples by scenario

```bash
# New feature
feat(orders): add bulk order export as CSV

# Bug fix with issue reference
fix(auth): redirect to login on 401 response

Closes #89

# Dependency update
chore(deps): bump helmet from 7.1.0 to 8.0.0

# Schema migration
chore(db): add deletedAt column to orders table

# Refactor with explanation
refactor(services): extract email notification into dedicated service

The order service was handling notifications inline, making it hard to
test and reuse. NotificationService now owns all email dispatch logic.

# Test coverage
test(OrderForm): add server validation error mapping test

# CI change
ci(pipeline): add secret scanning step before build

# Breaking API change
feat(api)!: remove /api/v1/orders/search endpoint

BREAKING CHANGE: use GET /api/v1/orders?q= instead.
The dedicated search endpoint is removed in favour of the unified
list endpoint with query parameter filtering.
```

---

## Bad examples — never do this

```bash
# ❌ Vague
fix
WIP
updates
stuff
misc changes

# ❌ Past tense
fixed the login bug
added order form
removed deprecated endpoint

# ❌ Too broad — multiple unrelated changes
feat: add orders, fix auth, update deps, refactor services

# ❌ No type
order form validation

# ❌ Uppercase
Fix: Login Bug

# ❌ Ends with period
feat(auth): add token refresh.
```

---

## Enforcing with commitlint (optional)

Add to project to enforce the format in CI:

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional
```

```js
// commitlint.config.js
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'subject-case': [2, 'always', 'lower-case'],
    'body-max-line-length': [1, 'always', 100],
  },
}
```

```yaml
# .github/workflows/ci.yml — add this step
- name: Lint commit messages
  run: npx commitlint --from ${{ github.event.pull_request.base.sha }} --to ${{ github.event.pull_request.head.sha }}
```
