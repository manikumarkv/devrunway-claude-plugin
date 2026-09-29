# React Best Practices

Source: Vercel Engineering agent-skills (adapted for React without Next.js)

---

## UI components — use the project's library

Use the component library the project already has: check `package.json` and the existing components folder before writing any UI.

- **Never hand-roll** a button, input, select, dialog, table, badge or toast when the project's library provides one. Wrap library primitives in domain components instead of rebuilding them.
- **Library-specific rules live in their own layers**, which load alongside this one: `ui-components/shadcn` (shadcn/ui), `ui-components/mui` (MUI), `ui-components/chakra` (Chakra UI), `ui-components/ant-design` (Ant Design).
- **No library yet?** Ask before adding one; don't pick a library on the project's behalf.
- Code samples in this file use plain JSX or shadcn-style imports for illustration. Translate them to the project's library.

---

## Constants — single source of truth

All application-wide values live in `src/lib/constants.ts`. Never hard-code a magic value inline — any number, string, or config value used in more than one place belongs here.

```ts
// src/lib/constants.ts

// ─── Pagination ────────────────────────────────────────────────────────────────
export const DEFAULT_PAGE_SIZE    = 20
export const MAX_PAGE_SIZE        = 100

// ─── Upload limits ─────────────────────────────────────────────────────────────
export const MAX_UPLOAD_SIZE_MB   = 10
export const MAX_UPLOAD_SIZE_B    = MAX_UPLOAD_SIZE_MB * 1024 * 1024
export const ACCEPTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const

// ─── Timing ────────────────────────────────────────────────────────────────────
export const DEBOUNCE_MS          = 300       // search input debounce delay
export const TOAST_DURATION_MS    = 4000      // snackbar auto-dismiss
export const FLAG_POLL_MS         = 30_000    // feature flag refetch interval

// ─── Auth ──────────────────────────────────────────────────────────────────────
export const TOKEN_REFRESH_BUFFER_S = 60      // refresh token 60s before expiry

// ─── Localisation ─────────────────────────────────────────────────────────────
export const DEFAULT_LOCALE       = 'en'
export const SUPPORTED_LOCALES    = ['en', 'fr', 'de'] as const
export type  Locale               = typeof SUPPORTED_LOCALES[number]

// ─── App ───────────────────────────────────────────────────────────────────────
export const APP_NAME             = 'MyApp'
```

```tsx
// ❌ — magic numbers scattered across files
const { data } = useQuery({ queryFn: () => fetch('/orders?limit=20') })
setTimeout(callback, 300)

// ✅ — imported from constants
import { DEFAULT_PAGE_SIZE, DEBOUNCE_MS } from '@/lib/constants'
const { data } = useQuery({ queryFn: () => fetch(`/orders?limit=${DEFAULT_PAGE_SIZE}`) })
setTimeout(callback, DEBOUNCE_MS)
```

---

## API routes — single file for all endpoint paths

All API endpoint paths live in `src/lib/api-routes.ts`. Never inline a URL string in a component or hook — import it from here.

```ts
// src/lib/api-routes.ts
const BASE = '/api/v1'

export const API_ROUTES = {
  health:  '/health',
  flags:   `${BASE}/flags`,
  me:      `${BASE}/me`,
  meDataExport: `${BASE}/me/data-export`,

  orders: {
    list:   `${BASE}/orders`,
    create: `${BASE}/orders`,
    get:    (id: string) => `${BASE}/orders/${id}`,
    update: (id: string) => `${BASE}/orders/${id}`,
    delete: (id: string) => `${BASE}/orders/${id}`,
    items:  (id: string) => `${BASE}/orders/${id}/items`,
  },

  users: {
    list:   `${BASE}/users`,
    get:    (id: string) => `${BASE}/users/${id}`,
  },
} as const
```

```ts
// src/features/orders/api/orders.api.ts
import { useQuery, useMutation } from '@tanstack/react-query'
import { API_ROUTES } from '@/lib/api-routes'
import { api } from '@/lib/api'

// ❌ — URL hardcoded inline
export function useOrders() {
  return useQuery({ queryFn: () => api.get('/api/v1/orders') })
}

// ✅ — imported from api-routes
export function useOrders() {
  return useQuery({
    queryKey: ['orders'],
    queryFn:  () => api.get(API_ROUTES.orders.list),
  })
}

export function useOrder(id: string) {
  return useQuery({
    queryKey: ['orders', id],
    queryFn:  () => api.get(API_ROUTES.orders.get(id)),
    enabled:  !!id,
  })
}

export function useCreateOrder() {
  return useMutation({
    mutationFn: (data: CreateOrderInput) => api.post(API_ROUTES.orders.create, data),
  })
}
```

---

## Localisation (i18n)

**If the project is localised** (it has an i18n library such as react-i18next, Lingui or FormatJS, or a `locales/` folder), every user-visible string goes through its translation function. Never inline a label in a component. Library rules live in `i18n/react-i18next` and `i18n/lingui`.

**If it isn't localised**, don't introduce i18n unprompted. Still keep user-visible strings out of logic, for example in a constants module, so localising later is a mechanical change.

---

## Re-render optimization — HIGH IMPACT

### Never define components inside components
Every render creates a new component type, causing full unmount/remount of children.
```tsx
// ❌
function Parent() {
  function Child() { return <div /> }  // new type every render
  return <Child />
}

// ✅
function Child() { return <div /> }
function Parent() { return <Child /> }
```

### Extract expensive JSX into memoized components
```tsx
// ❌
function List({ items, theme }) {
  return <ul>{items.map(i => <ExpensiveItem key={i.id} theme={theme} />)}</ul>
}

// ✅
const MemoItem = memo(ExpensiveItem)
function List({ items, theme }) {
  return <ul>{items.map(i => <MemoItem key={i.id} theme={theme} />)}</ul>
}
```

### Hoist static JSX outside components
Static elements re-created every render waste memory and break memoization.
```tsx
// ❌
function Page() {
  const header = <h1>Title</h1>  // new object every render
  return <div>{header}</div>
}

// ✅
const header = <h1>Title</h1>
function Page() { return <div>{header}</div> }
```

### Use functional setState for stable callback references
```tsx
// ❌ — stale closure, forces re-renders on consumers
function Counter() {
  const [count, setCount] = useState(0)
  const increment = useCallback(() => setCount(count + 1), [count])
  return <Button onClick={increment} />
}

// ✅ — stable reference, no count dependency
function Counter() {
  const [count, setCount] = useState(0)
  const increment = useCallback(() => setCount(c => c + 1), [])
  return <Button onClick={increment} />
}
```

### Don't useMemo for simple expressions
`useMemo` has overhead. Only use it for genuinely expensive computations.
```tsx
// ❌
const doubled = useMemo(() => count * 2, [count])

// ✅
const doubled = count * 2
```

### Derive state during render, not in useEffect
```tsx
// ❌ — extra render cycle
const [fullName, setFullName] = useState('')
useEffect(() => setFullName(`${first} ${last}`), [first, last])

// ✅ — calculated inline, zero extra renders
const fullName = `${first} ${last}`
```

### Extract non-primitive default values to constants
Inline objects/arrays are new references every render, breaking memo.
```tsx
// ❌
function Component({ items = [] }) { ... }  // new [] every render

// ✅
const EMPTY: string[] = []
function Component({ items = EMPTY }) { ... }
```

### Use primitive values as useEffect dependencies, not objects
```tsx
// ❌ — user object is new ref every render → infinite loop risk
useEffect(() => { fetch(user) }, [user])

// ✅
useEffect(() => { fetch(userId) }, [user.id])
```

### Don't subscribe to state you only read in callbacks
```tsx
// ❌ — re-renders on every searchParam change
function Component() {
  const [search] = useSearchParams()
  const handleClick = () => doSomething(search)  // only used on click
}

// ✅ — read at event time with a ref
function Component() {
  const searchRef = useRef(search)
  useLayoutEffect(() => { searchRef.current = search })
  const handleClick = () => doSomething(searchRef.current)
}
```

### Mark non-urgent updates with startTransition
```tsx
// ❌ — typing blocks UI
function Search() {
  const [query, setQuery] = useState('')
  return <Input onChange={e => setQuery(e.target.value)} />
}

// ✅ — urgent: update input; deferred: run expensive work
function Search() {
  const [query, setQuery] = useState('')
  const [isPending, startTransition] = useTransition()
  return <Input onChange={e => startTransition(() => setQuery(e.target.value))} />
}
```

### Use useDeferredValue for expensive derived renders
```tsx
// ❌
function Results({ query }) {
  const results = expensiveFilter(query)  // blocks every keystroke
  return <List items={results} />
}

// ✅
function Results({ query }) {
  const deferred = useDeferredValue(query)
  const results = expensiveFilter(deferred)
  return <List items={results} stale={deferred !== query} />
}
```

### Use useRef for values that change often but don't need re-renders
```tsx
// ❌ — causes re-render on every mouse move
const [mouseX, setMouseX] = useState(0)

// ✅
const mouseXRef = useRef(0)
// read mouseXRef.current in callbacks — no re-renders triggered
```

### Put interaction logic in event handlers, not useEffect
```tsx
// ❌
const [submitted, setSubmitted] = useState(false)
useEffect(() => {
  if (submitted) { navigate('/thanks') }
}, [submitted])

// ✅
async function handleSubmit() {
  await submitForm()
  navigate('/thanks')
}
```

### Split hooks that have different dependency cycles
```tsx
// ❌ — font or lang change reruns all logic
function useUserPrefs(userId, font, lang) {
  useEffect(() => { fetchAndApplyAll(userId, font, lang) }, [userId, font, lang])
}

// ✅
function useUserData(userId) {
  useEffect(() => { fetchUser(userId) }, [userId])
}
function useDisplayPrefs(font, lang) {
  useEffect(() => { applyPrefs(font, lang) }, [font, lang])
}
```

---

## Async and data fetching

### Parallelize independent operations
Sequential awaits are the #1 performance killer.
```tsx
// ❌ — sequential: A then B then C
const user = await getUser(id)
const posts = await getPosts(id)
const settings = await getSettings(id)

// ✅ — parallel: ~3× faster
const [user, posts, settings] = await Promise.all([
  getUser(id), getPosts(id), getSettings(id)
])
```

### Defer awaits into branches where actually needed
```tsx
// ❌ — always pays the fetch cost
async function getLabel(id: string) {
  const labels = await fetchLabels()
  return cache.get(id) ?? labels.find(l => l.id === id)?.name
}

// ✅ — only fetches when cache misses
async function getLabel(id: string) {
  if (cache.has(id)) return cache.get(id)
  const labels = await fetchLabels()
  return labels.find(l => l.id === id)?.name
}
```

### Use Suspense boundaries strategically
Show wrapper UI immediately while data loads below.
```tsx
// ✅
function Page() {
  return (
    <>
      <Header />
      <Suspense fallback={<Skeleton />}>
        <DataDependentSection />
      </Suspense>
    </>
  )
}
```

---

## Bundle size

### Avoid barrel file imports — use direct imports
Barrel files force the bundler to include the whole library even when you need one function.
```tsx
// ❌
import { formatDate } from '@/utils'            // pulls in entire utils/

// ✅
import { formatDate } from '@/utils/formatDate' // only what you need
```

### Lazy-load heavy components with React.lazy
```tsx
// ❌ — ChartEditor always in the main bundle
import { ChartEditor } from './ChartEditor'

// ✅
const ChartEditor = lazy(() => import('./ChartEditor'))
function Page() {
  return (
    <Suspense fallback={<Spinner />}>
      <ChartEditor />
    </Suspense>
  )
}
```

### Load large data/modules only when features are activated
```tsx
// ❌ — 2 MB emoji list loaded on startup
import emojiData from 'emoji-data'

// ✅
async function openEmojiPicker() {
  const { default: emojiData } = await import('emoji-data')
  showPicker(emojiData)
}
```

### Preload heavy bundles on user intent
```tsx
function HeavyButton() {
  const preload = () => import('./HeavyModal')  // start loading on hover
  return (
    <Button onMouseEnter={preload} onClick={() => setOpen(true)}>
      Open
    </Button>
  )
}
```

---

## Client-side

### Add `{ passive: true }` to touch and wheel listeners
Without it, the browser waits for your handler before scrolling — causes jank.
```tsx
useEffect(() => {
  el.addEventListener('wheel', handler, { passive: true })
  return () => el.removeEventListener('wheel', handler)
}, [])
```

### Use React Query or SWR — never fetch in useEffect
```tsx
// ❌ — no deduplication, no caching, race conditions
useEffect(() => {
  fetch('/api/user').then(r => r.json()).then(setUser)
}, [])

// ✅
const { data: user, isLoading } = useQuery({
  queryKey: ['user'],
  queryFn: () => fetch('/api/user').then(r => r.json()),
})
```

### Version-prefix localStorage keys and handle errors
```tsx
// ❌
localStorage.setItem('settings', JSON.stringify(data))

// ✅
const KEY = 'v2:user:settings'
try {
  localStorage.setItem(KEY, JSON.stringify({ theme: data.theme }))
} catch { /* storage full or blocked */ }
```

---

## Rendering

### Use ternary instead of && to avoid falsy value bugs
```tsx
// ❌ — renders "0" when count is 0
{count && <Badge count={count} />}

// ✅
{count > 0 ? <Badge count={count} /> : null}
```

### Apply CSS `content-visibility: auto` for long lists
Skips off-screen rendering — up to 10× faster for 1000+ items.
```css
.list-item {
  content-visibility: auto;
  contain-intrinsic-size: auto 80px; /* estimated row height */
}
```

### Wrap animated SVGs in a div for GPU acceleration
```tsx
// ❌ — animates on CPU
<svg style={{ transform: `rotate(${deg}deg)` }} />

// ✅ — GPU-accelerated via compositor
<div style={{ transform: `rotate(${deg}deg)` }}>
  <svg />
</div>
```

---

## JavaScript performance

### Use Map for O(1) lookups instead of array.find()
```ts
// ❌ — O(n) per lookup
const user = users.find(u => u.id === id)

// ✅ — build index once, O(1) lookups
const userMap = new Map(users.map(u => [u.id, u]))
const user = userMap.get(id)
```

### Use Set for membership checks
```ts
// ❌ — O(n)
const isAdmin = adminIds.includes(userId)

// ✅ — O(1)
const adminSet = new Set(adminIds)
const isAdmin = adminSet.has(userId)
```

### Use .flatMap() instead of .map().filter()
```ts
// ❌ — creates intermediate array
const result = items.map(transform).filter(Boolean)

// ✅ — single pass
const result = items.flatMap(i => {
  const r = transform(i)
  return r ? [r] : []
})
```

### Hoist RegExp to module scope — never create in render
```tsx
// ❌ — new RegExp every render
function validate(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
}

// ✅
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
function validate(email: string) { return EMAIL_RE.test(email) }
```

### Combine multiple iterations into one loop
```ts
// ❌ — 3 passes
const result = items
  .filter(i => i.active)
  .map(i => i.name)
  .map(n => n.toUpperCase())

// ✅ — single pass
const result = items.reduce<string[]>((acc, i) => {
  if (i.active) acc.push(i.name.toUpperCase())
  return acc
}, [])
```

### Exit early when result is determined
```ts
// ❌
function findFirst(items: Item[], id: string) {
  let result: Item | undefined
  for (const item of items) {
    if (item.id === id) result = item  // keeps looping
  }
  return result
}

// ✅
function findFirst(items: Item[], id: string) {
  for (const item of items) {
    if (item.id === id) return item  // stops immediately
  }
}
```

### Defer non-critical work with requestIdleCallback
```ts
function handleClick() {
  doImportantThing()
  requestIdleCallback(() => sendAnalytics(event))  // doesn't block
}
```

---

## Advanced patterns

### Module-level initialization guard — not in useEffect
```tsx
// ❌ — runs on every component mount
function App() {
  useEffect(() => { initSDK() }, [])
}

// ✅ — runs once when module loads, regardless of mount count
let initialized = false
if (!initialized) {
  initialized = true
  initSDK()
}
```

### Store event handlers in refs for stable subscriptions
```tsx
// ❌ — re-subscribes on every render because onMessage changes
useEffect(() => {
  socket.on('message', onMessage)
  return () => socket.off('message', onMessage)
}, [onMessage])

// ✅ — subscribes once, always calls latest handler
const handlerRef = useRef(onMessage)
useLayoutEffect(() => { handlerRef.current = onMessage })
useEffect(() => {
  const handler = (...args: unknown[]) => handlerRef.current(...args)
  socket.on('message', handler)
  return () => socket.off('message', handler)
}, [])
```

---

## URL accessibility — deep linking

Every meaningful view must have a unique, bookmarkable URL. Users must be able to share, bookmark, and navigate back to any feature state via the browser address bar. The URL is the source of truth for all navigational and list state — not component state.

### URL structure — RESTful page routes

```
/                              ← dashboard / home
/orders                        ← list (filterable, sortable, paginated via search params)
/orders/new                    ← create form (dedicated page — not a modal)
/orders/:id                    ← detail / view
/orders/:id/edit               ← edit form (dedicated page — not a modal)
/orders/:id/items              ← nested resource list
/orders/:id/items/:itemId      ← nested resource detail
/profile                       ← current user settings
/profile/security              ← sub-section via nested route
```

Define routes in `src/router/index.tsx`:

```tsx
import { createBrowserRouter } from 'react-router-dom'
import { ProtectedLayout } from '@/shared/components/ProtectedLayout'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <ProtectedLayout />,        // auth guard wraps all children
    children: [
      { index: true,              element: <DashboardPage /> },
      { path: 'orders',           element: <OrdersPage /> },
      { path: 'orders/new',       element: <CreateOrderPage /> },
      { path: 'orders/:id',       element: <OrderDetailPage /> },
      { path: 'orders/:id/edit',  element: <EditOrderPage /> },
    ],
  },
  { path: '/login',  element: <LoginPage /> },
  { path: '*',       element: <NotFoundPage /> },
])
```

### URL search params — list state

All list state (filters, search query, sort, pagination cursor) lives in the URL. Never store it in `useState`.

```tsx
// ❌ — state is lost on refresh, can't be shared or bookmarked
const [status, setStatus] = useState('PENDING')
const [search, setSearch] = useState('')
const [sortBy, setSortBy] = useState('createdAt')

// ✅ — URL is the source of truth
import { useSearchParams } from 'react-router-dom'

function OrdersPage() {
  const [searchParams, setSearchParams] = useSearchParams()

  const status  = searchParams.get('status') ?? 'all'
  const search  = searchParams.get('q') ?? ''
  const sortBy  = searchParams.get('sort') ?? 'createdAt'
  const cursor  = searchParams.get('cursor') ?? undefined

  function setFilter(key: string, value: string) {
    setSearchParams(prev => {
      const next = new URLSearchParams(prev)
      if (value) next.set(key, value)
      else next.delete(key)
      next.delete('cursor')   // reset pagination on filter change
      return next
    })
  }

  const { data } = useQuery({
    queryKey: ['orders', { status, search, sortBy, cursor }],
    queryFn: () => fetchOrders({ status, search, sortBy, cursor }),
  })

  return (
    <>
      <Input
        value={search}
        onChange={e => setFilter('q', e.target.value)}
        placeholder="Search orders…"
      />
      <Select value={status} onValueChange={v => setFilter('status', v)}>
        <SelectTrigger><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All</SelectItem>
          <SelectItem value="PENDING">Pending</SelectItem>
          <SelectItem value="SHIPPED">Shipped</SelectItem>
        </SelectContent>
      </Select>
      {/* list renders here */}
      {data?.meta.nextCursor && (
        <Button onClick={() => setFilter('cursor', data.meta.nextCursor)}>
          Load more
        </Button>
      )}
    </>
  )
}
```

Resulting URL: `/orders?status=PENDING&q=laptop&sort=createdAt&cursor=clxyz`  
Browser back button restores the exact filter state. Shareable link works.

### Tab state in URL

```tsx
// ❌ — tab selection lost on refresh
const [tab, setTab] = useState('details')

// ✅ — tab in URL
import { useSearchParams } from 'react-router-dom'

function OrderDetailPage() {
  const { id } = useParams<{ id: string }>()
  const [searchParams, setSearchParams] = useSearchParams()
  const tab = searchParams.get('tab') ?? 'details'

  return (
    <Tabs value={tab} onValueChange={t => setSearchParams({ tab: t })}>
      <TabsList>
        <TabsTrigger value="details">Details</TabsTrigger>
        <TabsTrigger value="items">Items</TabsTrigger>
        <TabsTrigger value="history">History</TabsTrigger>
      </TabsList>
      <TabsContent value="details"><OrderDetails id={id} /></TabsContent>
      <TabsContent value="items"><OrderItems id={id} /></TabsContent>
      <TabsContent value="history"><OrderHistory id={id} /></TabsContent>
    </Tabs>
  )
}
```

URL: `/orders/clxyz?tab=items` — deep-linkable to a specific tab.

### Navigation — always use Link, never window.location

```tsx
import { Link, useNavigate } from 'react-router-dom'

// ❌
window.location.href = `/orders/${id}`

// ✅ — declarative
<Link to={`/orders/${id}`}>View order</Link>

// ✅ — programmatic (after mutation)
const navigate = useNavigate()
async function handleCreate(values: FormValues) {
  const order = await createOrder(values)
  navigate(`/orders/${order.id}`)      // land on detail page after create
}
```

### useParams — reading route parameters

```tsx
import { useParams } from 'react-router-dom'

function OrderDetailPage() {
  const { id } = useParams<{ id: string }>()

  const { data: order, isLoading } = useQuery({
    queryKey: ['orders', id],
    queryFn: () => fetchOrder(id!),
    enabled: !!id,
  })

  if (isLoading) return <Skeleton />
  if (!order)    return <Navigate to="/orders" replace />

  return <OrderDetail order={order} />
}
```

### Breadcrumbs — reflect URL structure

```tsx
// src/shared/components/Breadcrumb.tsx
import { Link, useMatches } from 'react-router-dom'
import { Breadcrumb, BreadcrumbItem, BreadcrumbLink, BreadcrumbSeparator } from '@/components/ui/breadcrumb'

// Each route declares its breadcrumb label in the handle:
// { path: 'orders/:id', element: <OrderDetailPage />, handle: { breadcrumb: 'Order detail' } }

function AppBreadcrumb() {
  const matches = useMatches()
  const crumbs = matches.filter(m => m.handle?.breadcrumb)

  return (
    <Breadcrumb>
      {crumbs.map((match, i) => (
        <BreadcrumbItem key={match.id}>
          {i < crumbs.length - 1
            ? <BreadcrumbLink asChild><Link to={match.pathname}>{match.handle.breadcrumb}</Link></BreadcrumbLink>
            : <span>{match.handle.breadcrumb}</span>
          }
          {i < crumbs.length - 1 && <BreadcrumbSeparator />}
        </BreadcrumbItem>
      ))}
    </Breadcrumb>
  )
}
```

### URL accessibility checklist

| Rule | Reason |
|---|---|
| Every list has `?filter=&sort=&q=&cursor=` in URL | Shareable filtered views |
| Create form is `/resource/new` not a modal | Bookmarkable, back button works |
| Edit form is `/resource/:id/edit` not a modal | Bookmarkable, refresh-safe |
| Tab selection is `?tab=` in URL | Deep-linkable to a specific tab |
| Browser back button restores previous filter/sort state | `useSearchParams` handles this automatically |
| 404 on unknown routes | `{ path: '*', element: <NotFoundPage /> }` |
| Auth-required routes redirect to `/login?returnTo=<url>` | After login, user lands where they were going |

---

## UI patterns — modals and notifications

### Modals — only for confirmations, never for features

```tsx
// ❌ — opening a create form in a modal breaks the URL, back button, refresh
function OrdersPage() {
  const [showCreate, setShowCreate] = useState(false)
  return (
    <>
      <Button onClick={() => setShowCreate(true)}>New order</Button>
      <Dialog open={showCreate}>
        <CreateOrderForm />    {/* wrong — this needs its own page */}
      </Dialog>
    </>
  )
}

// ✅ — feature forms are dedicated pages
function OrdersPage() {
  return (
    <>
      <Button asChild>
        <Link to="/orders/new">New order</Link>
      </Button>
      <OrdersTable />
    </>
  )
}
```

**Use a modal (an alert dialog from the project's component library, e.g. shadcn `AlertDialog`, MUI `Dialog`) ONLY for:**
- Destructive confirmation — "Delete order?" with Cancel / Confirm
- Irreversible action confirmation — "Archive all?" with warning text

```tsx
// ✅ — AlertDialog for destructive confirmation only
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel,
  AlertDialogContent, AlertDialogDescription,
  AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog'

function DeleteOrderButton({ orderId }: { orderId: string }) {
  const { mutate: deleteOrder } = useMutation({
    mutationFn: () => api.delete(`/orders/${orderId}`),
    onSuccess: () => {
      toast.success('Order deleted')
      navigate('/orders')
    },
    onError: () => toast.error('Failed to delete order'),
  })

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button variant="destructive">Delete order</Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete this order?</AlertDialogTitle>
          <AlertDialogDescription>
            This action cannot be undone. The order and all its items will be permanently removed.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancel</AlertDialogCancel>
          <AlertDialogAction onClick={() => deleteOrder()}>Delete</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
```

### Notifications — always use toast (snackbar), never inline modal alerts

Use the project's toast/snackbar component for all feedback messages (Sonner with shadcn, `Snackbar` with MUI, `useToast` with Chakra). The examples below use Sonner.

```bash
npx shadcn@latest add sonner   # preferred — simpler API, auto-dismiss, stacking
```

Setup in `App.tsx`:
```tsx
import { Toaster } from '@/components/ui/sonner'

function App() {
  return (
    <>
      <RouterProvider router={router} />
      <Toaster position="bottom-right" richColors closeButton />
    </>
  )
}
```

Usage across the app:
```tsx
import { toast } from 'sonner'

// ✅ — success
toast.success('Order created', {
  description: 'Order #1234 is now being processed.',
})

// ✅ — error
toast.error('Failed to save', {
  description: error.message,
})

// ✅ — warning
toast.warning('Unsaved changes', {
  description: 'Navigate away and your changes will be lost.',
})

// ✅ — info
toast.info('Sync in progress', {
  description: 'Your data is being updated in the background.',
})

// ✅ — loading state that resolves to success/error
toast.promise(saveOrder(values), {
  loading: 'Saving order…',
  success: 'Order saved',
  error:   'Failed to save order',
})
```

**Where to call toast in mutations:**

```tsx
// ✅ — call from mutation callbacks, never from component render
const { mutate: createOrder, isPending } = useMutation({
  mutationFn: (values: CreateOrderInput) => api.post('/api/v1/orders', values),
  onSuccess: (order) => {
    toast.success('Order created')
    navigate(`/orders/${order.id}`)
  },
  onError: (error: ApiError) => {
    toast.error('Failed to create order', { description: error.message })
  },
})
```

### UI pattern decision table

| Situation | Pattern |
|---|---|
| Create a resource | Navigate to `/resource/new` (dedicated page) |
| Edit a resource | Navigate to `/resource/:id/edit` (dedicated page) |
| View resource detail | Navigate to `/resource/:id` (dedicated page) |
| Delete / destructive action | `AlertDialog` confirmation modal → toast on result |
| API success | `toast.success()` |
| API error | `toast.error()` |
| Validation warning | `toast.warning()` or inline `<FormMessage />` under the field |
| Background operation | `toast.promise()` |
| System info | `toast.info()` |
| Blocking form errors | `<FormMessage />` inline under each field (not a toast) |
