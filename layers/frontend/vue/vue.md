# Vue 3 Standards

---

## Component structure (SFC)

```vue
<!-- src/components/orders/OrderCard.vue -->
<script setup lang="ts">
import { computed } from 'vue'
import { useOrderActions } from '@/composables/useOrderActions'
import type { Order } from '@/types'

// ── Props ─────────────────────────────────────────────────────────────────────
const props = defineProps<{
  order:    Order
  selected?: boolean
}>()

// ── Emits ─────────────────────────────────────────────────────────────────────
const emit = defineEmits<{
  (e: 'select', orderId: string): void
  (e: 'cancel', orderId: string): void
}>()

// ── Composables ───────────────────────────────────────────────────────────────
const { cancelOrder, isLoading } = useOrderActions()

// ── Computed ──────────────────────────────────────────────────────────────────
const statusLabel = computed(() => ({
  pending:   'Pending',
  shipped:   'Shipped',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
}[props.order.status] ?? props.order.status))

const canCancel = computed(
  () => props.order.status === 'pending' && !isLoading.value
)

// ── Methods ───────────────────────────────────────────────────────────────────
async function handleCancel() {
  await cancelOrder(props.order.id)
  emit('cancel', props.order.id)
}
</script>

<template>
  <article
    class="order-card"
    :class="{ 'order-card--selected': selected }"
    @click="emit('select', order.id)"
  >
    <header class="order-card__header">
      <h3>Order #{{ order.id }}</h3>
      <span class="order-card__status">{{ statusLabel }}</span>
    </header>

    <p>${{ order.total.toFixed(2) }}</p>

    <button
      v-if="canCancel"
      :disabled="isLoading"
      @click.stop="handleCancel"
    >
      {{ isLoading ? 'Cancelling…' : 'Cancel' }}
    </button>
  </article>
</template>

<style scoped>
.order-card {
  padding: 1rem;
  border: 1px solid var(--color-border);
  border-radius: 0.5rem;
  cursor: pointer;
  transition: border-color 0.15s;
}
.order-card--selected { border-color: var(--color-primary); }
.order-card__header   { display: flex; justify-content: space-between; }
</style>
```

---

## Reactivity — ref vs reactive

```typescript
import { ref, reactive, computed, watch, watchEffect } from 'vue'

// ── ref — primitives and single values ────────────────────────────────────────
const count   = ref(0)
const message = ref('')
const user    = ref<User | null>(null)

// Access via .value in <script>; auto-unwrapped in <template>
count.value++
console.log(count.value)

// ── reactive — objects (caution: destructuring breaks reactivity) ──────────────
const form = reactive({
  email:    '',
  password: '',
})
form.email = 'user@example.com'   // ✅ reactive
// const { email } = form          // ❌ breaks reactivity — use toRefs() instead

// If you need to destructure, use toRefs
import { toRefs } from 'vue'
const { email, password } = toRefs(form)   // ✅ still reactive

// ── computed — derived state ───────────────────────────────────────────────────
const fullName = computed(() => `${user.value?.firstName} ${user.value?.lastName}`)
const isValid  = computed(() => form.email.includes('@') && form.password.length >= 8)

// ── watch — explicit source, access to old value ──────────────────────────────
watch(
  () => user.value?.id,
  (newId, oldId) => {
    if (newId && newId !== oldId) {
      fetchUserProfile(newId)
    }
  },
  { immediate: true }
)

// ── watchEffect — auto-tracks dependencies ────────────────────────────────────
watchEffect(() => {
  if (count.value > 10) {
    console.log('Count exceeded 10')
  }
})
```

---

## Composables

```typescript
// src/composables/useOrderActions.ts
import { ref } from 'vue'
import { ordersApi } from '@/api/orders'

export function useOrderActions() {
  const isLoading = ref(false)
  const error     = ref<string | null>(null)

  async function cancelOrder(id: string) {
    isLoading.value = true
    error.value     = null
    try {
      await ordersApi.cancel(id)
    } catch (err) {
      error.value = (err as Error).message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  return { cancelOrder, isLoading, error }
}
```

```typescript
// src/composables/useOrders.ts — composable that calls another composable
import { ref, computed } from 'vue'
import { useQuery } from '@tanstack/vue-query'
import type { OrderFilters } from '@/types'

export function useOrders(filters: Ref<OrderFilters>) {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey:  computed(() => ['orders', filters.value]),
    queryFn:   () => ordersApi.list(filters.value),
    staleTime: 30_000,
  })

  const pendingOrders = computed(
    () => data.value?.filter((o) => o.status === 'pending') ?? []
  )

  return { data, isLoading, error, refetch, pendingOrders }
}
```

---

## Props and v-model

```vue
<!-- Parent -->
<SearchInput v-model="searchQuery" />
<SearchInput v-model:query="searchQuery" v-model:loading="isSearching" />

<!-- SearchInput.vue — single v-model -->
<script setup lang="ts">
const props = defineProps<{
  modelValue: string
}>()
const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
}>()
</script>
<template>
  <input
    :value="modelValue"
    @input="emit('update:modelValue', ($event.target as HTMLInputElement).value)"
  />
</template>
```

```vue
<!-- Multiple v-model bindings -->
<script setup lang="ts">
const props = defineProps<{
  query:   string
  loading: boolean
}>()
const emit = defineEmits<{
  (e: 'update:query',   value: string):  void
  (e: 'update:loading', value: boolean): void
}>()
</script>
```

---

## Slots

```vue
<!-- Card.vue — generic card with named slots -->
<template>
  <div class="card">
    <header v-if="$slots.header" class="card__header">
      <slot name="header" />
    </header>
    <div class="card__body">
      <slot />   <!-- default slot -->
    </div>
    <footer v-if="$slots.footer" class="card__footer">
      <slot name="footer" />
    </footer>
  </div>
</template>

<!-- Scoped slot — passes data to parent -->
<template>
  <ul>
    <li v-for="item in items" :key="item.id">
      <slot :item="item" :index="index" />
    </li>
  </ul>
</template>

<!-- Usage -->
<Card>
  <template #header>Order Details</template>
  <p>Body content</p>
  <template #footer>
    <button>Save</button>
  </template>
</Card>
```

---

## Template directives

```vue
<template>
  <!-- v-if / v-else-if / v-else -->
  <div v-if="status === 'loading'">Loading…</div>
  <div v-else-if="status === 'error'">Error: {{ errorMessage }}</div>
  <div v-else>Content</div>

  <!-- v-for — always use :key; prefer stable IDs over array index -->
  <ul>
    <li v-for="order in orders" :key="order.id">
      {{ order.status }}
    </li>
  </ul>

  <!-- v-if + v-for — use <template> to avoid same-element conflict -->
  <template v-for="order in orders" :key="order.id">
    <li v-if="order.status !== 'cancelled'">{{ order.id }}</li>
  </template>

  <!-- v-show — hides with CSS (keeps DOM); use for frequently toggled elements -->
  <div v-show="isMenuOpen">Menu</div>

  <!-- v-bind shorthand and object spread -->
  <Button v-bind="buttonProps" :disabled="isLoading" />

  <!-- Event modifiers -->
  <form @submit.prevent="handleSubmit">
  <a @click.stop.prevent="handleClick">
  <input @keyup.enter="search" />
</template>
```

---

## Provide / Inject (dependency injection)

```typescript
// Parent — provide.ts (or in setup)
import { provide, ref } from 'vue'
import type { InjectionKey } from 'vue'

export interface UserContext {
  user:   Ref<User | null>
  logout: () => void
}

export const UserContextKey: InjectionKey<UserContext> = Symbol('user-context')

// In a parent component or plugin
provide(UserContextKey, {
  user:   ref(currentUser),
  logout: () => { /* ... */ },
})
```

```typescript
// Child — inject with type safety
import { inject } from 'vue'
import { UserContextKey } from '@/keys'

const context = inject(UserContextKey)
if (!context) throw new Error('UserContextKey not provided')

const { user, logout } = context
```

---

## defineExpose (expose to parent via template ref)

```vue
<script setup lang="ts">
import { ref } from 'vue'

const inputRef = ref<HTMLInputElement | null>(null)

function focus() {
  inputRef.value?.focus()
}

// Expose methods to parent
defineExpose({ focus })
</script>
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `reactive()` followed by destructuring | Use `ref()` or `toRefs(reactive(...))` to preserve reactivity |
| Mutating props directly | Emit an event or use `v-model` |
| `v-if` and `v-for` on the same element | Wrap in `<template>` — `v-if` evaluates first, which may not be what you want |
| Options API `this` in Composition API | Composition API has no `this` — access everything from setup scope |
| Array index as `:key` in mutable lists | Use stable IDs — index causes DOM thrashing when items are reordered |
| Logic directly in `<script setup>` that belongs in a composable | Extract to `use*` composables — keeps setup readable and code reusable |
| `computed()` that has side effects | Computed is for derived state only — use `watch` or `watchEffect` for side effects |
