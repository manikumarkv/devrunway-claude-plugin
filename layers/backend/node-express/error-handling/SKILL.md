---
name: error-handling
description: Error handling standards for frontend and backend — custom error classes, Express centralized handler, React Query errors, error boundaries, form errors, toast patterns. Load when writing error handling, try/catch blocks, or error UI.
user-invocable: false
stack: backend/node-express
---

Full standards in [error-handling.md](error-handling.md). Always-on summary:

**Backend:**
- All custom errors extend `AppError` (message, statusCode, code): `NotFoundError`, `ValidationError`, `ConflictError`, etc.
- `asyncHandler(fn)` wraps every async route — no try/catch in controllers
- One centralized `errorHandler` middleware catches everything; never returns stack traces
- `ZodError` is caught in the error handler and mapped to `400` with field-level messages from `error.flatten()`
- Response shape: `{ statusCode, error: { code: 'NOT_FOUND', message: '...' } }`
- Prisma `P2002` (unique) → 409, `P2025` (not found) → 404
- Never expose stack traces or internal messages to clients

**Never:**
- `try/catch` in Express route handlers — use `asyncHandler(`
- `res.status(500).json({ error: e.message })` — leaks internals
- Generic "Something went wrong" for errors the user can fix
- Silent catch blocks

**For frontend error handling** (React Query `onError`, error boundaries, form field errors, toast patterns), see `layers/frontend/react/react-standards`.


**Related skills — apply together:**
- `api-conventions` — error response envelope shape, status code mapping
- `typescript-patterns` — type AppError subclasses and discriminated error unions
- `monitoring` — Sentry.captureException in boundaries, structured logs on 5xx
- `security` — never expose err.message or stack traces to clients