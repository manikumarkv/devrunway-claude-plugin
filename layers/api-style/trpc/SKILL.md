---
name: trpc
description: tRPC standards — router definition, procedures, middleware, input validation, and React Query integration. Load when working with tRPC.
user-invocable: false
stack: api-style/trpc
paths:
  - "**/trpc/**"
  - "**/router/**"
  - "**/server/api/**"
  - "src/server/api/**"
---

Full standards in [trpc.md](trpc.md). Always-on summary:

**Router structure:**
- One router per feature/domain: `ordersRouter`, `usersRouter`, `productsRouter`
- Merge into a root `appRouter` — this is the single type exported to the client
- Export the `AppRouter` type (not the router instance) to the client package

**Procedures:**
- `publicProcedure` — no auth required (e.g., list public products)
- `protectedProcedure` — validates session in middleware; throw `TRPCError` if not authed
- All input must go through `.input(z.object({ ... }))` — never read raw arguments without validation: `.input(z.object({ name: z.string(), price: z.number() }))`
- Use `.query()` for reads and `.mutation()` for writes — matches REST conventions

**Middleware:**
- Auth middleware: validate session, attach `ctx.user` — reuse across all protected procedures
- Never put business logic in middleware — keep it thin (auth, logging, rate-limiting only)

**Errors:**
- Throw `TRPCError` with the appropriate `code:` `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `BAD_REQUEST` — e.g. `new TRPCError({ code: 'NOT_FOUND', message: 'User not found' })`
- tRPC automatically maps codes to HTTP status codes when used over HTTP
- The client receives typed errors — use `err.data?.code` to handle specific cases

**Client:**
- Use the tRPC React Query integration (`@trpc/react-query`) — you get `useQuery`, `useMutation` for free
- Share types end-to-end: the client infers input/output types directly from the router
- Set `defaultOptions.queries.refetchOnWindowFocus: false` in the QueryClient unless you need it

**Never:**
- Export the router instance to the client — export only the `AppRouter` type
- Skip `.input()` validation — procedures without input validation are untyped API holes
- Put DB calls directly in procedures — delegate to service layer functions

**Related skills:** `api-style/rest` (HTTP alternative), `validation/zod` (tRPC uses Zod for input validation), `frontend/nextjs`
