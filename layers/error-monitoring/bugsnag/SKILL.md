---
name: bugsnag
description: Bugsnag — init, breadcrumbs, error groups, severity, source maps, React ErrorBoundary
user-invocable: false
stack: error-monitoring/bugsnag
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/bugsnag*"
  - "**/error-boundary*"
  - "**/*monitoring*"
---

Full standards in [bugsnag.md](bugsnag.md). Always-on summary:

**Initialization:**
- Initialize Bugsnag once at app entry point — never call `Bugsnag.start()` more than once
- Set `apiKey:` from environment — never commit it
- Set `releaseStage` and `enabledReleaseStages` — only report from staging/production, not dev
- Set `appVersion` to the deployed git SHA or semantic version

**Breadcrumbs:**
- Leave breadcrumbs for significant user actions and API calls — aids reproduction
- Use `Bugsnag.leaveBreadcrumb(message, metadata, type)` with structured metadata
- Types: `"navigation"`, `"request"`, `"process"`, `"log"`, `"user"`, `"state"`, `"error"`, `"manual"`

**Error Groups and Metadata:**
- Set user context with `setUser(id, ...)` so errors are grouped per user — only pass the user ID, not PII like address or personal identifiers
- Add `addMetadata` for request context, feature flags, or any debugging state
- Use `groupingHash` to force-merge or force-separate errors that Bugsnag groups incorrectly

**Severity:**
- `error` — unexpected exceptions that indicate a bug; pages on-call
- `warning` — degraded behavior, expected edge cases; review daily
- `info` — notable events, not actionable

**Source Maps:**
- Upload source maps in CI immediately after build — before any test or deploy step
- Use `@bugsnag/source-maps` CLI or the webpack/vite plugin
- Source maps must match the exact build artifact being deployed

**React ErrorBoundary:**
- Wrap the root app and each major feature section with `<Bugsnag.getPlugin('react').createErrorBoundary(React)>`
- Provide a meaningful fallback UI — never a blank screen
- Never catch errors in an ErrorBoundary without notifying Bugsnag

**Never:**
- Report errors in the `development` release stage — noise drowns production alerts
- Include PII (passwords, payment data) in metadata
- Use `Bugsnag.notify()` without adding contextual metadata

**Related skills:** `error-handling`, `logging-standards`, `security-principles`
