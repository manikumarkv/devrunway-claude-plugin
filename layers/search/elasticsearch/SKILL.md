---
name: elasticsearch
description: Elasticsearch standards — index mappings, query DSL, aggregations, pagination, and the official Node.js client. Load when working with Elasticsearch.
user-invocable: false
stack: search/elasticsearch
paths:
  - "**/elasticsearch*"
  - "**/elastic*"
  - "**/search/**"
---

Full standards in [elasticsearch.md](elasticsearch.md). Always-on summary:

**Client setup:**
- Use the official `@elastic/elasticsearch` client — never HTTP calls directly
- Create a singleton client; the client manages connection pooling internally
- Always configure `tls.ca` or `tls.rejectUnauthorized` for production — do not disable TLS verification

**Index mappings:**
- Define explicit mappings before indexing data — never rely on dynamic mapping in production
- Use `keyword` for exact-match fields (IDs, status, tags); `text` for full-text search
- Add `"dynamic": "strict"` to reject documents with unmapped fields

**Querying:**
- Use `query: { bool:` as the outer query shape; put scoring terms in `must:` and non-scoring conditions in `filter:`
- Put date ranges and term filters in `filter:` context — they're cached and don't affect relevance score
- Always paginate: use `search_after` for deep pagination — avoid the `from`/`size` offset pattern beyond 10,000 results

**Aggregations:**
- Use `terms` aggregation for facet counts, `date_histogram` for time-series, `range` for price buckets
- Set `size` on `terms` aggregations — default is 10, which may miss long-tail values

**Index lifecycle:**
- Use ILM (Index Lifecycle Management) for time-series data (logs, events)
- Use aliases — point your app at an alias, not an index name, so reindexing is seamless

**Never:**
- Use `match_all` with no pagination in production — full scans can bring down the cluster
- Use `wildcard` queries on `text` fields — use `match` instead
- Store binary files in Elasticsearch — store URLs; keep binaries in object storage

**Related skills:** `search/algolia` (managed alternative), `cache-queue/redis` (caching frequent queries)
