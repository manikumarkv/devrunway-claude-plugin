# Vue I18n v9 Standards

---

## Setup

```bash
npm install vue-i18n@9
```

---

## Plugin setup

```typescript
// src/i18n/index.ts
import { createI18n } from 'vue-i18n'

// Eagerly load the default locale
import en from './locales/en.json'

export const i18n = createI18n({
  legacy:        false,        // use Composition API mode
  locale:        detectLocale(),
  fallbackLocale: 'en',
  messages: {
    en,
  },
  // Silence missing translation warnings in production
  missingWarn:   process.env.NODE_ENV !== 'production',
  fallbackWarn:  process.env.NODE_ENV !== 'production',
})

function detectLocale(): string {
  const stored = localStorage.getItem('locale')
  if (stored && SUPPORTED_LOCALES.includes(stored)) return stored

  const browser = navigator.language.split('-')[0]
  if (SUPPORTED_LOCALES.includes(browser)) return browser

  return 'en'
}

export const SUPPORTED_LOCALES = ['en', 'es', 'fr', 'de', 'ja']
```

```typescript
// src/main.ts
import { createApp } from 'vue'
import { i18n } from './i18n'
import App from './App.vue'

createApp(App)
  .use(i18n)
  .mount('#app')
```

---

## Locale files

```json
// src/i18n/locales/en.json
{
  "common": {
    "save":   "Save",
    "cancel": "Cancel",
    "loading": "Loading…",
    "error":  "Something went wrong"
  },
  "orders": {
    "title":   "Your Orders",
    "empty":   "You have no orders yet.",
    "status": {
      "pending":   "Pending",
      "shipped":   "Shipped",
      "delivered": "Delivered",
      "cancelled": "Cancelled"
    },
    "itemCount": "No items | 1 item | {count} items"
  },
  "user": {
    "greeting": "Hello, {name}!",
    "role": {
      "admin": "Administrator",
      "user":  "Member",
      "guest": "Guest"
    }
  }
}
```

---

## useI18n in script setup

```vue
<!-- src/components/OrderList.vue -->
<script setup lang="ts">
import { useI18n } from 'vue-i18n'

const { t, n, d, locale } = useI18n()

const props = defineProps<{
  orders: Order[]
  userName: string
}>()

// t() with interpolation
const greeting = computed(() => t('user.greeting', { name: props.userName }))

// n() for number formatting (uses Intl.NumberFormat under the hood)
function formatPrice(amount: number) {
  return n(amount, 'currency', { currency: 'USD' })
}

// d() for date formatting
function formatDate(date: Date) {
  return d(date, 'long')
}
</script>

<template>
  <section>
    <h1>{{ greeting }}</h1>
    <h2>{{ t('orders.title') }}</h2>

    <p v-if="!orders.length">{{ t('orders.empty') }}</p>

    <ul v-else>
      <li v-for="order in orders" :key="order.id">
        <!-- Nested key -->
        <span>{{ t(`orders.status.${order.status}`) }}</span>
        <span>{{ formatPrice(order.total) }}</span>
        <span>{{ formatDate(new Date(order.createdAt)) }}</span>
      </li>
    </ul>
  </section>
</template>
```

---

## Pluralisation

```vue
<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

const props = defineProps<{ itemCount: number }>()
</script>

<template>
  <!-- "itemCount": "No items | 1 item | {count} items" -->
  <p>{{ t('orders.itemCount', props.itemCount, { count: props.itemCount }) }}</p>
</template>
```

---

## Locale switching with lazy loading

```typescript
// src/i18n/loadLocale.ts
import { i18n, SUPPORTED_LOCALES } from './index'

const loadedLocales = new Set<string>(['en'])   // en is loaded eagerly

export async function switchLocale(newLocale: string): Promise<void> {
  if (!SUPPORTED_LOCALES.includes(newLocale)) {
    console.warn(`Unsupported locale: ${newLocale}`)
    return
  }

  // Load if not already cached
  if (!loadedLocales.has(newLocale)) {
    const messages = await import(`./locales/${newLocale}.json`)
    i18n.global.setLocaleMessage(newLocale, messages.default)
    loadedLocales.add(newLocale)
  }

  // Mutate the locale ref — Vue I18n updates all bindings reactively
  i18n.global.locale.value = newLocale
  localStorage.setItem('locale', newLocale)

  // Update the HTML lang attribute for accessibility
  document.documentElement.lang = newLocale
}
```

```vue
<!-- src/components/LocaleSwitcher.vue -->
<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { switchLocale } from '@/i18n/loadLocale'
import { SUPPORTED_LOCALES } from '@/i18n'

const { locale } = useI18n()

const LOCALE_LABELS: Record<string, string> = {
  en: 'English',
  es: 'Español',
  fr: 'Français',
  de: 'Deutsch',
  ja: '日本語',
}
</script>

<template>
  <select :value="locale" @change="(e) => switchLocale((e.target as HTMLSelectElement).value)">
    <option v-for="code in SUPPORTED_LOCALES" :key="code" :value="code">
      {{ LOCALE_LABELS[code] }}
    </option>
  </select>
</template>
```

---

## i18n-t component — HTML in translations

```vue
<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
</script>

<template>
  <!-- "termsNotice": "By continuing you agree to our {terms} and {privacy}." -->
  <i18n-t keypath="termsNotice" tag="p">
    <template #terms>
      <RouterLink to="/terms">{{ t('common.termsOfService') }}</RouterLink>
    </template>
    <template #privacy>
      <RouterLink to="/privacy">{{ t('common.privacyPolicy') }}</RouterLink>
    </template>
  </i18n-t>
</template>
```

---

## Number and date formatting

```typescript
// src/i18n/index.ts — declare formats
export const i18n = createI18n({
  legacy: false,
  // …
  numberFormats: {
    en: {
      currency: { style: 'currency', currency: 'USD' },
      percent:  { style: 'percent', minimumFractionDigits: 1 },
    },
    de: {
      currency: { style: 'currency', currency: 'EUR' },
    },
  },
  datetimeFormats: {
    en: {
      short: { year: 'numeric', month: 'short', day: 'numeric' },
      long:  { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' },
    },
  },
})
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Using `legacy: true` in new projects | Use `legacy: false` for Composition API — `$t` in templates still works |
| Mutating `$i18n.locale` directly | Set `locale.value` from `useI18n()` — direct mutation can bypass reactivity |
| Concatenating translated strings | `t('hello') + name` breaks in RTL — use `t('greeting', { name })` with a message that includes the variable |
| Bundling all locale files eagerly | Dynamic `import()` per locale reduces initial bundle size significantly |
| Not setting `document.documentElement.lang` | Screen readers use this attribute to announce language changes |
