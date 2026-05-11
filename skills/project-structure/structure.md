# Project Structure Standards

---

## Frontend — React + Vite + TypeScript

```
src/
├── assets/                     # Static files (images, fonts, icons)
│
├── components/                 # Shared, reusable UI components (no business logic)
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   └── index.ts
│   ├── Modal/
│   ├── Table/
│   └── index.ts                # Public barrel for shared components
│
├── features/                   # Feature modules — each is self-contained
│   └── <feature-name>/
│       ├── types.ts            # TypeScript interfaces for this feature
│       ├── api/
│       │   └── <feature>.api.ts   # React Query hooks (useQuery, useMutation)
│       ├── hooks/
│       │   └── use<Feature>.ts    # Business logic hook
│       ├── components/
│       │   └── <Component>/
│       │       ├── <Component>.tsx
│       │       ├── <Component>.test.tsx
│       │       └── index.ts
│       └── index.ts            # Public API — only export what other features need
│
├── hooks/                      # Shared hooks (no API calls — those live in features)
│   ├── useDebounce.ts
│   ├── useLocalStorage.ts
│   └── useMediaQuery.ts
│
├── lib/                        # Third-party client setup
│   ├── queryClient.ts          # React Query client instance
│   ├── router.tsx              # React Router definition
│   └── amplify.ts              # AWS Amplify config
│
├── pages/                      # Route-level pages — thin wrappers only
│   ├── DashboardPage.tsx       # Composes feature components, no logic
│   ├── LoginPage.tsx
│   └── NotFoundPage.tsx
│
├── stores/                     # Global client state (Zustand) — non-server state only
│   └── uiStore.ts              # e.g. sidebar open/closed, theme
│
├── styles/                     # Global CSS, Tailwind base
│   └── globals.css
│
├── test/                       # Test utilities (not test files)
│   ├── server.ts               # MSW server setup
│   ├── handlers.ts             # Default MSW handlers
│   └── utils.tsx               # createWrapper(), custom render
│
├── types/                      # Global TypeScript types used across features
│   └── api.ts                  # Shared API response shapes
│
├── utils/                      # Pure utility functions (no side effects)
│   ├── cn.ts                   # Tailwind class merging (clsx + tailwind-merge)
│   ├── formatDate.ts
│   └── formatCurrency.ts
│
├── App.tsx                     # Root component — providers only
├── main.tsx                    # Entry point — mounts App
└── vite-env.d.ts
```

### Feature module rules

```
features/orders/
  types.ts              ← Order, CreateOrderInput, UpdateOrderInput interfaces
  api/
    orders.api.ts       ← useOrders(), useOrder(id), useCreateOrder(), useUpdateOrder()
  hooks/
    useOrderForm.ts     ← form state, validation, submission logic
  components/
    OrderList/
      OrderList.tsx
      OrderList.test.tsx
      index.ts
    OrderForm/
      OrderForm.tsx
      OrderForm.test.tsx
      index.ts
    OrderDetail/
      OrderDetail.tsx
      OrderDetail.test.tsx
      index.ts
  index.ts              ← export { OrderList, OrderForm, OrderDetail, useOrderForm }
```

**Public API rule:** other features import only from `features/<name>/index.ts`, never from internal paths.

```ts
// ❌ — reaching into feature internals
import { OrderList } from '@/features/orders/components/OrderList/OrderList'

// ✅ — through the public API
import { OrderList } from '@/features/orders'
```

---

## Backend — Node.js + Express + TypeScript

```
src/
├── controllers/            # HTTP layer: validate input → call service → respond
│   ├── users.controller.ts
│   └── orders.controller.ts
│
├── services/               # Business logic — no HTTP, no DB
│   ├── users.service.ts
│   └── orders.service.ts
│
├── repositories/           # DB access only — no business logic
│   ├── users.repository.ts
│   └── orders.repository.ts
│
├── middleware/             # Express middleware
│   ├── auth.ts             # Cognito JWT verification
│   ├── requireGroup.ts     # Group-based authorization
│   ├── errorHandler.ts     # Centralized error handler
│   ├── requestLogger.ts    # Pino request logging
│   └── rateLimiter.ts      # express-rate-limit setup
│
├── types/                  # Zod schemas + inferred TS types
│   ├── users.types.ts      # createUserSchema, UpdateUserInput, etc.
│   └── orders.types.ts
│
├── lib/                    # Third-party client setup — singletons
│   ├── prisma.ts           # Prisma client
│   ├── dynamodb.ts         # DynamoDB DocumentClient
│   └── logger.ts           # Pino logger instance
│
├── utils/                  # Pure utilities
│   ├── asyncHandler.ts     # Wraps async route handlers
│   ├── errors.ts           # Custom error classes
│   └── pagination.ts       # Cursor pagination helpers
│
├── routes/
│   └── index.ts            # Mounts all routers: app.use('/api/v1/users', usersRouter)
│
├── app.ts                  # Express app setup: middleware, routes, error handler
└── server.ts               # Entry point: listens on port / Lambda handler
```

### Layer responsibility rules

```ts
// Controller — validate, call service, respond. Nothing else.
export const createOrder = asyncHandler(async (req, res) => {
  const body = createOrderSchema.parse(req.body)          // validate
  const order = await orderService.create(body, req.user) // delegate
  res.status(201).json({ success: true, data: order })    // respond
})

// Service — business logic only. No req/res, no DB.
async function create(input: CreateOrderInput, user: AuthUser): Promise<Order> {
  await checkInventory(input.productId, input.quantity)   // business rule
  const order = await orderRepository.create({ ...input, userId: user.sub })
  await notifyUser(user.sub, order.id)
  return order
}

// Repository — DB access only. No business logic.
async function create(data: CreateOrderData): Promise<Order> {
  return prisma.order.create({ data })
}
```

---

## Monorepo structure (if applicable)

```
/
├── apps/
│   ├── web/               # React frontend
│   └── api/               # Node.js backend
│
├── packages/
│   ├── types/             # Shared TypeScript types (FE + BE)
│   │   └── src/
│   │       ├── user.ts
│   │       └── order.ts
│   └── validators/        # Shared Zod schemas (FE + BE)
│       └── src/
│           ├── user.schema.ts
│           └── order.schema.ts
│
├── infra/                 # AWS CDK stacks
│   ├── bin/app.ts
│   └── lib/
│       ├── api-stack.ts
│       └── frontend-stack.ts
│
├── e2e/                   # Playwright E2E tests
├── bruno/                 # Bruno API collections
├── package.json           # Workspace root
└── turbo.json             # Turborepo config
```

---

## Naming conventions

| Thing | Convention | Example |
|---|---|---|
| React components | PascalCase | `OrderList.tsx` |
| Hooks | camelCase with `use` prefix | `useOrderForm.ts` |
| API files | camelCase `.api.ts` | `orders.api.ts` |
| Services | camelCase `.service.ts` | `orders.service.ts` |
| Repositories | camelCase `.repository.ts` | `orders.repository.ts` |
| Controllers | camelCase `.controller.ts` | `orders.controller.ts` |
| Type files | camelCase `.types.ts` | `orders.types.ts` |
| Test files | Same name + `.test.ts(x)` | `OrderList.test.tsx` |
| E2E specs | camelCase `.spec.ts` | `orders.spec.ts` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_PAGE_SIZE` |
| Env vars | SCREAMING_SNAKE_CASE | `DATABASE_URL` |
| DB tables | snake_case | `order_items` |
| Prisma models | PascalCase | `OrderItem` |
