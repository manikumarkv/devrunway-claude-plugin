# react-i18next Internationalisation Standards

## Setup

```ts
// src/i18n/index.ts — import BEFORE rendering <App />
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import Backend from 'i18next-http-backend'
import LanguageDetector from 'i18next-browser-languagedetector'

i18n
  .use(Backend)
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    fallbackLng: 'en',
    supportedLngs: ['en', 'fr', 'de', 'ar'],
    ns: ['common', 'auth', 'dashboard', 'errors'],
    defaultNS: 'common',
    backend: {
      loadPath: '/locales/{{lng}}/{{ns}}.json',
    },
    detection: {
      order: ['querystring', 'cookie', 'localStorage', 'navigator'],
      caches: ['localStorage', 'cookie'],
    },
    interpolation: { escapeValue: false },  // React escapes by default
    saveMissing: import.meta.env.DEV,       // log missing keys in development
    debug: import.meta.env.DEV,
  })

export default i18n
```

```tsx
// src/main.tsx
import './i18n/index'  // must be before React renders
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(<App />)
```

## Namespace Conventions

One namespace per feature domain — never one mega `translation.json`:

```
public/locales/
  en/
    common.json        ← buttons, labels, shared UI
    auth.json          ← login, signup, password reset
    dashboard.json     ← dashboard-specific copy
    errors.json        ← error messages, validation text
  fr/
    common.json
    auth.json
    ...
```

## Key Naming

Format: `<component>.<element>` or `<section>.<element>`:

```json
// auth.json
{
  "loginButton": "Sign in",
  "loginTitle": "Welcome back",
  "emailLabel": "Email address",
  "passwordLabel": "Password",
  "forgotPassword": "Forgot your password?",
  "noAccount": "Don't have an account?",
  "signupLink": "Sign up"
}

// errors.json
{
  "networkError": "Unable to connect. Please check your internet connection.",
  "unauthorised": "You don't have permission to view this page.",
  "notFound": "This page doesn't exist.",
  "validation": {
    "required": "This field is required",
    "email": "Please enter a valid email address",
    "minLength": "Must be at least {{count}} characters"
  }
}
```

## Hook Usage

```tsx
import { useTranslation } from 'react-i18next'

// Always specify namespace — never rely on defaultNS for feature copy
function LoginForm() {
  const { t } = useTranslation('auth')
  const { t: tErrors } = useTranslation('errors')

  return (
    <form>
      <h1>{t('loginTitle')}</h1>
      <label>{t('emailLabel')}</label>
      {hasError && <p>{tErrors('validation.required')}</p>}
      <button type="submit">{t('loginButton')}</button>
    </form>
  )
}
```

## Interpolation

Never concatenate translated strings — always use i18next interpolation:

```json
// common.json
{
  "greeting": "Hello, {{name}}!",
  "pagination": "Showing {{from}}–{{to}} of {{total}} results"
}
```

```tsx
// ✅ Correct
t('greeting', { name: user.firstName })
t('pagination', { from: 1, to: 10, total: 100 })

// ❌ Wrong — breaks when word order differs in other languages
t('hello') + ', ' + user.firstName + '!'
```

## Pluralisation

Use i18next's built-in plural rules:

```json
// common.json
{
  "itemCount_one": "{{count}} item",
  "itemCount_other": "{{count}} items",
  "commentCount_zero": "No comments",
  "commentCount_one": "{{count}} comment",
  "commentCount_other": "{{count}} comments"
}
```

```tsx
// i18next automatically picks _one or _other based on count
t('itemCount', { count: items.length })
t('commentCount', { count: post.comments.length })
```

## RTL Support

```tsx
// src/i18n/rtl.ts
const RTL_LANGUAGES = ['ar', 'he', 'fa', 'ur']

export function applyDirection(lng: string) {
  const dir = RTL_LANGUAGES.includes(lng) ? 'rtl' : 'ltr'
  document.documentElement.setAttribute('dir', dir)
  document.documentElement.setAttribute('lang', lng)
}

// src/App.tsx
import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { applyDirection } from './i18n/rtl'

function App() {
  const { i18n } = useTranslation()

  useEffect(() => {
    applyDirection(i18n.language)
    i18n.on('languageChanged', applyDirection)
    return () => i18n.off('languageChanged', applyDirection)
  }, [i18n])

  return <Router />
}
```

## TypeScript Type Safety

Generate types from your locale JSON so `t()` is fully typed:

```ts
// src/i18n/types.ts (generated — use i18next-resources-to-backend or codegen)
import type enCommon from '../../public/locales/en/common.json'
import type enAuth from '../../public/locales/en/auth.json'
import type enErrors from '../../public/locales/en/errors.json'

declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: 'common'
    resources: {
      common: typeof enCommon
      auth: typeof enAuth
      errors: typeof enErrors
    }
  }
}
```

With this in place, `t('nonExistent')` is a TypeScript error.

## Language Switcher

```tsx
function LanguageSwitcher() {
  const { i18n } = useTranslation()

  const languages = [
    { code: 'en', label: 'English' },
    { code: 'fr', label: 'Français' },
    { code: 'ar', label: 'العربية' },
  ]

  return (
    <select
      value={i18n.language}
      onChange={(e) => i18n.changeLanguage(e.target.value)}
      aria-label="Select language"
    >
      {languages.map(({ code, label }) => (
        <option key={code} value={code}>{label}</option>
      ))}
    </select>
  )
}
```

## Anti-Patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| One `translation.json` for everything | Loads entire copy on init | Split by namespace |
| String concatenation | Breaks in other languages | Use `{{interpolation}}` |
| Hardcoded English in JSX | Untranslated strings | All user-visible text goes through `t()` |
| Missing `count` in plurals | Wrong plural form | Always pass `{ count }` for plural keys |
| No `fallbackLng` | Blank UI if language missing | Always set `fallbackLng: 'en'` |
| `t('key' as string)` | Loses type safety | Use generated types |
