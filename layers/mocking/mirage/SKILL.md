---
name: mirage
description: Mirage JS standards — server setup, models, factories, routes, and React integration. Load when working with Mirage JS.
user-invocable: false
stack: mocking/mirage
paths:
  - "**/mirage/**"
  - "**/miragejs/**"
  - "**/__mocks__/**"
---

Full standards in [mirage.md](mirage.md). Always-on summary:

**Server setup:**
- Call `createServer(` with `models:`, `factories:`, and a `routes(` function — this is the full Mirage setup
- Create Mirage server only in `development` and `test` environments — never in production
- Gate on `process.env.NODE_ENV !== 'production'` or use a `VITE_ENABLE_MIRAGE` flag
- Use `environment: 'test'` in tests — removes logging and sets `timing: 0`

**Models and relationships:**
- Declare `models:` with `belongsTo` / `hasMany` — Mirage resolves relationships automatically in serializers
- Use `Schema` and `Db` via route handler's first argument — do not access `server.db` directly in components

**Factories:**
- Define factories with `Factory.extend({ ... })` — one per model, with realistic fake data using `faker`
- Declare under `factories:` key in `createServer`
- Use traits for variant states: `server.create('user', 'admin')` or `server.create('order', 'cancelled')`
- `server.createList('product', 20)` for seeding list views

**Routes:**
- Inside the `routes(` function, call `this.passthrough(` for any URLs that should reach the real network
- Prefer `server.namespace = '/api'` over repeating `/api` in every route
- Use shorthand routes (`server.get('/users')`, `server.post('/users')`) when the default serializer is sufficient

**React integration:**
- Start Mirage in `main.tsx` (or `index.tsx`) before rendering, wrapped in an env guard
- In Storybook, start a per-story Mirage server in `decorators` — call `server.shutdown()` in cleanup

**Never:**
- Start the Mirage server in production bundles — it intercepts all `fetch` calls
- Hard-code IDs in factories — let Mirage auto-increment or use `faker.string.uuid()`
- Share a single Mirage server instance across tests — create and shut down per test

**Related skills:** `mocking/msw` (service-worker alternative), `mocking/json-server` (external mock server), `testing/vitest`
