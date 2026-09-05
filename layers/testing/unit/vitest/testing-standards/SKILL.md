---
name: testing-standards
description: React testing standards — accessible queries, MSW for API mocking, behavior over implementation, what to test and what not to. Load when writing or reviewing Vitest + Testing Library tests.
user-invocable: false
stack: testing/unit/vitest
paths:
  - "**/*.test.tsx"
  - "**/*.test.ts"
  - "vitest.config.*"
  - "**/setupTests.*"
  - "**/mocks/**"
---

Full standards in [testing.md](testing.md). Always-on summary:

> **Scope — applies only if this project uses vitest.** This layer shares `**/*.test.ts` with `jest` in `layers/testing/`, so more than one may load at once and their rules conflict. If the project is not using vitest, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Query priority (in order):**
`getByRole(` → `getByLabelText` → `getByPlaceholderText` → `getByText` → `getByTestId` (last resort only)

**Never:**
- Snapshot tests
- Low-level DOM event dispatching — use `userEvent` instead for realistic browser simulation
- Test internal state or implementation details
- `vi.mock('axios')` or mock native `fetch` — use MSW
- `getByTestId` as a first choice
- `waitFor` polling — prefer `findBy*` queries

**Always:**
- Test all four states: loading, success, empty, and error
- One logical assertion per test (multiple `expect` calls are fine if they test the same behaviour)
- `userEvent.setup()` at the top of each test
- Wrap with a custom `createWrapper()` that provides QueryClient + Router
- MSW handlers in `server.use()` for per-test overrides


**Related skills — apply together:**
- `typescript-patterns` — type all test utilities, wrappers, and mock data
- `accessibility` — prefer `getByRole` and `getByLabel` — they enforce accessible markup
- `error-handling` — test all four states: loading, success, empty, error
- `packages` — use vitest + @testing-library/react + msw, never jest