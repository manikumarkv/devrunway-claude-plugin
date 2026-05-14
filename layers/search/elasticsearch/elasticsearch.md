# Elasticsearch Standards

---

## Setup

```bash
npm install @elastic/elasticsearch
```

```typescript
// src/lib/elasticsearch.ts — singleton client
import { Client } from '@elastic/elasticsearch'

const node = process.env.ELASTICSEARCH_URL ?? 'http://localhost:9200'

export const esClient = new Client({
  node,
  auth: process.env.ELASTICSEARCH_API_KEY
    ? { apiKey: process.env.ELASTICSEARCH_API_KEY }
    : {
        username: process.env.ELASTICSEARCH_USERNAME ?? 'elastic',
        password: process.env.ELASTICSEARCH_PASSWORD ?? '',
      },
  tls: process.env.ELASTICSEARCH_CA_CERT
    ? { ca: process.env.ELASTICSEARCH_CA_CERT }
    : undefined,
  maxRetries:      3,
  requestTimeout:  10_000,
})

// Verify connection at startup
export async function pingElasticsearch() {
  const ok = await esClient.ping()
  if (!ok) throw new Error('Elasticsearch unreachable')
}
```

---

## Index mappings — always explicit

```typescript
// src/features/products/products.index.ts
import { esClient } from '../../lib/elasticsearch'

export const PRODUCTS_INDEX = 'products'

export async function createProductsIndex() {
  const exists = await esClient.indices.exists({ index: PRODUCTS_INDEX })
  if (exists) return

  await esClient.indices.create({
    index: PRODUCTS_INDEX,
    body: {
      settings: {
        number_of_shards:   1,
        number_of_replicas: 1,
        analysis: {
          analyzer: {
            autocomplete: {
              type:      'custom',
              tokenizer: 'standard',
              filter:    ['lowercase', 'autocomplete_filter'],
            },
          },
          filter: {
            autocomplete_filter: {
              type:     'edge_ngram',
              min_gram: 2,
              max_gram: 20,
            },
          },
        },
      },
      mappings: {
        dynamic: 'strict',   // reject unknown fields
        properties: {
          id:          { type: 'keyword' },
          name:        { type: 'text', analyzer: 'autocomplete', search_analyzer: 'standard',
                         fields: { keyword: { type: 'keyword' } } },
          description: { type: 'text' },
          brand:       { type: 'keyword' },
          categoryId:  { type: 'keyword' },
          price:       { type: 'scaled_float', scaling_factor: 100 },
          inStock:     { type: 'boolean' },
          tags:        { type: 'keyword' },
          popularity:  { type: 'integer' },
          createdAt:   { type: 'date' },
          updatedAt:   { type: 'date' },
        },
      },
    },
  })
}
```

---

## Indexing documents

```typescript
import { esClient, PRODUCTS_INDEX } from './products.index'

interface ProductDoc {
  id:          string
  name:        string
  description: string
  brand:       string
  categoryId:  string
  price:       number
  inStock:     boolean
  tags:        string[]
  popularity:  number
  createdAt:   string
  updatedAt:   string
}

// Index or update a single document
export async function indexProduct(product: ProductDoc) {
  await esClient.index({
    index: PRODUCTS_INDEX,
    id:    product.id,        // explicit ID = idempotent
    document: product,
  })
}

// Bulk index
export async function bulkIndexProducts(products: ProductDoc[]) {
  const operations = products.flatMap((p) => [
    { index: { _index: PRODUCTS_INDEX, _id: p.id } },
    p,
  ])
  const { errors, items } = await esClient.bulk({ operations, refresh: false })
  if (errors) {
    const failed = items.filter((i) => i.index?.error)
    throw new Error(`Bulk index errors: ${JSON.stringify(failed)}`)
  }
}

// Partial update
export async function updateProductStock(id: string, inStock: boolean) {
  await esClient.update({
    index: PRODUCTS_INDEX,
    id,
    doc: { inStock, updatedAt: new Date().toISOString() },
  })
}

// Delete
export async function deleteProduct(id: string) {
  await esClient.delete({ index: PRODUCTS_INDEX, id })
}
```

---

## Querying — bool query pattern

```typescript
interface SearchParams {
  query?:     string
  brand?:     string
  inStock?:   boolean
  minPrice?:  number
  maxPrice?:  number
  page?:      number
  pageSize?:  number
}

export async function searchProducts(params: SearchParams) {
  const {
    query    = '',
    brand,
    inStock,
    minPrice,
    maxPrice,
    page     = 0,
    pageSize = 20,
  } = params

  const must:   unknown[] = []
  const filter: unknown[] = []

  // Full-text search — scoring (must context)
  if (query) {
    must.push({
      multi_match: {
        query,
        fields: ['name^3', 'brand^2', 'description', 'tags'],  // ^N = boost
        fuzziness: 'AUTO',
        type: 'best_fields',
      },
    })
  } else {
    must.push({ match_all: {} })
  }

  // Filters — non-scoring (filter context = cached)
  if (brand)              filter.push({ term: { brand } })
  if (inStock !== undefined) filter.push({ term: { inStock } })
  if (minPrice !== undefined || maxPrice !== undefined) {
    filter.push({
      range: {
        price: {
          ...(minPrice !== undefined && { gte: minPrice }),
          ...(maxPrice !== undefined && { lte: maxPrice }),
        },
      },
    })
  }

  const result = await esClient.search<ProductDoc>({
    index: PRODUCTS_INDEX,
    body: {
      from:      page * pageSize,
      size:      pageSize,
      query:     { bool: { must, filter } },
      sort:      [
        { _score: 'desc' },
        { popularity: 'desc' },
      ],
      highlight: {
        fields: { name: {}, description: { fragment_size: 150 } },
      },
      _source: ['id', 'name', 'brand', 'price', 'inStock', 'slug'],
    },
  })

  return {
    hits:       result.hits.hits.map((h) => ({ ...h._source, highlight: h.highlight })),
    total:      result.hits.total,
    page,
    pageSize,
  }
}
```

---

## Aggregations (facets)

```typescript
export async function getProductFacets(query = '') {
  const result = await esClient.search({
    index: PRODUCTS_INDEX,
    size: 0,    // no hits needed — only aggregations
    body: {
      query: query
        ? { multi_match: { query, fields: ['name', 'brand', 'description'] } }
        : { match_all: {} },
      aggs: {
        brands: {
          terms: { field: 'brand', size: 50 },
        },
        priceRanges: {
          range: {
            field: 'price',
            ranges: [
              { to: 25 },
              { from: 25, to: 50 },
              { from: 50, to: 100 },
              { from: 100 },
            ],
          },
        },
        inStock: {
          terms: { field: 'inStock', size: 2 },
        },
      },
    },
  })

  return result.aggregations
}
```

---

## Deep pagination with search_after

```typescript
// Use search_after for pages beyond 10,000 hits (from+size has a 10k limit)
export async function deepSearch(query: string, searchAfter?: unknown[]) {
  const result = await esClient.search<ProductDoc>({
    index: PRODUCTS_INDEX,
    body: {
      size: 20,
      query: { match: { name: query } },
      sort: [
        { _score: 'desc' },
        { id: 'asc' },       // tie-breaker — must be unique and stable
      ],
      ...(searchAfter && { search_after: searchAfter }),
    },
  })

  const hits       = result.hits.hits
  const lastSort   = hits.at(-1)?.sort   // pass this as searchAfter for the next page
  const hasMore    = hits.length === 20

  return { hits: hits.map((h) => h._source), lastSort, hasMore }
}
```

---

## Index aliases (zero-downtime reindex)

```typescript
// Reindex pattern — avoids downtime
async function reindex() {
  const newIndex = `products_${Date.now()}`

  // 1. Create new index with updated mappings
  await esClient.indices.create({ index: newIndex, body: { mappings: { ... } } })

  // 2. Bulk index all data into the new index
  await bulkIndexInto(newIndex)

  // 3. Atomically swap the alias
  await esClient.indices.updateAliases({
    body: {
      actions: [
        { remove: { index: 'products_*', alias: 'products' } },
        { add:    { index: newIndex,      alias: 'products' } },
      ],
    },
  })

  // 4. Delete the old index
  await esClient.indices.delete({ index: 'products_old' })
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Dynamic mapping in production | Set `"dynamic": "strict"` — unknown fields are rejected |
| Filters in `must` context | Filters (non-scoring) go in `filter` context — they're cached |
| `from > 10000` for deep pagination | Use `search_after` with a stable sort key |
| No `size` on `terms` aggregation | Default is 10 — set `size: 50` or more for facets |
| `wildcard` queries on `text` fields | Use `match` or `match_phrase`; wildcards on text fields are slow |
| Indexing directly to index name | Point to an alias — swap indices atomically for reindexing |
| One document per `index()` call in a loop | Use `bulk()` API — orders of magnitude faster |
| `refresh: true` on every write | Only refresh when you need immediate visibility; default async refresh is fine |
