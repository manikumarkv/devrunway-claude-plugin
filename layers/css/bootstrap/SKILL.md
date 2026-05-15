---
name: bootstrap
description: Bootstrap 5 standards — utility classes, component customisation, SASS variables, and responsive layout. Load when working with Bootstrap.
user-invocable: false
stack: css/bootstrap
paths:
  - "**/*.scss"
  - "**/bootstrap*"
  - "**/custom.scss"
---

Full standards in [bootstrap.md](bootstrap.md). Always-on summary:

**Setup:**
- Import Bootstrap SCSS (not the compiled CSS) so you can override variables before the import
- One `custom.scss` entry point: override variables → import Bootstrap → add project utilities

**Customisation:**
- Override SCSS variables *before* `@import "bootstrap"` — never edit Bootstrap source files
- Use `$primary`, `$secondary`, `$font-family-base`, `$border-radius`, etc. to align with brand
- Extend utilities with `$utilities` map rather than writing one-off CSS classes

**Utility classes:**
- Prefer utility classes (`mt-3`, `d-flex`, `gap-2`, `text-truncate`) over custom CSS for one-off styles
- Use `gap-*` on flex/grid containers instead of margin hacks on children
- Responsive prefix: `col-12 col-md-6 col-lg-4` — mobile-first, always define xs first

**React-Bootstrap (when using React):**
- Use typed React-Bootstrap components — `Container`, `Row`, `Col`, `Button` — never raw divs with class strings
- Responsive columns: `<Row><Col xs={12} md={6}> ... </Col></Row>` — mobile-first using `xs=` prop
- Button variants: `<Button variant="primary">` — use the `variant` prop, not raw Bootstrap class strings

**Components (vanilla Bootstrap):**
- Initialise JS components via data attributes (`data-bs-toggle`, `data-bs-target`) — avoid manual `new bootstrap.Modal()` unless you need programmatic control
- When you do need JS, import individual components: `import { Modal } from 'bootstrap'` — not the whole bundle
- Override component CSS via SCSS maps (`$btn-padding-y`, `$modal-content-border-radius`) not by overriding compiled classes

**Accessibility:**
- Use Bootstrap's built-in ARIA roles (modals, dropdowns, alerts include them)
- Always add `aria-label` to icon-only buttons; Bootstrap does not do this automatically
- Use `.visually-hidden` (not `d-none`) for screen-reader-only text

**Never:**
- Edit files inside `node_modules/bootstrap/` — customise via SCSS variable overrides only
- Mix Bootstrap grid with CSS Grid/Flexbox ad-hoc — pick one layout system per section
- Load Bootstrap's full JS bundle when only using one or two components

**Related skills:** `core/dev-review` for accessibility checklist, `css/tailwind` if migrating
