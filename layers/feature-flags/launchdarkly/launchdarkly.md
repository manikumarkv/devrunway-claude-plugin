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

// Test seam — install a client built on a TestData source, or null to reset.
// Without this the module-level cache has no injection point and tests are
// pushed into mocking the SDK module, which stops exercising it entirely.
export function setLDClient(client: ld.LDClient | null): void {
  ldClient = client
}

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
      reactOptions={{
        // The React SDK camelCases flag keys by default, so useFlags() would
        // expose 'new-checkout-flow' as `newCheckoutFlow` and a lookup by the
        // FLAGS constant would silently read undefined. Turn it off so the
        // kebab-case keys in flags.ts stay the single source of truth.
        useCamelCaseFlagKeys: false,
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
  // Reads the raw key because the provider sets useCamelCaseFlagKeys: false
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

## Testing with a TestData source

`TestData` is the SDK's own test data source. It builds a real `LDClient` whose
flag values you control in-process — no network, and no module mocking, so the
SDK's evaluation logic is still exercised. It lives on the `integrations`
namespace of the server SDK, and in v9 it is a class: construct it with `new`.

```typescript
// src/lib/__tests__/checkout.test.ts
import * as ld from '@launchdarkly/node-server-sdk'
import { TestData } from '@launchdarkly/node-server-sdk/integrations'
import { setLDClient } from '../launchdarkly'
import { FLAGS } from '../flags'
import { getCheckoutUrl } from '../checkout'

let td: TestData
let client: ld.LDClient

beforeEach(async () => {
  td = new TestData()

  // A real client, fed by TestData instead of by LaunchDarkly's servers
  client = ld.init('sdk-key-unused-in-tests', {
    updateProcessor: td.getFactory(),
    sendEvents:      false,
    diagnosticOptOut: true,
  })
  await client.waitForInitialization({ timeout: 5 })

  setLDClient(client)   // inject through the seam, not through a module mock
})

afterEach(async () => {
  setLDClient(null)
  await client.close()
})

test('returns v2 URL when new-checkout-flow flag is on', async () => {
  await td.update(td.flag(FLAGS.NEW_CHECKOUT_FLOW).booleanFlag().variationForAll(true))

  expect(await getCheckoutUrl(mockUser)).toBe('/checkout/v2')
})

test('returns v1 URL when new-checkout-flow flag is off', async () => {
  await td.update(td.flag(FLAGS.NEW_CHECKOUT_FLOW).booleanFlag().variationForAll(false))

  expect(await getCheckoutUrl(mockUser)).toBe('/checkout/v1')
})

test('targets a single user without touching everyone else', async () => {
  await td.update(
    td.flag(FLAGS.NEW_CHECKOUT_FLOW)
      .variationForContext('user', 'beta-user', true)
      .fallthroughVariation(false)
  )

  expect(await getCheckoutUrl({ ...mockUser, id: 'beta-user' })).toBe('/checkout/v2')
  expect(await getCheckoutUrl({ ...mockUser, id: 'other-user' })).toBe('/checkout/v1')
})
```

Never replace the LaunchDarkly module with a test double. A module double asserts
only that your code called a function you wrote the return value of — flag
targeting, context matching, defaults and the kebab/camel key handling all go
untested, and the double drifts from the SDK on every upgrade without failing.

### Testing a React component

`TestData` is a server-SDK data source and has no client-side equivalent. Render
the component inside the React SDK's own context with the flag values the test
needs — still no network, still no module double:

```tsx
// src/features/checkout/__tests__/CheckoutPage.test.tsx
import { render, screen } from '@testing-library/react'
import { defaultReactOptions } from 'launchdarkly-react-client-sdk'
import { FLAGS } from '@/lib/flags'
import { CheckoutPage } from '../CheckoutPage'

function renderWithFlags(flags: Record<string, unknown>) {
  const { Provider } = defaultReactOptions.reactContext
  return render(
    <Provider value={{ flags, flagKeyMap: {}, ldClient: undefined }}>
      <CheckoutPage />
    </Provider>
  )
}

test('renders the new flow when the flag is on', () => {
  renderWithFlags({ [FLAGS.NEW_CHECKOUT_FLOW]: true })
  expect(screen.getByTestId('checkout-v2')).toBeInTheDocument()
})

test('falls back to the legacy flow when the flag is absent', () => {
  renderWithFlags({})
  expect(screen.getByTestId('checkout-v1')).toBeInTheDocument()
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
| Replacing the LaunchDarkly module with a test double | Build a real client on a `TestData` source and inject it — a module double never exercises targeting, defaults or key handling |
| Reading a kebab-case key off `useFlags()` | The React SDK camelCases keys by default — set `useCamelCaseFlagKeys: false` on the provider, or the lookup silently returns `undefined` |
