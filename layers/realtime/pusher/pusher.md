# Pusher Channels Standards

---

## Setup

```bash
npm install pusher          # server
npm install pusher-js       # client
```

---

## Server setup

```typescript
// src/lib/pusher.ts
import Pusher from 'pusher'

if (!process.env.PUSHER_APP_ID)     throw new Error('PUSHER_APP_ID is required')
if (!process.env.PUSHER_APP_KEY)    throw new Error('PUSHER_APP_KEY is required')
if (!process.env.PUSHER_APP_SECRET) throw new Error('PUSHER_APP_SECRET is required')
if (!process.env.PUSHER_CLUSTER)    throw new Error('PUSHER_CLUSTER is required')

export const pusherServer = new Pusher({
  appId:   process.env.PUSHER_APP_ID,
  key:     process.env.PUSHER_APP_KEY,
  secret:  process.env.PUSHER_APP_SECRET,
  cluster: process.env.PUSHER_CLUSTER,
  useTLS:  true,
})
```

---

## Server — publish events

```typescript
// src/services/notifications.ts
import { pusherServer } from '@/lib/pusher'

// Single channel publish
export async function notifyOrderUpdate(userId: string, orderId: string, payload: object) {
  await pusherServer.trigger(
    `private-user.${userId}`,       // private channel scoped to user
    'order-updated',
    { orderId, ...payload }
  )
}

// Batch publish — multiple events in one HTTP call (max 10)
export async function broadcastBatch(events: Array<{ channel: string; name: string; data: object }>) {
  await pusherServer.triggerBatch(
    events.map(e => ({ channel: e.channel, name: e.name, data: e.data }))
  )
}
```

---

## Auth endpoint (private + presence channels)

```typescript
// src/routes/pusher.ts
import { Router } from 'express'
import { pusherServer } from '@/lib/pusher'

const router = Router()

// Pusher calls this endpoint when a client subscribes to a private- or presence- channel
router.post('/pusher/auth', (req, res) => {
  const { socket_id, channel_name } = req.body

  // Authenticate the user with YOUR session/JWT before authorising
  if (!req.user) {
    return res.status(403).json({ error: 'Unauthorized' })
  }

  // Presence channels include user data visible to other members
  if (channel_name.startsWith('presence-')) {
    const presenceData = {
      user_id:   req.user.id,
      user_info: { displayName: req.user.name, avatarUrl: req.user.avatar },
    }
    const auth = pusherServer.authorizeChannel(socket_id, channel_name, presenceData)
    return res.json(auth)
  }

  // Private channels — no member data needed
  const auth = pusherServer.authorizeChannel(socket_id, channel_name)
  res.json(auth)
})
```

---

## Client setup

```typescript
// src/lib/pusherClient.ts  (browser only)
import PusherJS from 'pusher-js'

// Only PUSHER_APP_KEY and PUSHER_CLUSTER are safe for the browser
export const pusherClient = new PusherJS(process.env.NEXT_PUBLIC_PUSHER_APP_KEY!, {
  cluster:       process.env.NEXT_PUBLIC_PUSHER_CLUSTER!,
  authEndpoint:  '/api/pusher/auth',    // your auth route
  authTransport: 'ajax',
  auth: {
    headers: {
      // Forward your session cookie or bearer token
      Authorization: `Bearer ${getAccessToken()}`,
    },
  },
})
```

---

## Client — subscribe to channels

```typescript
// Public channel
const publicChannel = pusherClient.subscribe('announcements')
publicChannel.bind('new-post', (data: { title: string }) => {
  console.log('New post:', data.title)
})

// Private channel
const privateChannel = pusherClient.subscribe(`private-user.${currentUserId}`)
privateChannel.bind('order-updated', (data: OrderUpdatePayload) => {
  updateOrderInUI(data)
})

// Presence channel
const presenceChannel = pusherClient.subscribe(`presence-room.${roomId}`)

presenceChannel.bind('pusher:subscription_succeeded', (members: any) => {
  members.each((member: any) => console.log('online:', member.info.displayName))
})

presenceChannel.bind('pusher:member_added', (member: any) => {
  addMemberToUI(member)
})

presenceChannel.bind('pusher:member_removed', (member: any) => {
  removeMemberFromUI(member.id)
})
```

---

## React integration

```tsx
// src/hooks/usePusherChannel.ts
import { useEffect, useRef } from 'react'
import { pusherClient } from '@/lib/pusherClient'
import type { Channel } from 'pusher-js'

export function usePusherChannel<T>(
  channelName: string,
  eventName: string,
  handler: (data: T) => void
) {
  const handlerRef = useRef(handler)
  handlerRef.current = handler

  useEffect(() => {
    const channel: Channel = pusherClient.subscribe(channelName)

    const boundHandler = (data: T) => handlerRef.current(data)
    channel.bind(eventName, boundHandler)

    return () => {
      channel.unbind(eventName, boundHandler)
      pusherClient.unsubscribe(channelName)
    }
  }, [channelName, eventName])
}

// Usage in a component
export function OrderTracker({ orderId }: { orderId: string }) {
  const [status, setStatus] = useState('pending')

  usePusherChannel<{ status: string }>(
    `private-user.${currentUserId}`,
    'order-updated',
    (data) => setStatus(data.status)
  )

  return <p>Order status: {status}</p>
}
```

---

## Channel naming conventions

| Pattern | Type | Use case |
|---|---|---|
| `announcements` | public | Broadcasts to all users |
| `private-user.<userId>` | private | Per-user events |
| `private-order.<orderId>` | private | Order-specific updates |
| `presence-room.<roomId>` | presence | Chat room with member list |

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Putting `PUSHER_APP_SECRET` in client code | Secret stays server-side; only `APP_KEY` and `CLUSTER` go to the browser |
| No auth endpoint for private channels | Without auth, Pusher rejects all `private-` channel subscriptions |
| Binding to all events (`channel.bind_global`) | Bind to specific event names — blanket subscriptions process every internal Pusher event |
| Not unbinding handlers on unmount | Leaked handlers receive events after the component is gone, causing state updates on unmounted components |
| Payload > 10 KB | Pusher rejects events over 10 KB — store large data elsewhere and send a reference |
