---
name: zustand-state
description: Zustand state management patterns — store structure, slice conventions, selectors, devtools, persistence. Load when working with Zustand stores.
user-invocable: false
stack: state/zustand
paths:
  - "src/store/**"
  - "src/stores/**"
  - "**/*.store.ts"
---

Full standards in [zustand-state.md](zustand-state.md). Always-on summary:

**Store structure:**
- One store per domain: `useAuthStore`, `useCartStore`, `useUIStore` — not one mega store
- File: `src/store/auth.store.ts` — export the hook directly
- Actions live inside the store definition alongside state

**Selectors:**
- Always select only what you need: `const user = useAuthStore(s => s.user)`
- Never `const store = useAuthStore()` — it re-renders on any state change

**Mutations:**
- Never mutate state directly — use `set(state => ({ ...state, field: newVal }))`
- `immer` middleware for deeply nested state updates
- Always implement a `reset()` action returning to `initialState`

**Middleware stack (dev only):** `devtools(persist(immer(store), { partialize }))`

**Persistence:** `partialize` to save only what needs to survive reload — never persist derived state

**Testing:** import store factory via `zustand/vanilla`, not the hook, for unit tests
