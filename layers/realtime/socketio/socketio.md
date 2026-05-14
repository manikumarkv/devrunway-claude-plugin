# Socket.io Standards

---

## Setup

```bash
npm install socket.io              # server
npm install socket.io-client       # client
```

---

## Server setup — singleton

```typescript
// src/lib/socket.ts
import { Server } from 'socket.io'
import type { Server as HttpServer } from 'http'

let io: Server

export function initSocketServer(httpServer: HttpServer): Server {
  if (io) return io   // singleton guard

  io = new Server(httpServer, {
    cors: {
      origin:      process.env.CLIENT_ORIGIN ?? 'http://localhost:3000',
      credentials: true,
    },
    transports:            ['websocket', 'polling'],
    pingTimeout:           20_000,
    pingInterval:          25_000,
    maxHttpBufferSize:     1e6,   // 1 MB max message size
  })

  return io
}

export function getSocketServer(): Server {
  if (!io) throw new Error('Socket.io server not initialised — call initSocketServer() first')
  return io
}
```

```typescript
// src/server.ts — attach to HTTP server
import { createServer } from 'http'
import { app } from './app'
import { initSocketServer } from './lib/socket'
import { registerOrderHandlers } from './features/orders/orders.socket'

const httpServer = createServer(app)
const io = initSocketServer(httpServer)

// Register namespace handlers
registerOrderHandlers(io)

httpServer.listen(3001)
```

---

## Shared event types

```typescript
// src/types/socket-events.ts — shared between server and client
export const EVENTS = {
  ORDER_CREATED:   'order:created',
  ORDER_UPDATED:   'order:updated',
  ORDER_CANCELLED: 'order:cancelled',
  CHAT_MESSAGE:    'chat:message',
  CHAT_TYPING:     'chat:typing',
  ERROR:           'error',
} as const

export type EventKey = typeof EVENTS[keyof typeof EVENTS]

// Payload types per event
export interface ServerToClientEvents {
  [EVENTS.ORDER_CREATED]:   (order: Order) => void
  [EVENTS.ORDER_UPDATED]:   (order: Partial<Order> & { id: string }) => void
  [EVENTS.ORDER_CANCELLED]: (orderId: string) => void
  [EVENTS.CHAT_MESSAGE]:    (message: ChatMessage) => void
  [EVENTS.CHAT_TYPING]:     (userId: string) => void
  [EVENTS.ERROR]:           (error: { code: string; message: string }) => void
}

export interface ClientToServerEvents {
  [EVENTS.CHAT_MESSAGE]: (
    payload: { roomId: string; text: string },
    ack: (result: { ok: boolean; messageId?: string; error?: string }) => void
  ) => void
  [EVENTS.CHAT_TYPING]:  (roomId: string) => void
}

export interface SocketData {
  userId:   string
  userRole: 'admin' | 'customer'
}
```

---

## Authentication middleware

```typescript
// src/middleware/socket-auth.ts
import { Socket } from 'socket.io'
import { verifyToken } from '../lib/auth'
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from '../types/socket-events'

type AppSocket = Socket<ClientToServerEvents, ServerToClientEvents, never, SocketData>

export async function socketAuthMiddleware(
  socket: AppSocket,
  next: (err?: Error) => void
) {
  try {
    const token = socket.handshake.auth.token as string | undefined
    if (!token) throw new Error('No auth token provided')

    const payload = await verifyToken(token)

    // Attach user to socket.data — available in all event handlers
    socket.data.userId   = payload.sub
    socket.data.userRole = payload.role

    next()
  } catch (err) {
    next(new Error('Authentication failed'))
  }
}
```

---

## Namespace and room handlers

```typescript
// src/features/orders/orders.socket.ts
import { Server, Socket } from 'socket.io'
import { socketAuthMiddleware } from '../../middleware/socket-auth'
import { EVENTS } from '../../types/socket-events'
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from '../../types/socket-events'

type AppServer = Server<ClientToServerEvents, ServerToClientEvents, never, SocketData>
type AppSocket = Socket<ClientToServerEvents, ServerToClientEvents, never, SocketData>

export function registerOrderHandlers(io: AppServer) {
  // Namespace: /orders
  const ordersNS = io.of('/orders')
  ordersNS.use(socketAuthMiddleware)

  ordersNS.on('connection', (socket: AppSocket) => {
    const { userId, userRole } = socket.data

    console.log(`User ${userId} connected to /orders (${socket.id})`)

    // Join user-specific room on connect
    socket.join(`user:${userId}`)

    // Admins can subscribe to all orders
    if (userRole === 'admin') {
      socket.join('admin:orders')
    }

    // Client joins a specific order room
    socket.on('order:subscribe', (orderId: string) => {
      // Validate: user must own this order or be admin
      if (userRole === 'admin' || canUserAccessOrder(userId, orderId)) {
        socket.join(`order:${orderId}`)
        socket.emit('order:subscribed' as any, orderId)
      } else {
        socket.emit(EVENTS.ERROR, { code: 'FORBIDDEN', message: 'Access denied' })
      }
    })

    socket.on('disconnect', (reason) => {
      console.log(`User ${userId} disconnected: ${reason}`)
    })
  })
}

// Emit from outside the connection handler (e.g., after DB write)
export function notifyOrderUpdated(io: AppServer, order: Order) {
  io.of('/orders').to(`order:${order.id}`).emit(EVENTS.ORDER_UPDATED, order)
  io.of('/orders').to('admin:orders').emit(EVENTS.ORDER_UPDATED, order)
}
```

---

## Acknowledgements (reliable delivery)

```typescript
// Client-to-server with acknowledgement
socket.on(EVENTS.CHAT_MESSAGE, async (payload, ack) => {
  try {
    // Validate
    if (!payload.roomId || !payload.text?.trim()) {
      return ack({ ok: false, error: 'Invalid message' })
    }

    // Process
    const message = await saveChatMessage({
      roomId: payload.roomId,
      userId: socket.data.userId,
      text:   payload.text.trim(),
    })

    // Broadcast to room
    socket.to(`chat:${payload.roomId}`).emit(EVENTS.CHAT_MESSAGE, message)

    // Confirm to sender
    ack({ ok: true, messageId: message.id })
  } catch (err) {
    ack({ ok: false, error: 'Failed to send message' })
  }
})
```

---

## Client-side (React hook)

```typescript
// src/hooks/useOrderSocket.ts
import { useEffect, useRef, useCallback } from 'react'
import { io, Socket } from 'socket.io-client'
import { EVENTS } from '../types/socket-events'
import type { ServerToClientEvents, ClientToServerEvents } from '../types/socket-events'

type AppSocket = Socket<ServerToClientEvents, ClientToServerEvents>

export function useOrderSocket(orderId: string, onUpdate: (order: Order) => void) {
  const socketRef = useRef<AppSocket | null>(null)

  useEffect(() => {
    const socket: AppSocket = io('/orders', {
      auth:       { token: getAccessToken() },
      transports: ['websocket'],
      reconnection:          true,
      reconnectionAttempts:  5,
      reconnectionDelay:     1000,
      reconnectionDelayMax:  10_000,
    })

    socket.on('connect', () => {
      // Join the specific order room
      socket.emit('order:subscribe' as any, orderId)
    })

    socket.on(EVENTS.ORDER_UPDATED, onUpdate)

    socket.on('connect_error', (err) => {
      console.error('Socket connection error:', err.message)
    })

    socket.on('disconnect', (reason) => {
      if (reason === 'io server disconnect') {
        // Server disconnected us — reconnect manually
        socket.connect()
      }
      // Otherwise, socket.io auto-reconnects
    })

    socketRef.current = socket

    return () => {
      socket.disconnect()
    }
  }, [orderId])

  return socketRef
}
```

---

## Scaling with Redis adapter

```bash
npm install @socket.io/redis-adapter ioredis
```

```typescript
// src/lib/socket.ts
import { createAdapter } from '@socket.io/redis-adapter'
import { Redis } from 'ioredis'

const pubClient = new Redis(process.env.REDIS_URL!)
const subClient = pubClient.duplicate()

io.adapter(createAdapter(pubClient, subClient))

// Now events emitted on any server instance propagate to all connected clients
// across all server instances
```

---

## Emitting from outside socket context

```typescript
// From an API route or background job — emit after a DB change
import { getSocketServer } from '../lib/socket'
import { notifyOrderUpdated } from '../features/orders/orders.socket'

async function handleOrderStatusChange(order: Order) {
  await db.orders.update({ id: order.id, status: order.status })

  const io = getSocketServer()
  notifyOrderUpdated(io, order)   // broadcasts to all subscribers
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| No auth middleware on the namespace | Add `namespace.use(socketAuthMiddleware)` — runs before `connection` |
| Using `socket.broadcast.emit()` for rooms | Use `socket.to('room-name').emit()` for room-specific broadcasts |
| Accepting user-controlled room names | Validate and authorise before `socket.join(roomId)` |
| Not using acknowledgements for mutations | Add ack callbacks — clients need confirmation of success/failure |
| No `reconnectionAttempts` limit on client | Infinite reconnect can mask a down server — set a sensible limit |
| `io.emit()` for user-specific events | Use `io.to('user:userId').emit()` — `io.emit()` hits every connected socket |
| Creating a new `io` per request/import | Singleton pattern — one `Server` instance for the application lifetime |
| No Redis adapter in multi-server deploy | Without it, sockets on different servers can't communicate |
