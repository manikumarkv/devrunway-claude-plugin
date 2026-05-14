# Bruno API Testing Standards

---

## What Bruno is

Bruno is an offline-first API client and test runner. Collections live as `.bru` files in git alongside the code — no cloud sync, no sharing accounts.

- **Development:** use Bruno desktop app to explore and build requests interactively
- **CI:** run `npx @usebruno/cli run` to execute collections against staging after every deploy

---

## Collection structure

```
bruno/
├── environments/
│   ├── local.bru           # gitignored — contains real local credentials
│   └── staging.bru         # CI credentials via env vars — no real values in file
├── orders/
│   ├── create-order.bru
│   ├── get-order.bru
│   ├── list-orders.bru
│   ├── update-order.bru
│   └── delete-order.bru
├── auth/
│   ├── sign-in.bru         # Gets token, stores in env
│   └── refresh-token.bru
└── bruno.json              # Collection metadata
```

---

## Environment files

```bru
# bruno/environments/staging.bru
vars {
  baseUrl: {{process.env.STAGING_API_URL}}
  token:                              # populated by auth script at runtime
  testUserId:                         # populated after create
}
```

```bru
# bruno/environments/local.bru  (gitignored)
vars {
  baseUrl: http://localhost:3000
  token:
  testUserId:
}
```

---

## Auth — get token once, reuse across requests

```bru
# bruno/auth/sign-in.bru
meta {
  name: Sign In
  type: http
  seq: 1
}

post {
  url: {{baseUrl}}/api/v1/auth/sign-in
  body: json
  auth: none
}

body:json {
  {
    "email": "{{process.env.TEST_USER_EMAIL}}",
    "password": "{{process.env.TEST_USER_PASSWORD}}"
  }
}

script:post-response {
  // Store token for all subsequent requests
  bru.setEnvVar("token", res.body.data.accessToken)
}

tests {
  test("status is 200", function() {
    expect(res.status).to.equal(200)
  })

  test("returns access token", function() {
    expect(res.body.data).to.have.property("accessToken")
  })
}
```

---

## Request file template

```bru
# bruno/orders/create-order.bru
meta {
  name: Create Order
  type: http
  seq: 1
}

post {
  url: {{baseUrl}}/api/v1/orders
  body: json
  auth: bearer
}

auth:bearer {
  token: {{token}}
}

body:json {
  {
    "productId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "quantity": 2
  }
}

script:post-response {
  // Store created ID for downstream tests
  if (res.status === 201) {
    bru.setEnvVar("createdOrderId", res.body.data.id)
  }
}

tests {
  test("status is 201", function() {
    expect(res.status).to.equal(201)
  })

  test("returns order object", function() {
    expect(res.body.success).to.equal(true)
    expect(res.body.data).to.have.property("id")
    expect(res.body.data.status).to.equal("pending")
    expect(res.body.data.quantity).to.equal(2)
  })
}
```

---

## Get, update, delete — reference stored ID

```bru
# bruno/orders/get-order.bru
meta {
  name: Get Order
  type: http
  seq: 2
}

get {
  url: {{baseUrl}}/api/v1/orders/{{createdOrderId}}
  auth: bearer
}

auth:bearer {
  token: {{token}}
}

tests {
  test("status is 200", function() {
    expect(res.status).to.equal(200)
  })

  test("returns correct order", function() {
    expect(res.body.data.id).to.equal(bru.getEnvVar("createdOrderId"))
  })
}
```

---

## Test assertions — required in every request

Every `.bru` file must have a `tests {}` block. Minimum:

```bru
tests {
  test("status is 200", function() {
    expect(res.status).to.equal(200)
  })

  test("response has expected shape", function() {
    expect(res.body).to.have.property("data")
    // Assert key fields — not every field
  })
}
```

**Test error cases too:**

```bru
# bruno/orders/create-order-invalid.bru
body:json {
  {
    "productId": "not-a-uuid",
    "quantity": -1
  }
}

tests {
  test("status is 400", function() {
    expect(res.status).to.equal(400)
  })

  test("returns validation error", function() {
    expect(res.body.error).to.have.property("message")
  })
}
```

---

## CI integration

```yaml
# .github/workflows/api-tests.yml — runs after staging deploy
name: API Tests

on:
  workflow_run:
    workflows: ["Deploy — Staging"]
    types: [completed]

jobs:
  api-tests:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - run: npm install -g @usebruno/cli

      - name: Run Bruno collection
        run: bru run bruno/ --env staging
        env:
          STAGING_API_URL: ${{ secrets.STAGING_API_URL }}
          TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
          TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
```

---

## .gitignore additions

```
bruno/environments/local.bru
```

Never commit local environment files with real credentials.

---

## Never

- Hard-code tokens, passwords, or real IDs in `.bru` files
- Skip the `tests {}` block — every request must assert at minimum the status code
- Share tokens across collection runs without a re-auth — tokens expire
- Commit `local.bru` with real credentials
- Use Bruno as a substitute for unit tests — Bruno tests the deployed API, not business logic
