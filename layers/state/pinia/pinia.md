# Pinia Standards

---

## Setup

```bash
npm install pinia
```

```typescript
// src/main.ts
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'

const pinia = createPinia()
const app   = createApp(App)

app.use(pinia)
app.mount('#app')
```

---

## Store definition — Composition API style

```typescript
// src/stores/orders.store.ts
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { ordersApi } from '@/api/orders'
import type { Order, OrderFilters } from '@/types'

export const useOrdersStore = defineStore('orders', () => {
  // ── State ──────────────────────────────────────────────────────────────────
  const orders          = ref<Order[]>([])
  const selectedOrderId = ref<string | null>(null)
  const isLoading       = ref(false)
  const error           = ref<string | null>(null)
  const filters         = ref<OrderFilters>({
    status:    'all',
    dateRange: null,
  })

  // ── Getters (computed) ─────────────────────────────────────────────────────
  const selectedOrder = computed(
    () => orders.value.find((o) => o.id === selectedOrderId.value) ?? null
  )

  const filteredOrders = computed(() => {
    if (filters.value.status === 'all') return orders.value
    return orders.value.filter((o) => o.status === filters.value.status)
  })

  const pendingCount = computed(
    () => orders.value.filter((o) => o.status === 'pending').length
  )

  // ── Actions ────────────────────────────────────────────────────────────────
  async function fetchOrders() {
    isLoading.value = true
    error.value     = null
    try {
      orders.value = await ordersApi.list(filters.value)
    } catch (err) {
      error.value = (err as Error).message
    } finally {
      isLoading.value = false
    }
  }

  async function cancelOrder(id: string) {
    const order = orders.value.find((o) => o.id === id)
    if (!order || order.status !== 'pending') return

    try {
      await ordersApi.cancel(id)
      // Update state after success
      const idx = orders.value.findIndex((o) => o.id === id)
      if (idx !== -1) orders.value[idx] = { ...orders.value[idx], status: 'cancelled' }
    } catch (err) {
      error.value = `Failed to cancel order: ${(err as Error).message}`
      throw err   // re-throw so the component can show an error
    }
  }

  function selectOrder(id: string | null) {
    selectedOrderId.value = id
  }

  function setFilters(newFilters: Partial<OrderFilters>) {
    filters.value = { ...filters.value, ...newFilters }
  }

  function resetFilters() {
    filters.value = { status: 'all', dateRange: null }
  }

  // ── Return everything ──────────────────────────────────────────────────────
  return {
    // State (as refs — reactive in templates)
    orders,
    selectedOrderId,
    isLoading,
    error,
    filters,
    // Getters (computed)
    selectedOrder,
    filteredOrders,
    pendingCount,
    // Actions
    fetchOrders,
    cancelOrder,
    selectOrder,
    setFilters,
    resetFilters,
  }
})
```

---

## Using stores in components

```vue
<script setup lang="ts">
import { onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useOrdersStore } from '@/stores/orders.store'

const store = useOrdersStore()

// ✅ storeToRefs — destructure reactive state and getters
// (plain destructure breaks reactivity)
const { orders, filteredOrders, isLoading, error, selectedOrder } = storeToRefs(store)

// ✅ Actions are functions — destructure directly (no reactivity needed)
const { fetchOrders, cancelOrder, selectOrder, setFilters } = store

onMounted(() => {
  fetchOrders()
})
</script>

<template>
  <div>
    <div v-if="isLoading">Loading…</div>
    <div v-else-if="error">{{ error }}</div>
    <ul v-else>
      <li
        v-for="order in filteredOrders"
        :key="order.id"
        @click="selectOrder(order.id)"
      >
        {{ order.id }} — {{ order.status }}
      </li>
    </ul>

    <OrderDetail v-if="selectedOrder" :order="selectedOrder" @cancel="cancelOrder" />
  </div>
</template>
```

---

## Accessing one store from another

```typescript
// src/stores/cart.store.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useCartStore = defineStore('cart', () => {
  const items = ref<CartItem[]>([])

  async function checkout() {
    // ✅ Call other stores inside actions — not at module level
    const userStore = useUserStore()

    if (!userStore.isAuthenticated) {
      throw new Error('Must be logged in to checkout')
    }

    await ordersApi.create({ items: items.value, userId: userStore.user.id })
    items.value = []   // clear cart after successful checkout
  }

  return { items, checkout }
})
```

---

## $patch — batch updates

```typescript
// Multiple state changes — use $patch to batch (single watcher trigger)
store.$patch({
  isLoading:       false,
  error:           null,
  selectedOrderId: null,
})

// $patch with a function (for complex mutations)
store.$patch((state) => {
  state.orders.push(...newOrders)
  state.isLoading = false
})
```

---

## $subscribe — watch state changes

```typescript
// Watch specific store changes (e.g., persist to localStorage)
const store = useOrdersStore()

store.$subscribe((_mutation, state) => {
  localStorage.setItem('order-filters', JSON.stringify(state.filters))
}, { detached: true })   // detached: survives component unmount

// Restore on init
const saved = localStorage.getItem('order-filters')
if (saved) store.setFilters(JSON.parse(saved))
```

---

## Store with persist plugin

```bash
npm install pinia-plugin-persistedstate
```

```typescript
// src/main.ts
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)

// In store
export const usePreferencesStore = defineStore('preferences', () => {
  const darkMode  = ref(false)
  const language  = ref<'en' | 'fr' | 'de'>('en')

  return { darkMode, language }
}, {
  persist: {
    storage:  localStorage,
    pick:     ['darkMode', 'language'],   // persist only these fields
  },
})
```

---

## Testing

```typescript
// src/stores/__tests__/orders.store.test.ts
import { setActivePinia, createPinia } from 'pinia'
import { useOrdersStore } from '../orders.store'
import { ordersApi } from '@/api/orders'

// Mock the API
vi.mock('@/api/orders')

beforeEach(() => {
  // Creates a fresh Pinia for each test — no shared state
  setActivePinia(createPinia())
})

test('fetchOrders populates orders', async () => {
  const mockOrders = [{ id: '1', status: 'pending', total: 49.99 }]
  vi.mocked(ordersApi.list).mockResolvedValue(mockOrders)

  const store = useOrdersStore()
  await store.fetchOrders()

  expect(store.orders).toEqual(mockOrders)
  expect(store.isLoading).toBe(false)
})

test('cancelOrder updates order status', async () => {
  const store = useOrdersStore()
  // Set initial state directly
  store.orders = [{ id: '1', status: 'pending', total: 49.99 }]

  vi.mocked(ordersApi.cancel).mockResolvedValue(undefined)

  await store.cancelOrder('1')

  expect(store.orders[0].status).toBe('cancelled')
})

test('filteredOrders respects status filter', () => {
  const store = useOrdersStore()
  store.orders = [
    { id: '1', status: 'pending',  total: 10 },
    { id: '2', status: 'shipped',  total: 20 },
    { id: '3', status: 'pending',  total: 30 },
  ]
  store.setFilters({ status: 'pending' })

  expect(store.filteredOrders).toHaveLength(2)
})
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `const { orders } = store` (plain destructure) | Use `storeToRefs(store)` — plain destructure loses reactivity |
| `useStore()` at module level outside setup | Must be called inside a setup function or plugin with active Pinia |
| Server/API data in Pinia | Use Vue Query (`@tanstack/vue-query`) — it handles caching, loading, refetch |
| Calling `useOtherStore()` at module level | Call inside actions — prevents store initialisation order issues |
| Large monolithic store for all app state | One store per feature/domain |
| No error handling in async actions | Always `try/catch` in async actions; set `error.value` |
