---
name: pinia
description: Pinia state standards — store definition, composition stores, actions, getters, and testing. Load when working with Pinia (Vue state management).
user-invocable: false
stack: state/pinia
paths:
  - "**/stores/**"
  - "**/*.store.ts"
  - "**/pinia*"
---

Full standards in [pinia.md](pinia.md). Always-on summary:

**Store definition:**
- Use the Composition API style (`defineStore(id, () => { ... })`) — more flexible and better TypeScript inference than Options API style
- Name stores with a noun: `useOrdersStore`, `useUserStore`, `useCartStore`
- One store per feature/domain — not one giant store
- Export the store from a dedicated file: `src/stores/orders.store.ts`

**State, Getters, Actions:**
- State: `const count = ref(0)` — reactive refs inside the setup function
- Getters: `const doubled = computed(() => count.value * 2)` — computed inside setup
- Actions: `function increment() { count.value++ }` — plain functions, can be async
- Return everything from the setup function — Pinia requires explicit exports

**Async actions:**
- Async actions are plain `async` functions — no special handling needed
- Always handle errors in actions — the calling component should not need to know about API details
- Use `$patch` for batch state updates to avoid multiple watchers firing

**Accessing other stores:**
- Call `useOtherStore()` inside an action — not at the module level (avoids store order issues)

**Testing:**
- Use `setActivePinia(createPinia())` in `beforeEach` to create an isolated Pinia per test
- You can set state directly: `store.count = 10` — no need for mutations
- Mock API calls in actions with `vi.mock()` or `jest.mock()`

**Never:**
- Access store state in a template without `storeToRefs()` — destructuring breaks reactivity
- Put server state in Pinia if using Vue Query — that's the query library's job
- Call `useStore()` at the module level outside of a component or store — it requires an active Pinia

**Related skills:** `frontend/vue` (Vue 3 Composition API), `api-style/trpc` or data fetching layer
