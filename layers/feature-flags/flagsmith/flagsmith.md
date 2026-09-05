# Flagsmith Standards

## Flag Registry (Single Source of Truth)

```typescript
// src/flags/registry.ts
export const FLAGS = {
  NEW_CHECKOUT_FLOW: "new_checkout_flow",
  AI_RECOMMENDATIONS: "ai_recommendations",
  DARK_MODE: "dark_mode",
  BETA_DASHBOARD: "beta_dashboard",
  BANNER_MESSAGE: "banner_message",
} as const;

export type FlagName = (typeof FLAGS)[keyof typeof FLAGS];
```

## Browser SDK Initialization

```typescript
// src/lib/flagsmith.ts
import flagsmith from "flagsmith";

let initialized = false;

export async function initFlagsmith(user?: { id: string; plan: string; country: string }) {
  if (initialized) return;

  await flagsmith.init({
    // environmentID is the BROWSER key option. It takes the public client-side
    // key and belongs only in code that ships to the browser — never in a server
    // component or an API route. The server has its own key and its own SDK.
    environmentID: import.meta.env.VITE_FLAGSMITH_ENVIRONMENT_ID,
    cacheFlags: true,
    defaultFlags: {
      new_checkout_flow: { enabled: false, value: null },
      ai_recommendations: { enabled: false, value: null },
      dark_mode: { enabled: false, value: null },
      beta_dashboard: { enabled: false, value: null },
    },
    ...(user ? {
      identity: user.id,
      traits: { plan: user.plan, country: user.country },
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
// Same rule as above: environmentID is the browser key, and this file is browser code.

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
  // The identity is who Flagsmith evaluates for; the traits are what its segment
  // rules match on. Traits are stored in Flagsmith and visible in its dashboard,
  // so they carry opaque ids and tiers — never a name, an address, a phone
  // number, a password, a card number, a government id, or an email address.
  await flagsmith.identify(user.id, {
    plan: user.subscriptionPlan,          // "free" | "pro" | "enterprise"
    country: user.country,                // "US" | "GB" etc.
    account_age_days: user.accountAgeDays,
  });
}

// Adding traits later, for an identity already set
export async function onPlanChange(plan: string) {
  await flagsmith.setTraits({ plan });
}
```

## Reading a value flag in the browser

```typescript
// src/features/banner/bannerMessage.ts
import { flagsmith } from "../../lib/flagsmith";
import { FLAGS } from "../../flags/registry";

const DEFAULT_BANNER = "";

export function bannerMessage(): string {
  // hasFeature first: a flag that does not exist (typo, not yet created, deleted)
  // reads as null, and rendering "null" is worse than rendering nothing.
  if (!flagsmith.hasFeature(FLAGS.BANNER_MESSAGE)) return DEFAULT_BANNER;

  return (flagsmith.getValue(FLAGS.BANNER_MESSAGE, { fallback: DEFAULT_BANNER }) ??
    DEFAULT_BANNER) as string;
}
```

`flagsmith.hasFeature(` and `flagsmith.getValue(` are **browser** SDK methods.
The server SDK has neither: it returns a flags object per evaluation, and you read
from that — see below.

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

## Next.js server component

```tsx
// app/checkout/page.tsx — a React Server Component
import { flagsmithServer } from "@/lib/flagsmithServer";
import { FLAGS } from "@/flags/registry";
import { getSession } from "@/lib/auth";

export default async function CheckoutPage() {
  const session = await getSession();

  // Server evaluation, server key, server SDK. The browser client is not
  // imported here and the browser key is not referenced here: a server component
  // that initialises the browser SDK has to be given the public key, and a
  // sensitive flag then becomes a value the user can read and a rollout they can
  // see before it reaches them.
  const flags = session
    ? await flagsmithServer.getIdentityFlags(session.userId, { plan: session.plan })
    : await flagsmithServer.getEnvironmentFlags();

  return flags.isFeatureEnabled(FLAGS.NEW_CHECKOUT_FLOW)
    ? <NewCheckoutFlow />
    : <LegacyCheckoutFlow />;
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

## Common mistakes

| Mistake | Fix |
|---|---|
| Not defining `defaultFlags` | If the Flagsmith API is unreachable on first load, all flags evaluate to `undefined`; always declare defaults for every known flag |
| Checking a flag before `useIsLoading()` resolves | While flags are loading, `isFeatureEnabled` returns the default; render a skeleton/spinner until `isLoading` is `false` |
| Hardcoding flag name strings at call sites | Centralize all flag names in `src/flags/registry.ts`; typos in string literals silently evaluate to disabled |
| Using the client-side SDK key on the server | The browser SDK key is public; the server SDK requires a separate server-side key (`FLAGSMITH_SERVER_KEY`) |
| `environmentID` in a server component or API route | That option belongs to the browser SDK and takes the public key; server code uses `flagsmith-nodejs` with `environmentKey` |
| Calling the browser SDK's `hasFeature`/`getValue` on the server | The server SDK returns a flags object per evaluation — read with `isFeatureEnabled` and `getFeatureValue` on that object |
| Sending an email address or any personal detail as a trait | Traits are stored and displayed in Flagsmith; send an opaque id and a tier |
| Not enabling `enableLocalEvaluation` on the server SDK | Without it, every request makes a network call to Flagsmith, adding latency and creating a hard dependency on availability |
| Including PII in trait values | Traits are stored in Flagsmith; never pass email, SSN, or payment details — use opaque IDs and plan tiers instead |
| Calling `flagsmith.init()` multiple times | Guard with an `initialized` flag; reinitializing resets the cache and may cause race conditions |
