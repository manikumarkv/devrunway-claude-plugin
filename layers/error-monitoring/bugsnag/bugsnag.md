# Bugsnag Standards

## Browser / React Initialization

```typescript
// src/lib/bugsnag.ts
import Bugsnag from "@bugsnag/js";
import BugsnagPluginReact from "@bugsnag/plugin-react";
import React from "react";

Bugsnag.start({
  apiKey: import.meta.env.VITE_BUGSNAG_API_KEY,
  plugins: [new BugsnagPluginReact()],
  releaseStage: import.meta.env.VITE_RELEASE_STAGE ?? "development",
  enabledReleaseStages: ["staging", "production"],
  appVersion: import.meta.env.VITE_APP_VERSION,  // git SHA or semver
  onError: (event) => {
    // Enrich all events with the current user (set after login)
    const user = getCurrentUser();
    if (user) {
      event.setUser(user.id, user.email, user.name);
    }
    // Scrub sensitive fields
    event.errors.forEach((error) => {
      error.stacktrace.forEach((frame) => {
        // source maps handle file paths — no manual scrubbing needed
      });
    });
  },
});

export const ErrorBoundary = Bugsnag.getPlugin("react")!.createErrorBoundary(React);
export default Bugsnag;
```

## React Error Boundary

```tsx
// src/main.tsx
import { ErrorBoundary } from "./lib/bugsnag";
import FallbackUI from "./components/FallbackUI";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <ErrorBoundary FallbackComponent={FallbackUI}>
    <App />
  </ErrorBoundary>,
);
```

```tsx
// src/components/FallbackUI.tsx
interface FallbackProps {
  error: Error;
  info: React.ErrorInfo;
  clearError: () => void;
}

export default function FallbackUI({ error, clearError }: FallbackProps) {
  return (
    <div role="alert" className="error-page">
      <h1>Something went wrong</h1>
      <p>Our team has been notified. Please try again.</p>
      <button onClick={clearError}>Try again</button>
    </div>
  );
}
```

## Feature-Level Error Boundary

```tsx
// src/features/checkout/CheckoutPage.tsx
import { ErrorBoundary } from "../../lib/bugsnag";

export function CheckoutPage() {
  return (
    <ErrorBoundary FallbackComponent={CheckoutErrorFallback}>
      <CheckoutForm />
    </ErrorBoundary>
  );
}
```

## Breadcrumbs

```typescript
import Bugsnag from "./lib/bugsnag";

// Navigation breadcrumb
Bugsnag.leaveBreadcrumb("Page navigated", { from: "/dashboard", to: "/checkout" }, "navigation");

// API request breadcrumb
Bugsnag.leaveBreadcrumb("API request", {
  method: "POST",
  url: "/api/orders",
  status: 201,
}, "request");

// User action
Bugsnag.leaveBreadcrumb("Checkout initiated", {
  cartItems: 3,
  total: "49.99",
}, "user");

// State change
Bugsnag.leaveBreadcrumb("Feature flag evaluated", {
  flag: "new-checkout-flow",
  value: true,
}, "state");
```

## Manual Error Notification

```typescript
import Bugsnag from "./lib/bugsnag";

async function processPayment(orderId: string, payload: PaymentPayload) {
  try {
    return await paymentApi.charge(payload);
  } catch (err) {
    Bugsnag.notify(err as Error, (event) => {
      event.severity = "error";
      event.addMetadata("payment", {
        orderId,
        gateway: "stripe",
        // NEVER include: cardNumber, cvv, full amount (privacy)
      });
      event.addMetadata("request", {
        userId: getCurrentUserId(),
        sessionId: getSessionId(),
      });
    });
    throw err; // always rethrow — don't swallow
  }
}
```

## Severity Levels

```typescript
// Error — unexpected, indicates a bug, pages on-call
Bugsnag.notify(err, (event) => { event.severity = "error"; });

// Warning — degraded but expected edge case, review daily
Bugsnag.notify(err, (event) => { event.severity = "warning"; });

// Info — notable event, not necessarily actionable
Bugsnag.notify(err, (event) => { event.severity = "info"; });
```

## Custom Grouping

```typescript
// Force errors with different messages into one group
Bugsnag.notify(err, (event) => {
  event.groupingHash = "payment-timeout";  // all payment timeouts → one group
});
```

## Node.js (Backend)

```typescript
// src/lib/bugsnag.ts (Node.js)
import Bugsnag from "@bugsnag/node";

Bugsnag.start({
  apiKey: process.env.BUGSNAG_API_KEY!,
  releaseStage: process.env.NODE_ENV,
  enabledReleaseStages: ["staging", "production"],
  appVersion: process.env.APP_VERSION,
  logger: null,   // use your own logger for Bugsnag internal logs
});

export default Bugsnag;
```

```typescript
// Express middleware — catches unhandled errors
import { errorHandler, requestHandler } from "@bugsnag/plugin-express";

app.use(requestHandler);   // must be first middleware
// ... routes ...
app.use(errorHandler);     // must be last middleware
```

## Source Maps Upload (Vite)

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import bugsnagBuildReporter from "@bugsnag/build-reporter-vite-plugin";
import bugsnagSourceMaps from "@bugsnag/source-map-uploader-vite-plugin";

export default defineConfig({
  plugins: [
    bugsnagBuildReporter({
      apiKey: process.env.BUGSNAG_API_KEY!,
      appVersion: process.env.APP_VERSION!,
    }),
    bugsnagSourceMaps({
      apiKey: process.env.BUGSNAG_API_KEY!,
      appVersion: process.env.APP_VERSION!,
      overwrite: true,
    }),
  ],
});
```

## Source Maps Upload (CLI — CI Step)

```bash
# Run after npm run build, before deploy
npx @bugsnag/source-maps upload \
  --api-key $BUGSNAG_API_KEY \
  --app-version $GIT_SHA \
  --directory dist/ \
  --overwrite
```

## Checklist

- [ ] `enabledReleaseStages` excludes `development` — no noise in dev
- [ ] `apiKey` from environment variable — not committed
- [ ] `appVersion` set to git SHA or semver
- [ ] Root ErrorBoundary wraps the entire app
- [ ] Major feature sections have their own ErrorBoundary
- [ ] Source maps uploaded in CI before deploy
- [ ] `onError` callback sets user context after login
- [ ] No PII in `addMetadata` calls
