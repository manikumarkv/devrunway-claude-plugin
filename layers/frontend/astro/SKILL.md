---
name: astro
description: Astro standards — static-first pages, islands and client directives, content collections, env vars. Load when working with .astro files or astro.config.
user-invocable: false
stack: frontend/astro
paths:
  - "**/*.astro"
  - "**/astro.config.*"
  - "**/src/content/config.*"
  - "**/src/content.config.*"
---

Full standards in [astro.md](astro.md). Always-on summary:

- **Static by default.** Ship zero JS unless a component needs it. Use `output: 'server'` only when a page needs per-request data.
- **Islands.** Add a `client:*` directive only to interactive components. Prefer `client:visible` or `client:idle` over `client:load`.
- **Content.** Keep content in content collections with a Zod schema. Read it with `getCollection()` / `getEntry()`, never raw file imports.
- **Props.** Type every component's props with `interface Props` in the frontmatter.
- **Images.** Use `<Image />` from `astro:assets`, always with `alt`.
- **Env.** Only `PUBLIC_*` variables reach the browser. Secrets stay in server code.
- **Never** fetch data inside an island that the page could fetch at build time.
