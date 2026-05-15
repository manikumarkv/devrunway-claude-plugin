---
name: test
description: Run or generate tests — unit tests, E2E tests, API tests, coverage reports, watch mode. Detects the project's test runner from stack.json or package.json. Usage — /devrunway:test <sub-command> [args]
argument-hint: <unit|e2e|api|coverage|watch|generate> [file-or-feature]
arguments:
  - name: subcommand
    description: "Sub-command: unit, e2e, api, coverage, watch, generate"
  - name: target
    description: "Optional file path, feature name, or spec file to scope the operation"
user-invocable: true
context: fork
effort: low
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

## Detect the test runner

Before running, check `stack.json` and `package.json` to determine which tools are in use:

```bash
# Check stack.json for configured layers
cat stack.json 2>/dev/null | grep -E "testing-unit|testing-e2e|testing-api"

# Fallback: check package.json scripts and devDependencies
cat package.json | grep -E '"test"|vitest|jest|pytest|playwright|cypress|bruno'
```

Use the detected tool for all subsequent commands. If multiple tools are found, ask the user which to use.

---

## `/test unit [file-or-feature]`

Run unit tests. Detect runner from stack.json (`testing-unit`) or package.json.

```bash
# Common runners — use whichever is present:
# Vitest:  npx vitest run $TARGET
# Jest:    npx jest $TARGET --passWithNoTests
# pytest:  python -m pytest $TARGET
# dotnet:  dotnet test --filter $TARGET
```

After running, summarize: pass count, fail count, test files. Print any failing test names and error messages.

---

## `/test e2e [spec-file]`

Run E2E tests. Detect runner from stack.json (`testing-e2e`) or package.json.

```bash
# Common runners — use whichever is present:
# Playwright:   npx playwright test $SPEC_FILE
# Cypress:      npx cypress run --spec $SPEC_FILE
# WebdriverIO:  npx wdio $SPEC_FILE
```

After running, summarize results by spec file. Report any failures with screenshots if available.

---

## `/test api [collection-name]`

Run API tests. Detect runner from stack.json (`testing-api`) or project structure.

```bash
# Common runners — use whichever is present:
# Bruno:   npx @usebruno/cli run $COLLECTION --env local
# Newman:  npx newman run $COLLECTION.json --environment local.json
```

Summarize: requests passed, failed, error messages.

---

## `/test coverage [threshold]`

Run unit tests with coverage. Default threshold: 80%.

```bash
# Vitest:  npx vitest run --coverage
# Jest:    npx jest --coverage
# pytest:  python -m pytest --cov --cov-report=term
```

Flag files below the threshold. Print: statements, branches, functions, lines coverage overall.

---

## `/test watch [file]`

Run unit tests in watch mode for fast feedback during development.

```bash
# Vitest:  npx vitest $FILE
# Jest:    npx jest --watch $FILE
# pytest:  python -m pytest-watch $FILE
```

Inform the user how to quit the watch process for their specific runner.

---

## `/test generate [file-or-feature]`

Generate test stubs for existing code that lacks tests. Reads the source file(s), analyses what needs testing, writes comprehensive test files.

If no target given, use changed files from the current branch:
```bash
git diff develop...HEAD --name-only | head -20
```

### Universal test generation pattern

For every source file, generate tests that cover:

**Service / business logic:**
```
describe('<ServiceName>')
  describe('<methodName>')
    it('returns expected result for valid input')
    it('throws NotFoundError when resource does not exist')
    it('throws ForbiddenError when caller does not own the resource')
    it('handles edge case: <empty/zero/max>')
```

**Controller / handler / route:**
```
describe('<endpoint> <method>')
  it('returns 401 when unauthenticated')
  it('returns 400 when input is invalid')
  it('returns 201/200 on success')
  it('returns 404 when resource not found')
```

**UI component (if applicable):**
```
describe('<ComponentName>')
  it('renders loading state while fetching')
  it('renders data after successful fetch')
  it('renders error state when fetch fails')
  it('renders empty state when no data')
```

Use your installed testing layer's syntax (Vitest, Jest, pytest, etc.) for the actual test code. Consult your testing layer skill for framework-specific patterns and mock setup.

After writing each test file, run it to verify no syntax errors. Fix any failures before moving on.

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
