# CSS Modules Standards

---

## Setup

CSS Modules works out of the box with Next.js, Create React App, and Vite — no extra configuration needed for `.module.css` files.

### Vite (explicit config)

```typescript
// vite.config.ts
import { defineConfig } from 'vite'

export default defineConfig({
  css: {
    modules: {
      localsConvention: 'camelCase',   // card-header → cardHeader
      generateScopedName: '[name]__[local]__[hash:base64:5]',
    },
  },
})
```

### TypeScript typings

```bash
npm install --save-dev typed-css-modules
# or
npm install --save-dev typescript-plugin-css-modules
```

```json
// tsconfig.json — with typescript-plugin-css-modules
{
  "compilerOptions": {
    "plugins": [{ "name": "typescript-plugin-css-modules" }]
  }
}
```

```bash
# Generate .d.ts files (CI-safe approach)
npx tcm src --pattern "**/*.module.css"
```

---

## File naming and co-location

```
src/
  features/
    orders/
      OrderList.tsx
      OrderList.module.css     ← co-located with the component
      OrderCard.tsx
      OrderCard.module.css
  shared/
    ui/
      Button.tsx
      Button.module.css
    styles/
      utils.module.css         ← shared tokens for composes
```

---

## Basic usage

```css
/* OrderCard.module.css */
.card {
  border: 1px solid var(--color-border);
  border-radius: 0.5rem;
  padding: 1rem;
  transition: box-shadow 0.2s ease;
}

.card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.cardHeader {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 600;
}

.statusBadge {
  display: inline-flex;
  align-items: center;
  padding: 0.125rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
}

.statusBadge.pending  { background: #fef3c7; color: #92400e; }
.statusBadge.shipped  { background: #d1fae5; color: #065f46; }
.statusBadge.delivered { background: #dbeafe; color: #1e40af; }
```

```tsx
// OrderCard.tsx
import styles from './OrderCard.module.css'
import clsx from 'clsx'

interface Props {
  order: Order
}

export function OrderCard({ order }: Props) {
  return (
    <div className={styles.card}>
      <div className={styles.cardHeader}>
        <span>Order #{order.id}</span>
        <span className={clsx(styles.statusBadge, styles[order.status])}>
          {order.status}
        </span>
      </div>
    </div>
  )
}
```

---

## composes — reusing styles

```css
/* src/shared/styles/utils.module.css */
.srOnly {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.focusRing {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

.truncate {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
```

```css
/* Button.module.css */
.button {
  composes: focusRing from '../shared/styles/utils.module.css';  /* ← composes at top */
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.button:focus-visible {
  /* focusRing already applied via composes */
}

.label {
  composes: truncate from '../shared/styles/utils.module.css';
  max-width: 200px;
}
```

---

## Dynamic and conditional class names

```bash
npm install clsx
```

```tsx
import clsx from 'clsx'
import styles from './Button.module.css'

interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'danger'
  size?: 'sm' | 'md' | 'lg'
  isLoading?: boolean
  disabled?: boolean
  className?: string
}

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading,
  disabled,
  className,
  children,
  ...props
}: ButtonProps & React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={clsx(
        styles.button,
        styles[variant],      // styles.primary / styles.secondary / styles.danger
        styles[size],         // styles.sm / styles.md / styles.lg
        isLoading && styles.loading,
        disabled && styles.disabled,
        className,            // allow external className passthrough
      )}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading && <span className={styles.spinner} aria-hidden="true" />}
      {children}
    </button>
  )
}
```

---

## Global selectors — use sparingly

```css
/* Overriding a third-party library (acceptable use) */
:global(.react-datepicker) {
  font-family: var(--font-family-base);
  border-radius: 0.5rem;
}

:global(.react-datepicker__day--selected) {
  background-color: var(--color-primary);
}

/* Local scope with global child (pattern for rich text content) */
.content :global(h1),
.content :global(h2),
.content :global(p) {
  margin-bottom: 1em;
}
.content :global(a) {
  color: var(--color-primary);
  text-decoration: underline;
}
```

---

## CSS custom properties with CSS Modules

```css
/* src/shared/styles/tokens.css — not a module, imported globally */
:root {
  --color-primary:     #0d6efd;
  --color-primary-dark: #0a58ca;
  --color-border:      #dee2e6;
  --color-text:        #212529;
  --color-text-muted:  #6c757d;
  --color-bg:          #ffffff;
  --color-bg-subtle:   #f8f9fa;

  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;

  --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.12);
  --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.1);
}

/* CSS Modules reference global tokens — no import needed */
/* Card.module.css */
.card {
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
}
```

---

## Animation

```css
/* Component.module.css */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-4px); }
  to   { opacity: 1; transform: translateY(0); }
}

.dropdown {
  animation: fadeIn 0.15s ease-out;
}
```

> CSS Modules does NOT scope `@keyframes` names — they remain global. Use unique names or prefix with the component name (e.g., `@keyframes dropdownFadeIn`).

---

## Next.js specifics

```tsx
// App Router — CSS Modules work in both Server and Client Components
// Server Component (no 'use client' needed)
import styles from './Page.module.css'

export default function Page() {
  return <main className={styles.page}>...</main>
}

// Global styles — import in layout.tsx only
// app/layout.tsx
import './globals.css'     // NOT a module — applies globally
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `styles['card-header']` | Use camelCase: `styles.cardHeader` (set `localsConvention: 'camelCase'`) |
| Sharing one module across unrelated components | Each component gets its own module — use `composes` for shared tokens |
| `className={styles.btn + ' ' + styles.active}` | Use `clsx(styles.btn, styles.active)` |
| `:global(.myClass)` everywhere to avoid scoping | Only for third-party overrides — local scoping is the feature, not a bug |
| `!important` in a module | Module scoping prevents conflicts — if you need `!important`, investigate specificity |
| Putting grid/flex layout in a child's own module | Parent controls layout; child controls its internal appearance |
| No `.d.ts` generation in CI | Run `tcm` in CI to catch class name typos at build time |
