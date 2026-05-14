---
name: jest
description: Jest unit testing conventions — configuration, describe/it structure, mocking, async tests, and coverage. Load when working with Jest test files or jest.config.*.
user-invocable: false
stack: testing/unit/jest
paths:
  - "jest.config.*"
  - "**/*.test.ts"
  - "**/*.test.js"
  - "**/*.spec.ts"
  - "**/*.spec.js"
  - "**/__tests__/**"
---

Full standards in [jest.md](jest.md). Always-on summary:

**Structure:**
- One `describe` per module/class; one `describe` per method inside
- Test names complete the sentence: `it('returns null when user not found')`
- Arrange-Act-Assert — three clear sections per test, blank line between each

**Mocking:**
- `jest.mock()` calls go at the top of the file, before imports take effect
- Mock at the system boundary (HTTP, DB, filesystem) — not internal functions
- `jest.spyOn()` for partial mocks where you want the real implementation for some calls
- Always restore mocks: use `jest.restoreAllMocks()` in `afterEach` or `restoreMocks: true` in config

**Async:**
- Always `return` or `await` promises — an unawaited assertion can silently pass
- Use `jest.useFakeTimers()` for `setTimeout`/`setInterval` tests; always call `jest.useRealTimers()` in `afterEach`

**Coverage:**
- Set thresholds in `jest.config.ts` — don't chase 100%; target branches and functions
- `/* istanbul ignore next */` — use sparingly with a comment explaining why

**Never:**
- `it.only()` or `describe.only()` merged to main — use `--testNamePattern` in dev
- Test implementation details — test behaviour observable from the outside
- Assertions inside loops — extract to helpers or use `test.each`

**Related skills:** Your frontend or backend layer (framework-specific setup), `mocking/msw` (HTTP mocking for integration tests)
