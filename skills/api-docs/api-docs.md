# API Documentation Standards

---

## Approach: generate from code, not handwrite YAML

Use `@asteasolutions/zod-to-openapi` to derive OpenAPI schemas directly from Zod schemas already used for request validation. This keeps docs and implementation in sync automatically.

```
src/
├── lib/
│   └── openapi.ts          # OpenAPI registry + doc generation
├── types/
│   └── orders.types.ts     # Zod schemas (registered here)
├── routes/
│   └── index.ts            # Routes registered with openapi paths
└── app.ts                  # Swagger UI mounted at /api/docs
```

---

## Setup

```bash
npm install @asteasolutions/zod-to-openapi swagger-ui-express
npm install -D @types/swagger-ui-express
```

```ts
// src/lib/openapi.ts
import { OpenAPIRegistry, OpenApiGeneratorV31 } from '@asteasolutions/zod-to-openapi'

export const registry = new OpenAPIRegistry()

registry.registerComponent('securitySchemes', 'bearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
})

export function generateOpenAPIDocument() {
  const generator = new OpenApiGeneratorV31(registry.definitions)
  return generator.generateDocument({
    openapi: '3.1.0',
    info: {
      title: 'My App API',
      version: '1.0.0',
      description: 'Full-stack app API',
    },
    servers: [{ url: '/api/v1' }],
  })
}
```

---

## Register Zod schemas as OpenAPI components

```ts
// src/types/orders.types.ts
import { z } from 'zod'
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi'
import { registry } from '../lib/openapi'

extendZodWithOpenApi(z)

export const createOrderSchema = z.object({
  productId: z.string().uuid().openapi({ description: 'Product UUID' }),
  quantity: z.number().int().positive().openapi({ description: 'Units to order' }),
})

export const orderSchema = z.object({
  id: z.string().uuid(),
  productId: z.string().uuid(),
  quantity: z.number().int(),
  status: z.enum(['pending', 'confirmed', 'shipped', 'delivered']),
  createdAt: z.string().datetime(),
})

export type CreateOrderInput = z.infer<typeof createOrderSchema>
export type Order = z.infer<typeof orderSchema>

// Register as reusable components
registry.register('CreateOrderInput', createOrderSchema)
registry.register('Order', orderSchema)
```

---

## Register routes with OpenAPI paths

```ts
// src/routes/orders.ts
import { registry } from '../lib/openapi'
import { createOrderSchema, orderSchema } from '../types/orders.types'
import { z } from 'zod'

// Register the path — separate from Express route definition
registry.registerPath({
  method: 'post',
  path: '/orders',
  summary: 'Create a new order',
  description: 'Creates an order for the authenticated user. Validates inventory before confirming.',
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      content: { 'application/json': { schema: createOrderSchema } },
      required: true,
    },
  },
  responses: {
    201: {
      description: 'Order created successfully',
      content: { 'application/json': { schema: z.object({ success: z.literal(true), data: orderSchema }) } },
    },
    400: {
      description: 'Validation error',
      content: { 'application/json': { schema: z.object({ error: z.object({ message: z.string() }) }) } },
    },
    401: { description: 'Missing or invalid JWT' },
    422: { description: 'Insufficient inventory' },
    500: { description: 'Internal server error' },
  },
})
```

---

## Mount Swagger UI

```ts
// src/app.ts
import swaggerUi from 'swagger-ui-express'
import { generateOpenAPIDocument } from './lib/openapi'

// Only expose docs in non-production environments
if (process.env.NODE_ENV !== 'production') {
  const spec = generateOpenAPIDocument()
  app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(spec))
  app.get('/api/docs.json', (req, res) => res.json(spec))
}
```

Swagger UI available at: `http://localhost:3000/api/docs`

---

## Every endpoint must document

| Field | Required | Notes |
|---|---|---|
| `summary` | Yes | One-line description |
| `description` | Recommended | When behavior isn't obvious |
| `security` | Yes | `[{ bearerAuth: [] }]` for protected routes |
| `request.body` | Yes | For POST/PUT/PATCH |
| Response 200/201 | Yes | Success shape |
| Response 400 | Yes | Zod validation failure |
| Response 401 | Yes | Auth required |
| Response 403 | If applicable | Authorization (wrong role/group) |
| Response 404 | If applicable | Resource not found |
| Response 500 | Yes | Generic server error |

---

## Consistent error response shape

Define once, reference everywhere:

```ts
// src/types/api.types.ts
export const errorResponseSchema = z.object({
  error: z.object({
    message: z.string(),
    code: z.string().optional(),
    details: z.record(z.string()).optional(),
  }),
})

registry.register('ErrorResponse', errorResponseSchema)
```

```ts
// In route registration — reference the component
responses: {
  400: {
    description: 'Validation error',
    content: { 'application/json': { schema: errorResponseSchema } },
  },
}
```

---

## Never

- Write OpenAPI YAML by hand — it will drift from the Zod schemas that actually validate requests
- Omit error responses — consumers need to know what errors to expect
- Document a response shape that differs from what the code returns
- Expose `/api/docs` in production without authentication
- Use `z.any()` in schemas — document the actual shape
