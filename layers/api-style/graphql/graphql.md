# GraphQL Standards

---

## Setup (Apollo Server + GraphQL Codegen)

```bash
npm install @apollo/server graphql graphql-tag
npm install --save-dev @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-resolvers
npm install dataloader   # N+1 prevention
```

```typescript
// codegen.ts — generates TypeScript types from schema
import type { CodegenConfig } from '@graphql-codegen/cli'

const config: CodegenConfig = {
  schema:     'src/schema/**/*.graphql',
  generates: {
    'src/generated/graphql.ts': {
      plugins: ['typescript', 'typescript-resolvers'],
      config: {
        contextType: '../context#GraphQLContext',
        useIndexSignature: true,
      },
    },
  },
}

export default config
```

---

## Schema definition (SDL-first)

```graphql
# src/schema/orders.graphql

type Query {
  order(id: ID!): Order
  orders(
    first: Int
    after: String
    filter: OrderFilter
  ): OrderConnection!
}

type Mutation {
  createOrder(input: CreateOrderInput!): CreateOrderResult!
  updateOrder(id: ID!, input: UpdateOrderInput!): UpdateOrderResult!
}

type Subscription {
  orderUpdated(id: ID!): Order!
}

# ── Types ─────────────────────────────────────────────────────────────────────

type Order {
  id:         ID!
  status:     OrderStatus!
  total:      Float!
  customer:   User!             # resolved via DataLoader
  items:      [OrderItem!]!     # resolved via DataLoader
  createdAt:  DateTime!
  updatedAt:  DateTime!
}

enum OrderStatus {
  PENDING
  SHIPPED
  DELIVERED
  CANCELLED
}

# ── Connections (pagination) ───────────────────────────────────────────────────

type OrderConnection {
  edges:    [OrderEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type OrderEdge {
  cursor: String!
  node:   Order!
}

type PageInfo {
  hasNextPage:     Boolean!
  hasPreviousPage: Boolean!
  startCursor:     String
  endCursor:       String
}

# ── Inputs ────────────────────────────────────────────────────────────────────

input CreateOrderInput {
  customerId: ID!
  items:      [OrderItemInput!]!
  notes:      String
}

input OrderItemInput {
  productId: ID!
  quantity:  Int!
}

input OrderFilter {
  status:   OrderStatus
  from:     DateTime
  to:       DateTime
}

# ── Result types (typed errors as data) ───────────────────────────────────────

union CreateOrderResult = Order | ValidationError | NotFoundError

type ValidationError {
  message: String!
  fields:  [FieldError!]!
}

type FieldError {
  field:   String!
  message: String!
}

type NotFoundError {
  message:    String!
  resourceId: ID!
}
```

---

## Context

```typescript
// src/context.ts
import { verifyToken } from './lib/auth'
import { db } from './lib/db'
import { createOrderLoader, createUserLoader } from './loaders'
import { GraphQLError } from 'graphql'

export interface GraphQLContext {
  user:         AuthenticatedUser | null
  db:           typeof db
  loaders: {
    order:    ReturnType<typeof createOrderLoader>
    user:     ReturnType<typeof createUserLoader>
  }
}

export async function createContext({ req }: { req: Request }): Promise<GraphQLContext> {
  let user: AuthenticatedUser | null = null

  const authHeader = req.headers.get('authorization')
  if (authHeader?.startsWith('Bearer ')) {
    try {
      const token = authHeader.slice(7)
      user = await verifyToken(token)
    } catch {
      // Invalid token — context user stays null
      // Individual resolvers decide if they require auth
    }
  }

  return {
    user,
    db,
    loaders: {
      order: createOrderLoader(db),
      user:  createUserLoader(db),
    },
  }
}
```

---

## DataLoader — N+1 prevention

```typescript
// src/loaders/order.loader.ts
import DataLoader from 'dataloader'
import type { PrismaClient } from '@prisma/client'

// Batches individual order.customer lookups into one DB query per render
export function createUserLoader(db: PrismaClient) {
  return new DataLoader<string, User>(
    async (userIds) => {
      const users = await db.user.findMany({
        where: { id: { in: userIds as string[] } },
      })
      // DataLoader requires results in the same order as keys
      const userMap = Object.fromEntries(users.map((u) => [u.id, u]))
      return userIds.map((id) => userMap[id] ?? new Error(`User ${id} not found`))
    },
    { cache: true }   // cache within a single request
  )
}

export function createOrderLoader(db: PrismaClient) {
  return new DataLoader<string, Order[]>(
    async (customerIds) => {
      const orders = await db.order.findMany({
        where: { customerId: { in: customerIds as string[] } },
      })
      const ordersByCustomer = customerIds.map((id) =>
        orders.filter((o) => o.customerId === id)
      )
      return ordersByCustomer
    }
  )
}
```

---

## Resolvers

```typescript
// src/resolvers/order.resolver.ts
import { GraphQLError } from 'graphql'
import type { Resolvers } from '../generated/graphql'

export const orderResolvers: Resolvers = {
  Query: {
    order: async (_parent, { id }, context) => {
      // Auth check
      if (!context.user) throw new GraphQLError('Not authenticated', {
        extensions: { code: 'UNAUTHENTICATED' },
      })

      const order = await context.db.order.findUnique({ where: { id } })
      if (!order) throw new GraphQLError('Order not found', {
        extensions: { code: 'NOT_FOUND' },
      })

      // Authorisation: users can only see their own orders
      if (order.customerId !== context.user.id && context.user.role !== 'admin') {
        throw new GraphQLError('Forbidden', { extensions: { code: 'FORBIDDEN' } })
      }

      return order
    },

    orders: async (_parent, { first = 20, after, filter }, context) => {
      if (!context.user) throw new GraphQLError('Not authenticated', {
        extensions: { code: 'UNAUTHENTICATED' },
      })

      // Delegate to service layer
      return getOrderConnection({ userId: context.user.id, first, after, filter }, context.db)
    },
  },

  Mutation: {
    createOrder: async (_parent, { input }, context) => {
      if (!context.user) throw new GraphQLError('Not authenticated', {
        extensions: { code: 'UNAUTHENTICATED' },
      })

      try {
        const order = await createOrderService(input, context.user.id, context.db)
        return order   // __typename = 'Order' via result union
      } catch (err) {
        if (err instanceof ValidationError) {
          return { __typename: 'ValidationError', message: err.message, fields: err.fields }
        }
        throw err
      }
    },
  },

  Order: {
    // DataLoader — resolved without N+1
    customer: (parent, _args, context) => {
      return context.loaders.user.load(parent.customerId)
    },
    items: (parent, _args, context) => {
      return context.loaders.order.load(parent.id)
    },
  },

  Subscription: {
    orderUpdated: {
      subscribe: (_parent, { id }, context) => {
        if (!context.user) throw new GraphQLError('Not authenticated', {
          extensions: { code: 'UNAUTHENTICATED' },
        })
        return pubsub.asyncIterator(`ORDER_UPDATED_${id}`)
      },
      resolve: (payload) => payload.orderUpdated,
    },
  },
}
```

---

## Apollo Server setup

```typescript
// src/server.ts
import { ApolloServer } from '@apollo/server'
import { expressMiddleware } from '@apollo/server/express4'
import { makeExecutableSchema } from '@graphql-tools/schema'
import depthLimit from 'graphql-depth-limit'
import { createComplexityLimitRule } from 'graphql-validation-complexity'
import { loadFilesSync } from '@graphql-tools/load-files'
import { mergeTypeDefs } from '@graphql-tools/merge'
import path from 'path'
import { orderResolvers } from './resolvers/order.resolver'
import { createContext } from './context'

const typeDefs = mergeTypeDefs(
  loadFilesSync(path.join(__dirname, 'schema/**/*.graphql'))
)

const schema = makeExecutableSchema({
  typeDefs,
  resolvers: [orderResolvers],
})

const server = new ApolloServer({
  schema,
  validationRules: [
    depthLimit(7),                              // prevent deeply nested queries
    createComplexityLimitRule(1000),            // prevent expensive queries
  ],
  introspection: process.env.NODE_ENV !== 'production',
  formatError: (formattedError, error) => {
    // Don't expose internal details in production
    if (process.env.NODE_ENV === 'production') {
      const code = formattedError.extensions?.code
      if (!['UNAUTHENTICATED', 'FORBIDDEN', 'NOT_FOUND', 'BAD_USER_INPUT'].includes(code as string)) {
        return { message: 'Internal server error', extensions: { code: 'INTERNAL_SERVER_ERROR' } }
      }
    }
    return formattedError
  },
})

await server.start()

app.use(
  '/graphql',
  express.json(),
  expressMiddleware(server, { context: createContext }),
)
```

---

## Client-side (Apollo Client)

```typescript
// src/lib/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client'
import { setContext } from '@apollo/client/link/context'
import { onError } from '@apollo/client/link/error'

const httpLink = createHttpLink({ uri: '/graphql' })

const authLink = setContext((_, { headers }) => ({
  headers: {
    ...headers,
    authorization: `Bearer ${getAccessToken()}`,
  },
}))

const errorLink = onError(({ graphQLErrors, networkError }) => {
  graphQLErrors?.forEach(({ message, extensions }) => {
    if (extensions?.code === 'UNAUTHENTICATED') {
      // Redirect to login
    }
    console.error(`[GraphQL error]: ${message}`)
  })
  if (networkError) console.error(`[Network error]: ${networkError}`)
})

export const apolloClient = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          orders: {
            keyArgs:  ['filter'],
            merge:    (existing, incoming) => ({
              ...incoming,
              edges: [...(existing?.edges ?? []), ...incoming.edges],
            }),
          },
        },
      },
    },
  }),
})
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Querying DB in resolver without DataLoader | Use DataLoader for all parent→child relationships — prevents N+1 |
| No depth or complexity limits | Set `depthLimit(7)` and complexity rules — clients can DoS without them |
| Returning `any` / raw JSON for structured data | Define proper types and input types in the schema |
| Business errors as GraphQL errors | Return typed error unions: `union Result = Success | ValidationError` |
| Auth check inside the SDL | Auth is in resolvers (or directives) — not in the schema definition |
| Exposing stack traces in production | Use `formatError` to sanitise error messages |
| Plain arrays for paginated data | Use the Relay connections pattern (`edges`, `node`, `pageInfo`) |
| Introspection enabled in production | `introspection: process.env.NODE_ENV !== 'production'` |
