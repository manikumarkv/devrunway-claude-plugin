# Tailwind CSS v3 Standards

## Class ordering

Apply classes in this order consistently. Use `prettier-plugin-tailwindcss` to enforce it automatically — don't rely on manual discipline.

```
layout → box model → typography → visual → interactive
```

| Category | Examples |
|---|---|
| Layout | `flex`, `grid`, `block`, `hidden`, `relative`, `absolute`, `z-10` |
| Box model | `w-full`, `h-16`, `p-4`, `m-2`, `gap-3`, `overflow-hidden` |
| Typography | `text-sm`, `font-medium`, `leading-tight`, `text-center`, `tracking-wide` |
| Visual | `bg-white`, `border`, `rounded-md`, `shadow-sm`, `opacity-50` |
| Interactive | `cursor-pointer`, `hover:bg-gray-100`, `focus:ring-2`, `transition` |

```tsx
// Good — ordered
<div className="flex items-center gap-3 px-4 py-2 text-sm font-medium bg-white border rounded-md shadow-sm hover:bg-gray-50 focus:outline-none" />

// Bad — random order (hard to scan, conflicts undetectable at a glance)
<div className="hover:bg-gray-50 text-sm border px-4 flex rounded-md bg-white gap-3 py-2 shadow-sm font-medium focus:outline-none items-center" />
```

## Responsive — mobile first

Always write base styles for mobile. Add `sm:` / `md:` / `lg:` / `xl:` modifiers for larger breakpoints.

```tsx
// Good — mobile-first
<div className="flex flex-col gap-4 md:flex-row md:gap-8">
  <aside className="w-full md:w-64 lg:w-72" />
  <main className="flex-1" />
</div>

// Bad — desktop-first, mobile broken
<div className="flex flex-row gap-8 sm:flex-col sm:gap-4">
```

Breakpoints (Tailwind defaults):
| Prefix | Min-width |
|---|---|
| `sm:` | 640px |
| `md:` | 768px |
| `lg:` | 1024px |
| `xl:` | 1280px |
| `2xl:` | 1536px |

## Dark mode

Use `class` strategy — never `media`. The `dark` class on `<html>` is toggled by `ThemeProvider`.

```ts
// tailwind.config.ts
export default {
  darkMode: 'class',
  // ...
}
```

```tsx
// Components use dark: variants — they follow the class, not system preference
<div className="bg-white text-gray-900 dark:bg-gray-900 dark:text-gray-100" />
```

Never toggle dark mode by checking `window.matchMedia` yourself — use the ThemeProvider which also persists the preference.

## Arbitrary values — use design tokens first

Before using `[123px]` arbitrary syntax, check `tailwind.config.ts` for an existing token.

```tsx
// Good — uses config token
<div className="w-72" />  // 288px from Tailwind scale

// Only OK if no token exists and the value is truly one-off
<div className="w-[288px]" />

// Bad — use a token
<div className="w-[288px]" />  // when w-72 exists
```

If you find yourself repeating an arbitrary value, add it to `tailwind.config.ts` `theme.extend`.

## `@apply` — limited use

`@apply` is acceptable for multi-element CSS patterns where the same group of classes applies to many elements and extracting a React component isn't practical (e.g. Markdown prose styling, rich-text editor output).

```css
/* OK — styling arbitrary HTML from a CMS */
.prose h2 {
  @apply text-2xl font-bold mt-8 mb-4 text-gray-900 dark:text-gray-100;
}
.prose p {
  @apply leading-relaxed text-gray-700 dark:text-gray-300 mb-4;
}
```

Not acceptable — extracting a React component is the right answer:
```css
/* Bad — use a <Button> component instead */
.btn-primary {
  @apply px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700;
}
```

## Custom tokens in `tailwind.config.ts`

Add custom design tokens in `theme.extend` only. Never replace core tokens.

```ts
// tailwind.config.ts
import type { Config } from 'tailwindcss'

export default {
  content: ['./src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eff6ff',
          500: '#3b82f6',
          900: '#1e3a8a',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      spacing: {
        18: '4.5rem',
        88: '22rem',
      },
      borderRadius: {
        '4xl': '2rem',
      },
    },
  },
  plugins: [],
} satisfies Config
```

## Container

Configure `container` in the config so you don't override it per-use:

```ts
theme: {
  container: {
    center: true,
    padding: {
      DEFAULT: '1rem',
      sm: '2rem',
      lg: '4rem',
    },
  },
}
```

Then just `<div className="container">` — never `<div className="container mx-auto px-4">`.

## `group` and `peer` — avoid JS for state-based children

```tsx
// Good — parent hover styles child via CSS
<div className="group flex items-center gap-2 hover:bg-gray-50">
  <span>Label</span>
  <ChevronIcon className="opacity-0 group-hover:opacity-100 transition-opacity" />
</div>

// Good — preceding sibling state affects following sibling
<input className="peer border rounded-md" />
<p className="hidden peer-invalid:block text-red-500 text-sm">Invalid input</p>

// Bad — JavaScript needed for something CSS handles
const [isHovered, setIsHovered] = useState(false)
<div onMouseEnter={() => setIsHovered(true)} onMouseLeave={() => setIsHovered(false)}>
  <ChevronIcon className={isHovered ? 'opacity-100' : 'opacity-0'} />
</div>
```

## Gradients

Use Tailwind's built-in gradient utilities:

```tsx
// Good
<div className="bg-gradient-to-r from-blue-500 to-purple-600" />
<div className="bg-gradient-to-br from-blue-500 via-purple-500 to-pink-500" />

// Bad — arbitrary when utilities exist
<div className="bg-[linear-gradient(to_right,#3b82f6,#a855f7)]" />
```

## `!important` — avoid entirely

The `!` prefix in Tailwind (`!text-red-500`) applies `!important`. This creates specificity debt.

```tsx
// Bad — band-aid fix
<p className="!text-red-500" />

// Good — investigate why specificity is wrong and fix the root cause
// Usually the issue is an overly broad selector in a CSS file or incorrect class ordering
```

## Transitions and animations

```tsx
// Smooth transitions for interactive elements
<button className="bg-blue-600 hover:bg-blue-700 transition-colors duration-200" />

// Scale on click
<button className="active:scale-95 transition-transform" />

// Loading pulse
<div className="animate-pulse bg-gray-200 rounded-md h-4 w-full" />
```

Use `transition-colors` not `transition-all` — `transition-all` can cause unexpected transitions on layout-affecting properties.

## Extracting repeated class strings

When the same combination of classes appears in 3+ places, extract a component — not a CSS class.

```tsx
// Bad — repeating classes, use @apply or inline
const cardClass = 'rounded-lg border bg-card text-card-foreground shadow-sm p-6'
// Used in 5 different places

// Good — extract a component
export function Card({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn('rounded-lg border bg-card text-card-foreground shadow-sm p-6', className)}>
      {children}
    </div>
  )
}
```
