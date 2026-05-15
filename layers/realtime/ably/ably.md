# Ably Standards

---

## Setup

```bash
npm install ably                 # shared (server + client)
npm install @ably/react          # React hooks (client only)
```

---

## Server — token request endpoint

```typescript
// src/lib/ably.ts  (server-side only)
import Ably from 'ably'

if (!process.env.ABLY_API_KEY) throw new Error('ABLY_API_KEY is required')

// REST client for server-side publishing and token generation
export const ablyServer = new Ably.Rest(process.env.ABLY_API_KEY)
```

```typescript
// src/routes/ably.ts
import { Router } from 'express'
import { ablyServer } from '@/lib/ably'

const router = Router()

// Browser clients request a token here — never expose the API key to the browser
router.post('/ably-token', async (req, res) => {
  const userId = req.user?.id
  if (!userId) return res.status(401).json({ error: 'Unauthorized' })

  try {
    const tokenRequest = await ablyServer.auth.createTokenRequest({
      clientId:   userId,
      capability: {
        // Scope channels to this user — principle of least privilege
        [`order:${userId}:*`]: ['subscribe'],
        [`chat:*`]:            ['publish', 'subscribe', 'presence'],
      },
      ttl: 60 * 60 * 1000,   // 1 hour in milliseconds
    })

    res.json(tokenRequest)
  } catch (err) {
    res.status(500).json({ error: 'Token generation failed' })
  }
})
```

---

## Server — publish to a channel

```typescript
async function publishOrderUpdate(userId: string, orderId: string, payload: object) {
  const channel = ablyServer.channels.get(`order:${userId}:${orderId}`)

  await channel.publish('order-updated', {
    orderId,
    ...payload,
    timestamp: new Date().toISOString(),
  })
}
```

---

## React setup

```tsx
// src/providers/AblyProvider.tsx
'use client'

import Ably from 'ably'
import { AblyProvider, ChannelProvider } from '@ably/react'
import { useMemo } from 'react'

export function RealtimeProvider({ children }: { children: React.ReactNode }) {
  const client = useMemo(() => new Ably.Realtime({
    authUrl:    '/api/ably-token',
    authMethod: 'POST',
  }), [])

  return (
    <AblyProvider client={client}>
      {children}
    </AblyProvider>
  )
}

// Wrap a subtree in a specific channel
export function OrderChannelProvider({
  orderId,
  children,
}: {
  orderId: string
  children: React.ReactNode
}) {
  const channelName = `order:${userId}:${orderId}`    // userId from auth context

  return (
    <ChannelProvider channelName={channelName}>
      {children}
    </ChannelProvider>
  )
}
```

---

## React hooks — subscriptions

```tsx
// src/components/OrderStatus.tsx
import { useChannel } from '@ably/react'

export function OrderStatus({ orderId }: { orderId: string }) {
  const [status, setStatus] = useState('pending')

  // useChannel handles subscribe and unsubscribe automatically on mount/unmount
  const { channel } = useChannel(`order:${userId}:${orderId}`, 'order-updated', (message) => {
    setStatus(message.data.status)
  })

  return <span>Status: {status}</span>
}
```

---

## Presence

```tsx
// src/components/OnlineUsers.tsx
import { usePresence, useChannel } from '@ably/react'

export function OnlineUsers({ roomId }: { roomId: string }) {
  const channelName = `chat:${roomId}`

  // Enter presence with user data; returns current members
  const { presenceData, updateStatus } = usePresence(channelName, {
    userId:      currentUser.id,
    displayName: currentUser.name,
    status:      'online',
  })

  return (
    <ul>
      {presenceData.map((member) => (
        <li key={member.clientId}>{member.data.displayName}</li>
      ))}
    </ul>
  )
}
```

---

## Low-level channel management (non-React)

```typescript
// For vanilla TS or Node clients that need fine-grained control
const client  = new Ably.Realtime({ authUrl: '/api/ably-token', authMethod: 'POST' })
const channel = client.channels.get('order:user-123:order-456')

// Subscribe to a specific event
const handler = (message: Ably.Message) => {
  console.log('order-updated', message.data)
}
channel.subscribe('order-updated', handler)

// Always clean up on page unload or component unmount
function cleanup() {
  channel.unsubscribe('order-updated', handler)
  channel.detach()
  client.close()
}

window.addEventListener('beforeunload', cleanup)
```

---

## Channel naming conventions

| Pattern | Use case |
|---|---|
| `order:<userId>:<orderId>` | Per-order status updates scoped to the owner |
| `chat:<roomId>` | Group chat room |
| `admin:dashboard` | Server → admin broadcast |
| `notifications:<userId>` | Per-user push notifications |

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Embedding the Ably API key in browser code | Use `authUrl` pointing to your token endpoint — API key stays server-side |
| Not unsubscribing on component unmount | Ghost listeners accumulate and cause memory leaks — use `@ably/react` hooks or call `unsubscribe` manually |
| Publishing payloads > 64 KB | Store large data in object storage; publish a reference ID only |
| Subscribing to all events on a busy channel | Use named events (`channel.subscribe('event-name', handler)`) to filter at the SDK level |
| Creating a new `Ably.Realtime` client per component | Create once (e.g., in a context/provider) and share across the tree |
