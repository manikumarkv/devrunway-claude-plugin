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
- Always select only what you need: `useStore(s => s.user)` — never subscribe to the whole store (re-renders on every change)

**Mutations:**
- Never mutate state directly — use `set(prev => ({ ...prev, field: newVal }))` or Immer
- `immer` middleware for deeply nested state updates
- Always implement a `reset:` action that restores `initialState`

**Middleware stack (dev only):** `devtools(persist(immer(store), { partialize }))`

**Persistence:** `partialize` to save only what needs to survive reload — never persist derived state

**Testing:** import store factory via `zustand/vanilla`, not the hook, for unit tests
