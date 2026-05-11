# Testing Standards

Stack: Vitest + React Testing Library + MSW

---

## Core philosophy

**Test behaviour, not implementation.** Tests should describe what a user sees and does, not how the code works internally. If you can refactor the implementation without changing a test, the test is well-written.

---

## Query priority — HIGH IMPACT

Always use the most semantic query available. This order matches how users and assistive technology find elements.

```
1. getByRole          — preferred for everything interactive
2. getByLabelText     — form inputs
3. getByPlaceholderText — last resort for inputs
4. getByText          — non-interactive content
5. getByDisplayValue  — current value of form fields
6. getByAltText       — images
7. getByTitle         — tooltips (use sparingly)
8. getByTestId        — ONLY when nothing else works, add data-testid
```

```tsx
// ❌ — implementation detail, breaks on className change
container.querySelector('.submit-button')

// ❌ — testId is a crutch, not semantic
screen.getByTestId('submit-btn')

// ✅ — semantic, matches how users find the button
screen.getByRole('button', { name: /submit/i })
screen.getByLabelText(/email address/i)
screen.getByRole('textbox', { name: /username/i })
```

---

## Test setup — always use a wrapper

Every test that renders React components needs QueryClient + Router. Create a shared wrapper instead of repeating it.

```tsx
// src/test/utils.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'

export function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },   // no retries in tests
      mutations: { retry: false },
    },
  })

  return function Wrapper({ children }: { children: React.ReactNode }) {
    return (
      <QueryClient client={queryClient}>
        <MemoryRouter>{children}</MemoryRouter>
      </QueryClient>
    )
  }
}

// Usage in every test
render(<MyComponent />, { wrapper: createWrapper() })
```

---

## User interactions — use userEvent, not fireEvent

`userEvent` simulates real browser behaviour (focus, keyboard events, pointer events). `fireEvent` just dispatches a single DOM event.

```tsx
// ❌ — fireEvent doesn't simulate real typing
fireEvent.change(input, { target: { value: 'hello' } })

// ✅ — userEvent types like a real user
const user = userEvent.setup()
await user.type(input, 'hello')
await user.click(button)
await user.selectOptions(select, 'option-value')
await user.clear(input)
await user.tab()  // keyboard navigation
```

Always call `userEvent.setup()` once at the top of a test, not inside every interaction:

```tsx
describe('LoginForm', () => {
  it('submits with valid credentials', async () => {
    const user = userEvent.setup()   // ✅ once per test
    render(<LoginForm />, { wrapper: createWrapper() })

    await user.type(screen.getByLabelText(/email/i), 'test@example.com')
    await user.type(screen.getByLabelText(/password/i), 'secret123')
    await user.click(screen.getByRole('button', { name: /sign in/i }))

    expect(await screen.findByText(/welcome/i)).toBeInTheDocument()
  })
})
```

---

## API mocking — MSW only, never mock fetch

```tsx
// ❌ — mocking fetch/axios tests the wrong thing
vi.mock('axios')
vi.spyOn(global, 'fetch').mockResolvedValue(...)

// ✅ — MSW intercepts at the network level, same as production
// src/test/server.ts
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

export const server = setupServer(
  http.get('/api/users', () =>
    HttpResponse.json({ success: true, data: [{ id: '1', name: 'Alice' }] })
  )
)

// src/test/setup.ts
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

Override handlers per test for specific scenarios:

```tsx
it('shows error state when API fails', async () => {
  server.use(
    http.get('/api/users', () => HttpResponse.json({}, { status: 500 }))
  )

  render(<UserList />, { wrapper: createWrapper() })
  expect(await screen.findByRole('alert')).toBeInTheDocument()
})
```

---

## What to test — the four states

Every component that fetches data must test all four states:

```tsx
describe('UserList', () => {
  it('renders loading state', () => {
    // MSW handler delays response — or use a pending promise
    render(<UserList />, { wrapper: createWrapper() })
    expect(screen.getByRole('status', { name: /loading/i })).toBeInTheDocument()
  })

  it('renders users when loaded', async () => {
    render(<UserList />, { wrapper: createWrapper() })
    expect(await screen.findByRole('listitem', { name: /alice/i })).toBeInTheDocument()
  })

  it('renders empty state', async () => {
    server.use(http.get('/api/users', () => HttpResponse.json({ data: [] })))
    render(<UserList />, { wrapper: createWrapper() })
    expect(await screen.findByText(/no users found/i)).toBeInTheDocument()
  })

  it('renders error state', async () => {
    server.use(http.get('/api/users', () => HttpResponse.json({}, { status: 500 })))
    render(<UserList />, { wrapper: createWrapper() })
    expect(await screen.findByRole('alert')).toBeInTheDocument()
  })
})
```

---

## Async queries — findBy over waitFor

```tsx
// ❌ — verbose, polling
await waitFor(() => {
  expect(screen.getByText('Alice')).toBeInTheDocument()
})

// ✅ — findBy* already waits and retries
expect(await screen.findByText('Alice')).toBeInTheDocument()
expect(await screen.findByRole('button', { name: /save/i })).toBeEnabled()
```

Use `waitFor` only when asserting that something is NOT present (absence):

```tsx
// ✅ — correct use of waitFor for absence
await waitFor(() => {
  expect(screen.queryByRole('status', { name: /loading/i })).not.toBeInTheDocument()
})
```

---

## What NOT to test

```tsx
// ❌ — never test internal state
const { result } = renderHook(() => useCounter())
expect(result.current.count).toBe(0)  // testing internals

// ❌ — never test implementation details
expect(mockSetState).toHaveBeenCalledWith(5)
expect(component.instance().handleClick).toBeDefined()

// ❌ — never snapshot test UI components
expect(container).toMatchSnapshot()

// ❌ — never test third-party library behaviour
expect(queryClient.getQueryData(['users'])).toEqual(...)
```

---

## Service / hook unit tests

For custom hooks and service functions, test behaviour not internals:

```tsx
// Testing a custom hook
it('increments count when increment is called', async () => {
  const { result } = renderHook(() => useCounter(), { wrapper: createWrapper() })

  act(() => result.current.increment())

  expect(result.current.count).toBe(1)  // ✅ observable output
})

// Testing a service function
it('throws NotFoundError when user does not exist', async () => {
  vi.mocked(userRepository.findById).mockResolvedValue(null)

  await expect(userService.getById('missing-id', 'user-1'))
    .rejects.toThrow(NotFoundError)
})
```

---

## Test file conventions

```
src/features/users/
  components/UserList/
    UserList.tsx
    UserList.test.tsx   ← co-located with component

src/services/
  user.service.ts
  user.service.test.ts  ← co-located with service

e2e/
  users.spec.ts         ← Playwright E2E

bruno/
  users/                ← Bruno API collection
```

One `describe` block per component/hook/service. Group related tests with nested `describe`. Name tests as: `'<does something> when <condition>'`.

```tsx
describe('UserList', () => {
  describe('when users exist', () => {
    it('renders each user name', async () => { ... })
    it('renders user avatars', async () => { ... })
  })

  describe('when no users exist', () => {
    it('renders empty state message', async () => { ... })
  })
})
```
