# Development Action Checklists

Apply the relevant checklist before marking any task done. Every `[ ]` is a required step or a conscious skip — never silently omit.

---

## 1 — API Creation / Modification

Use when: creating a new route, modifying an existing controller, adding a new HTTP method to an existing resource.

### Route & naming
- [ ] Route follows REST convention — plural noun, kebab-case (`/api/v1/order-items`)
- [ ] HTTP method matches the action — GET read, POST create, PUT replace, PATCH partial update, DELETE remove
- [ ] No verb in path — state changes go via PATCH body (`{ status: "cancelled" }`), not `/cancel`
- [ ] Versioned under `/api/v1/` (or current version prefix)
- [ ] Route registered in `src/routes/` and mounted in `src/routes/index.ts`

### Request validation
- [ ] Zod schema validates the request body / query params / path params
- [ ] Schema exported from `src/types/<resource>.types.ts`
- [ ] `listOrdersQuerySchema.parse(req.query)` for list endpoints — throws `ValidationError` → 400
- [ ] Path param validated (`.cuid()` or `.uuid()` — not bare `.string()`)

### Response
- [ ] Uses response helper — `ok()`, `created()`, `paginated()`, `noContent()` — never raw `res.json()`
- [ ] Success response wrapped in `{ success: true, data, meta }` envelope
- [ ] List endpoint uses `paginated()` with cursor, total, limit, hasMore
- [ ] DELETE returns 204 via `noContent(res)` — no body
- [ ] Correct HTTP status code for every branch (200 / 201 / 204 / 400 / 401 / 403 / 404 / 409 / 422 / 500)

### Auth & authorization
- [ ] `requireAuth` middleware applied to the router (or individual route if mixed auth)
- [ ] Ownership check performed — user can only access their own resources unless admin
- [ ] `requireGroup('Admin')` on admin-only sub-routes (Cognito group names are case-sensitive — use 'Admin')
- [ ] JWT claims used from `req.user` — never re-fetch user in controller

### Error handling
- [ ] Controller wrapped in `asyncHandler()` — no bare `async (req, res) =>` without try/catch
- [ ] Business rule violations throw `UnprocessableError` (422), not `ValidationError` (400)
- [ ] Resource-not-found throws `NotFoundError('Order', id)`
- [ ] Forbidden access throws `ForbiddenError()` — not `NotFoundError` (avoid leaking existence)
- [ ] No `try/catch` in controller — errors propagate to centralized `errorHandler`

### API documentation
- [ ] Route registered in `registry.registerPath()` in `src/docs/routes/<resource>.docs.ts`
- [ ] All path / query params documented with examples
- [ ] Request body references a named `$ref` schema (not inline)
- [ ] All realistic response codes documented (at minimum: success + 400 + 401 + 404 + 500)
- [ ] `security: [{ bearerAuth: [] }]` set (or explicitly public if unauthenticated)
- [ ] `npm run docs:export` run — `openapi.json` updated

### API routes file
- [ ] New path added to `src/lib/api-routes.ts` (backend) — no hardcoded strings in controllers
- [ ] Frontend `src/lib/api-routes.ts` updated if FE will call this route

### Tests
- [ ] Happy-path integration test — correct response shape and status code
- [ ] Validation failure test — 400 with `details` field
- [ ] Auth failure test — 401 when no token, 403 when wrong role/owner
- [ ] Not-found test — 404 response
- [ ] Business rule failure test — 422 where applicable

### Bruno collection
- [ ] Bruno request added / updated in `bruno/<feature>/`
- [ ] Example request body included

---

## 2 — Component Creation

Use when: creating any new React component (`.tsx` file) — whether shared, feature, or page-level.

### Before writing any code
- [ ] Checked `src/components/ui/` — does a shadcn/ui component already cover this?
- [ ] Checked `src/shared/components/` — does a composite component already exist?
- [ ] If shadcn component is needed but not installed: `npx shadcn@latest add <component>`

### File & structure
- [ ] File lives in the right folder:
  - `src/components/ui/` — shadcn primitives (never hand-edited)
  - `src/shared/components/` — reusable composite components wrapping shadcn
  - `src/features/<name>/components/` — feature-specific components
- [ ] Filename matches the component name — `OrderCard.tsx` exports `OrderCard`
- [ ] Named export — no default export inside feature folders
- [ ] Props defined as an explicit `interface` — not inline type, not `type`
- [ ] Component is ≤ 150 lines — extract sub-components or hooks if longer

### TypeScript
- [ ] No `any` — all props, event handlers, and return types are typed
- [ ] Event handlers typed: `React.MouseEvent<HTMLButtonElement>`, `React.ChangeEvent<HTMLInputElement>`, etc.
- [ ] Children typed as `React.ReactNode` where accepted
- [ ] Optional props have `?` — required props have no default unless it's meaningful

### Styling & UI
- [ ] `cn()` from `src/lib/utils.ts` used for conditional class merging — no template literals
- [ ] No `style={{}}` for static values — Tailwind classes only
- [ ] Responsive classes used where layout changes at breakpoints (`sm:`, `md:`, `lg:`)
- [ ] shadcn `<Button>`, `<Badge>`, `<Card>`, etc. used instead of built-from-scratch equivalents

### Localisation
- [ ] Every user-visible string goes through `t()` — no hardcoded English in JSX
- [ ] Translation key added to `src/locales/en/<namespace>.json`
- [ ] Namespace matches the feature folder name

### Constants
- [ ] No magic numbers or timeouts inline — added to `src/lib/constants.ts`
- [ ] No hardcoded page size, debounce delay, or limit

### Business logic
- [ ] No API calls directly in component body — extracted to a `use<Feature>` hook
- [ ] No `useEffect` for data fetching — use React Query (`useQuery` / `useMutation`)
- [ ] No server state stored in `useState` — React Query is the source of truth
- [ ] Complex derived data in `useMemo` only if computation is genuinely expensive

### Accessibility
- [ ] Interactive elements are semantic (`<button>`, not `<div onClick>`)
- [ ] Images have `alt` text — empty `alt=""` for decorative images
- [ ] Form fields have associated `<label>` (shadcn `<FormLabel>` for form fields)
- [ ] Focus is visible — no `outline: none` without a replacement
- [ ] Keyboard navigation works — Tab, Enter, Escape where expected

### Performance
- [ ] Static JSX and non-primitive defaults hoisted outside the component
- [ ] No components defined inside components
- [ ] No barrel imports — direct imports only (`import { Button } from '@/components/ui/button'`)

### Testing
- [ ] Co-located test file `ComponentName.test.tsx` created
- [ ] Tests cover: loading state, success/data state, empty state, error state
- [ ] Interactive elements tested — button clicks, form submissions

---

## 3 — Page Creation / Update

Use when: creating a new route/page, adding a tab to a page, adding a new view, or significantly changing what a page renders.

### Route definition
- [ ] Page has a dedicated route in `src/routes.tsx` (or router config)
- [ ] Route path is human-readable and matches the resource: `/orders`, `/orders/new`, `/orders/:id`, `/orders/:id/edit`
- [ ] Create form → `/resource/new` (own page, not a modal)
- [ ] Edit form → `/resource/:id/edit` (own page, not a modal)
- [ ] Detail view → `/resource/:id`
- [ ] No modals for create/edit — `AlertDialog` for destructive confirmations only

### URL state
- [ ] All list state (filters, sort, search, pagination cursor) lives in URL search params via `useSearchParams()` — not `useState`
- [ ] Tab selection → `?tab=<name>` in URL
- [ ] Changing a filter resets the cursor to avoid stale pagination
- [ ] Browser back button restores previous state (no state in local variables)
- [ ] Page is deep-linkable — sharing the URL shows the same view

### Navigation
- [ ] After create/edit mutation: `navigate('/resource/:id')` to the detail page — not stay on form
- [ ] Breadcrumbs updated if the app uses them
- [ ] Page title (`document.title` or `<Helmet>`) updated

### Data fetching
- [ ] Data fetched via React Query `useQuery` — never `useEffect + fetch`
- [ ] Loading state rendered — skeleton or spinner
- [ ] Empty state rendered — not just blank space
- [ ] Error state rendered — error boundary or inline error UI
- [ ] Stale-while-revalidate handled — user sees cached data while fresh data loads

### User feedback
- [ ] Success mutations → `toast.success(t('orders.created'))` via Sonner
- [ ] Error mutations → `toast.error(t('errors.generic'))` (or specific message from API)
- [ ] Async operations with perceptible delay → `toast.promise(mutation, { loading, success, error })`
- [ ] No `alert()` or modal for feedback — always Sonner toast

### Localisation
- [ ] Page title goes through `t()`
- [ ] All headings, labels, button text, empty-state copy goes through `t()`
- [ ] Translation keys added to `src/locales/en/<namespace>.json`
- [ ] Dynamic values use interpolation: `t('orders.count', { count: total })`

### Constants & routes
- [ ] Page path constant added to `src/lib/api-routes.ts` if navigated to programmatically
- [ ] Magic values (page size, max upload size, poll interval) in `src/lib/constants.ts`

### Accessibility
- [ ] Page has a unique `<h1>` heading
- [ ] Focus management on route change (React Router handles this, verify if custom)
- [ ] Skip-to-content link present if there's a persistent nav

### Testing
- [ ] E2E spec exists (or updated) for the primary happy path
- [ ] Unit test for the page component covers loading / success / empty / error states
- [ ] URL state tested — filter change updates URL, URL param renders correct content

---

## 4 — API Integration (Frontend)

Use when: connecting a frontend component or page to a backend API endpoint for the first time, or adding a new query/mutation hook.

### API route
- [ ] Endpoint path defined in `src/lib/api-routes.ts` — not hardcoded in the hook
- [ ] Path uses the constant: `API_ROUTES.orders.list` not `'/api/v1/orders'`

### TypeScript types
- [ ] Response type defined (or imported from `src/types/`) matching the API response envelope
- [ ] Request body type defined for mutations
- [ ] No `any` in API response handling — use `SuccessResponse<Order>`, `PaginatedResponse<Order>`, etc.
- [ ] If `openapi-typescript` is used: type imported from `src/types/api.gen.ts`

### React Query hook
- [ ] Query lives in `src/features/<name>/api/<name>.api.ts` — not inline in component
- [ ] `useQuery` for reads, `useMutation` for writes
- [ ] `queryKey` is an array that includes all cache-busting variables: `['orders', { status, cursor }]`
- [ ] `staleTime` set for data that doesn't change frequently (e.g. `1000 * 60 * 5` for 5 min)
- [ ] Paginated list uses `useInfiniteQuery` with `getNextPageParam` reading `pagination.nextCursor`

### Mutations
- [ ] `onSuccess`: invalidate related queries (`queryClient.invalidateQueries`) + navigate if needed
- [ ] `onError`: `toast.error()` with a human-readable message — never expose raw API error to user
- [ ] `onSuccess` shows `toast.success()` confirmation
- [ ] Long-running mutations use `toast.promise(mutateAsync(...), { loading, success, error })`
- [ ] Mutation is disabled / button shows loading state while `isPending`

### Error handling
- [ ] `isError` state handled in the component — not just ignored
- [ ] 401 errors trigger sign-out / redirect to login
- [ ] 403 errors show a "not authorized" message, not a blank screen
- [ ] 404 errors show a "not found" page or inline empty state
- [ ] Network errors surface a user-friendly toast — not a raw `Error: Network request failed`

### Loading & empty states
- [ ] `isLoading` / `isPending` renders a skeleton or spinner — not blank
- [ ] Empty array (`data.length === 0`) renders an empty state — not blank
- [ ] Skeleton matches the shape of the loaded content (avoids layout shift)

### Security
- [ ] Auth token attached via the `apiClient` interceptor — not manually per-request
- [ ] No sensitive data stored in `localStorage` or `sessionStorage` from the response
- [ ] PII fields (email, name, phone) not logged in console

---

## 5 — Adding a Log Statement

Use when: adding any `logger.*` call, adding structured context to an existing log, or deciding what to log in a new code path.

### Log level
- [ ] `logger.error` — unexpected failures, caught exceptions, unhandled promise rejections
- [ ] `logger.warn` — expected-but-notable conditions: deprecated feature used, retry attempt, rate limit approaching
- [ ] `logger.info` — significant business events: order created, user signed in, payment processed
- [ ] `logger.debug` — developer detail only: query params, intermediate values (stripped in production)
- [ ] No `console.log` / `console.error` — always pino logger

### Structured context
- [ ] First argument is a context object, second is the message string: `logger.info({ userId, orderId }, 'Order created')`
- [ ] Message is a static string — dynamic values go in the context object, not string interpolation
- [ ] Context includes identifiers that make the log searchable: `userId`, `orderId`, `requestId`
- [ ] `requestId` always included on request-scoped logs (set automatically by pino-http on `req.id`)
- [ ] `correlationId` included in child logger — propagated from `X-Correlation-Id` header via pino-http; ties logs across services

### PII & secrets
- [ ] No email addresses in log messages or context
- [ ] No passwords, tokens, API keys, or secrets ever logged
- [ ] No full name or phone number logged — use an ID to look up user details in logs
- [ ] No full request body logged — log specific fields, not `req.body`
- [ ] Credit card numbers, SSNs, health data — never log

### Error logs
- [ ] `logger.error({ err, userId, requestId }, 'Payment failed')` — pass the error as `err` key (pino serializes it)
- [ ] Stack trace included via the `err` object — not manually concatenated into the message
- [ ] Sentry `captureException(err)` called for unexpected 5xx errors (handled by centralized errorHandler — don't duplicate)

### Volume & noise
- [ ] No log in a tight loop — log once before/after, not per iteration
- [ ] Debug logs wrapped in `if (process.env.NODE_ENV === 'development')` or use `logger.debug` (disabled in prod)
- [ ] Repeated polling / health-check paths excluded or sampled — not logged on every call

### Verification
- [ ] Log appears correctly in local dev (`pino-pretty` output)
- [ ] CloudWatch log group and metric filter updated if a new log pattern needs alarming

---

## 6 — DB Query (Prisma)

Use when: writing a new Prisma query, modifying an existing repository function, or adding a raw SQL query.

### Query correctness
- [ ] `where: { deletedAt: null }` on every `findMany` / `findFirst` that should exclude soft-deleted records
- [ ] `findUniqueOrThrow` / `findFirstOrThrow` used when a missing record is an error — throws `P2025` → `NotFoundError`
- [ ] `select` used to return only the fields needed — no bare `findMany()` returning every column
- [ ] Pagination uses cursor-based pattern — never `skip: offset` on large tables

### N+1 prevention
- [ ] No loop with a query inside — use `include` or nested `select` to load related data in one query
- [ ] If batching is needed: `prisma.user.findMany({ where: { id: { in: ids } } })` not `Promise.all(ids.map(...))`

### Transactions
- [ ] Multi-step mutations (create + update, create + decrement) use `prisma.$transaction([])`
- [ ] Logic-dependent transactions (check stock → create order) use `prisma.$transaction(async tx => { ... })`
- [ ] Transaction does not call external services (HTTP, email) — side effects go after the transaction commits

### Raw SQL
- [ ] No string interpolation in `$queryRaw` — always tagged template literal: `prisma.$queryRaw\`SELECT ... WHERE id = ${id}\``
- [ ] Raw SQL only used when Prisma ORM cannot express the query (window functions, CTEs, `LATERAL` joins)

### Performance
- [ ] Query plan reviewed for new queries on large tables — `EXPLAIN ANALYZE` in dev
- [ ] Index exists for every `WHERE` column and every `ORDER BY` column
- [ ] `take` / `limit` always set — no unbounded `findMany()` without pagination
- [ ] Compound index considered for queries filtering by 2+ columns

### Security
- [ ] Query scoped to the authenticated user: `where: { userId: req.user.sub }` — no cross-user data leakage
- [ ] Admin-bypass queries gated behind `requireGroup('Admin')` middleware
- [ ] No raw `$executeRaw` with user-supplied data without parameterisation

---

## 7 — DB Schema Change (Prisma Model / Migration)

Use when: adding a new model, adding/removing/renaming a column, adding an index, or adding a constraint.

### Prisma schema
- [ ] New model includes standard base fields: `id`, `createdAt`, `updatedAt`, `deletedAt?`
- [ ] `id` uses `@default(cuid())` — not auto-increment int
- [ ] `@@map("snake_case_table_name")` set on every model
- [ ] Every foreign key has explicit `onDelete` behaviour (`Cascade`, `Restrict`, `SetNull`)
- [ ] Every foreign key column has a matching `@@index([fkColumn])`
- [ ] Every column used in `WHERE` or `ORDER BY` queries has an index
- [ ] `@@unique` constraint set where business rules require uniqueness (e.g. `@@unique([userId, productId])`)
- [ ] Nullable columns are truly optional — required-at-app-layer columns are `NOT NULL` with a default or non-nullable

### Migration file
- [ ] Generated with a descriptive name: `npx prisma migrate dev --name add_orders_shipped_at`
- [ ] Migration file header comment includes: description, reversibility, breaking-change flag
- [ ] New column added as **nullable** (or with a default) — never `NOT NULL` without a default on existing table
- [ ] `NOT NULL` on existing table uses `NOT VALID` + `VALIDATE CONSTRAINT` pattern (two migrations)
- [ ] Index created with `CONCURRENTLY` and `-- This migration does not use a transaction` comment
- [ ] No full-table rewrites — `ALTER COLUMN TYPE` on a large table → use a new column instead
- [ ] No `RENAME COLUMN` — use expand-contract: add new column → dual-write → drop old column
- [ ] Backfill uses batched `UPDATE` (chunks of 1000) — not a single `UPDATE` without `LIMIT`
- [ ] Migration is idempotent where possible (`IF NOT EXISTS` / `IF EXISTS` guards)

### Safety checklist
- [ ] Migration reviewed with the **safe migration checklist** in `database-sql` skill
- [ ] `npx prisma migrate status` shows only this migration as pending before applying
- [ ] Migration tested on a copy of production data volume (or staging) before deploying to prod

### Seeders & test data
- [ ] Seeder updated if the new table/column needs seed data
- [ ] Seeder uses `upsert` — not `create` (idempotent)
- [ ] Test fixtures updated to include the new field where needed

### API impact
- [ ] If the model is exposed via API: Zod schema updated to include/exclude the new field
- [ ] OpenAPI schema updated (`npm run docs:export`)
- [ ] Frontend TypeScript types regenerated if using `openapi-typescript`
- [ ] Response helper still returns the right shape — check `select` clauses in repositories

### Breaking-change check
- [ ] Removing a column: all code reading it is removed and deployed **before** the `DROP COLUMN` migration
- [ ] Renaming a column: expand-contract pattern used — never rename directly
- [ ] Changing a column type: new column added alongside old one; app migrated; old column dropped later
- [ ] Any removal that changes the public API shape → API version bump (v1 → v2)

---

## Combined checklist — quick reference

| Checklist | Key pillars |
|---|---|
| **API** | Zod validation · response envelope · asyncHandler · Swagger registered · tests |
| **Component** | shadcn/ui first · typed props · `t()` · constants · named export · test |
| **Page** | Dedicated route · `useSearchParams` · toast feedback · loading/empty/error · E2E |
| **API Integration** | `api-routes.ts` · React Query · invalidate on success · error toast · skeleton |
| **Logging** | Pino logger · correct level · structured context · no PII · `requestId` |
| **DB Query** | `deletedAt: null` · no N+1 · cursor pagination · transaction · scoped to user |
| **DB Schema** | Base fields · FK `onDelete` · indexes · safe migration · seeder · API updated |
