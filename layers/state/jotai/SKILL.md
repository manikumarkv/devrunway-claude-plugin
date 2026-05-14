---
name: jotai
description: Jotai state standards — atom definition, derived atoms, async atoms, atomFamily, and testing patterns. Load when working with Jotai.
user-invocable: false
stack: state/jotai
paths:
  - "**/atoms/**"
  - "**/*.atom.ts"
  - "**/store/**"
  - "**/jotai*"
---

Full standards in [jotai.md](jotai.md). Always-on summary:

**Atom definition:**
- Define atoms in dedicated `atoms/` directories, co-located with their feature
- Name primitive atoms as nouns: `selectedOrderIdAtom`, `darkModeAtom`
- Name derived atoms as computed descriptions: `filteredOrdersAtom`, `totalPriceAtom`
- Export atoms — never create atoms inside components (re-created on every render)

**Derived atoms:**
- Use `atom(get => get(otherAtom))` for computed state — never store derived data in a primitive atom
- Derived atoms are always synchronous unless they return a Promise
- Writable derived atoms use `atom(get => ..., (get, set, value) => ...)` — keep setter logic simple

**Async atoms:**
- Async atoms return a Promise or use `loadable()` to avoid suspense
- Always wrap async atom usage in `<Suspense>` or use `loadable(atom)` for loading state
- Use `atomWithQuery` from `jotai-tanstack-query` for server data — not raw async atoms

**atomFamily:**
- Use `atomFamily` for per-ID state (e.g., per-item selection, per-row edit mode)
- Pass a serialisable key to `atomFamily` — strings or numbers, not objects
- Call `atomFamily.remove(param)` to clean up atoms when the item is removed

**Testing:**
- Use `createStore()` from jotai for isolated test stores
- Wrap the component under test in `<Provider store={store}>` with your test store
- Set initial atom values with `store.set(atom, value)` before rendering

**Never:**
- Create atoms inside React components — they lose their value on unmount
- Put server state (API data) in primitive atoms — use React Query / jotai-tanstack-query
- Use atoms as a global event bus — use atom effects or custom hooks instead

**Related skills:** `state/redux-toolkit` (heavier alternative for large apps), `frontend/react` (React hooks patterns)
