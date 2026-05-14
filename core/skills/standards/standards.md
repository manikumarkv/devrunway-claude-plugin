# Full Stack Coding Standards

## Git & GitHub Workflow

### Branching Strategy
- `main` — production only, protected, no direct pushes
- `develop` — integration branch, all features merge here first
- `feature/<GH-id>-<short-desc>` — new features (e.g. `feature/GH-42-user-profile`)
- `fix/<GH-id>-<short-desc>` — bug fixes (e.g. `fix/GH-99-login-redirect`)
- `chore/<desc>` — dependency updates, config changes
- `release/<version>` — release prep

### Commit Convention (Conventional Commits)
```
<type>(<scope>): <short summary>

[optional body]

[optional footer: refs #<issue>]
```
Types: `feat` | `fix` | `chore` | `docs` | `refactor` | `test` | `perf` | `ci`

### Pull Requests
- Title follows Conventional Commits format
- All PRs target `develop` (not `main`) unless hotfix
- 1 reviewer approval required, all CI checks must pass
- Description: What / Why / How to Test / Screenshots (if UI)
- Link issue: `Closes #<n>`
- Never merge with unresolved comments

### Issues
- Label: `bug` | `feature` | `enhancement` | `chore` | `blocked`
- Always create feature branch from the issue
- Close via `Closes #<n>` in PR description

---

## React (Frontend)

### Project Structure
```
src/
├── assets/
├── components/        # Shared reusable components
│   └── Button/
│       ├── Button.tsx
│       ├── Button.test.tsx
│       └── index.ts
├── features/          # Feature modules
│   └── auth/
│       ├── components/
│       ├── hooks/
│       ├── api/
│       ├── types.ts
│       └── index.ts
├── hooks/             # Global shared hooks
├── pages/             # Route-level components
├── services/          # API clients
├── store/             # Global state
├── types/             # Shared TS types
├── utils/             # Pure utilities
└── App.tsx
```

### Component Rules
- One component per file, PascalCase filename
- Always TypeScript; explicit prop `interface`
- Functional components with hooks only — no class components
- Max ~150 lines; split if larger
- Tests co-located as `Component.test.tsx`
- Named exports (not default exports) in feature folders

### Hooks
- Names start with `use`
- Never conditional hook calls
- `useMemo` for expensive calculations, `useCallback` for stable callbacks
- Business logic extracted to custom hooks, not inline in components

### State Management
- Local UI state: `useState` / `useReducer`
- Server state: React Query (`@tanstack/react-query`) — no manual fetch/useEffect for data
- Global app state: Redux Toolkit or Zustand
- Never store server response data in Redux

### Styling
- Tailwind CSS as default
- CSS Modules for component-specific styles when needed
- No inline `style={{}}` except for truly dynamic computed values
- No global CSS overrides of third-party components

### Testing
- Vitest + React Testing Library
- Test behavior via accessible roles/labels, not DOM selectors
- Every component has a smoke test minimum
- MSW for API mocking
- Coverage target ≥ 80% for feature code

---

## Node.js (Backend)

### Project Structure
```
src/
├── config/
├── controllers/       # Thin request handlers
├── services/          # Business logic
├── repositories/      # DB queries
├── middleware/        # Auth, logging, validation
├── routes/
├── types/
└── utils/
index.ts               # Entry point
```

### API Design
- RESTful, plural nouns: `/users`, `/orders`
- Versioned from day one: `/api/v1/...`
- Success response: `{ success: true, data: {...}, message?: "..." }`
- Error response: `{ success: false, error: { code, message, details } }`

### Error Handling
- Centralized error handler middleware — no inline `res.status(500)`
- Typed custom error classes extending `Error`
- All async handlers wrapped with `asyncHandler` utility
- Errors logged with correlation IDs

### Validation
- `zod` at controller boundary for all incoming data
- Return 400 with field-level details on validation failure

### Security
- `helmet` for security headers
- `express-rate-limit` on public endpoints
- Never log tokens, passwords, or PII
- Secrets in AWS SSM/Secrets Manager — never committed `.env`

### Logging
- Structured JSON with `pino`
- Fields: `timestamp`, `level`, `requestId`, `userId`, `message`
- Levels: `error` (actionable) · `warn` (handled) · `info` (business events) · `debug` (dev only)

### TypeScript
- `"strict": true` in tsconfig
- No `any` — use `unknown` and narrow
- Explicit return types on all exported functions
- `zod` schemas as source of truth for runtime + compile-time types

---

## AWS

### Naming Convention
`<project>-<env>-<service>-<resource-type>`

Examples:
- S3: `myapp-prod-assets-bucket`
- Lambda: `myapp-staging-process-order-fn`
- DynamoDB: `myapp-prod-users-table`
- Cognito: `myapp-prod-users-pool`

### Environments
`dev` → `staging` → `prod`. Never test against prod.

### Infrastructure as Code
- AWS CDK (TypeScript) for everything — no manual console changes
- `infra/` directory at repo root
- One CDK stack per logical unit (AuthStack, ApiStack, DatabaseStack)
- Tag all resources: `Project`, `Environment`, `Owner`, `ManagedBy: cdk`

### IAM
- Least privilege always — no `*` actions/resources in prod
- IAM roles for service-to-service, never long-lived access keys
- Rotate access keys every 90 days
- Never hardcode credentials

### Lambda
- Single-purpose functions
- Explicit memory + timeout (not defaults)
- X-Ray tracing enabled
- DLQ for async invocations

### S3
- Block all public access by default; use signed URLs or CloudFront
- Versioning on prod buckets
- SSE-S3 minimum (SSE-KMS for sensitive data)
- Lifecycle policies for cost management

### API Gateway
- HTTP API for new projects (not REST API unless features needed)
- Throttling on all endpoints
- Custom Domain Names with ACM certs
- Log all requests to CloudWatch

---

## AWS Cognito

### User Pool Config
- MFA enabled (optional for users, required for admins)
- Password policy: min 12 chars, upper + lower + numbers + symbols
- Email verification enabled
- Tokens: Access 1h, Refresh 30 days

### Frontend Auth
- `aws-amplify` or `amazon-cognito-identity-js` — never call Cognito APIs directly
- Store tokens in memory (not `localStorage`); `HttpOnly` cookies where possible
- Silent token refresh before expiry
- On 401: attempt one refresh, then redirect to login if refresh fails
- `signOut()` on logout — don't just delete cookies

### Backend Auth
- `aws-jwt-verify` for server-side JWT verification
- Extract `sub` (user ID) and `cognito:groups` from verified claims
- Group-based authorization middleware
- Authorization by `sub`, never by username/email

---

## CI/CD (GitHub Actions)
- Push to any branch → lint + tests
- Merge to `develop` → lint + tests + deploy to staging
- Merge to `main` → lint + tests + deploy to prod (manual approval gate)
- AWS credentials via OIDC — no long-lived access keys in secrets

## Quality Gates (every PR)
- `tsc --noEmit` — zero TS errors
- `eslint .` — zero lint errors
- `prettier --check .` — formatted
- All tests pass, coverage ≥ 80%
- No `console.log` in prod code
- No hardcoded secrets
- No untracked `TODO`/`FIXME`
- API changes reflected in types
