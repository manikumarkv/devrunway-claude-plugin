# Astro standards

Short rules for Astro sites. When a rule and the project disagree, follow the project and say so.

## 1. Rendering

- Default to static output. Switch to `output: 'server'` (with an adapter) only when pages need per-request data such as auth or personalisation.
- For a mostly static site with a few dynamic pages, keep static output and mark just those pages with `export const prerender = false`.
- Fetch data in the component frontmatter (the `---` block). It runs at build time, or on the server, and never ships to the browser.

## 2. Islands

- A framework component (React, Vue, Svelte) renders to plain HTML unless it has a `client:*` directive.
- Pick the lightest directive that works:

| Directive | Use when |
|---|---|
| `client:visible` | Below the fold (carousels, comments) |
| `client:idle` | Needed soon but not urgent |
| `client:load` | Must work immediately (search box, nav menu) |
| `client:media` | Only on some screen sizes |
| `client:only="react"` | Cannot render on the server (uses `window`) |

- Pass serialisable props only (no functions or class instances) into an island.
- The framework's own rules (React, Vue) still apply inside the island.

## 3. Content collections

- Define each collection in `src/content.config.ts` (Astro 5) or `src/content/config.ts` (Astro 4) with a Zod schema.
- Make required fields required. Use `z.enum` for fixed values and `reference()` for links between entries.
- Read entries with `getCollection('name')` / `getEntry('name', id)`. Filter drafts in the query.
- Build dynamic routes from collections with `getStaticPaths()`.

```ts
// src/content.config.ts
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const terms = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/terms' }),
  schema: z.object({
    title: z.string(),
    difficulty: z.enum(['beginner', 'intermediate', 'advanced']),
    related: z.array(z.string()).default([]),
  }),
});

export const collections = { terms };
```

## 4. Components and layouts

- Type props in the frontmatter:

```astro
---
interface Props { title: string; description?: string }
const { title, description = '' } = Astro.props;
---
```

- Put the shared `<head>`, meta tags and site chrome in one `src/layouts/` layout. Pages pass `title` and `description`.
- Use `<slot />` for children, and named slots for optional regions.

## 5. Images and assets

- Import local images and render them with `<Image />` or `<Picture />` from `astro:assets`. They get sized and optimised automatically.
- `alt` is required. Use `alt=""` only for decorative images.
- Put files in `public/` only when they must keep their exact URL (favicons, `robots.txt`).

## 6. Environment variables

- `import.meta.env.PUBLIC_*` is bundled into the browser. Anything else is server-only.
- On Astro 5, declare variables with `astro:env` (`envField`) so they are typed and checked at startup.

## 7. SEO and performance

- Every page sets `<title>`, a meta description and a canonical URL.
- Add `@astrojs/sitemap` for static sites.
- Use `<ViewTransitions />` / `<ClientRouter />` only if the site needs app-like navigation.

## Never

- `client:load` on everything. That turns the site back into an SPA.
- Reading content with `import.meta.glob` or `fs` when a collection exists.
- Secrets in `PUBLIC_*` variables.
- Fetching in an island what the page could fetch at build time.
