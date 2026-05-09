# Node.js Standards — Full Reference

## Project Structure
```
src/
├── config/
│   ├── env.ts           # Zod-validated env vars — fail fast if missing
│   └── constants.ts     # App-wide constants
├── controllers/         # Thin: validate input → call service → return response
├── services/            # Business logic — pure functions where possible
├── repositories/        # DB access layer
├── middleware/
│   ├── auth.ts          # Cognito JWT verification
│   ├── requireGroup.ts  # Group-based authorization
│   ├── requestId.ts     # Attach UUID request ID
│   ├── errorHandler.ts  # Centralized error middleware
│   └── rateLimiter.ts   # express-rate-limit configs
├── routes/              # Route definitions (thin, delegate to controllers)
├── types/               # Shared TypeScript types + Zod schemas
├── utils/
│   ├── asyncHandler.ts  # Wrap async route handlers
│   ├── logger.ts        # Pino logger instance
│   └── errors.ts        # Custom error classes
└── app.ts               # Express setup (no listen())
index.ts                 # Entry point (listen())
```

## Core Utilities (always exist in every project)

### asyncHandler
```ts
// utils/asyncHandler.ts
import type { RequestHandler } from 'express';

export const asyncHandler = (fn: RequestHandler): RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
```

### Pino logger
```ts
// utils/logger.ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  formatters: {
    level: label => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
```

### Custom error classes
```ts
// utils/errors.ts
export class AppError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly statusCode: number = 400,
    public readonly details: unknown[] = [],
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super('NOT_FOUND', `${resource} with id '${id}' not found`, 404);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super('UNAUTHORIZED', message, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super('FORBIDDEN', message, 403);
  }
}
```

### Centralized error handler
```ts
// middleware/errorHandler.ts
import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';
import { AppError } from '../utils/errors';
import { logger } from '../utils/logger';

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  const requestId = (req as any).id;
  const userId = (req as any).user?.sub;

  if (err instanceof ZodError) {
    logger.warn({ requestId, userId, err: err.issues }, 'Validation error');
    return res.status(400).json({
      success: false,
      error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: err.issues },
    });
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error({ requestId, userId, err }, err.message);
    } else {
      logger.warn({ requestId, userId, code: err.code }, err.message);
    }
    return res.status(err.statusCode).json({
      success: false,
      error: { code: err.code, message: err.message, details: err.details },
    });
  }

  logger.error({ requestId, userId, err }, 'Unhandled error');
  res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'An unexpected error occurred' },
  });
};
```

### Env config (Zod validated — fail at startup if missing)
```ts
// config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'staging', 'production']),
  PORT: z.coerce.number().default(3000),
  AWS_REGION: z.string(),
  COGNITO_USER_POOL_ID: z.string(),
  COGNITO_CLIENT_ID: z.string(),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  // Add project-specific vars here
});

export const env = envSchema.parse(process.env);
```

## Controller Pattern
```ts
// controllers/orders.controller.ts
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { OrdersService } from '../services/orders.service';
import type { AuthenticatedRequest } from '../middleware/auth';

const createOrderSchema = z.object({
  items: z.array(z.object({ productId: z.string().uuid(), quantity: z.number().int().min(1) })),
  shippingAddressId: z.string().uuid(),
});

export const OrdersController = {
  create: asyncHandler(async (req, res) => {
    const body = createOrderSchema.parse(req.body);         // throws ZodError on invalid
    const userId = (req as AuthenticatedRequest).user.sub;

    const order = await OrdersService.create({ userId, ...body });
    res.status(201).json({ success: true, data: order });
  }),

  list: asyncHandler(async (req, res) => {
    const userId = (req as AuthenticatedRequest).user.sub;
    const orders = await OrdersService.listByUser(userId);
    res.json({ success: true, data: orders });
  }),

  getById: asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = (req as AuthenticatedRequest).user.sub;
    const order = await OrdersService.getById(id, userId);   // service enforces ownership
    res.json({ success: true, data: order });
  }),
};
```

## Service Pattern
```ts
// services/orders.service.ts
import { NotFoundError, ForbiddenError } from '../utils/errors';
import { OrdersRepository } from '../repositories/orders.repository';
import { logger } from '../utils/logger';
import type { CreateOrderInput, Order } from '../types/orders';

export const OrdersService = {
  async create(input: CreateOrderInput & { userId: string }): Promise<Order> {
    logger.info({ userId: input.userId, action: 'createOrder', items: input.items.length }, 'Creating order');
    const order = await OrdersRepository.create(input);
    logger.info({ userId: input.userId, action: 'createOrder', orderId: order.id }, 'Order created');
    return order;
  },

  async getById(id: string, requestingUserId: string): Promise<Order> {
    const order = await OrdersRepository.findById(id);
    if (!order) throw new NotFoundError('Order', id);
    if (order.userId !== requestingUserId) throw new ForbiddenError();
    return order;
  },

  async listByUser(userId: string): Promise<Order[]> {
    return OrdersRepository.findByUserId(userId);
  },
};
```

## Repository Pattern
```ts
// repositories/orders.repository.ts
import { db } from '../config/database';     // Prisma or DynamoDB client
import type { CreateOrderInput, Order } from '../types/orders';

export const OrdersRepository = {
  async create(input: CreateOrderInput & { userId: string }): Promise<Order> {
    return db.order.create({ data: input });
  },

  async findById(id: string): Promise<Order | null> {
    return db.order.findUnique({ where: { id } });
  },

  async findByUserId(userId: string): Promise<Order[]> {
    return db.order.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  },
};
```

## Route Definition
```ts
// routes/orders.routes.ts
import { Router } from 'express';
import { OrdersController } from '../controllers/orders.controller';
import { authMiddleware } from '../middleware/auth';
import { requireGroup } from '../middleware/requireGroup';

const router = Router();

router.post('/', authMiddleware, OrdersController.create);
router.get('/', authMiddleware, OrdersController.list);
router.get('/:id', authMiddleware, OrdersController.getById);
router.delete('/:id', authMiddleware, requireGroup('Admin'), OrdersController.remove);

export default router;
```

## Testing with Vitest + Supertest

```ts
// controllers/orders.controller.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../app';
import { OrdersService } from '../services/orders.service';

vi.mock('../services/orders.service');
vi.mock('../middleware/auth', () => ({
  authMiddleware: (req: any, _res: any, next: any) => {
    req.user = { sub: 'user-123', email: 'test@example.com', groups: ['User'] };
    next();
  },
}));

describe('POST /api/v1/orders', () => {
  it('creates an order with valid input', async () => {
    const mockOrder = { id: 'order-1', userId: 'user-123' };
    vi.mocked(OrdersService.create).mockResolvedValue(mockOrder as any);

    const res = await request(app)
      .post('/api/v1/orders')
      .send({ items: [{ productId: 'prod-1', quantity: 2 }], shippingAddressId: 'addr-1' });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ success: true, data: mockOrder });
  });

  it('returns 400 for invalid input', async () => {
    const res = await request(app).post('/api/v1/orders').send({ items: [] });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});
```

## Approved Libraries

| Category | Library |
|---|---|
| Runtime | Node.js 20 LTS |
| Language | TypeScript 5+ strict |
| Framework | Express 4 |
| Validation | Zod |
| Logging | Pino |
| Auth | aws-jwt-verify |
| Security | helmet, express-rate-limit |
| ORM (SQL) | Prisma |
| AWS SDK | @aws-sdk/client-dynamodb, @aws-sdk/lib-dynamodb |
| UUID | crypto.randomUUID() (built-in) |
| Testing | Vitest, Supertest |
| API Testing | Bruno |
