# json-server Standards

---

## Setup

```bash
npm install --save-dev json-server
```

---

## db.json structure

```json
// db.json — each top-level key is a REST resource
{
  "users": [
    { "id": "u1", "name": "Alice", "email": "alice@example.com", "role": "admin" },
    { "id": "u2", "name": "Bob",   "email": "bob@example.com",   "role": "user"  }
  ],
  "products": [
    { "id": "p1", "name": "Widget Pro", "price": 29.99, "categoryId": "c1", "inStock": true },
    { "id": "p2", "name": "Gadget Lite","price": 9.99,  "categoryId": "c1", "inStock": false }
  ],
  "categories": [
    { "id": "c1", "name": "Electronics" }
  ],
  "orders": []
}
```

Auto-generated REST routes:

| Method | Path | Action |
|---|---|---|
| GET | `/users` | List all |
| GET | `/users/:id` | Get one |
| POST | `/users` | Create |
| PUT | `/users/:id` | Replace |
| PATCH | `/users/:id` | Update |
| DELETE | `/users/:id` | Delete |

Relationships resolve automatically: `GET /products?_expand=category` joins the category.

---

## routes.json — path rewriting

```json
// routes.json — maps public paths to json-server resource paths
{
  "/api/*": "/$1",
  "/api/v1/*": "/$1"
}
```

This lets your app call `/api/users` and json-server serves from `/users`.

---

## package.json scripts

```json
{
  "scripts": {
    "mock": "json-server --watch db.json --routes routes.json --port 3001 --delay 200",
    "mock:ci": "json-server --watch db.json --routes routes.json --port 3001 --delay 0"
  }
}
```

---

## Custom middleware

```javascript
// middleware/auth.js — require Authorization header on non-GET requests
module.exports = (req, res, next) => {
  if (req.method !== 'GET' && !req.headers.authorization) {
    return res.status(401).json({ error: 'Authorization header required' })
  }
  next()
}

// middleware/delay.js — per-route delay
module.exports = (req, res, next) => {
  const delays = {
    '/api/slow-endpoint': 2000,
    '/api/users':          300,
  }
  const delay = delays[req.path] ?? 0
  setTimeout(next, delay)
}
```

```bash
# Run with middleware
json-server --watch db.json --middlewares middleware/auth.js middleware/delay.js --port 3001
```

---

## Programmatic server (custom endpoints)

```javascript
// server.js — extend json-server with custom routes
const jsonServer = require('json-server')
const server     = jsonServer.create()
const router     = jsonServer.router('db.json')
const middlewares = jsonServer.defaults()

server.use(middlewares)
server.use(jsonServer.bodyParser)

// Custom endpoint — not expressible in db.json
server.get('/api/stats', (req, res) => {
  const db = router.db.getState()
  res.json({
    userCount:    db.users.length,
    productCount: db.products.length,
    orderCount:   db.orders.length,
  })
})

// Custom error simulation
server.post('/api/payment', (req, res) => {
  if (req.body.card?.startsWith('4000')) {
    return res.status(402).json({ error: 'Card declined' })
  }
  res.json({ transactionId: `txn_${Date.now()}` })
})

server.use(jsonServer.rewriter({ '/api/*': '/$1' }))
server.use(router)
server.listen(3001, () => console.log('Mock server running on :3001'))
```

---

## CI usage

```yaml
# .github/workflows/test.yml
- name: Start mock server
  run: |
    cp db.fixture.json db.json   # reset to clean fixture
    npx json-server --watch db.json --port 3001 &
    npx wait-on http://localhost:3001/users

- name: Run integration tests
  run: npm test

- name: Reset db.json
  if: always()
  run: cp db.fixture.json db.json
```

```bash
# install wait-on for reliable server readiness check
npm install --save-dev wait-on
```

---

## Fixture management

```
mocks/
  db.fixture.json      ← committed, never mutated directly
  db.json              ← gitignored; copied from fixture before tests
  routes.json
  middleware/
    auth.js
    delay.js
```

Add to `.gitignore`:
```
mocks/db.json
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Committing mutated `db.json` | Gitignore `db.json`; commit only `db.fixture.json` and copy before runs |
| Starting json-server without `--delay` | Instant responses hide loading states — use `--delay 200` in dev |
| Using json-server as a production server | It is a dev/test tool; it has no auth, rate-limiting, or persistence guarantees |
| Hardcoded IDs that conflict with auto-increment | json-server auto-increments numeric IDs; use string UUIDs to avoid collisions |
| Missing `--routes` flag | Without routes, your app's `/api/users` calls fail — always pass routes.json |
