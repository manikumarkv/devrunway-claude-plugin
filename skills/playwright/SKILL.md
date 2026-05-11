---
name: playwright
description: Playwright E2E testing standards — test structure, selectors, fixtures, page objects, CI integration. Load when writing or reviewing Playwright specs.
user-invocable: false
---

Full standards in [playwright.md](playwright.md). Always-on summary:

**Selectors — priority order:**
1. `getByRole` — semantic, accessible
2. `getByLabel` / `getByPlaceholder`
3. `getByTestId` — only when no semantic selector works
4. Never: CSS classes, XPath, implementation-specific attributes

**Structure:**
- Tests in `e2e/<feature>.spec.ts`
- Page objects in `e2e/pages/<Page>.ts` — locators + actions, no assertions
- Fixtures in `e2e/fixtures/` — shared setup (auth, seeded data)
- `test.use({ storageState: 'e2e/.auth/user.json' })` for authenticated tests

**Never:**
- `page.waitForTimeout()` — use `waitFor` or auto-waiting
- Shared mutable state between tests
- Assert in page objects
- Hard-code URLs — use `baseURL` from config
