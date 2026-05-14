# Jest Standards

---

## Configuration

```typescript
// jest.config.ts
import type { Config } from 'jest'

const config: Config = {
  preset: 'ts-jest',                    // or 'babel-jest' for non-TS projects
  testEnvironment: 'node',              // 'jsdom' for browser/React tests
  rootDir: '.',
  testMatch: ['**/*.test.ts', '**/*.spec.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',     // mirror your tsconfig paths
  },
  setupFilesAfterFramework: ['./jest.setup.ts'],
  clearMocks: true,       // clears mock.calls and mock.instances between tests
  restoreMocks: true,     // restores spies after each test
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/index.ts',   // barrel exports don't need coverage
  ],
  coverageThresholds: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
    },
  },
}

export default config
```

```typescript
// jest.setup.ts — runs after framework is installed
import '@testing-library/jest-dom'  // if using React + Testing Library
```

---

## Test structure

```typescript
// src/services/user.service.test.ts

import { UserService } from './user.service'
import { userRepository } from '../repositories/user.repository'

// Mock at the module level, at the top
jest.mock('../repositories/user.repository')

const mockUserRepository = jest.mocked(userRepository)

describe('UserService', () => {
  describe('getById', () => {
    it('returns the user when found', async () => {
      // Arrange
      const user = { id: '1', email: 'test@example.com' }
      mockUserRepository.findById.mockResolvedValue(user)

      // Act
      const result = await UserService.getById('1')

      // Assert
      expect(result).toEqual(user)
    })

    it('throws NotFoundError when user does not exist', async () => {
      // Arrange
      mockUserRepository.findById.mockResolvedValue(null)

      // Act & Assert
      await expect(UserService.getById('missing')).rejects.toThrow('User not found')
    })

    it('throws when caller does not own the resource', async () => {
      // Arrange
      mockUserRepository.findById.mockResolvedValue({ id: '1', ownerId: 'other' })

      // Act & Assert
      await expect(UserService.getById('1', 'me')).rejects.toThrow('Forbidden')
    })
  })
})
```

---

## Mocking patterns

### Module mocks

```typescript
// Mock an entire module
jest.mock('../lib/email', () => ({
  sendEmail: jest.fn().mockResolvedValue({ messageId: 'test-id' }),
}))

// Access the mock in tests
import { sendEmail } from '../lib/email'
const mockSendEmail = jest.mocked(sendEmail)

it('sends a welcome email', async () => {
  await createUser({ email: 'test@example.com' })
  expect(mockSendEmail).toHaveBeenCalledWith({
    to: 'test@example.com',
    template: 'welcome',
  })
})
```

### Partial mocks with spyOn

```typescript
import * as dateUtils from '../utils/date'

it('uses the current date', () => {
  // Arrange — spy on one function, leave the rest real
  const spy = jest.spyOn(dateUtils, 'now').mockReturnValue(new Date('2024-01-15'))

  // Act
  const result = getDeadline(7)

  // Assert
  expect(result).toEqual(new Date('2024-01-22'))

  // Spy is automatically restored by restoreMocks: true
})
```

### Factory functions over beforeEach mutation

```typescript
// ✅ Factory — explicit, composable
const makeUser = (overrides = {}) => ({
  id: '1',
  email: 'test@example.com',
  role: 'user',
  ...overrides,
})

it('allows admin access', () => {
  const admin = makeUser({ role: 'admin' })
  expect(canAccess(admin, '/admin')).toBe(true)
})

// ❌ Shared mutable state — leads to order-dependent tests
let user: User
beforeEach(() => {
  user = { id: '1', email: 'test@example.com', role: 'user' }
})
```

---

## Async tests

```typescript
// ✅ Always await or return promises
it('resolves with the expected value', async () => {
  const result = await fetchUser('1')
  expect(result.email).toBe('test@example.com')
})

// ✅ Testing rejections
it('rejects on network failure', async () => {
  mockFetch.mockRejectedValue(new Error('Network error'))
  await expect(fetchUser('1')).rejects.toThrow('Network error')
})

// ✅ resolves/rejects matchers (shorter but be careful — always await)
it('resolves with user data', async () => {
  await expect(fetchUser('1')).resolves.toMatchObject({ email: expect.any(String) })
})

// ❌ Missing await — test passes even if the assertion fails
it('BAD: missing await', () => {
  expect(fetchUser('1')).resolves.toBe(null)  // silently passes even if wrong
})
```

### Fake timers

```typescript
describe('debounce', () => {
  beforeEach(() => {
    jest.useFakeTimers()
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  it('does not call fn immediately', () => {
    const fn = jest.fn()
    debounce(fn, 500)()
    expect(fn).not.toHaveBeenCalled()
  })

  it('calls fn after the delay', () => {
    const fn = jest.fn()
    debounce(fn, 500)()
    jest.advanceTimersByTime(500)
    expect(fn).toHaveBeenCalledTimes(1)
  })
})
```

---

## Parameterised tests

```typescript
// test.each — avoid copy-paste for similar tests
test.each([
  ['valid email',     'user@example.com', true],
  ['missing @',       'userexample.com',  false],
  ['missing domain',  'user@',            false],
  ['empty string',    '',                 false],
])('isValidEmail(%s) returns %s', (_, email, expected) => {
  expect(isValidEmail(email)).toBe(expected)
})
```

---

## Snapshot tests

Use sparingly — only for stable, complex output that is hard to assert field-by-field:

```typescript
it('renders the correct HTML structure', () => {
  const html = renderToString(<UserCard user={mockUser} />)
  expect(html).toMatchSnapshot()
})
```

**Rules:**
- Commit snapshots — they are part of the test
- Review snapshot diffs in PRs as carefully as code diffs
- Never use `--updateSnapshot` blindly to fix a failing test without reviewing the change
- Prefer inline snapshots (`toMatchInlineSnapshot()`) for small outputs

---

## Coverage

```bash
# Run with coverage report
jest --coverage

# Run in watch mode
jest --watch

# Run only changed files (since last commit)
jest --onlyChanged

# Run tests matching a name pattern
jest --testNamePattern="getById"

# Run tests in a specific file
jest src/services/user.service.test.ts
```

```typescript
// Exclude from coverage when intentional (add a comment explaining why)
/* istanbul ignore next */
function platformSpecificCode() {
  // Only runs on Windows — not testable in CI
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `it.only()` merged to main | Use `jest --testNamePattern` in dev; never merge `.only` |
| Unawaited async assertions | Always `await` or `return` promises in tests |
| Testing implementation (private methods) | Test through the public API; if private logic is complex, extract to its own module |
| Mock reset issues between tests | Use `clearMocks: true` + `restoreMocks: true` in config |
| Order-dependent tests | Each test must be fully independent; use factory functions not shared state |
