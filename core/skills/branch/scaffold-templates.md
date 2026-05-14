# Branch Scaffold Templates

> **Note:** The canonical scaffold templates live in `skills/scaffold/SKILL.md`.
> When `/branch create` triggers scaffolding, read that skill for the full
> up-to-date templates. The summaries below are kept for quick reference only.

Used by `/branch create` to generate boilerplate for new features and API endpoints.

---

## Frontend Feature Scaffold

Directory: `src/features/<name>/`

### `types.ts`
```typescript
export interface $NAME {
  id: string;
  // TODO: add fields
  createdAt: string;
  updatedAt: string;
}

export interface Create$NAMEInput {
  // TODO: add input fields
}
```

### `api/$name.api.ts`
```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/services/api';
import type { $NAME, Create$NAMEInput } from '../types';

const QUERY_KEY = '$name' as const;

export const use$NAMEs = () =>
  useQuery({
    queryKey: [QUERY_KEY],
    queryFn: () => apiClient.get<$NAME[]>('/$name'),
  });

export const use$NAME = (id: string) =>
  useQuery({
    queryKey: [QUERY_KEY, id],
    queryFn: () => apiClient.get<$NAME>(`/$name/${id}`),
    enabled: !!id,
  });

export const useCreate$NAME = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: Create$NAMEInput) =>
      apiClient.post<$NAME>('/$name', input),
    onSuccess: () => qc.invalidateQueries({ queryKey: [QUERY_KEY] }),
  });
};
```

### `hooks/use$NAME.ts`
```typescript
import { use$NAMEs, useCreate$NAME } from '../api/$name.api';

export const use$NAME = () => {
  const { data: items = [], isLoading, error } = use$NAMEs();
  const createMutation = useCreate$NAME();

  const create = (input: Parameters<typeof createMutation.mutate>[0]) =>
    createMutation.mutate(input);

  return { items, isLoading, error, create, isCreating: createMutation.isPending };
};
```

### `components/$NAME/$NAME.tsx`
```typescript
import type { FC } from 'react';
import { use$NAME } from '../../hooks/use$NAME';

interface $NAMEProps {
  // TODO: add props
}

export const $NAME: FC<$NAMEProps> = () => {
  const { items, isLoading, error } = use$NAME();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error loading data</div>;
  if (!items.length) return <div>No items found</div>;

  return (
    <div>
      {/* TODO: render items */}
    </div>
  );
};
```

### `components/$NAME/$NAME.test.tsx`
```typescript
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { $NAME } from './$NAME';
import { createWrapper } from '@/test/utils';

describe('$NAME', () => {
  it('renders loading state', () => {
    // TODO: mock loading state with MSW
    render(<$NAME />, { wrapper: createWrapper() });
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  it('renders items when loaded', async () => {
    // TODO: mock success state with MSW handler
    render(<$NAME />, { wrapper: createWrapper() });
    // expect(await screen.findByRole('...', { name: '...' })).toBeInTheDocument();
  });

  it('renders empty state', () => {
    // TODO: mock empty response with MSW
    render(<$NAME />, { wrapper: createWrapper() });
    // expect(screen.getByText('No items found')).toBeInTheDocument();
  });
});
```

### `components/$NAME/index.ts`
```typescript
export { $NAME } from './$NAME';
```

### `index.ts` (feature public API)
```typescript
export { $NAME } from './components/$NAME';
export { use$NAME } from './hooks/use$NAME';
export type { $NAME as $NAMEType, Create$NAMEInput } from './types';
```

---

## Backend API Endpoint Scaffold

### `src/types/$name.types.ts`
```typescript
import { z } from 'zod';

export const create$NAMESchema = z.object({
  // TODO: add fields
});

export const $NAMEParamsSchema = z.object({
  id: z.string().uuid(),
});

export type Create$NAMEInput = z.infer<typeof create$NAMESchema>;
```

### `src/repositories/$name.repository.ts`
```typescript
import { logger } from '../utils/logger';

export const $nameRepository = {
  async findAll(): Promise<$NAME[]> {
    // TODO: implement DB query
    logger.debug({ action: 'findAll$NAME' }, 'Fetching all $name records');
    return [];
  },

  async findById(id: string): Promise<$NAME | null> {
    logger.debug({ action: 'findById$NAME', id }, 'Fetching $name by id');
    // TODO: implement DB query
    return null;
  },

  async create(input: Create$NAMEInput): Promise<$NAME> {
    logger.debug({ action: 'create$NAME', input }, 'Creating $name');
    // TODO: implement DB insert
    throw new Error('Not implemented');
  },
};
```

### `src/services/$name.service.ts`
```typescript
import { $nameRepository } from '../repositories/$name.repository';
import { logger } from '../utils/logger';

export const $nameService = {
  async getAll(userId: string): Promise<$NAME[]> {
    logger.info({ userId, action: 'getAll$NAME' }, 'Fetching $names');
    return $nameRepository.findAll();
  },

  async getById(id: string, userId: string): Promise<$NAME> {
    const item = await $nameRepository.findById(id);
    if (!item) {
      const err = new Error('NOT_FOUND');
      logger.warn({ userId, action: 'getById$NAME', id }, '$NAME not found');
      throw err;
    }
    return item;
  },

  async create(input: Create$NAMEInput, userId: string): Promise<$NAME> {
    logger.info({ userId, action: 'create$NAME' }, 'Creating $name');
    return $nameRepository.create(input);
  },
};
```

### `src/controllers/$name.controller.ts`
```typescript
import { Router } from 'express';
import { asyncHandler } from '../utils/asyncHandler';
import { authMiddleware } from '../middleware/auth';
import { $nameService } from '../services/$name.service';
import { create$NAMESchema, $NAMEParamsSchema } from '../types/$name.types';
import { logger } from '../utils/logger';

export const $nameRouter = Router();

$nameRouter.use(authMiddleware);

$nameRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = req.user.sub;
    const data = await $nameService.getAll(userId);
    logger.info({ userId, action: 'list$NAME', count: data.length }, 'Listed $names');
    res.json({ success: true, data });
  }),
);

$nameRouter.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const { id } = $NAMEParamsSchema.parse(req.params);
    const userId = req.user.sub;
    const data = await $nameService.getById(id, userId);
    res.json({ success: true, data });
  }),
);

$nameRouter.post(
  '/',
  asyncHandler(async (req, res) => {
    const userId = req.user.sub;
    const input = create$NAMESchema.parse(req.body);
    const data = await $nameService.create(input, userId);
    logger.info({ userId, action: 'create$NAME', id: data.id }, '$NAME created');
    res.status(201).json({ success: true, data });
  }),
);
```
