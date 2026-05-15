---
name: playwright
description: Playwright E2E testing standards — test structure, selectors, fixtures, page objects, CI integration, and MCP runner so tests can be triggered from prompts. Load when writing, reviewing, or running Playwright specs.
user-invocable: false
stack: testing/e2e/playwright
---

Full standards in [playwright.md](playwright.md).
MCP + prompt runner guide in [playwright-mcp.md](playwright-mcp.md).

**Running tests via prompts — quick reference:**
- "Run all E2E tests" → `npx playwright test`
- "Run the orders spec" → `npx playwright test e2e/orders.spec.ts`
- "Run tests tagged @smoke" → `npx playwright test --grep @smoke`
- "Open Playwright UI mode" → `npx playwright test --ui`
- "Show failing tests from the last run" → reads `playwright-report/results.json`
- "Generate a test for the checkout flow" → `npx playwright codegen http://localhost:5173`

**MCP setup:** `.mcp.json` at project root registers `@playwright/mcp` so Claude can also
control the browser directly (navigate, click, screenshot) for interactive debugging.

**Tag convention (filter tests by prompt):**
- `@smoke` — core happy paths; run after every deploy
- `@regression` — edge cases; run on full PR suite
- `@<feature>` — e.g. `@orders`, `@auth`, `@admin`
- `@slow` — excluded from smoke; nightly only

**Selectors — priority order:**
1. `getByRole(` — semantic, accessible; first choice
2. `getByLabel` / `getByPlaceholder`
3. `getByTestId` — only when no semantic selector works
4. Never: CSS classes, XPath, implementation-specific attributes

**Structure:**
- Tests in `e2e/<feature>.spec.ts`; use `expect(` from `@playwright/test` for all assertions
- Page objects are `class ` definitions in `e2e/pages/<Page>.ts` — locators + actions only; assertions belong in the test file, not the page object
- Fixtures in `e2e/fixtures/` — shared setup (auth, seeded data)
- `test.use({ storageState: 'e2e/.auth/user.json' })` for authenticated tests

**Never:**
- Hard-coded sleep delays — use `waitFor` or Playwright auto-waiting instead
- Shared mutable state between tests
- Assert in page objects
- Hard-code URLs — use `baseURL` from config

**Related skills — apply together:**
- `testing-standards` — unit tests cover component logic; Playwright covers cross-page flows
- `accessibility` — keyboard navigation and focus management verified in E2E specs
- `api-conventions` — tests call real API endpoints; response shapes must match the contract
