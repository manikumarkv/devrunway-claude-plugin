# Cypress Standards

---

## Configuration

```typescript
// cypress.config.ts
import { defineConfig } from 'cypress'

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    specPattern: 'cypress/e2e/**/*.cy.ts',
    supportFile: 'cypress/support/e2e.ts',
    fixturesFolder: 'cypress/fixtures',
    viewportWidth: 1280,
    viewportHeight: 720,
    video: false,          // enable in CI if you need failure recordings
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 6000,
    retries: {
      runMode: 2,          // retry failed tests in CI
      openMode: 0,         // no retries in interactive mode
    },
    env: {
      apiUrl: 'http://localhost:3001',
    },
    setupNodeEvents(on, config) {
      // Register tasks here (Node.js code that runs in Cypress process)
      on('task', {
        seedDatabase: async (data) => {
          // call your DB seeding script
          return null
        },
        clearDatabase: async () => {
          // reset DB between tests
          return null
        },
      })
      return config
    },
  },
})
```

---

## Selectors — priority order

```typescript
// 1. Accessible queries (preferred) — install @testing-library/cypress
cy.findByRole('button', { name: /submit order/i }).click()
cy.findByLabelText('Email address').type('user@example.com')
cy.findByText('Order confirmed').should('be.visible')

// 2. data-testid — explicit and stable
cy.get('[data-testid="submit-button"]').click()
cy.get('[data-testid="error-message"]').should('contain', 'Required')

// 3. Aria attributes
cy.get('[aria-label="Close dialog"]').click()

// ❌ Never — brittle to styling and structure changes
cy.get('.btn-primary').click()
cy.get('button:nth-child(2)').click()
cy.get('#submit').click()   // IDs change; use data-testid
```

**Add data-testid to HTML components:**
```tsx
<button data-testid="checkout-button" type="submit">
  Checkout
</button>
```

---

## Test structure

```typescript
// cypress/e2e/checkout.cy.ts
describe('Checkout flow', () => {
  beforeEach(() => {
    // Programmatic login — don't click through UI every time
    cy.login('user@example.com', 'password')
    cy.visit('/cart')
  })

  it('completes a purchase with a valid card', () => {
    // Arrange — seed data via task, not UI
    cy.task('seedDatabase', { cart: [{ productId: 'p1', qty: 2 }] })

    // Act
    cy.findByRole('button', { name: /checkout/i }).click()
    cy.findByLabelText('Card number').type('4242424242424242')
    cy.findByLabelText('Expiry').type('12/26')
    cy.findByLabelText('CVC').type('123')
    cy.findByRole('button', { name: /pay now/i }).click()

    // Assert
    cy.findByText('Order confirmed').should('be.visible')
    cy.url().should('include', '/orders/')
  })

  it('shows an error for a declined card', () => {
    cy.intercept('POST', '/api/v1/orders', {
      statusCode: 402,
      body: { error: { code: 'CARD_DECLINED', message: 'Card declined' } },
    }).as('createOrder')

    cy.findByRole('button', { name: /pay now/i }).click()
    cy.wait('@createOrder')

    cy.findByRole('alert').should('contain', 'Card declined')
  })

  it('requires authentication', () => {
    cy.clearCookies()
    cy.visit('/checkout')
    cy.url().should('include', '/login')
  })
})
```

---

## Custom commands

```typescript
// cypress/support/commands.ts
import '@testing-library/cypress/add-commands'

// Programmatic login — bypasses UI; much faster
Cypress.Commands.add('login', (email: string, password: string) => {
  cy.request({
    method: 'POST',
    url: '/api/v1/auth/login',
    body: { email, password },
  }).then(({ body }) => {
    window.localStorage.setItem('auth_token', body.data.token)
  })
})

// Create a resource via API — don't use UI for setup
Cypress.Commands.add('createProduct', (data: Partial<Product> = {}) => {
  return cy.request({
    method: 'POST',
    url: '/api/v1/products',
    headers: { Authorization: `Bearer ${localStorage.getItem('auth_token')}` },
    body: {
      name: 'Test Product',
      price: 1000,
      ...data,
    },
  }).its('body.data')
})
```

```typescript
// cypress/support/e2e.ts
import './commands'

// Reset state before each test
beforeEach(() => {
  cy.task('clearDatabase')
})
```

```typescript
// cypress/support/index.d.ts — TypeScript declarations for custom commands
declare global {
  namespace Cypress {
    interface Chainable {
      login(email: string, password: string): Chainable<void>
      createProduct(data?: Partial<Product>): Chainable<Product>
    }
  }
}
```

---

## Network interception

```typescript
// Spy on a request (don't mock — let it through to the real server)
cy.intercept('GET', '/api/v1/orders').as('getOrders')
cy.visit('/orders')
cy.wait('@getOrders')
cy.findByRole('table').should('be.visible')

// Mock a response
cy.intercept('POST', '/api/v1/payments', {
  statusCode: 200,
  body: { success: true, data: { id: 'pay_123', status: 'succeeded' } },
}).as('createPayment')

// Mock using a fixture file
cy.intercept('GET', '/api/v1/products', { fixture: 'products.json' }).as('getProducts')

// Delay a response (test loading states)
cy.intercept('GET', '/api/v1/orders', (req) => {
  req.reply((res) => {
    res.setDelay(2000)
  })
}).as('slowOrders')

cy.visit('/orders')
cy.findByRole('progressbar').should('be.visible')   // loading state
cy.wait('@slowOrders')
cy.findByRole('progressbar').should('not.exist')    // loaded
```

---

## Fixtures

```json
// cypress/fixtures/user.json
{
  "id": "user-123",
  "email": "test@example.com",
  "name": "Test User",
  "role": "user"
}
```

```typescript
// Use fixture data in tests
cy.fixture('user.json').then((user) => {
  cy.intercept('GET', '/api/v1/me', { body: { data: user } })
})

// Or shorthand in intercept
cy.intercept('GET', '/api/v1/me', { fixture: 'user.json' })
```

---

## CI configuration

```yaml
# GitHub Actions
- uses: cypress-io/github-action@v6
  with:
    build: npm run build
    start: npm run start
    wait-on: 'http://localhost:3000'
    browser: chrome
    record: true   # requires CYPRESS_RECORD_KEY secret
  env:
    CYPRESS_RECORD_KEY: ${{ secrets.CYPRESS_RECORD_KEY }}
```

```bash
# Run headless (CI)
npx cypress run --browser chrome

# Run specific spec
npx cypress run --spec "cypress/e2e/checkout.cy.ts"

# Run in interactive mode (dev)
npx cypress open
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `cy.wait(2000)` | Use `cy.wait('@interceptAlias')` or retry-able assertions |
| Setting up state via UI clicks | Use `cy.request()` / `cy.task()` for speed and reliability |
| Tests depending on order | Each test seeds its own data; `beforeEach` resets state |
| `.get('.class-name')` | Use `[data-testid]` or `findByRole` |
| No timeout on intercept alias | `cy.wait('@alias', { timeout: 10000 })` if network is slow |
