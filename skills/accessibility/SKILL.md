---
name: accessibility
description: Web accessibility (a11y) standards — semantic HTML, ARIA, keyboard navigation, focus management, forms, dynamic content. Load when writing or reviewing any UI component or page.
user-invocable: false
---

Full rules in [accessibility.md](accessibility.md). Always-on summary:

**Never:**
- `<div onClick>` or `<span onClick>` for interactive elements — use `<button>` or `<a>`
- Images without descriptive `alt` text — always set `alt=` on `<img>` elements; decorative images use `role="presentation"`, informative images must describe the content
- Form inputs without an associated `<label>`
- `tabIndex` values > 0 (breaks natural tab order)
- `aria-label` that duplicates visible text
- Color as the only way to convey meaning
- Auto-playing audio or video

**Always:**
- Semantic HTML first — `<nav>`, `<main>`, `<header>`, `<button>`, `<a href>`
- Keyboard navigable: every interactive element reachable and operable by keyboard
- Focus visible: never `outline: none` without a custom focus style
- `aria-live` for content that updates without a page reload
- Focus trap inside modals/dialogs; restore focus on close
- Error messages linked to their input with `aria-describedby`
- Custom interactive elements must handle `onKeyDown` (Enter/Space/Arrow keys) and be focusable with `tabIndex={0}`


**Related skills — apply together:**
- Your frontend layer skill — semantic HTML is the foundation of accessible UI
- Your testing layer skill — role/label-based selectors enforce accessibility in tests
- Your E2E testing layer skill — keyboard navigation and screen reader flows belong in E2E tests