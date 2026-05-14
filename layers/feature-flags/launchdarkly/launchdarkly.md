# LaunchDarkly Standards

---

## Setup

```bash
# Server-side
npm install @launchdarkly/node-server-sdk

# Client-side (React)
npm install launchdarkly-react-client-sdk
```

---

## Flag key constants

```typescript
// src/lib/flags.ts — single source of truth for flag keys
export const FLAGS = {
  // Feature rollouts
  NEW_CHECKOUT_FLOW:    'new-checkout-flow',
  ENABLE_DARK_MODE:     'enable-dark-mode',
  SEARCH_USE_ALGOLIA:   'search-use-algolia',

  // Configuration values (non-boolean)
  MAX_UPLOAD_SIZE_MB:   'max-upload-size-mb',      // number flag
  PAYMENT_PROVIDER:     'payments-provider',        // string flag: 'stripe' | 'braintree'
  PROMO_BANNER_CONFIG:  'marketing-promo-banner',   // JSON flag
} as const

export type FlagKey = typeof FLAGS[keyof typeof FLAGS]
```

---

## Server-side SDK

```typescript
// src/lib/launchdarkly.ts
import * as ld from '@launchdarkly/node-server-sdk'

let ldClient: ld.LDClient | null = null

export async function getLDClient(): Promise<ld.LDClient> {
  if (ldClient) return ldClient

  ldClient = ld.init(process.env.LAUNCHDARKLY_SDK_KEY!, {
    // Optional: send events in batches
    flushInterval: 5000,
  })

  await ldClient.waitForInitialization({ timeout: 5 })  // fail fast at startup
  return ldClient
}

// Typed wrapper — returns the flag value or the default
export async function getFlag<T extends boolean | string | number | object>(
  key: FlagKey,
  context: ld.LDContext,
  defaultValue: T
): Promise<T> {
  const client = await getLDClient()
  return client.variation(key, context, defaultValue) as T
}
```

```typescript
// Building a context (user targeting)
import type { LDContext } from '@launchdarkly/node-server-sdk'

export function buildUserContext(user: AuthenticatedUser): LDContext {
  return {
    kind: 'user',
    key:  user.id,                    // stable, unique identifier
    // Targeting attributes — include what your rules need
    email:   user.email,
    plan:    user.subscriptionPlan,   // 'free' | 'pro' | 'enterprise'
    country: user.country,
    role:    user.role,
  }
}
```

```typescript
// Usage in an API route / service
import { getFlag, buildUserContext } from '../../lib/launchdarkly'
import { FLAGS } from '../../lib/flags'

export async function getCheckoutUrl(user: AuthenticatedUser): Promise<string> {
  const context        = buildUserContext(user)
  const useNewCheckout = await getFlag(FLAGS.NEW_CHECKOUT_FLOW, context, false)

  return useNewCheckout ? '/checkout/v2' : '/checkout/v1'
}
```

---

## React client SDK

```typescript
// src/app/layout.tsx (Next.js) or index.tsx
import { LDProvider } from 'launchdarkly-react-client-sdk'

interface User {
  id:    string
  email: string
  plan:  string
}

export function AppProviders({ user, children }: { user: User; children: React.ReactNode }) {
  return (
    <LDProvider
      clientSideID={process.env.NEXT_PUBLIC_LAUNCHDARKLY_CLIENT_ID!}
      context={{
        kind:  'user',
        key:   user.id,
        email: user.email,
        plan:  user.plan,
      }}
      options={{
        streaming:  true,   // real-time flag updates
        fetchGoals: false,   // disable A/B goal tracking if not using it
      }}
    >
      {children}
    </LDProvider>
  )
}
```

```tsx
// src/features/checkout/CheckoutPage.tsx
import { useFlags } from 'launchdarkly-react-client-sdk'
import { FLAGS } from '../../lib/flags'

export function CheckoutPage() {
  const flags = useFlags()
  const useNewFlow = flags[FLAGS.NEW_CHECKOUT_FLOW] ?? false  // default if not loaded

  return useNewFlow ? <NewCheckoutFlow /> : <LegacyCheckoutFlow />
}
```

```tsx
// For a single flag — useFlags() returns all flags; useLDClient() for programmatic use
import { useLDClient } from 'launchdarkly-react-client-sdk'

export function UploadButton() {
  const ldClient = useLDClient()
  const maxMb    = ldClient?.variation(FLAGS.MAX_UPLOAD_SIZE_MB, 10) ?? 10

  return <input type="file" data-max-mb={maxMb} />
}
```

---

## Server-side rendering (Next.js)

```typescript
// Evaluate flags on the server; pass to the client component as props
// src/app/checkout/page.tsx
import { getLDClient, buildUserContext } from '@/lib/launchdarkly'
import { FLAGS } from '@/lib/flags'

export default async function CheckoutPage() {
  const user    = await getCurrentUser()
  const context = buildUserContext(user)
  const client  = await getLDClient()

  const useNewFlow = await client.variation(FLAGS.NEW_CHECKOUT_FLOW, context, false)

  return <CheckoutContent useNewFlow={useNewFlow} />
}
```

---

## Testing with testData source

```typescript
// src/lib/__tests__/checkout.test.ts
import * as ld from '@launchdarkly/node-server-sdk'
import { getCheckoutUrl } from '../checkout'

// Mock the LD client for unit tests
jest.mock('@launchdarkly/node-server-sdk')

const mockVariation = jest.fn()

beforeEach(() => {
  jest.mocked(ld.init).mockReturnValue({
    waitForInitialization: jest.fn().mockResolvedValue(undefined),
    variation:             mockVariation,
    flush:                 jest.fn().mockResolvedValue(undefined),
    close:                 jest.fn().mockResolvedValue(undefined),
  } as unknown as ld.LDClient)
})

test('returns v2 URL when new-checkout-flow flag is on', async () => {
  mockVariation.mockResolvedValue(true)

  const url = await getCheckoutUrl(mockUser)
  expect(url).toBe('/checkout/v2')
})

test('returns v1 URL when new-checkout-flow flag is off', async () => {
  mockVariation.mockResolvedValue(false)

  const url = await getCheckoutUrl(mockUser)
  expect(url).toBe('/checkout/v1')
})
```

---

## Flag lifecycle checklist

When adding a new flag:
- [ ] Key follows `kebab-case` convention and is in `FLAGS` constants
- [ ] Flag has a description and owner tag in the LaunchDarkly dashboard
- [ ] Default value (flag off) is the safe/existing behaviour
- [ ] Targeting rules are documented (which users/segments get it first)

When retiring a flag:
- [ ] 100% rollout confirmed and stable for ≥ 1 sprint
- [ ] Remove all `variation()` calls and conditional code from the codebase
- [ ] Delete the constant from `flags.ts`
- [ ] Archive the flag in the LaunchDarkly dashboard

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Server SDK key in the browser | Use client-side SDK key (`NEXT_PUBLIC_*`) in the browser — never the server SDK key |
| Raw string flag keys scattered across codebase | Centralise in `flags.ts` constants |
| No default value in `variation()` | Always pass a safe default — the flag may not be evaluated if LD is down |
| Evaluating flags deep in utility functions | Evaluate at the feature/page level; pass down as props |
| Flags used as permanent access control | Flags are for rollout; use RBAC/permissions for permanent access decisions |
| Leaving retired flags as dead code | Remove the code path and archive the flag — technical debt accumulates fast |
