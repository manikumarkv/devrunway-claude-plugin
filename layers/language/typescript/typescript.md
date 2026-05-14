# TypeScript Patterns

---

## State modelling — CRITICAL

### Use discriminated unions, not parallel boolean flags

Parallel booleans create impossible states. A discriminated union makes illegal states unrepresentable.

```ts
// ❌ — 8 possible combinations, most nonsensical
interface FetchState {
  isLoading: boolean
  isError: boolean
  isSuccess: boolean
  data?: User
  error?: string
}

// ✅ — exactly 3 valid states, each carries only what makes sense
type FetchState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'error'; error: string }
  | { status: 'success'; data: User }

// Narrowing is automatic
function render(state: FetchState) {
  if (state.status === 'success') {
    return state.data.name  // TS knows data exists here
  }
  if (state.status === 'error') {
    return state.error      // TS knows error exists here
  }
}
```

### Exhaustive checks with `never`

Catch unhandled cases at compile time, not runtime.

```ts
// ❌ — silent bug when a new status is added
function getLabel(status: OrderStatus): string {
  if (status === 'pending') return 'Pending'
  if (status === 'shipped') return 'Shipped'
  return ''  // new status silently falls through
}

// ✅ — compile error forces you to handle new cases
function getLabel(status: OrderStatus): string {
  switch (status) {
    case 'pending':  return 'Pending'
    case 'shipped':  return 'Shipped'
    case 'delivered': return 'Delivered'
    default: {
      const _exhaustive: never = status  // TS error if a case is missing
      return _exhaustive
    }
  }
}
```

---

## Type safety — HIGH IMPACT

### `unknown` over `any` — always narrow before use

```ts
// ❌ — any disables the type checker entirely
async function fetchUser(id: string): Promise<any> {
  const res = await fetch(`/api/users/${id}`)
  return res.json()
}
const user = await fetchUser('1')
user.nonExistentField  // no error — silent bug

// ✅ — unknown forces you to validate
async function fetchUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`)
  const data: unknown = await res.json()
  return userSchema.parse(data)  // Zod validates and narrows
}
```

### Type guards over type assertions

```ts
// ❌ — assertion: you're telling TS to trust you. If wrong, runtime crash.
const user = data as User

// ✅ — type guard: runtime check + compile-time narrowing
function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    typeof (value as any).id === 'string'
  )
}

if (isUser(data)) {
  console.log(data.id)  // safe
}
```

### `satisfies` for validated literals without widening

```ts
// ❌ — type is widened to Record<string, string>
const ROUTES = {
  home: '/',
  login: '/login',
  dashboard: '/dashboard',
}

// ❌ — `as const` narrows but no type safety on the shape
const ROUTES = {
  home: '/',
  login: '/login',
} as const

// ✅ — `satisfies` validates shape AND preserves literal types
const ROUTES = {
  home: '/',
  login: '/login',
  dashboard: '/dashboard',
} satisfies Record<string, `/${string}`>

type Route = typeof ROUTES[keyof typeof ROUTES]  // '/' | '/login' | '/dashboard'
```

### Branded types for IDs — prevent mix-ups at compile time

```ts
// ❌ — all IDs are just strings, easy to pass wrong one
function getPost(userId: string, postId: string) { ... }
getPost(post.id, user.id)  // swapped — no compile error

// ✅ — branded types make mix-ups impossible
type UserId = string & { readonly __brand: 'UserId' }
type PostId = string & { readonly __brand: 'PostId' }

function brandUserId(id: string): UserId { return id as UserId }
function brandPostId(id: string): PostId { return id as PostId }

function getPost(userId: UserId, postId: PostId) { ... }

getPost(post.id, user.id)  // ✅ TS error — types don't match
```

### Explicit return types on all exported functions

```ts
// ❌ — return type inferred; changes silently break callers
export async function getUser(id: string) {
  return db.user.findUnique({ where: { id } })
}

// ✅ — explicit: breaking changes are caught immediately
export async function getUser(id: string): Promise<User | null> {
  return db.user.findUnique({ where: { id } })
}
```

---

## Generics — MEDIUM

### Write generic functions instead of repeating types

```ts
// ❌ — duplicated for every entity
async function getUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`)
  return res.json()
}
async function getPost(id: string): Promise<Post> {
  const res = await fetch(`/api/posts/${id}`)
  return res.json()
}

// ✅ — generic, reusable
async function fetchOne<T>(path: string): Promise<T> {
  const res = await fetch(path)
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  return res.json() as Promise<T>
}

const user = await fetchOne<User>(`/api/users/${id}`)
const post = await fetchOne<Post>(`/api/posts/${id}`)
```

### Constrain generics to avoid `any` creep

```ts
// ❌ — T is unconstrained; callers can pass anything
function getProperty<T>(obj: T, key: string) {
  return (obj as any)[key]  // forced to use any
}

// ✅ — constrained: only valid keys of T are accepted
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]
}

const name = getProperty(user, 'name')   // string
const id = getProperty(user, 'id')       // string
const bad = getProperty(user, 'missing') // TS error
```

---

## Utility types — MEDIUM

```ts
// Pick — subset of a type
type UserPreview = Pick<User, 'id' | 'name' | 'avatarUrl'>

// Omit — everything except
type CreateUserInput = Omit<User, 'id' | 'createdAt' | 'updatedAt'>

// Partial — all fields optional (useful for PATCH payloads)
type UpdateUserInput = Partial<Pick<User, 'name' | 'email' | 'bio'>>

// Required — remove all optionals
type CompleteConfig = Required<AppConfig>

// ReturnType — infer return type of a function
type ApiResponse = ReturnType<typeof fetchUser>

// Awaited — unwrap a Promise
type User = Awaited<ReturnType<typeof fetchUser>>

// Record — typed object map
const labelsByStatus: Record<OrderStatus, string> = {
  pending: 'Pending',
  shipped: 'Shipped',
  delivered: 'Delivered',
}
```

---

## Const assertions — MEDIUM

```ts
// ❌ — type is string[], values can be anything
const ALLOWED_ROLES = ['admin', 'editor', 'viewer']

// ✅ — type is readonly ['admin', 'editor', 'viewer'], values are literal
const ALLOWED_ROLES = ['admin', 'editor', 'viewer'] as const
type Role = typeof ALLOWED_ROLES[number]  // 'admin' | 'editor' | 'viewer'

// Useful for route maps, config objects, enum-like values
const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  NOT_FOUND: 404,
} as const
type HttpStatus = typeof HTTP_STATUS[keyof typeof HTTP_STATUS]
```

---

## React-specific TypeScript

### Type component props explicitly — never inline

```tsx
// ❌ — inline object type, can't be reused or extended
function Button({ label, onClick }: { label: string; onClick: () => void }) { ... }

// ✅ — named interface, exportable, extendable
interface ButtonProps {
  label: string
  onClick: () => void
  variant?: 'primary' | 'secondary' | 'ghost'
  disabled?: boolean
}
export function Button({ label, onClick, variant = 'primary', disabled }: ButtonProps) { ... }
```

### Type event handlers precisely

```tsx
// ❌ — loses the event type
const handleChange = (e: any) => setValue(e.target.value)

// ✅ — fully typed
const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => setValue(e.target.value)
const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => { e.preventDefault(); ... }
const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => { ... }
```

### Type children correctly

```tsx
// ❌ — too broad
interface LayoutProps { children: any }

// ✅ — use React.ReactNode for any renderable content
interface LayoutProps { children: React.ReactNode }

// For render props that return JSX
interface ListProps<T> {
  items: T[]
  renderItem: (item: T, index: number) => React.ReactElement
}
```

### Use `ComponentProps` to extend native element props

```tsx
// ❌ — manually re-declaring all button props
interface ButtonProps {
  label: string
  onClick?: () => void
  disabled?: boolean
  type?: 'button' | 'submit' | 'reset'
  // ... missing dozens of valid button attrs
}

// ✅ — extend native props, add your own
interface ButtonProps extends React.ComponentProps<'button'> {
  label: string
  variant?: 'primary' | 'secondary'
}
export function Button({ label, variant = 'primary', ...buttonProps }: ButtonProps) {
  return <button className={cn(styles[variant])} {...buttonProps}>{label}</button>
}
```
