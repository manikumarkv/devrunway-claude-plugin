# Linting & Formatting Standards (ESLint v9 + Prettier v3)

---

## Package installation

### Frontend (React + TypeScript + Tailwind)

```bash
npm install -D \
  eslint \
  @eslint/js \
  typescript-eslint \
  eslint-config-prettier \
  prettier \
  prettier-plugin-tailwindcss \
  eslint-plugin-react \
  eslint-plugin-react-hooks \
  eslint-plugin-jsx-a11y \
  eslint-plugin-react-refresh \
  eslint-plugin-tailwindcss \
  lint-staged \
  husky
```

### Backend (Node.js + TypeScript + Express)

```bash
npm install -D \
  eslint \
  @eslint/js \
  typescript-eslint \
  eslint-config-prettier \
  prettier \
  eslint-plugin-n \
  eslint-plugin-security \
  lint-staged \
  husky
```

---

## ESLint flat config — Frontend

```ts
// eslint.config.ts  (root of the project)
import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import reactPlugin from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import reactRefresh from 'eslint-plugin-react-refresh'
import tailwind from 'eslint-plugin-tailwindcss'
import prettier from 'eslint-config-prettier'

export default tseslint.config(
  // ── Global ignores ────────────────────────────────────────────────────────
  {
    ignores: [
      'dist/**',
      'build/**',
      'node_modules/**',
      'src/components/ui/**',   // shadcn/ui — never hand-edited
      '*.config.js',
      '*.config.ts',
      'vite.config.ts',
    ],
  },

  // ── Base JS rules ─────────────────────────────────────────────────────────
  js.configs.recommended,

  // ── TypeScript rules ──────────────────────────────────────────────────────
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },

  // ── React rules ───────────────────────────────────────────────────────────
  {
    plugins: {
      react: reactPlugin,
      'react-hooks': reactHooks,
      'jsx-a11y': jsxA11y,
      'react-refresh': reactRefresh,
    },
    settings: { react: { version: 'detect' } },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      ...reactPlugin.configs['jsx-runtime'].rules,  // React 17+ JSX transform
      ...reactHooks.configs.recommended.rules,
      ...jsxA11y.configs.recommended.rules,

      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      'react/prop-types': 'off',                    // TypeScript handles this
      'react/display-name': 'error',
      'react-hooks/exhaustive-deps': 'error',       // warn → error: missing deps cause bugs
    },
  },

  // ── Tailwind class ordering ────────────────────────────────────────────────
  ...tailwind.configs['flat/recommended'],

  // ── Project-wide custom rules ──────────────────────────────────────────────
  {
    rules: {
      // No any — ever
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',

      // Type-only imports
      '@typescript-eslint/consistent-type-imports': ['error', {
        prefer: 'type-imports',
        fixStyle: 'inline-type-imports',
      }],

      // Floating Promises — must await or void
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',

      // No unused vars — prefix with _ to mark intentional
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        caughtErrorsIgnorePattern: '^_',
      }],

      // No console — use structured logging
      'no-console': 'error',

      // Nullish coalescing over || for nullable values
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',

      // Exhaustive switch on unions
      '@typescript-eslint/switch-exhaustiveness-check': 'error',

      // Return type on exported functions
      '@typescript-eslint/explicit-module-boundary-types': 'off', // inferred is fine
    },
  },

  // ── Test file overrides ────────────────────────────────────────────────────
  {
    files: ['**/*.test.ts', '**/*.test.tsx', '**/*.spec.ts', '**/*.spec.tsx', 'e2e/**'],
    rules: {
      '@typescript-eslint/no-non-null-assertion': 'off',   // common in test assertions
      '@typescript-eslint/no-explicit-any': 'warn',        // mocks may need any
      'no-console': 'off',
    },
  },

  // ── Prettier last — disables all formatting rules ─────────────────────────
  prettier,
)
```

---

## ESLint flat config — Backend

```ts
// eslint.config.ts  (root of the project)
import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import nodePlugin from 'eslint-plugin-n'
import security from 'eslint-plugin-security'
import prettier from 'eslint-config-prettier'

export default tseslint.config(
  // ── Global ignores ────────────────────────────────────────────────────────
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'prisma/migrations/**',  // generated SQL — not linted
    ],
  },

  // ── Base ──────────────────────────────────────────────────────────────────
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },

  // ── Node.js rules ─────────────────────────────────────────────────────────
  {
    plugins: { n: nodePlugin },
    rules: {
      'n/no-process-exit': 'error',        // use graceful shutdown, not process.exit(1)
      'n/no-sync': 'warn',                 // prefer async fs operations
      'n/prefer-promises/fs': 'error',     // fs.promises over callback-style fs
      'n/no-deprecated-api': 'error',
    },
  },

  // ── Security rules ────────────────────────────────────────────────────────
  {
    plugins: { security },
    rules: {
      ...security.configs.recommended.rules,
      'security/detect-object-injection': 'warn',   // noisy but worth reviewing
      'security/detect-non-literal-regexp': 'warn',
      'security/detect-possible-timing-attacks': 'error',
    },
  },

  // ── Project-wide custom rules ─────────────────────────────────────────────
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',

      '@typescript-eslint/consistent-type-imports': ['error', {
        prefer: 'type-imports',
        fixStyle: 'inline-type-imports',
      }],

      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',

      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        caughtErrorsIgnorePattern: '^_',
      }],

      'no-console': 'error',   // use pino logger, never console.log

      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',
      '@typescript-eslint/switch-exhaustiveness-check': 'error',
    },
  },

  // ── Test file overrides ────────────────────────────────────────────────────
  {
    files: ['**/*.test.ts', '**/*.spec.ts', 'tests/**'],
    rules: {
      '@typescript-eslint/no-non-null-assertion': 'off',
      '@typescript-eslint/no-explicit-any': 'warn',
      'no-console': 'off',
      'security/detect-object-injection': 'off',
    },
  },

  // ── Prettier last ─────────────────────────────────────────────────────────
  prettier,
)
```

---

## Prettier config

One shared `.prettierrc` for both FE and BE:

```json
// .prettierrc
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false,
  "bracketSpacing": true,
  "arrowParens": "always",
  "endOfLine": "lf",
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

> Remove `prettier-plugin-tailwindcss` from the backend `.prettierrc` — it is frontend-only.

```json
// .prettierignore
dist/
build/
node_modules/
prisma/migrations/
*.min.js
public/
```

---

## package.json scripts

```json
{
  "scripts": {
    "lint":        "eslint .",
    "lint:fix":    "eslint . --fix",
    "format":      "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck":   "tsc --noEmit"
  }
}
```

Run all three as a pre-commit gate:

```bash
npm run typecheck && npm run lint && npm run format:check
```

---

## Pre-commit hook — lint-staged + husky

### Setup

```bash
npx husky init
```

```bash
# .husky/pre-commit
npx lint-staged
```

### lint-staged config

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{js,mjs,cjs}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml,css}": [
      "prettier --write"
    ]
  }
}
```

This only lints **staged files** — fast on large repos, never re-lints everything.

---

## CI lint step

```yaml
# .github/workflows/ci.yml
- name: Lint
  run: |
    npm run typecheck
    npm run lint
    npm run format:check
```

Fail fast: lint runs before tests. A lint failure saves test-runner minutes.

---

## tsconfig alignment

ESLint `strictTypeChecked` requires these `tsconfig.json` flags to be set:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

If the project uses `tsconfig.json` + `tsconfig.app.json` (Vite default), point ESLint's `projectService` at the one that includes `src/**`:

```ts
// eslint.config.ts
languageOptions: {
  parserOptions: {
    project: ['./tsconfig.app.json'],
    tsconfigRootDir: import.meta.dirname,
  },
},
```

---

## Common rule violations and fixes

### `no-floating-promises`

```ts
// ❌ — Promise not awaited; errors are silently swallowed
router.get('/', (req, res) => {
  fetchData().then(data => res.json(data))
})

// ✅ — wrap in asyncHandler which catches rejections
router.get('/', asyncHandler(async (req, res) => {
  const data = await fetchData()
  res.json(data)
}))
```

### `no-console`

```ts
// ❌
console.log('User created:', user.id)

// ✅ — structured log with pino
logger.info({ userId: user.id }, 'User created')
```

### `@typescript-eslint/no-explicit-any`

```ts
// ❌
function transform(data: any): any { ... }

// ✅
function transform(data: unknown): Record<string, string> { ... }
// or use generics
function transform<T>(data: T): T { ... }
```

### `consistent-type-imports`

```ts
// ❌ — mixes value and type imports
import { User, createUser } from './user.service'

// ✅ — explicit type-only import
import { type User, createUser } from './user.service'
// or separate lines
import type { User } from './user.service'
import { createUser } from './user.service'
```

### `switch-exhaustiveness-check`

```ts
type Status = 'PENDING' | 'CONFIRMED' | 'CANCELLED'

// ❌ — missing CANCELLED case; TypeScript won't catch this without ESLint rule
switch (status) {
  case 'PENDING':    return 'Waiting'
  case 'CONFIRMED':  return 'Confirmed'
}

// ✅ — exhaustive; adding a new union member causes a lint error
switch (status) {
  case 'PENDING':    return 'Waiting'
  case 'CONFIRMED':  return 'Confirmed'
  case 'CANCELLED':  return 'Cancelled'
}
```

---

## Inline disable — always explain why

```ts
// ❌ — disable without reason
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function legacyBridge(data: any) { ... }

// ✅ — reason is documented; reviewers know it is intentional
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- legacy SDK returns untyped payload; tracked in #1234
function legacyBridge(data: any) { ... }
```

---

## VS Code integration

```json
// .vscode/settings.json  (commit this to the repo)
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "eslint.useFlatConfig": true,
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}
```

```json
// .vscode/extensions.json
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "bradlc.vscode-tailwindcss"
  ]
}
```
