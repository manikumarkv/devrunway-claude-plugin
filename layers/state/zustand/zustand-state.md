# Zustand State Management Standards

## Store structure

One store per domain — never one god store:

```ts
// src/store/auth.store.ts
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'
import { immer } from 'zustand/middleware/immer'

interface AuthState {
  user: User | null
  token: string | null
  isLoading: boolean
}

interface AuthActions {
  setUser: (user: User) => void
  clearUser: () => void
  reset: () => void
}

const initialState: AuthState = {
  user: null,
  token: null,
  isLoading: false,
}

export const useAuthStore = create<AuthState & AuthActions>()(
  devtools(
    persist(
      immer((set) => ({
        ...initialState,

        setUser: (user) =>
          set((state) => {
            state.user = user
          }),

        clearUser: () =>
          set((state) => {
            state.user = null
            state.token = null
          }),

        reset: () => set(initialState),
      })),
      {
        name: 'auth-store',
        partialize: (state) => ({ token: state.token }), // only persist token
      }
    ),
    { name: 'AuthStore' }
  )
)
```

## Selector pattern

Always select the minimum slice — prevents unnecessary re-renders:

```ts
// ✅ Good — re-renders only when user changes
const user = useAuthStore((s) => s.user)

// ❌ Bad — re-renders on any store change
const { user, token, isLoading } = useAuthStore()

// ✅ Good — stable reference for actions (actions never change)
const setUser = useAuthStore((s) => s.setUser)
```

## Derived state

Compute derived state in the selector, not the store:

```ts
// ✅ Derived in selector
const isAdmin = useAuthStore((s) => s.user?.role === 'admin')

// ❌ Don't store derived state
set({ isAdmin: user.role === 'admin' }) // stale if role changes elsewhere
```

## Middleware guidelines

| Middleware | When to use | Notes |
|---|---|---|
| `immer` | Nested state updates | Wrap innermost |
| `persist` | State must survive page reload | Use `partialize` to select what to save |
| `devtools` | Always in development | Wrap outermost; strip in production |
| `subscribeWithSelector` | Fine-grained subscriptions | Rarely needed — prefer selectors |

Production middleware (no devtools):
```ts
const store = isDev
  ? create(devtools(persist(immer(storeFactory))))
  : create(persist(immer(storeFactory)))
```

## Actions pattern

Actions belong inside the store, not in components or external files:

```ts
// ✅ Actions in store
export const useCartStore = create<CartState & CartActions>()(
  immer((set, get) => ({
    items: [],

    addItem: (item) =>
      set((state) => {
        const existing = state.items.find((i) => i.id === item.id)
        if (existing) {
          existing.quantity += 1
        } else {
          state.items.push({ ...item, quantity: 1 })
        }
      }),

    removeItem: (id) =>
      set((state) => {
        state.items = state.items.filter((i) => i.id !== id)
      }),

    // Async action — fetch then set
    fetchCart: async () => {
      set((state) => { state.isLoading = true })
      try {
        const cart = await cartApi.get()
        set((state) => { state.items = cart.items; state.isLoading = false })
      } catch (err) {
        set((state) => { state.isLoading = false })
        throw err
      }
    },

    reset: () => set(initialCartState),
  }))
)
```

## Reset pattern

Every store must have a `reset()` action. Call it on logout / route change if needed:

```ts
// Logout handler
const reset = useAuthStore((s) => s.reset)
const resetCart = useCartStore((s) => s.reset)

const handleLogout = () => {
  reset()
  resetCart()
  router.push('/login')
}
```

## Persistence — `partialize`

Only persist what truly needs to survive a page reload:

```ts
persist(storeFactory, {
  name: 'user-prefs',
  // Only persist theme and language — not session data
  partialize: (state) => ({
    theme: state.theme,
    language: state.language,
  }),
})
```

Never persist: tokens in localStorage if you can use httpOnly cookies, large data sets, derived state, UI loading flags.

## Anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| `useStore()` with no selector | Re-renders on every change | `useStore(s => s.field)` |
| Mutating state directly | Bypasses reactivity | Use `set()` or `immer` |
| Logic outside the store | Hard to test | Move async logic into store actions |
| Persisting everything | Stale data, security risk | Use `partialize` |
| One huge store | Unrelated re-renders | Split by domain |

## Testing

Use `zustand/vanilla` to test stores without React:

```ts
import { createStore } from 'zustand/vanilla'

// Create a fresh store for each test
const store = createStore<AuthState & AuthActions>()(
  immer((set) => ({
    ...initialState,
    setUser: (user) => set((s) => { s.user = user }),
    reset: () => set(initialState),
  }))
)

test('setUser updates state', () => {
  store.getState().setUser({ id: '1', name: 'Alice', role: 'user' })
  expect(store.getState().user?.name).toBe('Alice')
})

test('reset clears state', () => {
  store.getState().setUser({ id: '1', name: 'Alice', role: 'user' })
  store.getState().reset()
  expect(store.getState().user).toBeNull()
})
```
