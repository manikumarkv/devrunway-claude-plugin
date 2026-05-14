# Jotai Standards

---

## Setup

```bash
npm install jotai
```

---

## Primitive atoms

```typescript
// src/features/orders/atoms/orders.atoms.ts
import { atom } from 'jotai'

// Primitive atoms — module-level, not inside components
export const selectedOrderIdAtom = atom<string | null>(null)
export const orderFiltersAtom = atom<{
  status: 'all' | 'pending' | 'shipped' | 'delivered'
  dateRange: { from: string; to: string } | null
}>({
  status:    'all',
  dateRange: null,
})

export const darkModeAtom   = atom<boolean>(false)
export const sidebarOpenAtom = atom<boolean>(true)

// Read-only atoms (derived, see below)
// Write-only atoms (action atoms)
export const resetFiltersAtom = atom(null, (_get, set) => {
  set(orderFiltersAtom, { status: 'all', dateRange: null })
  set(selectedOrderIdAtom, null)
})
```

---

## Derived (computed) atoms

```typescript
// Derived atoms — synchronous, no side effects
export const activeFilterCountAtom = atom((get) => {
  const filters = get(orderFiltersAtom)
  let count = 0
  if (filters.status !== 'all')  count++
  if (filters.dateRange !== null) count++
  return count
})

// Derived from multiple atoms
export const filteredOrdersAtom = atom((get) => {
  const orders  = get(allOrdersAtom)     // another primitive atom
  const filters = get(orderFiltersAtom)

  return orders.filter((order) => {
    if (filters.status !== 'all' && order.status !== filters.status) return false
    if (filters.dateRange) {
      const date = new Date(order.createdAt)
      if (date < new Date(filters.dateRange.from)) return false
      if (date > new Date(filters.dateRange.to))   return false
    }
    return true
  })
})

// Writable derived atom (computed getter + custom setter)
export const selectedOrderAtom = atom(
  // Getter — derived from selectedOrderIdAtom
  (get) => {
    const id     = get(selectedOrderIdAtom)
    const orders = get(allOrdersAtom)
    return id ? orders.find((o) => o.id === id) ?? null : null
  },
  // Setter — accepts the order object, sets the ID
  (_get, set, order: Order | null) => {
    set(selectedOrderIdAtom, order?.id ?? null)
  }
)
```

---

## Usage in components

```tsx
// src/features/orders/components/OrderFilters.tsx
import { useAtom, useAtomValue, useSetAtom } from 'jotai'
import { orderFiltersAtom, resetFiltersAtom, activeFilterCountAtom } from '../atoms/orders.atoms'

export function OrderFilters() {
  // Read + write
  const [filters, setFilters] = useAtom(orderFiltersAtom)
  // Read only — component only re-renders when this value changes
  const activeCount = useAtomValue(activeFilterCountAtom)
  // Write only — doesn't subscribe to value, no re-render on change
  const reset = useSetAtom(resetFiltersAtom)

  return (
    <div>
      <select
        value={filters.status}
        onChange={(e) => setFilters((prev) => ({ ...prev, status: e.target.value as any }))}
      >
        <option value="all">All</option>
        <option value="pending">Pending</option>
        <option value="shipped">Shipped</option>
      </select>

      {activeCount > 0 && (
        <button onClick={reset}>Clear filters ({activeCount})</button>
      )}
    </div>
  )
}
```

---

## Async atoms

```typescript
import { atom } from 'jotai'
import { loadable } from 'jotai/utils'

// Async atom — causes Suspense
export const userProfileAtom = atom(async (get) => {
  const userId = get(selectedUserIdAtom)
  if (!userId) return null
  const res = await fetch(`/api/users/${userId}`)
  return res.json() as Promise<User>
})

// Loadable variant — no Suspense needed, returns { state, data, error }
export const loadableUserAtom = loadable(userProfileAtom)
```

```tsx
// With Suspense
import { Suspense } from 'react'
import { useAtomValue } from 'jotai'
import { userProfileAtom } from '../atoms'

function UserProfile() {
  const user = useAtomValue(userProfileAtom)   // suspends while loading
  if (!user) return <EmptyState />
  return <div>{user.name}</div>
}

export function UserSection() {
  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile />
    </Suspense>
  )
}

// With loadable — no Suspense
function UserProfileSafe() {
  const state = useAtomValue(loadableUserAtom)

  if (state.state === 'loading') return <Skeleton />
  if (state.state === 'hasError') return <ErrorState error={state.error} />
  if (!state.data) return <EmptyState />
  return <div>{state.data.name}</div>
}
```

---

## Server data with jotai-tanstack-query

```bash
npm install jotai-tanstack-query @tanstack/react-query
```

```typescript
// Preferred for server data — handles caching, loading, error, refetching
import { atomWithQuery, atomWithMutation } from 'jotai-tanstack-query'

export const ordersQueryAtom = atomWithQuery((get) => ({
  queryKey: ['orders', get(orderFiltersAtom)],
  queryFn:  async ({ queryKey: [, filters] }) => {
    const res = await fetch('/api/orders?' + new URLSearchParams(filters as any))
    return res.json()
  },
}))

export const createOrderMutationAtom = atomWithMutation(() => ({
  mutationFn: (data: CreateOrderInput) =>
    fetch('/api/orders', { method: 'POST', body: JSON.stringify(data) }).then((r) => r.json()),
}))
```

---

## atomFamily — per-item state

```typescript
import { atomFamily } from 'jotai/utils'

// Per-order editing state
export const orderEditModeAtomFamily = atomFamily(
  (_orderId: string) => atom(false)
)

// Per-item selection in a list
export const itemSelectedAtomFamily = atomFamily(
  (_itemId: string) => atom(false),
  (a, b) => a === b   // equality check for the key
)

// Usage
function OrderRow({ order }: { order: Order }) {
  const [isEditing, setIsEditing] = useAtom(orderEditModeAtomFamily(order.id))

  return (
    <div>
      {isEditing ? <EditForm order={order} /> : <OrderDisplay order={order} />}
      <button onClick={() => setIsEditing((e) => !e)}>
        {isEditing ? 'Cancel' : 'Edit'}
      </button>
    </div>
  )
}

// Clean up when item is removed
function useRemoveOrder(orderId: string) {
  return () => {
    orderEditModeAtomFamily.remove(orderId)
    itemSelectedAtomFamily.remove(orderId)
  }
}
```

---

## Atom effects (side effects)

```typescript
import { atomWithStorage, atomWithReset, RESET } from 'jotai/utils'

// Persist to localStorage automatically
export const darkModeAtom = atomWithStorage('darkMode', false)

// Atom with reset capability
export const searchQueryAtom = atomWithReset('')

// Usage: set(searchQueryAtom, RESET) resets to default
```

---

## Testing

```typescript
// src/features/orders/__tests__/OrderFilters.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createStore, Provider } from 'jotai'
import { orderFiltersAtom } from '../atoms/orders.atoms'
import { OrderFilters } from '../components/OrderFilters'

function renderWithStore(ui: React.ReactElement, initialValues?: Parameters<ReturnType<typeof createStore>['set']>[]) {
  const store = createStore()
  initialValues?.forEach(([atom, value]) => store.set(atom, value))

  return {
    store,
    ...render(<Provider store={store}>{ui}</Provider>),
  }
}

test('shows filter count badge when filters are active', async () => {
  const { store } = renderWithStore(<OrderFilters />, [
    [orderFiltersAtom, { status: 'pending', dateRange: null }],
  ])

  expect(screen.getByText('Clear filters (1)')).toBeInTheDocument()
})

test('resets filters on button click', async () => {
  const { store } = renderWithStore(<OrderFilters />, [
    [orderFiltersAtom, { status: 'shipped', dateRange: null }],
  ])

  await userEvent.click(screen.getByRole('button', { name: /clear filters/i }))

  expect(store.get(orderFiltersAtom).status).toBe('all')
})
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Creating atoms inside components | Module-level only — atoms inside components are recreated on every render |
| Storing derived data in a primitive atom | Use `atom(get => ...)` — computed atoms stay in sync automatically |
| Server state in primitive atoms | Use `atomWithQuery` (jotai-tanstack-query) — handles caching and revalidation |
| Not using `useSetAtom` for write-only | `useAtom` subscribes to the value — `useSetAtom` avoids unnecessary re-renders |
| No `atomFamily.remove()` on item deletion | Memory leak — atoms persist after the item is gone |
| Async atoms without Suspense or loadable | The component will suspend indefinitely — wrap in Suspense or use `loadable()` |
