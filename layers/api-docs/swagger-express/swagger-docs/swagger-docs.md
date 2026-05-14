# Swagger / OpenAPI 3.1 Documentation Standards

---

## Package installation

```bash
npm install @asteasolutions/zod-to-openapi swagger-ui-express
npm install -D @types/swagger-ui-express
```

---

## File structure

```
src/
├── docs/
│   ├── openapi-registry.ts    ← register all schemas here
│   ├── openapi.ts             ← assemble the final spec
│   └── schemas/
│       ├── common.schema.ts   ← shared: pagination, meta, error envelope
│       ├── orders.schema.ts   ← feature-specific schemas
│       └── users.schema.ts
```

---

## Setup — OpenAPI registry

```ts
// src/docs/openapi-registry.ts
import { OpenAPIRegistry } from '@asteasolutions/zod-to-openapi'

export const registry = new OpenAPIRegistry()

// Security scheme — register once
registry.registerComponent('securitySchemes', 'bearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
  description: 'Cognito JWT — obtain from POST /api/v1/auth/sign-in',
})
```

```ts
// src/docs/openapi.ts
import { OpenApiGeneratorV31 } from '@asteasolutions/zod-to-openapi'
import { registry } from './openapi-registry'

export function buildOpenApiSpec() {
  const generator = new OpenApiGeneratorV31(registry.definitions)
  return generator.generateDocument({
    openapi: '3.1.0',
    info: {
      title:       'My App API',
      version:     'v1',
      description: 'REST API — all endpoints require Bearer JWT unless marked public',
      contact: {
        name:  'Backend Team',
        email: 'backend@example.com',
      },
    },
    servers: [
      { url: 'http://localhost:3000', description: 'Local' },
      { url: 'https://api-staging.example.com', description: 'Staging' },
    ],
    tags: [
      { name: 'Auth',     description: 'Authentication — sign in, refresh, sign out' },
      { name: 'Orders',   description: 'Order management' },
      { name: 'Users',    description: 'User management (admin only)' },
      { name: 'Products', description: 'Product catalogue' },
    ],
  })
}
```

---

## Mount Swagger UI

```ts
// src/app.ts
import swaggerUi from 'swagger-ui-express'
import { buildOpenApiSpec } from './docs/openapi'

// Only expose docs in non-production environments
if (process.env.NODE_ENV !== 'production') {
  const spec = buildOpenApiSpec()

  app.get('/api-docs/spec.json', (_req, res) => {
    res.json(spec)
  })

  app.use(
    '/api-docs',
    swaggerUi.serve,
    swaggerUi.setup(spec, {
      swaggerOptions: {
        persistAuthorization: true,    // keeps Bearer token across page reloads
        displayRequestDuration: true,
        docExpansion: 'none',          // collapsed by default — cleaner
        filter: true,                  // search box
      },
      customSiteTitle: 'My App API Docs',
    }),
  )

  // eslint-disable-next-line no-console -- startup info printed once; logger not available yet
  process.stdout.write('📖 Swagger UI: http://localhost:3000/api-docs\n')
}
```

---

## Registering schemas — derive from Zod, never duplicate

```ts
// src/docs/schemas/orders.schema.ts
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi'
import { z } from 'zod'
import { registry } from '../openapi-registry'

// Must call once in the app — typically in the registry file
extendZodWithOpenApi(z)

// ── Enums ─────────────────────────────────────────────────────────────────
export const orderStatusSchema = z.enum(['PENDING', 'CONFIRMED', 'SHIPPED', 'CANCELLED'])
  .openapi({ description: 'Current lifecycle state of the order' })

// ── Request schemas ────────────────────────────────────────────────────────
export const createOrderBodySchema = z.object({
  productId: z.string().cuid().openapi({ example: 'clxyz123' }),
  quantity:  z.number().int().min(1).max(100).openapi({ example: 3 }),
  notes:     z.string().max(500).optional().openapi({ example: 'Leave at the door' }),
}).openapi({ ref: 'CreateOrderBody' })   // ← ref name used in $ref

export const listOrdersQuerySchema = z.object({
  status: z.union([orderStatusSchema, z.array(orderStatusSchema)]).optional(),
  sort:   z.enum(['createdAt', 'updatedAt', 'total']).default('createdAt'),
  order:  z.enum(['asc', 'desc']).default('desc'),
  limit:  z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().optional(),
}).openapi({ ref: 'ListOrdersQuery' })

// ── Response schemas ───────────────────────────────────────────────────────
export const orderSchema = z.object({
  id:        z.string().cuid().openapi({ example: 'clxyz123' }),
  status:    orderStatusSchema,
  total:     z.number().openapi({ example: 49.99 }),
  createdAt: z.string().datetime().openapi({ example: '2026-01-15T10:30:00.000Z' }),
  updatedAt: z.string().datetime().openapi({ example: '2026-01-15T10:30:00.000Z' }),
}).openapi({ ref: 'Order' })

// Register schemas in the global registry
registry.register('Order', orderSchema)
registry.register('CreateOrderBody', createOrderBodySchema)
```

---

## Shared envelope schemas

```ts
// src/docs/schemas/common.schema.ts
import { z } from 'zod'
import { registry } from '../openapi-registry'

export const responseMeta = z.object({
  requestId: z.string().openapi({ example: 'a1b2-c3d4' }),
  timestamp: z.string().datetime().openapi({ example: '2026-05-14T10:00:00.000Z' }),
  version:   z.string().openapi({ example: 'v1' }),
}).openapi({ ref: 'ResponseMeta' })

export const paginationSchema = z.object({
  nextCursor: z.string().nullable().openapi({ example: 'eyJpZCI6ImFiYzEyMyJ9' }),
  total:      z.number().int().openapi({ example: 84 }),
  limit:      z.number().int().openapi({ example: 20 }),
  hasMore:    z.boolean().openapi({ example: true }),
}).openapi({ ref: 'Pagination' })

export const errorDetailSchema = z.object({
  code:     z.string().openapi({ example: 'NOT_FOUND' }),
  message:  z.string().openapi({ example: 'Order not found' }),
  details:  z.record(z.string()).optional().openapi({
    example: { email: 'Enter a valid email address' },
  }),
  path:     z.string().openapi({ example: '/api/v1/orders/clxyz' }),
}).openapi({ ref: 'ErrorDetail' })

/** Helper: wrap a resource schema in the success envelope */
export function successResponse<T extends z.ZodTypeAny>(dataSchema: T, ref: string) {
  return z.object({
    success: z.literal(true),
    data:    dataSchema,
    meta:    responseMeta,
  }).openapi({ ref })
}

/** Helper: wrap an array in the paginated envelope */
export function paginatedResponse<T extends z.ZodTypeAny>(dataSchema: T, ref: string) {
  return z.object({
    success:    z.literal(true),
    data:       z.array(dataSchema),
    pagination: paginationSchema,
    meta:       responseMeta,
  }).openapi({ ref })
}

/** Standard error response */
export const errorResponseSchema = z.object({
  success: z.literal(false),
  error:   errorDetailSchema,
  meta:    responseMeta,
}).openapi({ ref: 'ErrorResponse' })

registry.register('ResponseMeta',   responseMeta)
registry.register('Pagination',     paginationSchema)
registry.register('ErrorDetail',    errorDetailSchema)
registry.register('ErrorResponse',  errorResponseSchema)
```

---

## Documenting routes — full example

```ts
// src/docs/routes/orders.docs.ts
import { z } from 'zod'
import { registry } from '../openapi-registry'
import { errorResponseSchema, successResponse, paginatedResponse } from '../schemas/common.schema'
import { orderSchema, createOrderBodySchema, listOrdersQuerySchema } from '../schemas/orders.schema'

const OrderResponse = successResponse(orderSchema, 'OrderResponse')
const OrdersListResponse = paginatedResponse(orderSchema, 'OrdersListResponse')

registry.registerPath({
  method:  'get',
  path:    '/api/v1/orders',
  tags:    ['Orders'],
  summary: 'List orders',
  description: 'Returns a paginated list of orders belonging to the authenticated user.',
  security: [{ bearerAuth: [] }],
  request: {
    query: listOrdersQuerySchema,
  },
  responses: {
    200: {
      description: 'Paginated list of orders',
      content: { 'application/json': { schema: OrdersListResponse } },
    },
    401: {
      description: 'Not authenticated',
      content: { 'application/json': { schema: errorResponseSchema } },
    },
    500: {
      description: 'Internal server error',
      content: { 'application/json': { schema: errorResponseSchema } },
    },
  },
})

registry.registerPath({
  method:  'post',
  path:    '/api/v1/orders',
  tags:    ['Orders'],
  summary: 'Create an order',
  description: 'Places a new order for the authenticated user. Deducts stock atomically.',
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      required: true,
      content: { 'application/json': { schema: createOrderBodySchema } },
    },
  },
  responses: {
    201: {
      description: 'Order created successfully',
      content: { 'application/json': { schema: OrderResponse } },
    },
    400: {
      description: 'Validation error',
      content: { 'application/json': { schema: errorResponseSchema } },
    },
    401: { description: 'Not authenticated',      content: { 'application/json': { schema: errorResponseSchema } } },
    404: { description: 'Product not found',      content: { 'application/json': { schema: errorResponseSchema } } },
    422: { description: 'Insufficient stock',     content: { 'application/json': { schema: errorResponseSchema } } },
    500: { description: 'Internal server error',  content: { 'application/json': { schema: errorResponseSchema } } },
  },
})

registry.registerPath({
  method:  'get',
  path:    '/api/v1/orders/{id}',
  tags:    ['Orders'],
  summary: 'Get order by ID',
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({ id: z.string().cuid().openapi({ example: 'clxyz123' }) }),
  },
  responses: {
    200: {
      description: 'Order details',
      content: { 'application/json': { schema: OrderResponse } },
    },
    401: { description: 'Not authenticated',  content: { 'application/json': { schema: errorResponseSchema } } },
    403: { description: 'Forbidden',          content: { 'application/json': { schema: errorResponseSchema } } },
    404: { description: 'Order not found',    content: { 'application/json': { schema: errorResponseSchema } } },
    500: { description: 'Internal error',     content: { 'application/json': { schema: errorResponseSchema } } },
  },
})

registry.registerPath({
  method:  'patch',
  path:    '/api/v1/orders/{id}',
  tags:    ['Orders'],
  summary: 'Update order status',
  description: 'Partial update — typically used to change `status`. Invalid transitions return 422.',
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({ id: z.string().cuid().openapi({ example: 'clxyz123' }) }),
    body: {
      required: true,
      content: {
        'application/json': {
          schema: z.object({
            status: z.enum(['CONFIRMED', 'CANCELLED']).openapi({ example: 'CANCELLED' }),
          }).openapi({ ref: 'UpdateOrderBody' }),
        },
      },
    },
  },
  responses: {
    200: { description: 'Updated order',              content: { 'application/json': { schema: OrderResponse } } },
    400: { description: 'Validation error',           content: { 'application/json': { schema: errorResponseSchema } } },
    401: { description: 'Not authenticated',          content: { 'application/json': { schema: errorResponseSchema } } },
    403: { description: 'Forbidden',                  content: { 'application/json': { schema: errorResponseSchema } } },
    404: { description: 'Order not found',            content: { 'application/json': { schema: errorResponseSchema } } },
    422: { description: 'Invalid status transition',  content: { 'application/json': { schema: errorResponseSchema } } },
    500: { description: 'Internal error',             content: { 'application/json': { schema: errorResponseSchema } } },
  },
})

registry.registerPath({
  method:  'delete',
  path:    '/api/v1/orders/{id}',
  tags:    ['Orders'],
  summary: 'Delete (cancel) order',
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({ id: z.string().cuid().openapi({ example: 'clxyz123' }) }),
  },
  responses: {
    204: { description: 'Deleted — no body' },
    401: { description: 'Not authenticated',  content: { 'application/json': { schema: errorResponseSchema } } },
    403: { description: 'Forbidden',          content: { 'application/json': { schema: errorResponseSchema } } },
    404: { description: 'Order not found',    content: { 'application/json': { schema: errorResponseSchema } } },
    500: { description: 'Internal error',     content: { 'application/json': { schema: errorResponseSchema } } },
  },
})
```

---

## Load all route docs in app.ts

```ts
// src/docs/index.ts  — import all route doc files to trigger registry.registerPath() calls
import './routes/auth.docs'
import './routes/orders.docs'
import './routes/users.docs'
import './routes/products.docs'
```

```ts
// src/app.ts
import './docs'   // must import before buildOpenApiSpec()
import { buildOpenApiSpec } from './docs/openapi'
```

---

## Auth header in Swagger UI — testing flows

The `bearerAuth` security scheme enables the **Authorize** button in Swagger UI. Users paste their Cognito JWT and all subsequent requests include `Authorization: Bearer <token>`.

To get a token in development:
```bash
# Quick: use AWS CLI to get a Cognito token
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <client-id> \
  --auth-parameters USERNAME=admin@example.com,PASSWORD=changeme-on-first-login \
  --query 'AuthenticationResult.IdToken' \
  --output text
```

Paste the output into the Swagger UI Authorize dialog.

---

## Spec export for downstream tooling

```ts
// scripts/export-openapi-spec.ts
// Run with: ts-node scripts/export-openapi-spec.ts
import fs from 'fs'
import '../src/docs'   // trigger all registerPath() calls
import { buildOpenApiSpec } from '../src/docs/openapi'

const spec = buildOpenApiSpec()
fs.writeFileSync('openapi.json', JSON.stringify(spec, null, 2))
process.stdout.write('✅ openapi.json written\n')  // script context — no app logger available
```

```json
// package.json
{
  "scripts": {
    "docs:export": "ts-node scripts/export-openapi-spec.ts"
  }
}
```

Use `openapi.json` for:
- **Bruno** — import into Bruno to auto-generate the collection (`bruno import openapi`)
- **Postman** — `Import → OpenAPI` in the Postman app
- **Frontend SDK** — `openapi-typescript` to generate typed API client
  ```bash
  npx openapi-typescript openapi.json -o src/types/api.gen.ts
  ```

---

## Documentation quality checklist

Before merging a new endpoint:

```
[ ] Route registered in registry.registerPath()
[ ] All path/query params documented with examples
[ ] Request body references a named $ref schema (not inline)
[ ] All realistic response codes documented (minimum: success + 400 + 401 + 404 + 500)
[ ] Security: [{ bearerAuth: [] }] set (or explicitly public if unauthenticated)
[ ] Summary is a short verb phrase ("List orders", "Create order")
[ ] Description explains business rules or side effects (stock deduction, email sent, etc.)
[ ] Zod schema has .openapi({ example: ... }) on all fields
[ ] openapi.json regenerated (npm run docs:export) and committed
```

---

## Never

```ts
// ❌ — inline object schema (un-referenceable, duplicates type definitions)
content: {
  'application/json': {
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        status: { type: 'string' },
      },
    },
  },
}

// ✅ — reference a named schema derived from Zod
content: { 'application/json': { schema: OrderResponse } }

// ❌ — expose docs in production
if (true) {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(spec))
}

// ✅ — dev/staging only
if (process.env.NODE_ENV !== 'production') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(spec))
}

// ❌ — undocumented route
router.post('/orders', asyncHandler(createOrder))  // no registry.registerPath()

// ✅ — every route has a matching docs entry
// (docs/routes/orders.docs.ts loaded in docs/index.ts)
router.post('/orders', asyncHandler(createOrder))
```
