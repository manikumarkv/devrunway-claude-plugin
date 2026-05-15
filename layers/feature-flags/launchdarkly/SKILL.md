---
name: launchdarkly
description: LaunchDarkly standards — flag naming, SDK setup, targeting rules, React integration, and testing with flag overrides. Load when working with LaunchDarkly.
user-invocable: false
stack: feature-flags/launchdarkly
paths:
  - "**/launchdarkly*"
  - "**/launch-darkly*"
  - "**/ldclient*"
  - "**/flags/**"
---

Full standards in [launchdarkly.md](launchdarkly.md). Always-on summary:

**SDK setup:**
- Server-side SDK: initialise once per process; await `client.waitForInitialization()` before serving requests
- Client-side SDK: use the React SDK (`launchdarkly-react-client-sdk`) — it handles streaming updates and context
- Never use the server SDK in the browser — it exposes your SDK key and all flag configurations

**Flag naming:**
- Use `UPPER_SNAKE_CASE` constants in a central `flags.ts` file, e.g., `PAYMENTS_USE_STRIPE_V3 = 'payments-use-stripe-v3'` — never scatter raw string keys
- Prefix with the team or feature area for discoverability
- Boolean flags for on/off; string/number flags for configuration values; JSON flags for complex config

**Context (user targeting):**
- Always pass a context object with at least `key:` (stable user or device ID) and `kind:` (e.g., `'user'`) — missing `kind:` disables multi-context targeting rules
- Include attributes you'll target on: `email`, `plan`, `country`, `role`
- Never log or store the full context object — it may contain PII

**Flag lifecycle:**
- Archive flags after the rollout is complete — don't leave permanent flags cluttering the dashboard
- Track flag dependencies: if flag B depends on flag A, document it
- Add a description and tags to every flag — "who owns this?", "what does it control?"

**Testing:**
- Use `TestData(` as the data source for unit tests — it controls flag values without calling the real LaunchDarkly API
- Expose a `getFlag(key)` helper in your app so tests can override via DI, not global state

**Never:**
- Hardcode flag keys as raw strings in multiple places — export from a central `flags.ts` constants file
- Evaluate flags in deeply nested components — evaluate at the page/feature level and pass down
- Use a flag to hide code permanently — flags are for rollout, not as a permanent access control layer (use RBAC for that)

**Related skills:** `feature-flags/posthog` (combined analytics + flags alternative)
