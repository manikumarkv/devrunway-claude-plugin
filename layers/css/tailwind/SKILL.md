---
name: tailwind-css
description: Tailwind CSS v3 conventions — class ordering, responsive design, dark mode, custom config, @apply usage rules. Load when working with Tailwind classes.
user-invocable: false
stack: css/tailwind
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.html"
  - "tailwind.config.*"
---

Full standards in [tailwind-css.md](tailwind-css.md). Always-on summary:

**Class ordering:** layout → box model → typography → visual → interactive
(enforce via `prettier-plugin-tailwindcss`)

**Responsive:** mobile-first — base styles for mobile, `sm:` / `md:` / `lg:` for larger screens

**Dark mode:** `class` strategy (not `media`) — ThemeProvider toggles `dark` class on `<html>`

**Config:**
- Custom tokens go in `tailwind.config.ts` `theme.extend` — never override core tokens
- `container`: set `center: true` + `padding` in config — don't override per-use

**`@apply`:** only in component stylesheets for multi-element patterns; never as a substitute for extracting a React component

**Never:**
- Arbitrary values `[123px]` when a design token exists — check config first
- `!important` (`!` prefix) — fix specificity instead
- Override core Tailwind tokens in config (use `extend` only)

**Use:**
- `group` and `peer` for state-based child styling instead of JS
- `bg-gradient-to-r from-blue-500 to-purple-500` — not arbitrary gradients

**Related skills:** `shadcn-ui` (cn() utility), `react-standards` (class merge patterns)
