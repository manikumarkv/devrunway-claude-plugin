---
name: scaffold
description: Generate all boilerplate files for a new feature. Usage — /scaffold <feature-name> [frontend|backend|fullstack]
argument-hint: <feature-name> [frontend|backend|fullstack]
arguments:
  - name: feature-name
    description: "kebab-case feature name, e.g. order-items, user-profile, payment-methods"
  - name: scope
    description: "frontend, backend, or fullstack (default: fullstack)"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(ls *)
  - Bash(find *)
  - Bash(mkdir *)
---

# Scaffold

Generate all boilerplate files for a new feature so development starts with
working, standards-compliant shells — not blank files.

Parse `$ARGUMENTS`:
- `featureName` = first arg (kebab-case, e.g. `order-items`)
- `scope` = second arg: `frontend`, `backend`, or `fullstack` (default `fullstack`)

Derive naming variants from `featureName`:
- `PascalName` = PascalCase singular: `order-items` → `OrderItem`
- `PascalNames` = PascalCase plural: `order-items` → `OrderItems`
- `camelName` = camelCase singular: `order-items` → `orderItem`
- `camelNames` = camelCase plural: `order-items` → `orderItems`
- `kebabName` = as-is: `order-items`
- `kebabNames` = plural: `order-items` → `order-items` (already plural — keep as-is)

Before writing, check for existing files at the target paths. If any exist, list
them and ask the user to confirm before overwriting.

---

## Frontend scaffold

Create all files under `src/features/<kebabName>/`.

### `src/features/<kebabName>/types.ts`

```typescript
export interface <PascalName> {
  id: string
  createdAt: string
  updatedAt: string
  // TODO: add domain fields
}

export interface Create<PascalName>Input {
  // TODO: add required fields
}

export interface Update<PascalName>Input {
  // TODO: add updatable fields
}
```

---

### `src/features/<kebabName>/api/<kebabName>.api.ts`

```typescript
import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { apiClient } from '@/lib/apiClient'
import type { <PascalName>, Create<PascalName>Input, Update<PascalName>Input } from '../types'
import type { PaginatedResponse } from '@/types/api'

const QUERY_KEY = '<camelNames>' as const

export function use<PascalNames>(params?: { limit?: number }) {
  return useInfiniteQuery({
    queryKey: [QUERY_KEY, params],
    queryFn: ({ pageParam }) =>
      apiClient.get<PaginatedResponse<<PascalName>>>(
        `/api/v1/<kebabNames>?limit=${params?.limit ?? 20}${pageParam ? `&cursor=${pageParam}` : ''}`
      ),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.meta.nextCursor ?? undefined,
  })
}

export function use<PascalName>(id: string) {
  return useQuery({
    queryKey: [QUERY_KEY, id],
    queryFn: () => apiClient.get<{ success: true; data: <PascalName> }>(`/api/v1/<kebabNames>/${id}`),
    enabled: Boolean(id),
    select: (res) => res.data,
  })
}

export function useCreate<PascalName>() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Create<PascalName>Input) =>
      apiClient.post<{ success: true; data: <PascalName> }>('/api/v1/<kebabNames>', input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEY] })
    },
  })
}

export function useUpdate<PascalName>() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, ...input }: Update<PascalName>Input & { id: string }) =>
      apiClient.patch<{ success: true; data: <PascalName> }>(`/api/v1/<kebabNames>/${id}`, input),
    onSuccess: (_data, { id }) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEY] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEY, id] })
    },
  })
}

export function useDelete<PascalName>() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: string) =>
      apiClient.delete(`/api/v1/<kebabNames>/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEY] })
    },
  })
}
```

---

### `src/features/<kebabName>/components/<PascalName>List/<PascalName>List.tsx`

```tsx
import { use<PascalNames> } from '../../api/<kebabName>.api'
import { ApiError } from '@/utils/errors'

export function <PascalName>List() {
  const { data, isLoading, error, fetchNextPage, hasNextPage, isFetchingNextPage } = use<PascalNames>()

  if (isLoading) {
    return <div aria-busy="true" aria-label="Loading <camelNames>">Loading...</div>
  }

  if (error) {
    return (
      <div role="alert" className="p-4 text-red-600">
        Failed to load <camelNames>.
      </div>
    )
  }

  const items = data?.pages.flatMap((page) => page.data) ?? []

  if (items.length === 0) {
    return <div>No <camelNames> found.</div>
  }

  return (
    <div>
      <ul role="list" aria-label="<PascalNames>">
        {items.map((item) => (
          <li key={item.id}>
            {/* TODO: render item */}
            {item.id}
          </li>
        ))}
      </ul>
      {hasNextPage && (
        <button
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
          aria-label="Load more <camelNames>"
        >
          {isFetchingNextPage ? 'Loading...' : 'Load more'}
        </button>
      )}
    </div>
  )
}
```

---

### `src/features/<kebabName>/components/<PascalName>List/<PascalName>List.test.tsx`

```tsx
import { screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { http, HttpResponse } from 'msw'
import { <PascalName>List } from './<PascalName>List'
import { createWrapper, renderWithWrapper } from '@/test/utils'
import { server } from '@/test/server'

const mock<PascalName> = {
  id: 'test-id-1',
  createdAt: '2024-01-01T00:00:00Z',
  updatedAt: '2024-01-01T00:00:00Z',
  // TODO: add domain fields
}

describe('<PascalName>List', () => {
  it('shows loading state', () => {
    server.use(
      http.get('/api/v1/<kebabNames>', () => new Promise(() => {}))
    )
    renderWithWrapper(<<PascalName>List />)
    expect(screen.getByRole('status')).toBeInTheDocument()
  })

  it('renders items when loaded', async () => {
    server.use(
      http.get('/api/v1/<kebabNames>', () =>
        HttpResponse.json({
          success: true,
          data: [mock<PascalName>],
          meta: { nextCursor: null, total: 1 },
        })
      )
    )
    renderWithWrapper(<<PascalName>List />)
    await screen.findByRole('list', { name: '<PascalNames>' })
    expect(screen.getAllByRole('listitem')).toHaveLength(1)
  })

  it('shows empty state when no items', async () => {
    server.use(
      http.get('/api/v1/<kebabNames>', () =>
        HttpResponse.json({ success: true, data: [], meta: { nextCursor: null, total: 0 } })
      )
    )
    renderWithWrapper(<<PascalName>List />)
    expect(await screen.findByText('No <camelNames> found.')).toBeInTheDocument()
  })

  it('shows error state on fetch failure', async () => {
    server.use(
      http.get('/api/v1/<kebabNames>', () =>
        HttpResponse.json({ error: { message: 'Server error', code: 'INTERNAL_ERROR' } }, { status: 500 })
      )
    )
    renderWithWrapper(<<PascalName>List />)
    expect(await screen.findByRole('alert')).toBeInTheDocument()
  })
})
```

---

### `src/features/<kebabName>/components/<PascalName>List/index.ts`

```typescript
export { <PascalName>List } from './<PascalName>List'
```

---

### `src/features/<kebabName>/components/<PascalName>Form/<PascalName>Form.tsx`

```tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import toast from 'react-hot-toast'
import { useCreate<PascalName> } from '../../api/<kebabName>.api'
import { create<PascalName>Schema, type Create<PascalName>Input } from '../../types'
import { ApiError } from '@/utils/errors'

interface <PascalName>FormProps {
  onSuccess?: () => void
}

export function <PascalName>Form({ onSuccess }: <PascalName>FormProps) {
  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<Create<PascalName>Input>({
    resolver: zodResolver(create<PascalName>Schema),
  })

  const { mutate, isPending } = useCreate<PascalName>()

  function onSubmit(data: Create<PascalName>Input) {
    mutate(data, {
      onSuccess: () => {
        reset()
        onSuccess?.()
      },
      onError: (error) => {
        if (error instanceof ApiError && error.details) {
          Object.entries(error.details).forEach(([field, message]) => {
            setError(field as keyof Create<PascalName>Input, { message })
          })
          return
        }
        toast.error(error instanceof ApiError ? error.message : 'Something went wrong')
      },
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      {/* TODO: add form fields */}
      {/* Example field:
      <div>
        <label htmlFor="fieldName">Field Label</label>
        <input id="fieldName" {...register('fieldName')} aria-describedby={errors.fieldName ? 'fieldName-error' : undefined} />
        {errors.fieldName && (
          <p id="fieldName-error" role="alert" className="text-red-600 text-sm">
            {errors.fieldName.message}
          </p>
        )}
      </div>
      */}

      <button type="submit" disabled={isPending || isSubmitting}>
        {isPending ? 'Saving...' : 'Create <PascalName>'}
      </button>
    </form>
  )
}
```

---

### `src/features/<kebabName>/components/<PascalName>Form/<PascalName>Form.test.tsx`

```tsx
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi } from 'vitest'
import { http, HttpResponse } from 'msw'
import { <PascalName>Form } from './<PascalName>Form'
import { renderWithWrapper } from '@/test/utils'
import { server } from '@/test/server'

describe('<PascalName>Form', () => {
  it('renders the form', () => {
    renderWithWrapper(<<PascalName>Form />)
    expect(screen.getByRole('button', { name: /create/i })).toBeInTheDocument()
  })

  it('submits valid data and calls onSuccess', async () => {
    const user = userEvent.setup()
    const onSuccess = vi.fn()

    server.use(
      http.post('/api/v1/<kebabNames>', () =>
        HttpResponse.json({
          success: true,
          data: { id: 'new-id', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
        }, { status: 201 })
      )
    )

    renderWithWrapper(<<PascalName>Form onSuccess={onSuccess} />)

    // TODO: fill in form fields
    // await user.type(screen.getByLabelText('Field Label'), 'value')

    await user.click(screen.getByRole('button', { name: /create/i }))

    await waitFor(() => expect(onSuccess).toHaveBeenCalledOnce())
  })

  it('shows server field errors inline', async () => {
    const user = userEvent.setup()

    server.use(
      http.post('/api/v1/<kebabNames>', () =>
        HttpResponse.json({
          error: { message: 'Validation failed', code: 'VALIDATION_ERROR', details: { fieldName: 'Already taken' } },
        }, { status: 400 })
      )
    )

    renderWithWrapper(<<PascalName>Form />)
    await user.click(screen.getByRole('button', { name: /create/i }))

    expect(await screen.findByRole('alert')).toBeInTheDocument()
  })

  it('disables submit button while pending', async () => {
    const user = userEvent.setup()

    server.use(
      http.post('/api/v1/<kebabNames>', () => new Promise(() => {}))
    )

    renderWithWrapper(<<PascalName>Form />)
    await user.click(screen.getByRole('button', { name: /create/i }))

    expect(await screen.findByRole('button', { name: /saving/i })).toBeDisabled()
  })
})
```

---

### `src/features/<kebabName>/components/<PascalName>Form/index.ts`

```typescript
export { <PascalName>Form } from './<PascalName>Form'
```

---

### `src/features/<kebabName>/index.ts`

```typescript
export { <PascalName>List } from './components/<PascalName>List'
export { <PascalName>Form } from './components/<PascalName>Form'
export { use<PascalNames>, use<PascalName>, useCreate<PascalName>, useUpdate<PascalName>, useDelete<PascalName> } from './api/<kebabName>.api'
export type { <PascalName>, Create<PascalName>Input, Update<PascalName>Input } from './types'
```

---

## Backend scaffold

### `src/types/<kebabName>.types.ts`

```typescript
import { z } from 'zod'

export const create<PascalName>Schema = z.object({
  // TODO: add required fields
})

export const update<PascalName>Schema = create<PascalName>Schema.partial()

export const <camelName>ParamsSchema = z.object({
  id: z.string().uuid(),
})

export const list<PascalNames>QuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().optional(),
})

export type Create<PascalName>Input = z.infer<typeof create<PascalName>Schema>
export type Update<PascalName>Input = z.infer<typeof update<PascalName>Schema>
export type List<PascalNames>Query = z.infer<typeof list<PascalNames>QuerySchema>
```

---

### `src/repositories/<kebabName>.repository.ts`

```typescript
import { prisma } from '../lib/prisma'
import { decodeCursor, encodeCursor } from '../utils/pagination'
import type { Create<PascalName>Input, Update<PascalName>Input, List<PascalNames>Query } from '../types/<kebabName>.types'

export async function findMany(userId: string, query: List<PascalNames>Query) {
  const cursorWhere = query.cursor
    ? { id: { lt: decodeCursor(query.cursor).id } }
    : {}

  const [items, total] = await prisma.$transaction([
    prisma.<camelName>.findMany({
      where: { userId, deletedAt: null, ...cursorWhere },
      orderBy: { createdAt: 'desc' },
      take: query.limit,
    }),
    prisma.<camelName>.count({ where: { userId, deletedAt: null } }),
  ])

  return { items, total }
}

export async function findById(id: string) {
  return prisma.<camelName>.findFirst({ where: { id, deletedAt: null } })
}

export async function create(data: Create<PascalName>Input & { userId: string }) {
  return prisma.<camelName>.create({ data })
}

export async function update(id: string, data: Update<PascalName>Input) {
  return prisma.<camelName>.update({ where: { id }, data })
}

export async function softDelete(id: string) {
  return prisma.<camelName>.update({ where: { id }, data: { deletedAt: new Date() } })
}
```

---

### `src/services/<kebabName>.service.ts`

```typescript
import * as <camelName>Repository from '../repositories/<kebabName>.repository'
import { NotFoundError, ForbiddenError } from '../utils/errors'
import { buildNextCursor } from '../utils/pagination'
import type { Create<PascalName>Input, Update<PascalName>Input, List<PascalNames>Query } from '../types/<kebabName>.types'
import type { AuthUser } from '../types/auth'

export async function list(user: AuthUser, query: List<PascalNames>Query) {
  const { items, total } = await <camelName>Repository.findMany(user.sub, query)
  return { items, total, nextCursor: buildNextCursor(items, query.limit) }
}

export async function getById(id: string, user: AuthUser) {
  const item = await <camelName>Repository.findById(id)
  if (!item) throw new NotFoundError('<PascalName>', id)
  if (item.userId !== user.sub) throw new ForbiddenError()
  return item
}

export async function create(input: Create<PascalName>Input, user: AuthUser) {
  return <camelName>Repository.create({ ...input, userId: user.sub })
}

export async function update(id: string, input: Update<PascalName>Input, user: AuthUser) {
  await getById(id, user)   // throws NotFoundError or ForbiddenError
  return <camelName>Repository.update(id, input)
}

export async function remove(id: string, user: AuthUser) {
  await getById(id, user)   // throws NotFoundError or ForbiddenError
  await <camelName>Repository.softDelete(id)
}
```

---

### `src/controllers/<kebabName>.controller.ts`

```typescript
import { Router } from 'express'
import { requireAuth } from '../middleware/auth'
import { asyncHandler } from '../utils/asyncHandler'
import { ok, created, noContent, paginated } from '../utils/response'
import * as <camelName>Service from '../services/<kebabName>.service'
import {
  create<PascalName>Schema,
  update<PascalName>Schema,
  <camelName>ParamsSchema,
  list<PascalNames>QuerySchema,
} from '../types/<kebabName>.types'

export const <camelNames>Router = Router()

<camelNames>Router.use(requireAuth)

<camelNames>Router.get('/', asyncHandler(async (req, res) => {
  const query = list<PascalNames>QuerySchema.parse(req.query)
  const { items, total, nextCursor } = await <camelName>Service.list(req.user, query)
  paginated(res, items, { nextCursor, total })
}))

<camelNames>Router.get('/:id', asyncHandler(async (req, res) => {
  const { id } = <camelName>ParamsSchema.parse(req.params)
  const item = await <camelName>Service.getById(id, req.user)
  ok(res, item)
}))

<camelNames>Router.post('/', asyncHandler(async (req, res) => {
  const input = create<PascalName>Schema.parse(req.body)
  const item = await <camelName>Service.create(input, req.user)
  created(res, item)
}))

<camelNames>Router.patch('/:id', asyncHandler(async (req, res) => {
  const { id } = <camelName>ParamsSchema.parse(req.params)
  const input = update<PascalName>Schema.parse(req.body)
  const item = await <camelName>Service.update(id, input, req.user)
  ok(res, item)
}))

<camelNames>Router.delete('/:id', asyncHandler(async (req, res) => {
  const { id } = <camelName>ParamsSchema.parse(req.params)
  await <camelName>Service.remove(id, req.user)
  noContent(res)
}))
```

After writing the controller, check if `src/routes/index.ts` exists and add the router registration:

```typescript
import { <camelNames>Router } from '../controllers/<kebabName>.controller'
app.use('/api/v1/<kebabNames>', <camelNames>Router)
```

---

## Bruno scaffold

Create `bruno/<kebabName>/` with five request files.

### `bruno/<kebabName>/list-<kebabNames>.bru`

```
meta {
  name: List <PascalNames>
  type: http
  seq: 1
}

get {
  url: {{baseUrl}}/api/v1/<kebabNames>?limit=20
  auth: bearer
}

auth:bearer {
  token: {{token}}
}

tests {
  test("status is 200", function() {
    expect(res.status).to.equal(200)
  })
  test("returns paginated envelope", function() {
    expect(res.body.success).to.equal(true)
    expect(res.body).to.have.property("meta")
    expect(res.body.meta).to.have.property("nextCursor")
  })
}
```

### `bruno/<kebabName>/create-<kebabName>.bru`

```
meta {
  name: Create <PascalName>
  type: http
  seq: 2
}

post {
  url: {{baseUrl}}/api/v1/<kebabNames>
  body: json
  auth: bearer
}

auth:bearer {
  token: {{token}}
}

body:json {
  {
    // TODO: add required fields
  }
}

script:post-response {
  if (res.status === 201) {
    bru.setEnvVar("created<PascalName>Id", res.body.data.id)
  }
}

tests {
  test("status is 201", function() {
    expect(res.status).to.equal(201)
  })
  test("returns created item", function() {
    expect(res.body.success).to.equal(true)
    expect(res.body.data).to.have.property("id")
  })
}
```

### `bruno/<kebabName>/get-<kebabName>.bru`

```
meta {
  name: Get <PascalName>
  type: http
  seq: 3
}

get {
  url: {{baseUrl}}/api/v1/<kebabNames>/{{created<PascalName>Id}}
  auth: bearer
}

auth:bearer {
  token: {{token}}
}

tests {
  test("status is 200", function() {
    expect(res.status).to.equal(200)
  })
  test("returns correct item", function() {
    expect(res.body.data.id).to.equal(bru.getEnvVar("created<PascalName>Id"))
  })
}
```

### `bruno/<kebabName>/update-<kebabName>.bru`

```
meta {
  name: Update <PascalName>
  type: http
  seq: 4
}

patch {
  url: {{baseUrl}}/api/v1/<kebabNames>/{{created<PascalName>Id}}
  body: json
  auth: bearer
}

auth:bearer {
  token: {{token}}
}

body:json {
  {
    // TODO: add fields to update
  }
}

tests {
  test("status is 200", function() {
    expect(res.status).to.equal(200)
  })
}
```

### `bruno/<kebabName>/delete-<kebabName>.bru`

```
meta {
  name: Delete <PascalName>
  type: http
  seq: 5
}

delete {
  url: {{baseUrl}}/api/v1/<kebabNames>/{{created<PascalName>Id}}
  auth: bearer
}

auth:bearer {
  token: {{token}}
}

tests {
  test("status is 204", function() {
    expect(res.status).to.equal(204)
  })
}
```

---

## After writing all files

Print a summary:

```
✅ Scaffolded: <featureName> (<scope>)

Frontend (src/features/<kebabName>/):
  types.ts
  api/<kebabName>.api.ts
  components/<PascalName>List/<PascalName>List.tsx
  components/<PascalName>List/<PascalName>List.test.tsx
  components/<PascalName>List/index.ts
  components/<PascalName>Form/<PascalName>Form.tsx
  components/<PascalName>Form/<PascalName>Form.test.tsx
  components/<PascalName>Form/index.ts
  index.ts

Backend:
  src/types/<kebabName>.types.ts
  src/repositories/<kebabName>.repository.ts
  src/services/<kebabName>.service.ts
  src/controllers/<kebabName>.controller.ts

Bruno (bruno/<kebabName>/):
  list-<kebabNames>.bru
  create-<kebabName>.bru
  get-<kebabName>.bru
  update-<kebabName>.bru
  delete-<kebabName>.bru

Next steps:
  1. Add domain fields to src/features/<kebabName>/types.ts and src/types/<kebabName>.types.ts
  2. Add Prisma model for <camelName> in prisma/schema.prisma
  3. Fill in Bruno request bodies with real field values
  4. Run: npx prisma migrate dev --name add-<kebabName>
```
