# Pagefind standards

Short rules for sites that use [Pagefind](https://pagefind.app) for search.

## 1. When to use it

- Static sites, docs and content sites, up to tens of thousands of pages.
- Choose a hosted search (Algolia, Typesense) instead when you need search over live database data, personalised results, or analytics on queries.

## 2. Build wiring

- Pagefind reads the **built** HTML, so it runs after the site build:

```json
{ "scripts": { "build": "astro build && pagefind --site dist" } }
```

- Or use an integration (`astro-pagefind`) that runs it for you.
- Install it as a dev dependency (`npm i -D pagefind`) so the version is pinned, rather than `npx pagefind` fetching whatever is latest.
- Add the output folder (`dist/pagefind/`, or `public/pagefind/` in dev) to `.gitignore`.
- In dev, run a build once so the index exists, or show a "search works after build" note.

## 3. Control what gets indexed

| Attribute | Use |
|---|---|
| `data-pagefind-body` | On the main content wrapper. Once any page uses it, pages without it are skipped. |
| `data-pagefind-ignore` | Nav, footer, sidebars, "related" lists, cookie banners |
| `data-pagefind-meta="title"` | Set the result title explicitly |
| `data-pagefind-filter="category"` | Values users can filter by |
| `data-pagefind-sort="date"` | Values results can be sorted by |
| `data-pagefind-weight="5"` | Boost headings or key terms |

```html
<main data-pagefind-body>
  <h1 data-pagefind-meta="title">Deductible</h1>
  <span data-pagefind-filter="difficulty">Beginner</span>
  ...
</main>
<aside data-pagefind-ignore>Related terms</aside>
```

- Set `<html lang="...">` on every page. Pagefind builds one index per language.

## 4. Search UI

- For most sites use the Default UI (`@pagefind/default-ui` or `/pagefind/pagefind-ui.js`) and theme it with CSS variables.
- For a custom UI use the JS API. Import it dynamically and debounce input:

```ts
const pagefind = await import(/* @vite-ignore */ '/pagefind/pagefind.js');
await pagefind.init();
const search = await pagefind.debouncedSearch(query);
const results = await Promise.all(search.results.slice(0, 10).map((r) => r.data()));
```

- Load results' data (`r.data()`) only for the results you show.
- The search box needs a `<label>` (or `aria-label`) and keyboard access to results.

## Never

- Run Pagefind before the site build, or by hand.
- Commit the generated index.
- Index navigation and footers (every page then matches "Home").
- Load the whole search bundle on every page.
