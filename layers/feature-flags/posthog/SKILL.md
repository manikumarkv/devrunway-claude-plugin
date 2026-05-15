---
name: posthog
description: PostHog feature flags standards — flag evaluation, gradual rollouts, A/B testing, multivariate flags, and analytics integration. Load when working with PostHog.
user-invocable: false
stack: feature-flags/posthog
paths:
  - "**/posthog*"
  - "**/ph-*"
  - "**/flags/**"
---

Full standards in [posthog.md](posthog.md). Always-on summary:

**SDK setup:**
- Server-side: use `posthog-node` — initialise once, call `shutdown()` on process exit to flush events
- Client-side: use `posthog-js` or the React provider — call `posthog.identify()` after login
- Always call `posthog.identify()` with your database user ID, not a temporary anonymous ID

**Feature flags (React):**
- Use `useFeatureFlagEnabled('flag-key')` hook in React components for boolean flags
- For A/B test variants: call `getFeatureFlagPayload('flag-key', distinctId)` to get the `payload` JSON object with variant-specific config
- Always provide a fallback — `useFeatureFlagEnabled(` returns `undefined` if flags are not loaded; treat it as `false`

**Feature flags (Node.js):**
- Use `client.isFeatureEnabled(flagKey, distinctId)` for boolean flags
- Use `client.getFeatureFlag(flagKey, distinctId)` for multivariate flags (returns the variant string)

**A/B testing:**
- Call `posthog.capture('experiment_started', { flag: key, variant })` when a user enters an experiment
- Always expose control and variant to equivalent user cohorts — never split by time
- Track the primary metric event the same way in both control and variant code paths

**Analytics integration:**
- PostHog automatically links feature flag evaluations to events — don't add manual flag properties to every event
- Group events by `$group_id` for B2B analytics (organisation-level metrics)

**Flag naming:**
- Same `kebab-case` convention: `new-onboarding-flow`, `checkout-variant-b`
- Keep a central constants file — never scatter raw string flag keys

**Never:**
- Use PostHog flags as the sole access-control mechanism — flags are for rollout, not auth
- Evaluate flags inside a loop or hot render path — evaluate once, store the result
- Forget to `posthog.shutdown()` in Node.js scripts — events may be lost if the process exits before flush

**Related skills:** `feature-flags/launchdarkly` (dedicated flag platform), `core/api-conventions`
