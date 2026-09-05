---
name: redux-toolkit
description: Redux Toolkit conventions — createSlice, RTK Query, store setup, and TypeScript patterns. Load when working with Redux Toolkit.
user-invocable: false
stack: state/redux-toolkit
paths:
  - "**/store/**"
  - "**/slices/**"
  - "**/features/**/slice*"
  - "src/app/store*"
---

Full standards in [redux-toolkit.md](redux-toolkit.md). Always-on summary:

> **Scope — applies only if this project uses redux-toolkit.** This layer shares `**/store/**` with `jotai` in `layers/state/`, so more than one may load at once and their rules conflict. If the project is not using redux-toolkit, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Store structure:**
- Co-locate slices with their feature: `src/features/orders/orders.slice.ts`
- One slice per feature/domain — not one giant slice
- Global state only for truly shared data; prefer component state or React Query for server state

**Slices:**
- Use `createSlice(` with a `reducers:` key for action handlers — not hand-written reducers/actions
- State mutations via Immer are allowed inside `createSlice` — `state.count++` is fine
- Selectors live alongside slices: `export const selectOrderById = ...`

**Async / RTK Query:**
- **RTK Query** for all data fetching — use `createApi(` with `endpoints:` key; handles caching, loading states, and invalidation automatically
- For one-off async operations not involving server data, use RTK's async thunk pattern (prefer RTK Query first)
- RTK Query handles caching, re-fetching, loading states, and invalidation automatically

**TypeScript:**
- Use `RootState` and `AppDispatch` from the store — never `any`
- Define and use `useAppDispatch(` and `useAppSelector(` typed hooks everywhere — not raw `useDispatch`/`useSelector`

**Never:**
- Mutate state outside of `createSlice` reducers — use `setState` pattern or RTK
- Put derived data in state — use `createSelector` (memoised selectors)
- Put server state in Redux if using RTK Query — that's RTK Query's job

**Related skills:** Your frontend layer (React hooks, component patterns), `mocking/msw` (mock RTK Query endpoints in tests)
