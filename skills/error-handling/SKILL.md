---
name: error-handling
description: Error handling standards for frontend and backend — custom error classes, Express centralized handler, React Query errors, error boundaries, form errors, toast patterns. Load when writing error handling, try/catch blocks, or error UI.
user-invocable: false
---

Full standards in [error-handling.md](error-handling.md). Always-on summary:

**Backend:**
- All custom errors extend `AppError` (message, statusCode, code)
- `asyncHandler` wraps every async route — no try/catch in controllers
- One centralized `errorHandler` middleware catches everything
- Zod parse errors → 400 with field-level messages
- Prisma `P2002` (unique) → 409, `P2025` (not found) → 404
- Never expose stack traces or internal messages to clients

**Frontend:**
- `ApiError` class carries `status` + `code` from the server
- React Query: `onError` in `QueryClient` defaults + per-query override
- Error boundaries wrap every route and every async feature
- Form errors: field-level via `react-hook-form` `setError`, not toast
- Toast only for non-recoverable async errors (mutation failures)
- Never catch and swallow — always log to Sentry or surface to user

**Never:**
- `try/catch` in Express route handlers — use `asyncHandler`
- `res.status(500).json({ error: e.message })` — leaks internals
- Generic "Something went wrong" for errors the user can fix
- Silent catch blocks with no Sentry or UI feedback


**Related skills — apply together:**
- `api-conventions` — error response envelope shape, status code mapping
- `typescript-patterns` — type AppError subclasses and discriminated error unions
- `monitoring` — Sentry.captureException in boundaries, structured logs on 5xx
- `security` — never expose err.message or stack traces to clients