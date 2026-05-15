# Flagsmith Standards

## Flag Registry (Single Source of Truth)

```typescript
// src/flags/registry.ts
export const FLAGS = {
  NEW_CHECKOUT_FLOW: "new_checkout_flow",
  AI_RECOMMENDATIONS: "ai_recommendations",
  DARK_MODE: "dark_mode",
  BETA_DASHBOARD: "beta_dashboard",
} as const;

export type FlagName = (typeof FLAGS)[keyof typeof FLAGS];
```

## Browser SDK Initialization

```typescript
// src/lib/flagsmith.ts
import flagsmith from "flagsmith";

let initialized = false;

export async function initFlagsmith(userId?: string, traits?: Record<string, string | number | boolean>) {
  if (initialized) return;

  await flagsmith.init({
    environmentID: import.meta.env.VITE_FLAGSMITH_ENVIRONMENT_ID,
    cacheFlags: true,
    defaultFlags: {
      new_checkout_flow: { enabled: false, value: null },
      ai_recommendations: { enabled: false, value: null },
      dark_mode: { enabled: false, value: null },
      beta_dashboard: { enabled: false, value: null },
    },
    ...(userId ? {
      identity: userId,
      traits,
    } : {}),
    onChange: (oldFlags, params) => {
      if (params.flagsChanged) {
        console.info("Feature flags updated", { changed: params.flagsChanged });
      }
    },
  });

  initialized = true;
}

export { flagsmith };
```

## React Provider

```tsx
// src/main.tsx
import { FlagsmithProvider } from "flagsmith/react";
import flagsmith from "./lib/flagsmith";
import { FLAGS } from "./flags/registry";

// Initialize before render with user identity
const userId = getAuthenticatedUserId();
const traits = userId ? { plan: getUserPlan(), country: getUserCountry() } : undefined;

ReactDOM.createRoot(document.getElementById("root")!).render(
  <FlagsmithProvider
    flagsmith={flagsmith}
    options={{
      environmentID: import.meta.env.VITE_FLAGSMITH_ENVIRONMENT_ID,
      identity: userId,
      traits,
      defaultFlags: {
        [FLAGS.NEW_CHECKOUT_FLOW]: { enabled: false, value: null },
        [FLAGS.AI_RECOMMENDATIONS]: { enabled: false, value: null },
      },
    }}
  >
    <App />
  </FlagsmithProvider>,
);
```

## useFlags Hook in Components

```tsx
// src/features/checkout/CheckoutPage.tsx
import { useFlags, useIsLoading } from "flagsmith/react";
import { FLAGS } from "../../flags/registry";

export function CheckoutPage() {
  const isLoading = useIsLoading();
  const flags = useFlags([FLAGS.NEW_CHECKOUT_FLOW]);

  // Always handle the loading state
  if (isLoading) {
    return <CheckoutSkeleton />;
  }

  // Use enabled state — defaults to false if flag absent
  if (flags.new_checkout_flow.enabled) {
    return <NewCheckoutFlow />;
  }
  return <LegacyCheckoutFlow />;
}
```

## Traits and Segment Targeting

```typescript
// Set traits after user authenticates — drives segment matching
import { flagsmith } from "../lib/flagsmith";

export async function onUserLogin(user: User) {
  await flagsmith.setTraits({
    plan: user.subscriptionPlan,          // "free" | "pro" | "enterprise"
    country: user.country,                // "US" | "GB" etc.
    account_age_days: user.accountAgeDays,
    // NEVER include: email, password, SSN, card number
  });
}
```

## Server-Side (Node.js) Evaluation

```typescript
// src/lib/flagsmithServer.ts
import Flagsmith from "flagsmith-nodejs";

const client = new Flagsmith({
  environmentKey: process.env.FLAGSMITH_SERVER_KEY!,
  enableLocalEvaluation: true,          // evaluates locally without API call per request
  environmentRefreshIntervalSeconds: 60,
});

await client.init();
export { client as flagsmithServer };
```

```typescript
// src/middleware/featureFlags.ts — per-request evaluation
import { flagsmithServer } from "../lib/flagsmithServer";
import { FLAGS } from "../flags/registry";
import { Request, Response, NextFunction } from "express";

export async function featureFlagsMiddleware(req: Request, res: Response, next: NextFunction) {
  const userId = req.user?.id;

  try {
    const flags = userId
      ? await flagsmithServer.getIdentityFlags(userId, { plan: req.user!.plan })
      : await flagsmithServer.getEnvironmentFlags();

    // Attach to request for use in handlers
    req.flags = {
      isNewCheckout: flags.isFeatureEnabled(FLAGS.NEW_CHECKOUT_FLOW),
      hasAiRecs: flags.isFeatureEnabled(FLAGS.AI_RECOMMENDATIONS),
    };
  } catch (err) {
    console.warn("Flagsmith unavailable — using defaults", { err });
    req.flags = {
      isNewCheckout: false,
      hasAiRecs: false,
    };
  }

  next();
}
```

## Value Flags

```typescript
// Flags can carry string/number/JSON values
const flags = await client.getIdentityFlags(userId);

// String value flag — e.g., banner message, API URL override
const bannerText = flags.getFeatureValue("banner_message") as string | null;

// JSON value flag
const checkoutConfig = JSON.parse(
  flags.getFeatureValue("checkout_config") as string ?? "{}"
);
```

## Testing with Flagsmith

```typescript
// Mock flagsmith in tests
vi.mock("flagsmith/react", () => ({
  useFlags: (flagNames: string[]) =>
    Object.fromEntries(flagNames.map((n) => [n, { enabled: false, value: null }])),
  useIsLoading: () => false,
  FlagsmithProvider: ({ children }: { children: React.ReactNode }) => children,
}));

// Override for a specific test
vi.mocked(useFlags).mockReturnValue({
  new_checkout_flow: { enabled: true, value: null },
});
```

## Checklist

- [ ] `FLAGSMITH_ENVIRONMENT_ID` / `FLAGSMITH_SERVER_KEY` from environment variables
- [ ] `defaultFlags` defined for all known flags — never assume a flag exists
- [ ] Flag names centralized in `src/flags/registry.ts`
- [ ] `useIsLoading()` handled in React components — no blocking render
- [ ] Server-side SDK uses `enableLocalEvaluation: true` — no per-request API call
- [ ] Traits set after authentication — no PII in trait values
- [ ] Flagsmith unavailability handled gracefully with safe defaults
