# Postman Standards

---

## Collection structure

```
Orders API (Collection)
├── Auth
│   ├── Login — POST /api/v1/auth/login
│   └── Refresh token — POST /api/v1/auth/refresh
├── Orders
│   ├── List orders — GET /api/v1/orders
│   ├── Get order — GET /api/v1/orders/:id
│   ├── Create order — POST /api/v1/orders
│   ├── Update order — PATCH /api/v1/orders/:id
│   └── Delete order — DELETE /api/v1/orders/:id
└── Error cases
    ├── Get order — not found (404)
    ├── Create order — invalid body (400)
    └── Get order — unauthenticated (401)
```

**Rules:**
- One collection per API domain — not one giant collection for everything
- Folders map 1:1 to resource groups, not to HTTP methods
- Include error case folders — happy path only tests are insufficient
- Request names are sentences: `List orders with cursor pagination`, not `GET orders`

---

## Environments

```json
// postman/environments/local.json
{
  "name": "Local",
  "values": [
    { "key": "base_url",    "value": "http://localhost:3000",  "enabled": true },
    { "key": "auth_token",  "value": "",                       "enabled": true },
    { "key": "user_id",     "value": "",                       "enabled": true }
  ]
}
```

```json
// postman/environments/staging.json
{
  "name": "Staging",
  "values": [
    { "key": "base_url",    "value": "https://api.staging.example.com", "enabled": true },
    { "key": "auth_token",  "value": "{{STAGING_TOKEN}}",                "enabled": true }
  ]
}
```

**Never commit real credentials.** Use `{{PLACEHOLDER}}` or empty strings. Inject real values via Newman's `--env-var` flag in CI.

---

## Request setup

```
# URL
{{base_url}}/api/v1/orders

# Headers
Content-Type: application/json
Authorization: Bearer {{auth_token}}

# Body (raw JSON)
{
  "items": [
    { "productId": "{{product_id}}", "quantity": 2 }
  ]
}
```

---

## Pre-request scripts

```javascript
// Collection-level pre-request script — runs before every request

// Auto-login if no token set
if (!pm.environment.get('auth_token')) {
  pm.sendRequest({
    url: pm.environment.get('base_url') + '/api/v1/auth/login',
    method: 'POST',
    header: { 'Content-Type': 'application/json' },
    body: {
      mode: 'raw',
      raw: JSON.stringify({
        email: pm.environment.get('test_email'),
        password: pm.environment.get('test_password'),
      }),
    },
  }, (err, res) => {
    if (!err && res.code === 200) {
      pm.environment.set('auth_token', res.json().data.token)
    }
  })
}
```

```javascript
// Request-level pre-request script — generate dynamic data
pm.environment.set('unique_email', `test+${Date.now()}@example.com`)
pm.environment.set('request_timestamp', new Date().toISOString())
```

---

## Test scripts

```javascript
// Minimum: status code check
pm.test('Status is 200', () => {
  pm.response.to.have.status(200)
})

// Full response assertion
pm.test('Returns the created order', () => {
  const body = pm.response.json()
  pm.expect(body.success).to.be.true
  pm.expect(body.data).to.have.property('id')
  pm.expect(body.data.status).to.equal('pending')
  pm.expect(body.data.items).to.have.length(1)
})

// Chaining: save ID for next request
pm.test('Saves order ID for subsequent requests', () => {
  const body = pm.response.json()
  pm.expect(body.data.id).to.be.a('string')
  pm.environment.set('order_id', body.data.id)
})

// Error case assertions
pm.test('Status is 400', () => {
  pm.response.to.have.status(400)
})
pm.test('Returns validation error', () => {
  const body = pm.response.json()
  pm.expect(body.success).to.be.false
  pm.expect(body.error.code).to.equal('VALIDATION_ERROR')
  pm.expect(body.error.details).to.be.an('array').with.length.above(0)
})

// Response time
pm.test('Responds within 500ms', () => {
  pm.expect(pm.response.responseTime).to.be.below(500)
})
```

---

## Chaining requests (flow)

The recommended flow for CRUD:

```
1. POST /orders  → save {{order_id}} from response
2. GET /orders/{{order_id}}  → verify it was created
3. PATCH /orders/{{order_id}}  → update it
4. GET /orders/{{order_id}}  → verify update
5. DELETE /orders/{{order_id}}  → delete it
6. GET /orders/{{order_id}}  → verify 404
```

Use Collection Runner to run the entire folder in sequence.

---

## Newman — CI runner

```bash
# Install Newman
npm install -g newman

# Run a collection with an environment
newman run postman/collections/orders.json \
  -e postman/environments/staging.json \
  --reporters cli,junit \
  --reporter-junit-export results/newman.xml

# Inject secrets from CI environment (override env vars)
newman run postman/collections/orders.json \
  -e postman/environments/staging.json \
  --env-var "auth_token=$STAGING_API_TOKEN" \
  --bail   # stop on first failure
```

```yaml
# GitHub Actions
- name: Run API tests with Newman
  run: |
    newman run postman/collections/orders.json \
      -e postman/environments/staging.json \
      --env-var "auth_token=${{ secrets.STAGING_API_TOKEN }}" \
      --reporters cli,junit \
      --reporter-junit-export results/newman.xml

- name: Publish test results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: results/newman.xml
```

---

## Collection export and version control

```bash
# Export from Postman UI:
# Collection → ... → Export → Collection v2.1 → Save to postman/collections/

# Keep environments as files (without real secrets):
# Environment → ... → Export → Save to postman/environments/
```

```
postman/
  collections/
    orders-api.postman_collection.json
    auth-api.postman_collection.json
  environments/
    local.postman_environment.json    ← placeholder values only
    staging.postman_environment.json  ← placeholder values only
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Hardcoded auth token in Authorization header | Use `{{auth_token}}` environment variable; auto-set in pre-request script |
| No tests on a request | Every request must have at minimum a status code test |
| Using `{{$randomEmail}}` and asserting on it | Save it to an env var first: `pm.environment.set('email', ...)` |
| Not chaining — manually copying IDs | Use `pm.environment.set` in Tests tab to pass data between requests |
| Committing real credentials in environment files | Use placeholders; inject via `--env-var` in CI |
