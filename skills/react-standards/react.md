# React Best Practices

Source: Vercel Engineering agent-skills (adapted for React without Next.js)

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
  return <input onChange={e => setQuery(e.target.value)} />
}

// ✅ — urgent: update input; deferred: run expensive work
function Search() {
  const [query, setQuery] = useState('')
  const [isPending, startTransition] = useTransition()
  return <input onChange={e => startTransition(() => setQuery(e.target.value))} />
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
    <button onMouseEnter={preload} onClick={() => setOpen(true)}>
      Open
    </button>
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
