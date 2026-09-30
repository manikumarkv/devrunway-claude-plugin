---
name: posthog-analytics
description: PostHog product analytics standards — single init, event naming, identify/reset, consent, no PII in events, server-side capture. Load when working with PostHog analytics.
user-invocable: false
stack: analytics/posthog
paths:
  - "**/posthog*"
  - "**/analytics/**"
  - "**/*analytics*.{ts,tsx,js,jsx}"
---

Full standards in [posthog-analytics.md](posthog-analytics.md). Feature flags are in `layers/feature-flags/posthog`. Always-on summary:

- **Init once** in one provider or module. Guard against double init (React StrictMode, HMR).
- **Name events `object_verb`** in snake_case (`signup_completed`, `term_viewed`). Keep them in one typed catalog; never scatter raw strings.
- **Identify** with your database user ID after login; call `posthog.reset()` on logout.
- **No PII** (email, name, phone, address) in event properties. Put allowed traits on the person, not the event.
- **Consent first.** Where consent is required, start opted out and call `opt_in_capturing()` after the user agrees.
- **Server-side** (`posthog-node`): flush with `await posthog.shutdown()` before a serverless function or script exits.
- The project key (`phc_…`) may be public. A personal API key (`phx_…`) never is.
