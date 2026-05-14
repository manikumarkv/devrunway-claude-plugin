---
name: msw-mocking
description: MSW v2 mock service worker patterns — handler setup, server/browser config, test utils, request matching. Load when working with MSW handlers or test setup.
user-invocable: false
stack: mocking/msw
paths:
  - "src/mocks/**"
  - "**/*.handlers.ts"
  - "**/*.test.tsx"
  - "**/*.test.ts"
---

Full standards in [msw-mocking.md](msw-mocking.md). Always-on summary:

**Syntax — always MSW v2:**
- `http.get()`, `http.post()` etc. — NOT `rest.get()` (v1 API)
- `HttpResponse.json(data)` — NOT `res(ctx.json(data))` (v1 API)
- `HttpResponse.json(data, { status: 400 })` for error responses

**Handler file layout:**
- `src/mocks/handlers/<domain>.ts` — one file per domain (auth, users, products)
- `export const userHandlers = [...]` then compose in `src/mocks/handlers/index.ts`
- Browser: `src/mocks/browser.ts` → `setupWorker(...handlers)`
- Tests: `src/mocks/server.ts` → `setupServer(...handlers)`

**Test patterns:**
- `server.use(overrideHandler)` inside individual tests for one-off scenarios
- `server.resetHandlers()` in `afterEach` — always, no exceptions
- `server.listen({ onUnhandledRequest: 'error' })` in `beforeAll`

**Never:**
- Mock `fetch` or `axios` directly — use MSW for all HTTP mocking
- Share mutable handler state between tests — reset in `afterEach`

**Passthrough:** `http.get('/api/real', ({ passthrough }) => passthrough())`

**Related skills:** `testing-standards` (test setup), `react-standards` (React Query + MSW pairing)
