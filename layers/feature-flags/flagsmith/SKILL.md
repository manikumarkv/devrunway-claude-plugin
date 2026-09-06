---
name: flagsmith
description: Flagsmith — SDK setup, remote evaluation, traits, segments, React provider
user-invocable: false
stack: feature-flags/flagsmith
paths:
  - "**/*flagsmith*"
  - "**/*feature-flag*"
  - "**/flags/**"
---

Full standards in [flagsmith.md](flagsmith.md). Always-on summary:

> **Scope — applies only if this project uses flagsmith.** This layer shares `**/*feature-flag*` with `aws-appconfig` in `layers/feature-flags/`, so more than one may load at once and their rules conflict. If the project is not using flagsmith, ignore this layer.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**SDK Setup — two SDKs, two keys, and they do not cross:**
- Browser: the `flagsmith` npm package, initialised once with `environmentID` from an env var — never hardcode. `environmentID` takes the **public client-side key** and is a browser-only option
- Server: the `flagsmith-nodejs` package, constructed with `environmentKey: process.env.FLAGSMITH_SERVER_KEY`
- **A server component or API route never imports the browser client and never references `environmentID`.** Doing so means shipping the public key into server code and evaluating a sensitive flag with the key the user already has — the flag's value, and the rollout, become visible to them
- Use `cacheFlags: true` to persist flags to localStorage between page loads (browser only)

**Remote Evaluation (Server-Side):**
- Prefer server-side evaluation for sensitive flags (security, payment features)
- Evaluate with `flagsmithServer.getIdentityFlags(userId, traits)` for a known user, or `getEnvironmentFlags()` when there is none; read from the returned object with `isFeatureEnabled(` and `getFeatureValue(`
- Do not share an evaluation result across requests; construct the client once, evaluate per request

**Traits and Segments:**
- Set `traits:` on an `identity` to drive segment-based targeting: pass `{ identity: userId, traits: { plan: 'pro' } }` when calling `getFlags()`
- Segments are defined in the Flagsmith dashboard — do not replicate segment logic in code
- Traits must not include PII beyond what Flagsmith's data retention policy covers

**React Provider:**
- Wrap app in `<FlagsmithProvider>` from `react-flagsmith` — provides context to all hooks
- Use `useFlags(['flag-name'])` to read flags — never access `flagsmith` client directly in components
- Use `useIsLoading()` to show a loading state before flags are resolved

**Flag Evaluation (browser SDK):**
- Check existence before reading: `if (flagsmith.hasFeature('my_flag')) { flagsmith.getValue('my_flag') }`
- `flagsmith.hasFeature(` and `flagsmith.getValue(` are browser methods. The server SDK has neither — it returns a flags object per evaluation and you read from that
- Always provide a default value when calling `flagsmith.getValue(` or `isEnabled()` — never assume a flag exists
- Cache flag state at component mount — do not re-fetch on every render
- Treat `isEnabled(flag)` returning `false` as the safe/disabled path

**Never:**
- Hardcode flag names as raw strings in multiple places — export constants from a flags registry file
- Block rendering indefinitely while waiting for flags — use defaults and load progressively
- Store traits with an email address, a name, a phone number, a password, payment card data, or government IDs — traits are stored and displayed in Flagsmith; send an opaque id and a tier
- Use the browser SDK, the browser key, or `environmentID` anywhere on the server

**Related skills:** `feature-flag`, `react-standards`, `security-principles` (never send a secret to the client, including in a bundled frontend build; deny by default when the flag service is unavailable)
