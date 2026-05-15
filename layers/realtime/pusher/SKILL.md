---
name: pusher
description: Pusher Channels standards — server publish, client subscribe, private/presence channels, and auth endpoint. Load when working with Pusher.
user-invocable: false
stack: realtime/pusher
paths:
  - "**/pusher/**"
  - "**/realtime/**"
  - "**/channels/**"
---

Full standards in [pusher.md](pusher.md). Always-on summary:

**Channel types:**
- Public channels: `channel-name` — no auth, visible to all
- Private channels: `private-<name>` — requires server auth endpoint
- Presence channels: `presence-<name>` — auth + member tracking; use for online indicators

**Auth endpoint:**
- Required for all `private-` and `presence-` channels
- Server calls `pusher.authorizeChannel(socketId, channel, presenceData?)` and returns the result
- Protect the auth endpoint with your own session/JWT check — Pusher does not authenticate users

**Server publish:**
- Use `pusher.trigger(channel, event, data)` to push events from server
- Batch with `pusher.triggerBatch([{ channel, name, data }])` for multiple events
- Keep payloads under 10 KB; for large data, publish an ID and have the client fetch

**Client subscribe:**
- Bind per-event: `channel.bind('order-updated', handler)` — do not bind to all events
- Call `pusher.disconnect()` and `channel.unbind_all()` on component unmount

**Presence channels:**
- `presenceChannel.members.each(member => ...)` to iterate current members
- Listen to `pusher:member_added` and `pusher:member_removed` for join/leave events

**Never:**
- Put `PUSHER_APP_SECRET` in browser-side code
- Skip auth-endpoint validation — any authenticated user can subscribe to private channels without it
- Publish sensitive data in public channels

**Related skills:** `realtime/ably` (Ably alternative), `backend/express` (auth endpoint setup), `error-handling`
