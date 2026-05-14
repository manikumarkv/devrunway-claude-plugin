---
name: socketio
description: Socket.io standards — namespaces, rooms, event naming, authentication middleware, reconnect logic, and server-side guards. Load when working with Socket.io.
user-invocable: false
stack: realtime/socketio
paths:
  - "**/socket*"
  - "**/socketio*"
  - "**/io.ts"
  - "**/io.js"
---

Full standards in [socketio.md](socketio.md). Always-on summary:

**Server setup:**
- Create the `io` instance once and export it — use a singleton module pattern
- Attach `io` to the HTTP server, not a standalone port — avoids CORS issues and port conflicts
- Always configure CORS explicitly — never use `origin: '*'` in production

**Authentication:**
- Validate the auth token in `io.use()` middleware (runs before `connection`) — reject unauthenticated sockets before they connect
- Never trust `socket.handshake.auth` data after connection without re-validating on sensitive events
- Attach user identity to `socket.data` in middleware so handlers don't need to re-fetch it

**Event naming:**
- Use `noun:verb` format: `order:created`, `chat:message`, `user:typing`
- Keep a shared `events.ts` file with typed event constants — never use raw strings in multiple files
- Server-to-client events and client-to-server events use the same naming convention

**Rooms:**
- Join rooms in `connection` handler after auth is verified
- Room name convention: `resource:id` — e.g., `order:abc123`, `chat:room-xyz`
- Leave rooms explicitly on disconnect or when the user's permission changes

**Error handling:**
- Emit typed error events back to the client — don't let exceptions propagate silently
- Use acknowledgement callbacks (3rd argument) for operations that need confirmation
- Always handle the `connect_error` event on the client side

**Never:**
- Broadcast from the client — only the server broadcasts to rooms
- Use `socket.broadcast.emit()` when you mean to emit to a specific room
- Accept user-controlled room names without validation — users could join arbitrary rooms

**Related skills:** `cache-queue/redis` (Redis adapter for multi-server scaling), `core/api-conventions`
