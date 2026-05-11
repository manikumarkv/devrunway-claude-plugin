# Playwright E2E Testing Standards

---

## File structure

```
e2e/
├── fixtures/
│   ├── auth.setup.ts       # Login once, save storage state
│   └── index.ts            # Custom fixtures
├── pages/
│   ├── LoginPage.ts
│   ├── DashboardPage.ts
│   └── OrdersPage.ts
├── .auth/
│   └── user.json           # Saved auth state (gitignored)
├── login.spec.ts
├── orders.spec.ts
└── playwright.config.ts
```

---

## Configuration

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'e2e/.auth/user.json',
      },
      dependencies: ['setup'],
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
})
```

---

## Auth setup — login once, reuse across all tests

```ts
// e2e/fixtures/auth.setup.ts
import { test as setup } from '@playwright/test'

const authFile = 'e2e/.auth/user.json'

setup('authenticate', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL!)
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('/dashboard')
  await page.context().storageState({ path: authFile })
})
```

---

## Page objects — locators + actions only, no assertions

```ts
// e2e/pages/OrdersPage.ts
import { type Page, type Locator } from '@playwright/test'

export class OrdersPage {
  readonly page: Page
  readonly createButton: Locator
  readonly orderList: Locator

  constructor(page: Page) {
    this.page = page
    this.createButton = page.getByRole('button', { name: 'Create order' })
    this.orderList = page.getByRole('list', { name: 'Orders' })
  }

  async goto() {
    await this.page.goto('/orders')
  }

  async createOrder(data: { product: string; quantity: number }) {
    await this.createButton.click()
    await this.page.getByLabel('Product').fill(data.product)
    await this.page.getByLabel('Quantity').fill(String(data.quantity))
    await this.page.getByRole('button', { name: 'Submit' }).click()
  }

  orderRow(name: string) {
    return this.orderList.getByRole('listitem').filter({ hasText: name })
  }
}
```

---

## Test file structure

```ts
// e2e/orders.spec.ts
import { test, expect } from '@playwright/test'
import { OrdersPage } from './pages/OrdersPage'

test.describe('Orders', () => {
  let ordersPage: OrdersPage

  test.beforeEach(async ({ page }) => {
    ordersPage = new OrdersPage(page)
    await ordersPage.goto()
  })

  test('shows empty state when no orders exist', async ({ page }) => {
    await expect(page.getByText('No orders yet')).toBeVisible()
  })

  test('creates a new order', async ({ page }) => {
    await ordersPage.createOrder({ product: 'Widget A', quantity: 3 })
    await expect(ordersPage.orderRow('Widget A')).toBeVisible()
  })

  test('shows error when quantity exceeds stock', async ({ page }) => {
    await ordersPage.createOrder({ product: 'Widget A', quantity: 9999 })
    await expect(page.getByRole('alert')).toContainText('Insufficient stock')
  })
})
```

---

## Selector priority

```ts
// ✅ 1. Semantic role — preferred
page.getByRole('button', { name: 'Submit' })
page.getByRole('heading', { name: 'Orders' })
page.getByRole('textbox', { name: 'Search' })

// ✅ 2. Label / placeholder
page.getByLabel('Email address')
page.getByPlaceholder('Search orders...')

// ✅ 3. Text content
page.getByText('No orders yet')

// ✅ 4. Test ID — last resort when no semantic selector works
page.getByTestId('order-summary-total')
// Add to element: <div data-testid="order-summary-total">

// ❌ Never
page.locator('.order-list-item')        // CSS class — implementation detail
page.locator('//div[@class="order"]')   // XPath
page.locator('[data-cy="submit"]')      // Cypress-specific attributes
```

---

## Waiting — use built-in auto-waiting

```ts
// ✅ Playwright auto-waits for elements to be actionable
await page.getByRole('button', { name: 'Save' }).click()
await expect(page.getByText('Saved')).toBeVisible()

// ✅ Wait for navigation
await page.waitForURL('/orders')

// ✅ Wait for network request to complete
await Promise.all([
  page.waitForResponse(r => r.url().includes('/api/orders') && r.status() === 201),
  page.getByRole('button', { name: 'Submit' }).click(),
])

// ❌ Never — arbitrary sleep
await page.waitForTimeout(2000)
```

---

## Custom fixtures

```ts
// e2e/fixtures/index.ts
import { test as base } from '@playwright/test'
import { OrdersPage } from '../pages/OrdersPage'

type Fixtures = {
  ordersPage: OrdersPage
}

export const test = base.extend<Fixtures>({
  ordersPage: async ({ page }, use) => {
    const ordersPage = new OrdersPage(page)
    await ordersPage.goto()
    await use(ordersPage)
  },
})

export { expect } from '@playwright/test'
```

```ts
// Use in tests
import { test, expect } from '../fixtures'

test('creates order', async ({ ordersPage, page }) => {
  await ordersPage.createOrder({ product: 'Widget', quantity: 1 })
  await expect(ordersPage.orderRow('Widget')).toBeVisible()
})
```

---

## CI integration

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  push:
    branches: [develop, main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      - name: Run E2E tests
        run: npx playwright test
        env:
          BASE_URL: ${{ secrets.STAGING_URL }}
          TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
          TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}

      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

---

## What to test with Playwright

**Do test:**
- Critical user journeys end-to-end (create order, checkout, login)
- Cross-page flows that unit tests can't cover
- Form submission with real API responses
- Error states triggered by real server errors
- Auth-protected routes redirect unauthenticated users

**Do not test:**
- Every edge case — that's unit test territory
- Visual pixel-perfect layout — use visual regression tools separately
- Implementation details (component state, hook return values)
- Things already covered by unit tests
