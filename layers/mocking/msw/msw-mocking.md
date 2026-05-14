# MSW v2 Mocking Standards

## MSW v2 syntax — mandatory

MSW v2 changed its API completely. Always use v2 syntax. The v1 `rest.*` / `ctx.*` API is removed.

```ts
// v2 — correct
import { http, HttpResponse } from 'msw'

http.get('/api/users', () => HttpResponse.json([{ id: '1', name: 'Alice' }]))
http.post('/api/users', async ({ request }) => {
  const body = await request.json()
  return HttpResponse.json({ id: '2', ...body }, { status: 201 })
})

// v1 — wrong, do not use
import { rest } from 'msw'
rest.get('/api/users', (req, res, ctx) => res(ctx.json([])))
```

## Handler file layout

One file per domain. Small, focused, easy to find.

```
src/
  mocks/
    handlers/
      auth.handlers.ts      ← sign-in, sign-out, token refresh
      users.handlers.ts     ← CRUD for users
      products.handlers.ts  ← CRUD for products
      index.ts              ← compose all handlers
    browser.ts              ← browser (dev) worker
    server.ts               ← Node test server
```

### `src/mocks/handlers/users.handlers.ts`

```ts
import { http, HttpResponse } from 'msw'

export const userHandlers = [
  http.get('/api/users', () =>
    HttpResponse.json([
      { id: '1', name: 'Alice', email: 'alice@example.com' },
    ])
  ),

  http.get('/api/users/:id', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json({ message: 'Not found' }, { status: 404 })
    }
    return HttpResponse.json({ id: params.id, name: 'Alice' })
  }),

  http.post('/api/users', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json({ id: crypto.randomUUID(), ...body }, { status: 201 })
  }),
]
```

### `src/mocks/handlers/index.ts`

```ts
import { authHandlers } from './auth.handlers'
import { userHandlers } from './users.handlers'
import { productHandlers } from './products.handlers'

export const handlers = [...authHandlers, ...userHandlers, ...productHandlers]
```

## Browser worker setup

Used in development to intercept real browser requests.

```ts
// src/mocks/browser.ts
import { setupWorker } from 'msw/browser'
import { handlers } from './handlers'

export const worker = setupWorker(...handlers)
```

```ts
// src/main.tsx — start in dev only
async function enableMocking() {
  if (import.meta.env.DEV) {
    const { worker } = await import('./mocks/browser')
    return worker.start({ onUnhandledRequest: 'bypass' })
  }
}

enableMocking().then(() => {
  ReactDOM.createRoot(document.getElementById('root')!).render(<App />)
})
```

## Test server setup

Used in Node (Vitest / Jest) to intercept fetch calls during tests.

```ts
// src/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)
```

```ts
// src/test/setup.ts (referenced in vitest.config.ts setupFiles)
import { server } from '../mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

`onUnhandledRequest: 'error'` catches missing handlers early — don't use `'warn'` in CI.

## Per-test overrides

Use `server.use()` inside a test to override the default handler for that test only. `afterEach` reset ensures it doesn't leak.

```ts
import { server } from '../mocks/server'
import { http, HttpResponse } from 'msw'

it('shows error state when API fails', async () => {
  server.use(
    http.get('/api/users', () =>
      HttpResponse.json({ message: 'Internal Server Error' }, { status: 500 })
    )
  )

  render(<UserList />)
  expect(await screen.findByText('Something went wrong')).toBeInTheDocument()
})
```

## Response patterns

```ts
// JSON success
HttpResponse.json({ id: '1', name: 'Alice' })

// JSON with status
HttpResponse.json({ message: 'Not found' }, { status: 404 })

// Empty 204
new HttpResponse(null, { status: 204 })

// Network error (simulates connection failure)
HttpResponse.error()

// Delayed response (use sparingly in tests — prefer testing loading state via React Query)
import { delay } from 'msw'
http.get('/api/slow', async () => {
  await delay(500)
  return HttpResponse.json({ data: 'loaded' })
})
```

## Request inspection

```ts
http.post('/api/login', async ({ request }) => {
  const { email, password } = await request.json()
  const url = new URL(request.url)
  const page = url.searchParams.get('page')
  const auth = request.headers.get('Authorization')

  return HttpResponse.json({ token: 'fake-token' })
})
```

## Passthrough — skip mocking for specific routes

```ts
http.get('/api/feature-flags', ({ passthrough }) => passthrough())
```

Use when you want a real network call to proceed (e.g. a service that must remain live in tests).

## Never mock fetch or axios directly

```ts
// Bad — brittle, implementation-coupled, breaks interceptors
vi.spyOn(global, 'fetch').mockResolvedValue(...)
vi.mock('axios')

// Good — MSW intercepts at the network level, works regardless of HTTP client
server.use(http.get('/api/data', () => HttpResponse.json({ value: 42 })))
```

## Keeping handlers realistic

- Mirror the real API's response shape exactly — MSW responses drift when the API changes
- For error cases, use the actual error shape your API returns, not ad-hoc objects
- If the API uses cursor pagination, mock that too — test the full flow
- Version your handlers alongside the API they mock

## Common test patterns

```ts
// Test loading state
it('shows skeleton while loading', () => {
  // Don't resolve immediately — use delay or never resolve
  server.use(http.get('/api/users', () => delay('infinite')))
  render(<UserList />)
  expect(screen.getByRole('status')).toBeInTheDocument() // skeleton/spinner
})

// Test empty state
it('shows empty message with no users', async () => {
  server.use(http.get('/api/users', () => HttpResponse.json([])))
  render(<UserList />)
  expect(await screen.findByText('No users found')).toBeInTheDocument()
})

// Test pagination
it('loads next page on scroll', async () => {
  server.use(
    http.get('/api/users', ({ request }) => {
      const cursor = new URL(request.url).searchParams.get('cursor')
      const data = cursor ? SECOND_PAGE_USERS : FIRST_PAGE_USERS
      return HttpResponse.json({ data, nextCursor: cursor ? null : 'page2' })
    })
  )
  // ... interaction and assertion
})
```
