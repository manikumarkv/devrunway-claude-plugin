---
name: ably
description: Ably standards — pub/sub channels, presence, token-request auth, and React hooks. Load when working with Ably.
user-invocable: false
stack: realtime/ably
paths:
  - "**/ably/**"
  - "**/realtime/**"
  - "**/channels/**"
---

Full standards in [ably.md](ably.md). Always-on summary:

**Authentication:**
- Always use token-request auth for browser clients — never embed the API key in frontend code
- Server endpoint returns a signed `TokenRequest`; client calls `ably.auth.requestToken()`
- Set `authUrl` on the client-side `Ably.Realtime` constructor to your token endpoint
- Scope capabilities per channel and per user in the token request

**Channels:**
- Use structured channel names: `<resource>:<id>` e.g. `order:abc123`, `chat:room42`
- Subscribe: `channel.subscribe('event-name', handler)` — use explicit event names, not all-events catch-alls
- On cleanup: `channel.unsubscribe(` to remove handlers and prevent ghost listener leaks

**Presence:**
- Enter presence with `channel.presence.enter({ userId, displayName })`
- Retrieve current members with `channel.presence.get(` — returns an array of present members
- Listen with `channel.presence.subscribe('enter' | 'leave' | 'update', handler)`
- Always call `channel.presence.leave()` on disconnect or unmount

**React hooks (ably/react):**
- Use `<AblyProvider>` and `<ChannelProvider>` at the app root
- `useChannel(channelName, eventName, handler)` for subscriptions — handles cleanup automatically
- `usePresence(channelName)` returns `presenceData` and `updateStatus`

**Never:**
- Put the Ably API key in browser-side code
- Forget to unsubscribe — it causes ghost listeners and memory leaks
- Publish large payloads (>64 KB) — chunk or store in object storage and publish a reference

**Related skills:** `realtime/pusher` (Pusher alternative), `frontend/react` (React integration), `auth/cognito`
