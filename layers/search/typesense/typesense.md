# Typesense Standards

---

## Setup

```bash
npm install typesense                           # server + Node.js
npm install typesense-instantsearch-adapter    # React instant-search
npm install react-instantsearch                # UI components
```

---

## Client configuration

```typescript
// src/lib/typesense.ts
import Typesense from 'typesense'

// Admin client — server-side only (indexing, schema management)
export const adminClient = new Typesense.Client({
  nodes: [{
    host:     process.env.TYPESENSE_HOST!,
    port:     parseInt(process.env.TYPESENSE_PORT ?? '443'),
    protocol: process.env.TYPESENSE_PROTOCOL ?? 'https',
  }],
  apiKey:         process.env.TYPESENSE_ADMIN_API_KEY!,
  connectionTimeoutSeconds: 5,
})

// Search client — use for browser; scoped to search-only key
export const searchClient = new Typesense.Client({
  nodes: [{
    host:     process.env.NEXT_PUBLIC_TYPESENSE_HOST!,
    port:     parseInt(process.env.NEXT_PUBLIC_TYPESENSE_PORT ?? '443'),
    protocol: process.env.NEXT_PUBLIC_TYPESENSE_PROTOCOL ?? 'https',
  }],
  apiKey:         process.env.NEXT_PUBLIC_TYPESENSE_SEARCH_KEY!,
  connectionTimeoutSeconds: 5,
})
```

---

## Collection schema

```typescript
// src/search/schema.ts
import { CollectionCreateSchema } from 'typesense/lib/Typesense/Collections'

export const productsSchema: CollectionCreateSchema = {
  name:                  'products',
  default_sorting_field: 'popularity_score',
  fields: [
    { name: 'id',               type: 'string' },
    { name: 'name',             type: 'string' },
    { name: 'description',      type: 'string' },
    { name: 'brand',            type: 'string', facet: true },
    { name: 'category',         type: 'string', facet: true },
    { name: 'price',            type: 'float',  facet: true },
    { name: 'in_stock',         type: 'bool',   facet: true },
    { name: 'rating',           type: 'float',  optional: true },
    { name: 'popularity_score', type: 'int32' },
    { name: 'created_at',       type: 'int64' },
  ],
}

// Create collection (idempotent — use alias swap for updates)
export async function ensureCollection() {
  try {
    await adminClient.collections('products').retrieve()
  } catch {
    await adminClient.collections().create(productsSchema)
  }
}
```

---

## Alias swap (zero-downtime reindex)

```typescript
// src/search/reindex.ts
export async function reindexProducts(products: Product[]) {
  const newCollectionName = `products_${Date.now()}`

  // 1. Create new versioned collection
  await adminClient.collections().create({
    ...productsSchema,
    name: newCollectionName,
  })

  // 2. Bulk import into new collection
  await importDocuments(newCollectionName, products)

  // 3. Swap the alias atomically
  await adminClient.aliases().upsert('products', {
    collection_name: newCollectionName,
  })

  // 4. Delete old collection (find it via aliases before swapping)
  // Optional cleanup of previous versioned collection
}

// Application code always uses the alias name 'products'
```

---

## Bulk indexing

```typescript
// src/search/indexing.ts
async function importDocuments(collectionName: string, documents: object[]) {
  const BATCH_SIZE = 1_000

  for (let i = 0; i < documents.length; i += BATCH_SIZE) {
    const batch = documents.slice(i, i + BATCH_SIZE)

    const results = await adminClient
      .collections(collectionName)
      .documents()
      .import(batch, { action: 'upsert' })

    // Check for per-document errors
    const errors = results.filter(r => !r.success)
    if (errors.length > 0) {
      console.error(`Import errors in batch ${i / BATCH_SIZE}:`, errors)
    }
  }
}

// Upsert a single document (e.g., after a product update)
async function upsertProduct(product: Product) {
  await adminClient
    .collections('products')
    .documents()
    .upsert(toSearchDocument(product))
}
```

---

## Search

```typescript
// src/search/queries.ts
async function searchProducts(query: string, filters?: {
  brand?: string
  minPrice?: number
  maxPrice?: number
  inStock?: boolean
  page?: number
}) {
  const filterBy: string[] = []

  if (filters?.brand)    filterBy.push(`brand:=${filters.brand}`)
  if (filters?.minPrice) filterBy.push(`price:>=${filters.minPrice}`)
  if (filters?.maxPrice) filterBy.push(`price:<=${filters.maxPrice}`)
  if (filters?.inStock)  filterBy.push(`in_stock:=true`)

  return adminClient.collections('products').documents().search({
    q:          query,
    query_by:   'name,description,brand',   // ordered by relevance weight
    filter_by:  filterBy.join(' && ') || undefined,
    facet_by:   'brand,category,price,in_stock',
    sort_by:    'popularity_score:desc',
    per_page:   24,
    page:       filters?.page ?? 1,
  })
}
```

---

## React instant-search integration

```tsx
// src/search/adapter.ts
import TypesenseInstantSearchAdapter from 'typesense-instantsearch-adapter'

export const typesenseAdapter = new TypesenseInstantSearchAdapter({
  server: {
    apiKey: process.env.NEXT_PUBLIC_TYPESENSE_SEARCH_KEY!,
    nodes: [{
      host:     process.env.NEXT_PUBLIC_TYPESENSE_HOST!,
      port:     parseInt(process.env.NEXT_PUBLIC_TYPESENSE_PORT ?? '443'),
      protocol: process.env.NEXT_PUBLIC_TYPESENSE_PROTOCOL ?? 'https',
    }],
  },
  additionalSearchParameters: {
    query_by:     'name,description,brand',
    per_page:     24,
  },
})

export const instantSearchClient = typesenseAdapter.searchClient
```

```tsx
// src/components/ProductSearch.tsx
import {
  InstantSearch,
  SearchBox,
  Hits,
  RefinementList,
  Pagination,
  Configure,
} from 'react-instantsearch'
import { instantSearchClient } from '@/search/adapter'

function ProductHit({ hit }: { hit: any }) {
  return (
    <div>
      <h3>{hit.name}</h3>
      <p>{hit.brand}</p>
      <p>${hit.price}</p>
    </div>
  )
}

export function ProductSearch() {
  return (
    <InstantSearch
      searchClient={instantSearchClient}
      indexName="products"
      future={{ preserveSharedStateOnUnmount: true }}
    >
      <Configure hitsPerPage={24} />

      <SearchBox placeholder="Search products…" />

      <div style={{ display: 'flex', gap: 24 }}>
        <aside>
          <h4>Brand</h4>
          <RefinementList attribute="brand" />
          <h4>Category</h4>
          <RefinementList attribute="category" />
        </aside>

        <main>
          <Hits hitComponent={ProductHit} />
          <Pagination />
        </main>
      </div>
    </InstantSearch>
  )
}
```

---

## Scoped search key generation (server)

```typescript
// Generate a search-only key scoped to specific collections — call from your API
async function generateSearchKey(userId: string) {
  return adminClient.keys().create({
    description:  `Search key for user ${userId}`,
    actions:      ['documents:search'],
    collections:  ['products'],
    expires_at:   Math.floor(Date.now() / 1000) + 60 * 60,  // 1 hour
  })
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Sending admin API key to the browser | Generate scoped search-only keys server-side; expose only those to the client |
| Mutating a live collection schema | Create a new versioned collection and swap the alias — Typesense does not support in-place schema changes |
| Using `query_by: '*'` | Disables relevance scoring — always specify the fields to search |
| Not batching imports | Single-document imports are slow for large datasets — use `import()` in batches of 1 000–10 000 |
| Omitting `default_sorting_field` | Queries without an explicit `sort_by` return results in an undefined order |
