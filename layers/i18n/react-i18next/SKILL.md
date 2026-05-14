---
name: react-i18next
description: react-i18next internationalisation patterns — i18next setup, useTranslation hook, namespace conventions, plural rules, lazy loading, TypeScript types. Load when working with i18n.
user-invocable: false
stack: i18n/react-i18next
paths:
  - "src/i18n/**"
  - "public/locales/**"
  - "**/*.tsx"
  - "**/*.ts"
---

Full standards in [react-i18next.md](react-i18next.md). Always-on summary:

**Namespaces:** one per feature area (`common`, `auth`, `dashboard`, `errors`) — never one giant `translation.json`

**Key convention:** `<component>.<element>` — e.g. `auth.loginButton`, `errors.networkError`

**Hook usage:** `const { t } = useTranslation('namespace')` — always specify namespace

**Never concatenate strings:** use interpolation `t('greeting', { name })` — not `t('hello') + ' ' + name`

**Plurals:** `t('itemCount', { count })` with `_one` / `_other` key variants in JSON

**Lazy loading:** `i18next-http-backend` loads JSON from `public/locales/<lng>/<ns>.json`

**Missing keys:** `saveMissing: true` in dev to catch untranslated strings at runtime

**RTL:** `i18n.dir()` → set `dir` attribute on `<html>` element

**TypeScript:** generate types from JSON files — never `t('key' as string)`
