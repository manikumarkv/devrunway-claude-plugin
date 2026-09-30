# PostHog analytics standards

Short rules for product analytics with PostHog (`posthog-js`, `posthog-node`). For feature flags and experiments see `layers/feature-flags/posthog`.

## 1. Setup

- Initialise once, in one module or provider:

```ts
// src/lib/analytics.ts
import posthog from 'posthog-js';

let started = false;
export function initAnalytics() {
  if (started || typeof window === 'undefined') return;
  posthog.init(import.meta.env.PUBLIC_POSTHOG_KEY, {
    api_host: '/ingest',               // reverse proxy, see section 6
    person_profiles: 'identified_only',
    capture_pageview: 'history_change', // SPA route changes
    opt_out_capturing_by_default: true, // where consent is required
  });
  started = true;
}
```

- Keys: the project key (`phc_…`) is public and fine in `PUBLIC_` / `NEXT_PUBLIC_` vars. A personal API key (`phx_…`) is a secret; server-only.

## 2. Event catalog

- Name events `object_verb`, lowercase snake_case, past tense: `term_viewed`, `quiz_completed`, `signup_completed`.
- Keep every event and its properties in one typed file, and capture through it:

```ts
type Events = {
  term_viewed: { term_id: string; source: 'search' | 'browse' | 'related' };
  quiz_completed: { quiz_id: string; score: number; total: number };
};

export function track<E extends keyof Events>(event: E, props: Events[E]) {
  posthog.capture(event, props);
}
```

- Property names are snake_case too. Use IDs, not display text.
- Autocapture is fine for exploration. Capture the events you report on explicitly.

## 3. Identity

- After login: `posthog.identify(user.id, { plan: user.plan })`, using the database user ID.
- On logout: `posthog.reset()`, so the next user on the device is not merged in.
- For B2B, add `posthog.group('company', orgId)`.

## 4. Privacy

- No PII in event properties: no email, name, phone, address, or free text a user typed.
- Put allowed person traits on `identify`, and only what your privacy policy covers.
- Mask inputs in session replay (`maskAllInputs` is the default; keep it).
- Where consent law applies, start opted out (`opt_out_capturing_by_default: true`) and call `posthog.opt_in_capturing()` after consent. Respect `opt_out_capturing()` on withdrawal.

## 5. Server-side capture

- Use `posthog-node` for events that happen on the server (payments, webhooks).
- In serverless functions and scripts, set `flushAt: 1, flushInterval: 0` and `await posthog.shutdown()` before returning, or events are lost.
- Use the same `distinctId` (the user ID) as the client.

## 6. Reliability

- Serve PostHog through a reverse proxy on your own domain (`/ingest`) so ad blockers don't drop events.
- Never let an analytics call throw into user code; capture is fire-and-forget.

## Never

- PII in event properties.
- Raw event-name strings scattered around the code.
- Initialising in more than one place.
- A personal API key in client code.
- Tracking before consent where consent is required.
