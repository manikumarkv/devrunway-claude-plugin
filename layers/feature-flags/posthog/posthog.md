# PostHog Feature Flags Standards

---

## Setup

```bash
# Server-side
npm install posthog-node

# Client-side
npm install posthog-js

# React
npm install posthog-js   # includes React provider
```

---

## Server-side (Node.js)

```typescript
// src/lib/posthog.ts — singleton client
import { PostHog } from 'posthog-node'

let client: PostHog | null = null

export function getPostHogClient(): PostHog {
  if (client) return client

  client = new PostHog(process.env.POSTHOG_API_KEY!, {
    host:         process.env.POSTHOG_HOST ?? 'https://app.posthog.com',
    flushAt:      20,       // batch size
    flushInterval: 10_000, // flush every 10s
  })

  return client
}

// Call in process exit handler
export async function shutdownPostHog() {
  await client?.shutdown()
}

process.on('SIGTERM', shutdownPostHog)
process.on('SIGINT',  shutdownPostHog)
```

---

## Flag key constants

```typescript
// src/lib/flags.ts — central flag key registry
export const FLAGS = {
  NEW_ONBOARDING_FLOW:    'new-onboarding-flow',
  CHECKOUT_VARIANT:       'checkout-variant',           // multivariate
  ENABLE_AI_SEARCH:       'enable-ai-search',
  SHOW_REFERRAL_BANNER:   'show-referral-banner',
  MAX_TEAM_SIZE:          'max-team-size',              // payload flag (number)
} as const

export type FlagKey = typeof FLAGS[keyof typeof FLAGS]
```

---

## Feature flag evaluation — server-side

```typescript
// src/lib/feature-flags.ts
import { getPostHogClient } from './posthog'
import type { FlagKey } from './flags'

interface FlagContext {
  userId:    string
  email?:    string
  plan?:     string
  country?:  string
  orgId?:    string
}

// Boolean flag
export async function isEnabled(
  flag: FlagKey,
  context: FlagContext,
  defaultValue = false
): Promise<boolean> {
  try {
    const client = getPostHogClient()
    const result = await client.isFeatureEnabled(flag, context.userId, {
      personProperties: {
        email:   context.email,
        plan:    context.plan,
        country: context.country,
      },
      groups: context.orgId ? { company: context.orgId } : undefined,
    })
    return result ?? defaultValue
  } catch {
    return defaultValue   // fail safe — always return the default
  }
}

// Multivariate flag — returns the variant string or null
export async function getVariant(
  flag: FlagKey,
  context: FlagContext
): Promise<string | boolean | null> {
  try {
    const client = getPostHogClient()
    return await client.getFeatureFlag(flag, context.userId, {
      personProperties: {
        email: context.email,
        plan:  context.plan,
      },
    }) ?? null
  } catch {
    return null
  }
}

// Flag with payload (JSON value attached to the flag variant)
export async function getFlagPayload<T>(
  flag: FlagKey,
  context: FlagContext
): Promise<T | null> {
  try {
    const client = getPostHogClient()
    const payload = await client.getFeatureFlagPayload(flag, context.userId)
    return payload as T ?? null
  } catch {
    return null
  }
}
```

---

## Usage in API routes / services

```typescript
// src/features/onboarding/onboarding.service.ts
import { isEnabled, getVariant } from '../../lib/feature-flags'
import { FLAGS } from '../../lib/flags'

export async function getOnboardingFlow(user: AuthenticatedUser) {
  const context = {
    userId:  user.id,
    email:   user.email,
    plan:    user.plan,
    country: user.country,
  }

  const useNewFlow = await isEnabled(FLAGS.NEW_ONBOARDING_FLOW, context)

  return useNewFlow ? 'v2' : 'v1'
}

// A/B test — checkout variant
export async function getCheckoutVariant(user: AuthenticatedUser): Promise<'control' | 'variant-b'> {
  const variant = await getVariant(FLAGS.CHECKOUT_VARIANT, { userId: user.id, email: user.email })

  // Track experiment exposure
  const posthog = getPostHogClient()
  posthog.capture({
    distinctId: user.id,
    event:      '$feature_flag_called',
    properties: {
      $feature_flag:          FLAGS.CHECKOUT_VARIANT,
      $feature_flag_response: variant,
    },
  })

  return variant === 'variant-b' ? 'variant-b' : 'control'
}
```

---

## React client-side

```tsx
// src/app/providers.tsx
'use client'
import posthog from 'posthog-js'
import { PostHogProvider } from 'posthog-js/react'
import { useEffect } from 'react'

export function PHProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
      api_host:               process.env.NEXT_PUBLIC_POSTHOG_HOST ?? 'https://app.posthog.com',
      capture_pageview:       false,  // handle manually with Next.js router
      capture_pageleave:      true,
      loaded: (ph) => {
        if (process.env.NODE_ENV === 'development') {
          ph.debug()
        }
      },
    })
  }, [])

  return <PostHogProvider client={posthog}>{children}</PostHogProvider>
}
```

```tsx
// Identify the user after login
import posthog from 'posthog-js'

function onLoginSuccess(user: User) {
  posthog.identify(user.id, {    // always use stable DB ID, not email
    email:      user.email,
    plan:       user.plan,
    created_at: user.createdAt,
  })

  // Group by organisation
  if (user.orgId) {
    posthog.group('company', user.orgId, { name: user.orgName })
  }
}
```

```tsx
// Using flags in React components
import { useFeatureFlagEnabled, useFeatureFlagVariantKey } from 'posthog-js/react'
import { FLAGS } from '../../lib/flags'

export function CheckoutPage() {
  const useNewFlow = useFeatureFlagEnabled(FLAGS.NEW_ONBOARDING_FLOW)
  // useFeatureFlagEnabled returns undefined while loading — treat undefined as false
  if (useNewFlow === undefined) return <LoadingSkeleton />

  return useNewFlow ? <NewCheckout /> : <LegacyCheckout />
}

// Multivariate
export function HeroSection() {
  const variant = useFeatureFlagVariantKey(FLAGS.CHECKOUT_VARIANT)

  if (variant === 'variant-b') return <HeroVariantB />
  return <HeroControl />
}
```

---

## Next.js — server-side flag evaluation (no client round-trip)

```typescript
// src/app/checkout/page.tsx
import { isEnabled } from '@/lib/feature-flags'
import { FLAGS } from '@/lib/flags'

export default async function CheckoutPage() {
  const user      = await getCurrentUser()
  const useNewFlow = await isEnabled(FLAGS.NEW_ONBOARDING_FLOW, {
    userId: user.id,
    email:  user.email,
    plan:   user.plan,
  })

  return useNewFlow ? <NewCheckoutFlow /> : <LegacyCheckoutFlow />
}
```

---

## Event capture best practices

```typescript
const posthog = getPostHogClient()

// Capture a business event with relevant properties
posthog.capture({
  distinctId: user.id,
  event:      'order_completed',
  properties: {
    order_id:       order.id,
    order_total:    order.total,
    payment_method: order.paymentMethod,
    item_count:     order.items.length,
    // PostHog auto-links to active feature flags — no need to add them here
  },
})
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `posthog.identify()` with email as distinct ID | Use the stable database user ID — email can change |
| No fallback for `isFeatureEnabled()` | It returns `undefined` if not loaded; always provide a default |
| Evaluating flags inside every render | Evaluate once at component mount or page level; store in state |
| `posthog.shutdown()` not called in scripts | Buffered events are lost on process exit — always flush |
| Using PostHog flags for access control | Flags are for rollout; RBAC is for access control |
| Leaving old experiment code paths after rollout | Remove the losing variant code; archive the flag |
| Client-side API key exposed as server key | `NEXT_PUBLIC_POSTHOG_KEY` is the project API key — it IS intended for the browser |
