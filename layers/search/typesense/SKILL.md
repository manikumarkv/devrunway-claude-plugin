---
name: typesense
description: Typesense standards — collection schema, indexing, search, facets, and instant-search React integration. Load when working with Typesense.
user-invocable: false
stack: search/typesense
paths:
  - "**/typesense/**"
  - "**/search/**"
  - "**/instantsearch/**"
---

Full standards in [typesense.md](typesense.md). Always-on summary:

**Collection schema:**
- Create with `client.collections().create({ name: 'products', fields: [...] })` — always define `fields:` explicitly
- Define fields with explicit `type` and `facet: true` where you need aggregation filters
- Use `default_sorting_field` on a numeric field (e.g. `popularity_score`) for rank-free queries
- Add `optional: true` only to fields that can genuinely be absent — omitting it enforces presence

**Indexing:**
- Use `collection.documents().import(docs, { action: 'upsert' })` for bulk loads
- Stream large datasets in batches of 1 000–10 000 documents
- Re-index on schema change: create a new collection, import, then use an alias to swap

**Search:**
- Always set `query_by` to the right text fields — order matters (first field weighs most)
- Use `filter_by` for exact-match filters; use `facet_by` to return counts alongside results
- Set `per_page` explicitly — default 10 can surprise users expecting more results

**Aliases:**
- Use `client.aliases().upsert('products', { collection_name: 'products_v2' })` for zero-downtime reindex
- Application code always references the alias name, never the versioned collection name

**Instant-search (React):**
- Initialize adapter: `const adapter = new TypesenseInstantSearchAdapter({ ... })` then pass its `searchClient` to `instantsearch(` from `react-instantsearch`
- Use `SearchBox`, `Hits`, `RefinementList`, `Pagination` from `react-instantsearch`
- Expose only `process.env.TYPESENSE_SEARCH_KEY` to the browser — never the admin key

**Never:**
- Send the admin API key to the browser — generate scoped search-only keys
- Mutate the live collection schema in production — use the alias swap pattern
- Use `query_by: '*'` — it disables relevance scoring

**Related skills:** `frontend/react` (instant-search UI), `backend/express` (indexing service), `api-conventions`
