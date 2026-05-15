---
name: flagsmith
description: Flagsmith — SDK setup, remote evaluation, traits, segments, React provider
user-invocable: false
stack: feature-flags/flagsmith
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*flagsmith*"
  - "**/*feature-flag*"
---

Full standards in [flagsmith.md](flagsmith.md). Always-on summary:

**SDK Setup:**
- Use `flagsmith` npm package (browser) or `flagsmith-nodejs` (server)
- Initialize once with `environmentID` from env var — never hardcode
- Use `cacheFlags: true` to persist flags to localStorage between page loads

**Remote Evaluation (Server-Side):**
- Prefer server-side evaluation for sensitive flags (security, payment features)
- Use `flagsmith-nodejs` with `environmentKey` and call `getFlags()` per request
- Pass `identity` for per-user flag evaluation; do not share SDK instances across requests

**Traits and Segments:**
- Set `traits:` on an `identity` to drive segment-based targeting: pass `{ identity: userId, traits: { plan: 'pro' } }` when calling `getFlags()`
- Segments are defined in the Flagsmith dashboard — do not replicate segment logic in code
- Traits must not include PII beyond what Flagsmith's data retention policy covers

**React Provider:**
- Wrap app in `<FlagsmithProvider>` from `react-flagsmith` — provides context to all hooks
- Use `useFlags(['flag-name'])` to read flags — never access `flagsmith` client directly in components
- Use `useIsLoading()` to show a loading state before flags are resolved

**Flag Evaluation:**
- Check existence before reading: `if (flagsmith.hasFeature('my_flag')) { flagsmith.getValue('my_flag') }`
- Always provide a default value when calling `flagsmith.getValue(` or `isEnabled()` — never assume a flag exists
- Cache flag state at component mount — do not re-fetch on every render
- Treat `isEnabled(flag)` returning `false` as the safe/disabled path

**Never:**
- Hardcode flag names as raw strings in multiple places — export constants from a flags registry file
- Block rendering indefinitely while waiting for flags — use defaults and load progressively
- Store traits with passwords, payment card data, or government IDs

**Related skills:** `feature-flag`, `react-standards`, `security-principles`
