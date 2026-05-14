# Algolia Standards

---

## Setup

```bash
npm install algoliasearch
npm install react-instantsearch   # for React UI components
```

```typescript
// src/lib/algolia.ts — server-side client (Admin key)
import algoliasearch from 'algoliasearch'

const appId  = process.env.ALGOLIA_APP_ID!
const adminKey = process.env.ALGOLIA_ADMIN_KEY!   // NEVER expose this client-side

export const algoliaAdmin = algoliasearch(appId, adminKey)
```

```typescript
// src/lib/algolia-client.ts — browser-safe client (Search key only)
import algoliasearch from 'algoliasearch/lite'

export const searchClient = algoliasearch(
  process.env.NEXT_PUBLIC_ALGOLIA_APP_ID!,
  process.env.NEXT_PUBLIC_ALGOLIA_SEARCH_KEY!,   // read-only search key
)
```

---

## Index configuration (code, not Dashboard)

```typescript
// scripts/configure-index.ts — run once; idempotent
import { algoliaAdmin } from '../src/lib/algolia'

async function configureIndex() {
  const index = algoliaAdmin.initIndex('products')

  await index.setSettings({
    // Ranked by importance — first attribute searched first
    searchableAttributes: [
      'name',
      'brand',
      'unordered(description)',   // unordered = position within field doesn't matter
      'tags',
    ],

    // Fields available for faceting and filtering
    attributesForFaceting: [
      'filterOnly(categoryId)',    // filter-only: not shown as facet counts
      'searchable(brand)',         // facet with search inside it
      'price',
      'inStock',
    ],

    // Business ranking on top of relevance
    customRanking: [
      'desc(popularity)',    // your custom field — higher = better
      'desc(updatedAt)',
    ],

    // Attributes returned in search results (omit heavy fields)
    attributesToRetrieve: [
      'objectID', 'name', 'brand', 'price', 'imageUrl', 'slug', 'inStock',
    ],

    // Snippets for description highlight
    attributesToSnippet: ['description:20'],

    // Typo tolerance
    minWordSizefor1Typo: 4,
    minWordSizefor2Typos: 8,
  })

  console.log('Index configured')
}

configureIndex()
```

---

## Indexing records

```typescript
// src/features/products/algolia-sync.ts
import { algoliaAdmin } from '../../lib/algolia'

const index = algoliaAdmin.initIndex('products')

export interface ProductRecord {
  objectID: string    // must match your DB primary key for idempotent saves
  name:     string
  brand:    string
  price:    number
  inStock:  boolean
  categoryId: string
  // Denormalised for search — avoids joins at query time
  categoryName: string
  tags:         string[]
  popularity:   number
  updatedAt:    number  // Unix timestamp for sorting
}

// Index a single product (on create/update)
export async function indexProduct(product: ProductRecord) {
  await index.saveObject(product)
}

// Bulk index (initial load or full reindex)
export async function bulkIndexProducts(products: ProductRecord[]) {
  await index.saveObjects(products, { autoGenerateObjectIDIfNotExist: false })
}

// Partial update — only changed fields
export async function updateProductStock(id: string, inStock: boolean) {
  await index.partialUpdateObject({ objectID: id, inStock })
}

// Delete a record
export async function deleteProduct(id: string) {
  await index.deleteObject(id)
}
```

---

## Secured API keys (per-user restrictions)

```typescript
// src/app/api/search-key/route.ts (Next.js API route — server only)
import algoliasearch from 'algoliasearch'
import { getCurrentUser } from '@/lib/auth'

const client = algoliasearch(
  process.env.ALGOLIA_APP_ID!,
  process.env.ALGOLIA_ADMIN_KEY!,
)

export async function GET() {
  const user = await getCurrentUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  // Generate a key restricted to this user's data
  const securedKey = client.generateSecuredApiKey(
    process.env.ALGOLIA_SEARCH_KEY!,
    {
      filters:     `userId:${user.id}`,        // can only see their records
      validUntil:  Math.floor(Date.now() / 1000) + 3600,  // expires in 1 hour
      restrictIndices: ['products', 'orders'],  // only these indices
    }
  )

  return Response.json({ key: securedKey, expiresIn: 3600 })
}
```

---

## React InstantSearch

```tsx
// src/features/search/ProductSearch.tsx
import {
  InstantSearch,
  SearchBox,
  Hits,
  RefinementList,
  Pagination,
  Highlight,
  useInstantSearch,
} from 'react-instantsearch'
import { searchClient } from '../../lib/algolia-client'

interface ProductHit {
  objectID:     string
  name:         string
  brand:        string
  price:        number
  imageUrl:     string
  slug:         string
}

function ProductHitCard({ hit }: { hit: ProductHit }) {
  return (
    <article>
      <img src={hit.imageUrl} alt={hit.name} />
      <h3>
        <Highlight attribute="name" hit={hit} />
      </h3>
      <p>{hit.brand}</p>
      <p>${hit.price.toFixed(2)}</p>
    </article>
  )
}

function NoResults() {
  const { results } = useInstantSearch()
  if (results.nbHits > 0) return null
  return <p>No products found for "{results.query}".</p>
}

export function ProductSearch() {
  return (
    <InstantSearch
      searchClient={searchClient}
      indexName="products"
      future={{ preserveSharedStateOnUnmount: true }}
    >
      <div className="search-layout">
        <aside>
          <h3>Brand</h3>
          <RefinementList attribute="brand" searchable />

          <h3>Category</h3>
          <RefinementList attribute="categoryName" />
        </aside>

        <main>
          <SearchBox placeholder="Search products…" autoFocus />
          <NoResults />
          <Hits hitComponent={ProductHitCard} />
          <Pagination />
        </main>
      </div>
    </InstantSearch>
  )
}
```

---

## Server-side search (API routes / SSR)

```typescript
// src/app/api/search/route.ts
import algoliasearch from 'algoliasearch'
import { NextRequest } from 'next/server'

const client = algoliasearch(
  process.env.ALGOLIA_APP_ID!,
  process.env.ALGOLIA_SEARCH_KEY!,
)
const index = client.initIndex('products')

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const query  = searchParams.get('q') ?? ''
  const page   = Number(searchParams.get('page') ?? 0)
  const brand  = searchParams.get('brand')

  const results = await index.search<ProductRecord>(query, {
    page,
    hitsPerPage: 20,
    filters: brand ? `brand:"${brand}"` : undefined,
    attributesToRetrieve: ['objectID', 'name', 'price', 'slug'],
    attributesToHighlight: ['name'],
  })

  return Response.json({
    hits:       results.hits,
    totalPages: results.nbPages,
    totalHits:  results.nbHits,
  })
}
```

---

## Replicas for sorting

```typescript
// Instead of duplicating the index, use virtual replicas
await index.setSettings({
  replicas: ['products_price_asc', 'products_price_desc', 'products_newest'],
})

const priceAscIndex = algoliaAdmin.initIndex('products_price_asc')
await priceAscIndex.setSettings({
  ranking: ['asc(price)', 'typo', 'geo', 'words', 'filters', 'proximity', 'attribute', 'exact', 'custom'],
})
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Admin API key in the browser | Use the Search API key (read-only); generate Secured API keys for restricted access |
| Indexing one record at a time in a loop | Use `saveObjects()` for batching — one API call for thousands of records |
| Reindexing everything on every change | Use `partialUpdateObject()` for field changes; `saveObject()` for full record updates |
| No `objectID` set | Set `objectID` to your DB primary key — enables idempotent saves |
| Sort replicas as separate full indices | Use virtual replicas with custom `ranking` settings |
| Client-side `filters` with unsanitised user input | Escape user input in filters; better: use Secured API Keys with pre-set filters |
| Index configuration done only in the Dashboard | Define settings in code (`setSettings`) so they're version-controlled and reproducible |
