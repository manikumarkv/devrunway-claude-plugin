# Sentry Error Monitoring Standards

## Initialization

Initialize Sentry in the app entry point, before rendering `<App />`.

```ts
// src/lib/sentry.ts
import * as Sentry from '@sentry/react'

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.VITE_ENV,           // 'production' | 'staging' | 'development'
  release: import.meta.env.VITE_SENTRY_RELEASE,    // must match CI deployment tag

  // Performance tracing
  tracesSampleRate: import.meta.env.PROD ? 0.1 : 1.0,   // 10% prod, 100% dev/staging
  tracePropagationTargets: ['localhost', /^https:\/\/api\.myapp\.com/],

  // Noise reduction
  denyUrls: [
    /extensions\//i,
    /^chrome:\/\//i,
    /^chrome-extension:\/\//i,
    /safari-extension/,
  ],
  ignoreErrors: [
    'ResizeObserver loop limit exceeded',  // benign browser quirk
    'Network request failed',              // handled at UI level
  ],

  // PII scrubbing — mandatory
  beforeSend(event) {
    if (event.user) {
      delete event.user.email
      delete event.user.username
      delete event.user.ip_address
    }
    scrubSensitiveData(event)
    return event
  },
})

function scrubSensitiveData(event: Sentry.Event) {
  const sensitivePattern = /password|token|secret|key|auth|credit|ssn/i
  const scrub = (obj: Record<string, unknown>) => {
    for (const key of Object.keys(obj)) {
      if (sensitivePattern.test(key)) {
        obj[key] = '[REDACTED]'
      } else if (typeof obj[key] === 'object' && obj[key] !== null) {
        scrub(obj[key] as Record<string, unknown>)
      }
    }
  }
  if (event.extra) scrub(event.extra as Record<string, unknown>)
  if (event.contexts) scrub(event.contexts as Record<string, unknown>)
}
```

```ts
// src/main.tsx
import './lib/sentry'  // import before everything else

ReactDOM.createRoot(document.getElementById('root')!).render(<App />)
```

## Release tracking

`release` must exactly match the git tag or deployment identifier used in CI. This enables Sentry to link errors to specific deployments and show regression markers.

```ts
// vite.config.ts — inject at build time
import { defineConfig } from 'vite'
import { sentryVitePlugin } from '@sentry/vite-plugin'

export default defineConfig({
  define: {
    'import.meta.env.VITE_SENTRY_RELEASE': JSON.stringify(process.env.GITHUB_SHA ?? 'local'),
  },
  plugins: [
    sentryVitePlugin({
      org: 'my-org',
      project: 'my-project',
      authToken: process.env.SENTRY_AUTH_TOKEN,
      sourcemaps: {
        assets: './dist/**',
        ignore: ['node_modules'],
        filesToDeleteAfterUpload: './dist/**/*.map', // don't ship maps to CDN
      },
    }),
  ],
  build: {
    sourcemap: true,
  },
})
```

## React error boundary

Wrap the entire React tree with `Sentry.ErrorBoundary`. Every async feature boundary should have its own.

```tsx
// App.tsx — top-level boundary
import * as Sentry from '@sentry/react'
import { ErrorPage } from '@/pages/ErrorPage'

export function App() {
  return (
    <Sentry.ErrorBoundary fallback={<ErrorPage />} showDialog>
      <Router>
        <Routes />
      </Router>
    </Sentry.ErrorBoundary>
  )
}
```

```tsx
// Feature-level boundary — wrap async-heavy features
import { Suspense } from 'react'
import * as Sentry from '@sentry/react'

export function CheckoutPage() {
  return (
    <Sentry.ErrorBoundary fallback={<CheckoutErrorState />}>
      <Suspense fallback={<CheckoutSkeleton />}>
        <CheckoutFlow />
      </Suspense>
    </Sentry.ErrorBoundary>
  )
}
```

## `captureException` — how to call it

```ts
// Caught error in a critical path — always include context, never PII
try {
  await processPayment(orderId, amount)
} catch (err) {
  Sentry.captureException(err, {
    extra: {
      orderId,         // ID is fine
      amount,          // amount is fine
      step: 'payment', // operational context
    },
    tags: {
      feature: 'checkout',
      paymentProvider: 'stripe',
    },
  })
  toast.error(t('errors.paymentFailed'))
}

// Don't double-log — if the error is already handled at the boundary, don't also captureException
// ErrorBoundary catches unhandled rejections; captureException is for caught + re-shown errors
```

## `captureMessage` — for expected-but-notable events

Use `captureMessage` when something is wrong but not an exception — e.g. an external service is degraded, a feature flag is misconfigured, or an unusual-but-handled state occurs.

```ts
// External service degraded — not an error, but worth tracking
if (featureFlagResponse.status === 503) {
  Sentry.captureMessage('Feature flag service unavailable — using defaults', 'warning')
}

// Unexpected data shape from third-party API
if (!response.data.items) {
  Sentry.captureMessage('Partner API returned unexpected shape', 'error')
}
```

Severity levels: `'fatal'` | `'error'` | `'warning'` | `'log'` | `'info'` | `'debug'`

## User identification — ID only

Always set the user after authentication. Never include email, name, or any PII.

```ts
// After sign-in
Sentry.setUser({ id: user.sub })  // Cognito sub UUID is safe

// After sign-out
Sentry.setUser(null)

// Bad — contains PII
Sentry.setUser({ id: user.sub, email: user.email, username: user.name })
```

## Scopes and context

Use `Sentry.withScope()` to attach context to a single capture without polluting the global scope.

```ts
Sentry.withScope(scope => {
  scope.setTag('feature', 'import')
  scope.setExtra('recordCount', records.length)
  scope.setExtra('fileType', fileType)
  Sentry.captureException(err)
})
```

Use `Sentry.setContext()` for structured context that persists for the session:

```ts
// After loading order details
Sentry.setContext('order', {
  id: order.id,
  status: order.status,
  itemCount: order.items.length,
})
```

## Source maps

Source maps let Sentry show readable stack traces for minified production builds.

- Generate source maps in the production build (`sourcemap: true` in Vite/Webpack)
- Upload to Sentry in CI during deployment (Vite plugin or `sentry-cli`)
- Delete source maps from the build output after upload — they must not be served publicly
- Source maps are tied to `release` — the release must match between init and upload

```yaml
# CI step — after build, before deploy
- name: Upload Sentry source maps
  run: npx sentry-cli releases files $GITHUB_SHA upload-sourcemaps ./dist
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: my-org
    SENTRY_PROJECT: my-project
```

## Alert routing

Configure in Sentry Dashboard → Alerts:

| Rule | Condition | Action |
|---|---|---|
| New Issue | First seen, any environment | Slack `#alerts-<project>` |
| Regression | Issue regresses after resolve | Slack `#alerts-<project>` + assignee DM |
| High volume | > 100 events in 1 hour | Slack `#incidents` + PagerDuty |
| Production error | Environment = production | Slack `#alerts-prod` |

## Performance monitoring

Sentry can trace React rendering and API call performance. Wrap route components with `Sentry.withProfiler()` for deep profiling in staging.

```ts
// React Router v6 integration — automatic route-level tracing
import * as Sentry from '@sentry/react'

Sentry.init({
  integrations: [
    Sentry.reactRouterV6BrowserTracingIntegration({
      useEffect,
      useLocation,
      useNavigationType,
      createRoutesFromChildren,
      matchRoutes,
    }),
  ],
  tracesSampleRate: 0.1,
})
```

## Environment configuration

| Variable | Description |
|---|---|
| `VITE_SENTRY_DSN` | Project DSN from Sentry Dashboard → Settings → Client Keys |
| `VITE_SENTRY_RELEASE` | Git SHA or tag, injected at build time by CI |
| `VITE_ENV` | `production` / `staging` / `development` |
| `SENTRY_AUTH_TOKEN` | CI secret for source map upload — never in client code |
