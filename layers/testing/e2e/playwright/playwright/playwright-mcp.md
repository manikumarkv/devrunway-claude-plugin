# Playwright MCP — Run Tests via Prompts

This document explains how to wire up the Playwright MCP server so developers can run, inspect, and debug E2E tests directly from Claude prompts without leaving the IDE.

---

## What the Playwright MCP enables

| Prompt | What happens |
|---|---|
| "Run all E2E tests" | `npx playwright test` — full suite |
| "Run the orders spec" | `npx playwright test e2e/orders.spec.ts` |
| "Run tests tagged @smoke" | `npx playwright test --grep @smoke` |
| "Show me failing tests from the last run" | Reads `playwright-report/results.json` |
| "Debug the login test" | Opens Playwright UI mode for that spec |
| "Show me a screenshot of the failure" | Returns the failure screenshot from `test-results/` |
| "List all spec files" | `find e2e -name '*.spec.ts'` |

---

## MCP server setup

The `@playwright/mcp` package provides an MCP server that exposes a browser Claude can control. For running tests via prompts, we use it in combination with direct `Bash` tool calls.

### Install

```bash
npm install -D @playwright/mcp
npx playwright install chromium  # install browser binaries
```

### Register in Claude Code project config

Create `.mcp.json` at the project root (committed to repo — all devs share it):

```json
// .mcp.json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--browser", "chromium"],
      "env": {
        "BASE_URL": "http://localhost:5173"
      }
    }
  }
}
```

> The Playwright MCP server exposes browser automation tools (`browser_navigate`, `browser_click`, `browser_screenshot`, etc.) that Claude can call directly for interactive debugging.

For running test suites via prompts (rather than interactive browsing), Claude uses the `Bash` tool to invoke `npx playwright test` — no extra MCP needed. The MCP adds the ability to visually inspect pages and interact with the running app.

---

## Prompt examples — test runner

These prompts work once the project has `playwright.config.ts` and specs in `e2e/`:

### Run the full suite
```
Run all Playwright E2E tests
```
Claude runs:
```bash
npx playwright test --reporter=list
```

### Run a specific spec file
```
Run the orders E2E tests
```
Claude runs:
```bash
npx playwright test e2e/orders.spec.ts --reporter=list
```

### Run tests matching a name pattern
```
Run all tests that contain "checkout"
```
Claude runs:
```bash
npx playwright test --grep "checkout" --reporter=list
```

### Run tagged tests
```
Run smoke tests only
```
Claude runs:
```bash
npx playwright test --grep @smoke --reporter=list
```

### Run a single test by title
```
Run the "user can cancel a pending order" test
```
Claude runs:
```bash
npx playwright test --grep "user can cancel a pending order" --reporter=list
```

### Run in headed mode (watch what the browser does)
```
Run the login test in headed mode so I can see what's happening
```
Claude runs:
```bash
npx playwright test e2e/login.spec.ts --headed
```

### Open Playwright UI mode
```
Open Playwright UI mode so I can step through tests
```
Claude runs:
```bash
npx playwright test --ui
```

### Show failing tests from last run
```
Which tests failed in the last run?
```
Claude reads:
```bash
cat playwright-report/results.json | jq '[.suites[].specs[] | select(.ok == false) | .title]'
```
or opens the HTML report:
```bash
npx playwright show-report
```

### Show a failure screenshot
```
Show me the screenshot from the failed checkout test
```
Claude reads the latest `.png` from `test-results/` matching the test name.

---

## Tag convention for test selection

Tag tests with `@` prefixes in the title so they are easily filterable:

```ts
// e2e/orders.spec.ts
test('@smoke @orders — orders list loads for authenticated user', async ({ page }) => { ... })
test('@orders — user can create an order', async ({ page }) => { ... })
test('@orders @regression — cancelled order cannot be reconfirmed', async ({ page }) => { ... })
```

Standard tags used across the project:

| Tag | Meaning | When to run |
|---|---|---|
| `@smoke` | Core happy paths — must never be broken | After every deploy (CI) |
| `@regression` | Edge cases and bug-fix verifications | Full test run (nightly / PR) |
| `@orders` | Order feature tests | When changing order code |
| `@auth` | Login / logout / session | When changing auth |
| `@admin` | Admin-only routes | When changing admin features |
| `@slow` | Tests > 10 s — excluded from smoke | Nightly only |

---

## `package.json` test scripts — prompts reference these

```json
{
  "scripts": {
    "e2e":            "playwright test",
    "e2e:smoke":      "playwright test --grep @smoke",
    "e2e:ui":         "playwright test --ui",
    "e2e:headed":     "playwright test --headed",
    "e2e:debug":      "playwright test --debug",
    "e2e:report":     "playwright show-report",
    "e2e:codegen":    "playwright codegen http://localhost:5173"
  }
}
```

Prompts can also call these scripts directly:
```
Run npm run e2e:smoke
```

---

## Interactive browser via Playwright MCP

When `.mcp.json` is present and Claude Code has the Playwright MCP connected, Claude can use browser tools directly in prompts:

```
Navigate to http://localhost:5173/orders and take a screenshot
```
```
Click the "Create order" button and fill in the form with product ID "clxyz" and quantity 2
```
```
Check if the success toast appears after submitting the order form
```

These are useful for:
- Exploring the running app before writing a test
- Verifying a fix visually without running the full suite
- Debugging a flaky test by reproducing it step by step

> **Note:** The Playwright MCP browser session is separate from any running test. Use it for exploration — run `npx playwright test` for the authoritative pass/fail verdict.

---

## CI — test results as artifacts

```yaml
# .github/workflows/ci.yml
- name: Run E2E tests
  run: npx playwright test --reporter=html,list
  env:
    BASE_URL: http://localhost:5173

- name: Upload Playwright report
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: playwright-report
    path: playwright-report/
    retention-days: 7
```

After a CI run:
```
Show me the Playwright report from the last CI run
```
Claude can download the artifact and parse `results.json` for failures.

---

## `.gitignore` additions

```
# Playwright
test-results/
playwright-report/
e2e/.auth/
/blob-report/
/playwright/.cache/
```

---

## Codegen — generate tests by recording browser actions

```
Generate a Playwright test for the order creation flow
```
Claude runs:
```bash
npx playwright codegen http://localhost:5173/orders/new
```
Then pastes the recorded test into `e2e/orders.spec.ts` and refactors it to use the page object pattern.
