# Mirage JS Standards

---

## Setup

```bash
npm install --save-dev miragejs @faker-js/faker
```

---

## Server bootstrap

```typescript
// src/mocks/server.ts
import { createServer, Model, Factory, belongsTo, hasMany, Response } from 'miragejs'
import { faker } from '@faker-js/faker'

export function startMirageServer({ environment = 'development' } = {}) {
  return createServer({
    environment,   // 'test' sets timing: 0 and disables logging

    models: {
      user:    Model.extend({}),
      product: Model.extend({ category: belongsTo() }),
      order:   Model.extend({ user: belongsTo(), items: hasMany('orderItem') }),
      orderItem: Model.extend({ product: belongsTo() }),
      category: Model.extend({ products: hasMany() }),
    },

    factories: {
      user: Factory.extend({
        id:    () => faker.string.uuid(),
        name:  () => faker.person.fullName(),
        email: () => faker.internet.email(),
        role:  'user',
      }),

      product: Factory.extend({
        id:      () => faker.string.uuid(),
        name:    () => faker.commerce.productName(),
        price:   () => parseFloat(faker.commerce.price({ min: 5, max: 500 })),
        inStock: () => faker.datatype.boolean(0.8),

        // Trait — override defaults for a specific state
        withTrait: {
          outOfStock: {
            inStock: false,
          },
        },
      }),

      order: Factory.extend({
        id:        () => faker.string.uuid(),
        status:    'pending',
        createdAt: () => faker.date.recent({ days: 30 }).toISOString(),

        withTrait: {
          shipped:   { status: 'shipped' },
          delivered: { status: 'delivered' },
          cancelled: { status: 'cancelled' },
        },
      }),
    },

    seeds(server) {
      // Called in development — not in 'test' environment
      const category = server.create('category', { name: 'Electronics' })
      server.createList('product', 20, { category })
      const user = server.create('user', { role: 'admin' } as any)
      server.create('order', { user, status: 'pending' } as any)
      server.createList('order', 5, 'shipped' as any)
    },

    namespace: '/api',

    routes() {
      this.namespace = '/api'
      this.timing = environment === 'test' ? 0 : 300

      // Shorthand — Mirage handles CRUD automatically
      this.get('/users')
      this.get('/users/:id')
      this.post('/users')
      this.patch('/users/:id')
      this.del('/users/:id')

      this.get('/products')
      this.get('/products/:id')

      // Custom handler with explicit response
      this.post('/orders', (schema, request) => {
        const attrs = JSON.parse(request.requestBody)

        if (!attrs.items?.length) {
          return new Response(400, {}, { error: 'At least one item is required' })
        }

        return schema.create('order', { ...attrs, status: 'pending' })
      })

      // Simulate auth endpoint
      this.post('/auth/login', (schema, request) => {
        const { email, password } = JSON.parse(request.requestBody)
        const user = schema.findBy('user', { email })

        if (!user || password !== 'password') {
          return new Response(401, {}, { error: 'Invalid credentials' })
        }

        return { token: 'fake-jwt-token', user: user.attrs }
      })

      // Pass through everything not matched — e.g., CDN assets
      this.passthrough('https://cdn.example.com/**')
    },
  })
}
```

---

## React integration

```tsx
// src/main.tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { App } from './App'

async function bootstrap() {
  // Only start Mirage in development or when explicitly enabled
  if (import.meta.env.DEV || import.meta.env.VITE_ENABLE_MIRAGE === 'true') {
    const { startMirageServer } = await import('./mocks/server')
    startMirageServer({ environment: 'development' })
  }

  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  )
}

bootstrap()
```

---

## Test setup (Vitest)

```typescript
// src/mocks/testServer.ts — create and shut down per test
import { startMirageServer } from './server'
import type { Server } from 'miragejs'

export function setupMirageServer() {
  let server: Server

  beforeEach(() => {
    // 'test' environment: timing = 0, no console logging
    server = startMirageServer({ environment: 'test' })
  })

  afterEach(() => {
    server.shutdown()
  })

  return { getServer: () => server }
}
```

```typescript
// src/features/orders/orders.test.ts
import { render, screen, waitFor } from '@testing-library/react'
import { setupMirageServer } from '@/mocks/testServer'
import { OrderList } from './OrderList'

const { getServer } = setupMirageServer()

it('renders a list of pending orders', async () => {
  const server = getServer()

  // Create test data per-test — never rely on seeds() in tests
  server.createList('order', 3, { status: 'pending' } as any)

  render(<OrderList />)

  await waitFor(() => {
    expect(screen.getAllByRole('listitem')).toHaveLength(3)
  })
})

it('shows empty state when no orders', async () => {
  // No seeding — tests an empty response
  render(<OrderList />)
  await waitFor(() => {
    expect(screen.getByText('No orders found')).toBeInTheDocument()
  })
})
```

---

## Storybook decorators

```tsx
// src/stories/OrderList.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { startMirageServer } from '@/mocks/server'
import { OrderList } from '@/features/orders/OrderList'

const meta: Meta<typeof OrderList> = {
  title:     'Features/OrderList',
  component: OrderList,
}
export default meta

type Story = StoryObj<typeof OrderList>

export const WithOrders: Story = {
  decorators: [
    (Story) => {
      const server = startMirageServer({ environment: 'test' })
      server.createList('order', 5, 'shipped' as any)

      // Return cleanup via useEffect pattern via Storybook addon
      return <Story />
    },
  ],
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Starting Mirage server in production | Gate on `import.meta.env.DEV` or a feature flag — Mirage intercepts all `fetch` calls |
| Sharing one server instance across tests | Create and `shutdown()` per test — shared state causes flaky tests |
| Hardcoded IDs in factories | Use `faker.string.uuid()` — hardcoded IDs collide between `createList` calls |
| Accessing `server.db` directly in components | Route handlers use `schema` — `server.db` is for test assertions only |
| Using seeds() data in tests | `seeds()` only runs in `development` environment — create your own data in each test |
