---
name: test
description: Run or generate tests — unit (Vitest), E2E (Playwright), API (Bruno), coverage reports, watch mode. Usage — /my-dev-standards:test <sub-command> [args]
argument-hint: <unit|e2e|api|coverage|watch|generate> [file-or-feature]
arguments:
  - name: subcommand
    description: "Sub-command: unit, e2e, api, coverage, watch, generate"
  - name: target
    description: "Optional file path, feature name, or spec file to scope the operation"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash(git *)
  - Bash(npm *)
  - Bash(npx *)
  - Bash(ls *)
  - Bash(find *)
---

# Test Runner & Generator

Run tests, check coverage, or generate test stubs for new code.

Sub-command is `$ARGUMENTS[0]`. Optional target path/file is the rest of `$ARGUMENTS`.

---

## `/test unit [file-or-feature]`

Run Vitest unit tests. Optional path scopes to a file or directory.

```bash
# All unit tests
npm test -- --run

# Specific file or directory
npx vitest run $TARGET

# Watch mode for a file
npx vitest $TARGET
```

After running, summarize: pass count, fail count, test files. Print any failing test names and their error messages.

---

## `/test e2e [spec-file]`

Run Playwright E2E tests.

```bash
# All E2E tests
npx playwright test

# Specific spec file
npx playwright test $SPEC_FILE

# With UI (headed mode)
npx playwright test --headed $SPEC_FILE
```

After running, summarize results by spec file. Print screenshots of any failures from `playwright-report/`.

---

## `/test api [collection-name]`

Run Bruno API tests.

```bash
# Run specific Bruno collection
npx @usebruno/cli run bruno/$COLLECTION --env local

# Run all Bruno collections
for dir in bruno/*/; do
  npx @usebruno/cli run "$dir" --env local
done
```

Summarize: requests passed, failed, error messages.

---

## `/test coverage [threshold]`

Run Vitest with coverage report. Default threshold: 80%.

```bash
npx vitest run --coverage
```

After running, parse the coverage summary and flag any files below the threshold:
- Print files with coverage < 80% (or `$THRESHOLD`%)
- Print overall: statements, branches, functions, lines coverage
- If any file is below threshold, exit with a warning

---

## `/test watch [file]`

Run Vitest in watch mode for fast feedback during development.

```bash
# Watch all
npx vitest

# Watch specific file
npx vitest $FILE
```

This runs interactively. Inform the user: "Vitest is now watching. Press `q` to quit, `r` to rerun."

---

## `/test generate [file-or-feature]`

Generate test stubs for existing code that lacks tests. Reads the source file(s), analyzes what needs testing, writes comprehensive test files.

If no target given, use changed files from the current branch:
```bash
git diff develop...HEAD --name-only | grep -E '\.(ts|tsx)$'
```

### Backend service/controller test pattern

Read the source file, identify all exported functions and edge cases, then write `<filename>.test.ts`:

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { OrdersService } from './orders.service';
import { OrdersRepository } from '../repositories/orders.repository';
import { NotFoundError, ForbiddenError } from '../utils/errors';

vi.mock('../repositories/orders.repository');

describe('OrdersService', () => {
  beforeEach(() => { vi.clearAllMocks(); });

  describe('getById', () => {
    it('returns the order when it belongs to the requesting user', async () => {
      const mockOrder = { id: 'order-1', userId: 'user-123' };
      vi.mocked(OrdersRepository.findById).mockResolvedValue(mockOrder as any);

      const result = await OrdersService.getById('order-1', 'user-123');
      expect(result).toEqual(mockOrder);
    });

    it('throws NotFoundError when order does not exist', async () => {
      vi.mocked(OrdersRepository.findById).mockResolvedValue(null);
      await expect(OrdersService.getById('missing', 'user-123')).rejects.toThrow(NotFoundError);
    });

    it('throws ForbiddenError when order belongs to a different user', async () => {
      vi.mocked(OrdersRepository.findById).mockResolvedValue({ id: 'order-1', userId: 'other-user' } as any);
      await expect(OrdersService.getById('order-1', 'user-123')).rejects.toThrow(ForbiddenError);
    });
  });
});
```

### React component test pattern

```tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { server } from '@/test/server';
import { createWrapper } from '@/test/utils';
import { OrderList } from './OrderList';

describe('OrderList', () => {
  it('shows loading skeleton while fetching', () => {
    render(<OrderList />, { wrapper: createWrapper() });
    expect(screen.getByRole('status', { name: /loading/i })).toBeInTheDocument();
  });

  it('renders orders after successful fetch', async () => {
    server.use(
      http.get('/api/v1/orders', () =>
        HttpResponse.json({ success: true, data: [{ id: '1', status: 'pending', total: 99 }] })
      )
    );
    render(<OrderList />, { wrapper: createWrapper() });
    await waitFor(() => expect(screen.getByText('$99.00')).toBeInTheDocument());
  });

  it('shows error message when fetch fails', async () => {
    server.use(http.get('/api/v1/orders', () => HttpResponse.json({}, { status: 500 })));
    render(<OrderList />, { wrapper: createWrapper() });
    await waitFor(() => expect(screen.getByRole('alert')).toBeInTheDocument());
  });

  it('shows empty state when no orders', async () => {
    server.use(http.get('/api/v1/orders', () => HttpResponse.json({ success: true, data: [] })));
    render(<OrderList />, { wrapper: createWrapper() });
    await waitFor(() => expect(screen.getByText(/no orders/i)).toBeInTheDocument());
  });
});
```

### E2E test pattern (Playwright)

Create in `e2e/<feature>.spec.ts`:

```ts
import { test, expect } from '@playwright/test';

test.describe('Orders', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL!);
    await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!);
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL('/dashboard');
  });

  test('user can view order list', async ({ page }) => {
    await page.goto('/orders');
    await expect(page.getByRole('heading', { name: /orders/i })).toBeVisible();
    await expect(page.getByRole('list', { name: /orders/i })).toBeVisible();
  });

  test('unauthenticated user is redirected to login', async ({ page }) => {
    await page.context().clearCookies();
    await page.goto('/orders');
    await expect(page).toHaveURL('/login');
  });
});
```

### Bruno API collection pattern

Create `bruno/<resource>/`:
```
create-<resource>.bru        — POST success (201)
create-<resource>-error.bru  — POST validation error (400)
get-<resource>.bru           — GET list (200)
get-<resource>-by-id.bru     — GET by ID (200 + 404)
auth-error.bru               — Missing/invalid token (401)
```

After writing each test file, run it to verify no syntax errors:
```bash
npx vitest run <test-file> 2>&1 | tail -20
```

Fix any failures before moving on.

### Generate summary

```
✅ Tests generated

Unit tests:  N files — N test cases
E2E tests:   N scenarios in e2e/
Bruno:       N requests in bruno/<resource>/

Run: /test unit     — run unit tests
     /test e2e      — run E2E tests
     /test coverage — check coverage %
```
