---
name: linting
description: ESLint and Prettier configuration for React/TypeScript frontend and Node.js/TypeScript backend. Load when setting up a new project, adding lint rules, fixing lint errors, or reviewing lint config.
user-invocable: false
stack: frontend/react---

Full rules in [linting.md](linting.md). Always-on summary:

**Stack (locked — no alternatives):**
- ESLint v9 flat config (`eslint.config.ts`) — never `.eslintrc.*`
- Prettier v3 — formatting only; ESLint handles code quality
- `eslint-config-prettier` — disables all ESLint rules that conflict with Prettier
- `lint-staged` + `husky` — auto-lint on `git commit`

**Frontend additions on top of base:**
- `eslint-plugin-react`, `eslint-plugin-react-hooks`, `eslint-plugin-jsx-a11y`
- `eslint-plugin-react-refresh` for Vite HMR safety
- `eslint-plugin-tailwindcss` — class order enforcement

**Backend additions on top of base:**
- `eslint-plugin-node` (or `eslint-plugin-n`) — Node.js-specific rules
- `eslint-plugin-security` — catches common security anti-patterns

**Rules enforced everywhere:**
- `no-console` — error in production code (use pino logger)
- `no-unused-vars` — error; `_` prefix for intentionally unused
- `@typescript-eslint/no-explicit-any` — error; never use `any`
- `@typescript-eslint/consistent-type-imports` — `import type` for type-only imports
- `no-floating-promises` — all Promises must be awaited or explicitly handled

**Never:**
- `.eslintignore` — use `ignores` array in flat config instead
- Disable rules inline with `// eslint-disable` without a comment explaining why
- Mix Prettier formatting rules into ESLint config
- Per-file overrides to weaken rules — fix the code, not the config

**Related skills — apply together:**
- `typescript-patterns` — strict TS compiler flags align with ESLint strict rules
- `react-standards` — React-specific hooks rules enforced by react-hooks plugin
- `testing-standards` — separate ESLint config for test files (jest/vitest globals)
