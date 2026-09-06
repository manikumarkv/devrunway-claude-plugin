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

> **Scope — applies only if this project uses launchdarkly.** This layer shares `**/flags/**` with `posthog` in `layers/feature-flags/`, so more than one may load at once and their rules conflict. If the project is not using launchdarkly, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**SDK setup:**
- Server-side SDK: initialise once per process; await `client.waitForInitialization()` before serving requests
- Client-side SDK: use the React SDK (`launchdarkly-react-client-sdk`) — it handles streaming updates and context
- Set `useCamelCaseFlagKeys: false` in the provider's `reactOptions`. The React SDK camelCases flag keys by default, so `useFlags()` would expose `'new-checkout-flow'` as `newCheckoutFlow` and a lookup by the kebab-case `FLAGS` constant silently reads `undefined`
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
- Build a real client on a `TestData(` source for unit tests: `new TestData()` from `@launchdarkly/node-server-sdk/integrations`, wired in with `updateProcessor: td.getFactory()`. It controls flag values in-process without calling the real LaunchDarkly API, and still exercises targeting, defaults and key handling
- Never replace the LaunchDarkly module with a test double — a module double only asserts your code called a function whose return value you wrote, and drifts from the SDK on every upgrade without failing
- Expose a `getFlag(key)` helper and a `setLDClient(` seam in your app so tests inject the TestData-backed client, not global state
- `TestData` is server-side only. Test a React component by rendering it inside the React SDK's own context (`defaultReactOptions.reactContext`) with the flag values the test needs

**Never:**
- Hardcode flag keys as raw strings in multiple places — export from a central `flags.ts` constants file
- Evaluate flags in deeply nested components — evaluate at the page/feature level and pass down
- Use a flag to hide code permanently — flags are for rollout, not as a permanent access control layer (use RBAC for that)

**Related skills:** `feature-flags/posthog` (combined analytics + flags alternative)
