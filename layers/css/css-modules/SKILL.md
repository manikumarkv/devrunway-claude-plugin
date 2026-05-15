---
name: css-modules
description: CSS Modules standards — scoped class names, composes, TypeScript typings, and co-location patterns. Load when working with CSS Modules.
user-invocable: false
stack: css/css-modules
paths:
  - "**/*.module.css"
  - "**/*.module.scss"
---

Full standards in [css-modules.md](css-modules.md). Always-on summary:

**File conventions:**
- Name files `ComponentName.module.css` — co-located with the component file
- One module per component; do not share modules across unrelated components
- Use camelCase class names so they destructure cleanly: `styles.cardHeader` not `styles['card-header']`

**Composing styles:**
- Use `composes` for shared base styles instead of duplicating declarations
- `composes` from a shared utilities file for reusable tokens (`.srOnly`, `.focusRing`)
- Keep `composes` at the top of a rule, before other declarations

**Global selectors:**
- Use `:global(.selector)` sparingly — only for third-party library overrides or body-level resets
- Never use `:global` as a shortcut to avoid scoping; that defeats the purpose of CSS Modules

**TypeScript:**
- Enable `declaration` + `modules: true` in your CSS Modules type generation tool (`css-modules-typescript-loader` or `typed-css-modules`)
- Import as `import styles from './Component.module.css'` then apply with `className={styles.cardHeader}` — you get full autocomplete on class names

**Composing:**
- Use `composes: baseCard from './shared.module.css';` to reuse base styles — keeps rules DRY

**Dynamic classes:**
- Use `clsx` or `classnames` for conditional class composition: `clsx(styles.btn, isActive && styles.active)`
- Never concatenate class strings manually — error-prone when class names are hashed

**Never:**
- Import a `.module.css` file from a different feature's directory — creates hidden coupling
- Use `!important` inside a CSS Module — the module's scoping already ensures specificity
- Put layout concerns (grid, positioning of siblings) inside a component's own module — the parent controls layout

**Related skills:** `css/tailwind` (utility-first alternative), `ui-components/mui` (sx prop styling)
