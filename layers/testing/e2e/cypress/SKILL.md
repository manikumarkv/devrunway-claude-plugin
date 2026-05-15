---
name: cypress
description: Cypress E2E testing conventions — selectors, fixtures, custom commands, cy.intercept, and CI configuration. Load when working with Cypress spec files or cypress.config.*.
user-invocable: false
stack: testing/e2e/cypress
paths:
  - "cypress.config.*"
  - "cypress/**"
  - "**/*.cy.ts"
  - "**/*.cy.js"
---

Full standards in [cypress.md](cypress.md). Always-on summary:

**Selectors — priority order:**
1. `cy.contains(` for text-based assertions and `cy.findByRole()` / `cy.findByLabelText()` — semantic and resilient
2. `data-testid` attribute — explicit test hook, not affected by styling or copy changes
3. `cy.get('.class')` or `cy.get('#id')` — last resort; brittle to refactoring

**Never use:** XPath, `:nth-child()`, tag-only selectors (`cy.get('button')`)

**Commands:**
- Custom reusable actions go in `cypress/support/commands.ts` — e.g. `cy.login()`, `cy.createUser()`
- Programmatic setup via `cy.request()` or `cy.task()` — never click through UI to set up state

**Network:**
- `cy.intercept(` to mock or spy on API calls; pass `{ fixture: 'filename.json' }` to serve fixture data
- Always `cy.wait('@alias')` after `cy.intercept(` before asserting on data that depends on the response

**Assertions:**
- Cypress auto-retries — write assertions naturally; no explicit waits needed if using built-in commands
- `cy.should('be.visible')` not `cy.wait(1000)` — never arbitrary waits

**Never:**
- `cy.wait(ms)` with a hard-coded number — use intercept aliases or retry-able assertions
- Sharing state between tests — each test must be able to run independently
- `cy.visit()` inside a `beforeEach` if not every test needs it

**Related skills:** `testing/unit/jest` (unit tests complement E2E), `mocking/msw` (alternative HTTP mocking)
