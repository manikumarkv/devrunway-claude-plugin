# LinguiJS Standards

---

## Setup

```bash
npm install @lingui/react @lingui/core
npm install --save-dev @lingui/cli @lingui/vite-plugin @lingui/swc-plugin
# or for Babel:
npm install --save-dev babel-plugin-macros @lingui/macro
```

---

## lingui.config.ts

```typescript
// lingui.config.ts
import { defineConfig } from '@lingui/conf'

export default defineConfig({
  locales:         ['en', 'es', 'fr', 'de'],
  sourceLocale:    'en',
  catalogs: [{
    path:    '<rootDir>/src/locales/{locale}/messages',
    include: ['src/**'],
    exclude: ['src/**/*.test.*', 'src/**/*.spec.*'],
  }],
  format:          'po',       // PO files are translator-friendly
  orderBy:         'origin',   // keeps messages stable across extraction runs
})
```

---

## Vite / SWC plugin setup

```typescript
// vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'
import { lingui } from '@lingui/vite-plugin'

export default defineConfig({
  plugins: [
    react({ plugins: [['@lingui/swc-plugin', {}]] }),
    lingui(),
  ],
})
```

---

## I18nProvider setup

```tsx
// src/main.tsx
import { i18n } from '@lingui/core'
import { I18nProvider } from '@lingui/react'
import { en } from './locales/en/messages'

// Activate the default locale eagerly
i18n.load('en', en.messages)
i18n.activate('en')

export async function loadLocale(locale: string) {
  const { messages } = await import(`./locales/${locale}/messages`)
  i18n.load(locale, messages)
  i18n.activate(locale)
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <I18nProvider i18n={i18n}>
    <App />
  </I18nProvider>
)
```

---

## t macro — plain strings

```tsx
import { t } from '@lingui/macro'
import { useLingui } from '@lingui/react'

// In a component (macro replaces at build time with a call to i18n._)
export function Greeting({ name }: { name: string }) {
  const { i18n } = useLingui()

  // Simple string
  const title = t`Welcome to our store`

  // Interpolation — variable is extracted as a named placeholder
  const greeting = t`Hello, ${name}!`

  // With explicit i18n instance (required outside components)
  const label = t(i18n)`Submit order`

  return <h1>{greeting}</h1>
}
```

---

## Trans component — JSX with embedded elements

```tsx
import { Trans } from '@lingui/macro'

// Inline elements are preserved correctly
export function TermsNotice() {
  return (
    <p>
      <Trans>
        By continuing, you agree to our{' '}
        <a href="/terms">Terms of Service</a> and{' '}
        <a href="/privacy">Privacy Policy</a>.
      </Trans>
    </p>
  )
}

// Dynamic values in JSX
export function OrderSummary({ count, total }: { count: number; total: string }) {
  return (
    <p>
      <Trans>
        You have <strong>{count}</strong> items totalling <strong>{total}</strong>.
      </Trans>
    </p>
  )
}
```

---

## Pluralisation

```tsx
import { plural, select } from '@lingui/macro'

export function CartBadge({ count }: { count: number }) {
  const label = plural(count, {
    zero:  'No items',
    one:   '# item',
    other: '# items',
  })

  return <span aria-label={label}>{count}</span>
}

// select — for gendered or enum-based messages
export function StatusMessage({ role }: { role: 'admin' | 'user' | 'guest' }) {
  const message = select(role, {
    admin: 'You have full access',
    user:  'You have standard access',
    other: 'You have limited access',
  })

  return <p>{message}</p>
}
```

---

## msg macro — constants and non-component contexts

```tsx
import { msg } from '@lingui/macro'
import { i18n } from '@lingui/core'

// Mark for extraction without translating immediately
const STATUS_LABELS = {
  pending:   msg`Pending`,
  shipped:   msg`Shipped`,
  delivered: msg`Delivered`,
  cancelled: msg`Cancelled`,
} as const

// Translate at render time
export function OrderStatusBadge({ status }: { status: keyof typeof STATUS_LABELS }) {
  return <span>{i18n._(STATUS_LABELS[status])}</span>
}
```

---

## Locale extraction and compilation

```bash
# Extract all strings from source into .po files
npx lingui extract

# Compile .po to .js for runtime use
npx lingui compile

# Check for untranslated strings (exit 1 if any — good for CI)
npx lingui extract --locale es | grep -c 'untranslated'
```

```json
// package.json scripts
{
  "scripts": {
    "i18n:extract": "lingui extract",
    "i18n:compile": "lingui compile",
    "i18n:check": "lingui extract && git diff --exit-code src/locales"
  }
}
```

---

## Locale switching

```tsx
// src/components/LocaleSwitcher.tsx
import { loadLocale } from '@/main'

const LOCALES = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Español' },
  { code: 'fr', label: 'Français' },
]

export function LocaleSwitcher() {
  async function handleChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const locale = e.target.value
    await loadLocale(locale)
    localStorage.setItem('locale', locale)
  }

  return (
    <select defaultValue={localStorage.getItem('locale') ?? 'en'} onChange={handleChange}>
      {LOCALES.map(l => (
        <option key={l.code} value={l.code}>{l.label}</option>
      ))}
    </select>
  )
}
```

---

## CI check

```yaml
# .github/workflows/i18n.yml
- name: Check for missing translations
  run: |
    npm run i18n:extract
    # Fail if extraction produced uncommitted changes (new strings not in .po)
    git diff --exit-code src/locales
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Using template literals without `t` macro | `Hello ${name}` is not extracted — use `` t`Hello ${name}` `` |
| Calling `t` outside a component without an i18n instance | Pass the instance: `t(i18n)\`...\`` or use `msg` and translate later with `i18n._()` |
| Concatenating translated strings | `t\`Hello\` + name` breaks in RTL languages — use interpolation: `` t`Hello, ${name}` `` |
| Not running `lingui extract` before committing | New strings are invisible to translators until extracted to `.po` files |
| Bundling all locale catalogs eagerly | Dynamic `import()` per locale keeps the initial bundle small |
