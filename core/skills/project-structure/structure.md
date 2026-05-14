# Universal Project Structure Principles

These principles apply to any language or framework. For technology-specific folder layouts, see your installed layer skills.

---

## Organise by Feature, Not by File Type

**File-type organisation** (avoid):
```
controllers/
  users.ts
  orders.ts
services/
  users.ts
  orders.ts
models/
  users.ts
  orders.ts
```

**Feature organisation** (prefer):
```
src/
  users/
    users.controller.ts
    users.service.ts
    users.repository.ts
    users.types.ts
    users.service.test.ts
  orders/
    orders.controller.ts
    orders.service.ts
    orders.repository.ts
    orders.types.ts
    orders.service.test.ts
```

**Why:** Code that changes together for the same reason lives together. Adding a new field to `User` touches `users/` only — not scattered files across 4 directories.

---

## Layered Architecture (applies to any stack)

Every application has these conceptual layers. The names differ by framework, but the boundaries are universal:

### Entry Point Layer (Controller / Handler / Route)
- Receives the request (HTTP, queue message, CLI command, event)
- Validates all inputs — rejects invalid data immediately
- Calls the service layer
- Formats and returns the response
- **Contains:** validation, routing, response formatting
- **Never contains:** business logic, database calls, complex conditionals

### Service Layer (Business Logic)
- Contains the application's business rules
- Orchestrates between repositories and external services
- Raises domain errors for invalid business states
- **Contains:** business rules, orchestration, domain logic
- **Never contains:** HTTP objects (Request/Response), SQL, framework-specific code

### Repository / Data Access Layer
- Translates domain objects to/from database representations
- Executes queries, handles transactions
- **Contains:** queries, database-specific code, mapping
- **Never contains:** business rules, HTTP concerns

### Infrastructure / Cross-Cutting Layer
- Logger, database client, HTTP client, config, cache
- Set up once at application start; injected into layers that need them
- **Never imported directly into business logic** — always injected as dependency

---

## Tests Live Next to Source

```
src/
  payments/
    payment.service.ts
    payment.service.test.ts     ← unit test beside source
    payment.repository.ts
    payment.repository.test.ts
    __tests__/
      payment.integration.test.ts  ← integration tests, if separated
```

**Why:** Tests are the documentation of expected behaviour. Readers look for documentation next to the code, not in a distant `tests/` tree.

---

## Shared vs. Feature-Owned Code

| Code type | Lives in |
|---|---|
| Used by only one feature | Inside that feature's directory |
| Used by 2+ features | `src/shared/` or `src/common/` |
| UI components used everywhere | `src/components/` |
| Pure utility functions | `src/utils/` |
| Third-party client setup | `src/lib/` or `src/infrastructure/` |
| Type definitions shared across features | `src/types/` |

**Rule:** start inside the feature. Move to shared only when a second consumer exists.

---

## Configuration and Secrets

```
src/
  config/
    index.ts        ← validates and exports all config at startup
    database.ts     ← DB connection config
    auth.ts         ← auth provider config
```

- Read environment variables once at startup, in `config/`
- Fail fast if required config is missing — crash at startup, not mid-request
- Pass config values as function arguments or inject via DI — never `process.env.X` scattered throughout the codebase

---

## Infrastructure Layout

```
project-root/
  src/            ← application source code
  infra/          ← infrastructure as code (CDK, Terraform, Pulumi)
  scripts/        ← one-off scripts, migrations, seeders
  docs/           ← architecture decisions, API docs
  .github/        ← CI/CD, PR templates, issue templates
```

---

*For technology-specific layouts (React feature structure, Express route layout, Prisma schema placement, etc.), consult your installed layer skills.*
