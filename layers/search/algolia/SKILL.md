---
name: algolia
description: Algolia standards — index configuration, InstantSearch, relevance tuning, secured API keys, and React integration. Load when working with Algolia.
user-invocable: false
stack: search/algolia
paths:
  - "**/algolia*"
  - "**/instantsearch*"
  - "**/search/**"
---

Full standards in [algolia.md](algolia.md). Always-on summary:

**Keys and security:**
- Never expose the Admin API Key in the browser — server-side only
- Use the Search API Key for client-side queries (read-only by default)
- Generate Secured API Keys server-side to restrict scope (filters, index, user) per session
- Store Admin Key in `process.env.ALGOLIA_ADMIN_KEY`; expose only the search key

**Indexing:**
- Shape records at index time: denormalise related data into each record so search is a single hit
- Keep records under 10 KB — split large documents into multiple records if needed
- Always set `objectID` explicitly (your DB primary key) — enables `saveObject` to be idempotent
- Batch-index with `saveObjects()`, not one-by-one — rate limits apply per operation, not per record

**Index configuration (do it in code, not the Dashboard):**
- Define `searchableAttributes` in ranked order (more important attributes rank first)
- Set `attributesForFaceting` for any field used in filters or facets
- Use `customRanking` for business metrics (popularity, recency) — never hard-code sort logic in the client

**Querying:**
- Initialize with `algoliasearch(appId, searchKey)` then use InstantSearch hooks (`useSearchBox(`, `useHits(`) — they handle debounce, cache, and loading states
- Use `facetFilters` in search params to filter by facet values: `index.search('query', { facetFilters: ['category:shoes'] })`
- For server-side search (SSR, API routes), use `algoliasearch` SDK, not `lite` client
- Always set `hitsPerPage` — default is 20, which may be too many for some UIs

**Never:**
- Run Algolia Admin API calls from the browser — the Admin Key grants full write access
- Duplicate indices for "sort by" variants — use virtual replicas
- Reindex the entire dataset on every record change — use partial updates (`partialUpdateObject`)

**Related skills:** `search/elasticsearch` (self-hosted alternative), `cache-queue/redis` (caching search results)
