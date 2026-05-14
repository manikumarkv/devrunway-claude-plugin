# Redis Standards

---

## Connection — singleton client

```typescript
// src/lib/redis.ts
import Redis from 'ioredis'

const redis = new Redis({
  host: process.env.REDIS_HOST ?? 'localhost',
  port: Number(process.env.REDIS_PORT ?? 6379),
  password: process.env.REDIS_PASSWORD,
  db: Number(process.env.REDIS_DB ?? 0),
  maxRetriesPerRequest: 3,
  retryStrategy(times) {
    if (times > 10) return null   // stop retrying after 10 attempts
    return Math.min(times * 200, 2000)  // exponential backoff, max 2s
  },
  lazyConnect: false,
})

// Handle errors — required; unhandled error events crash the process
redis.on('error', (err) => {
  console.error('Redis error', err)
})

redis.on('connect', () => {
  console.log('Redis connected')
})

export default redis
```

For connection strings (Upstash, Redis Cloud):
```typescript
const redis = new Redis(process.env.REDIS_URL!, {
  tls: process.env.REDIS_URL!.startsWith('rediss://') ? {} : undefined,
})
```

---

## Key naming convention

```
Pattern: <resource>:<id>[:<field>]

Examples:
  user:123:profile         — cached user profile
  user:123:permissions     — cached permission list
  session:abc123           — user session data
  rate-limit:ip:1.2.3.4   — rate limit counter
  order:456:status         — order status cache
  cache:products:page:1    — paginated list cache
  lock:order:456           — distributed lock
```

**Rules:**
- Lowercase only
- Colons `:` as separators — readable in Redis CLI and monitoring
- IDs go in the middle — enables prefix scanning: `SCAN 0 MATCH user:123:*`
- No spaces, special chars, or dynamic lengths that could vary unexpectedly

---

## TTL — always set one

```typescript
// ✅ Set with TTL (EX = seconds, PX = milliseconds)
await redis.set('user:123:profile', JSON.stringify(user), 'EX', 3600)  // 1 hour

// ✅ Set with absolute expiry
await redis.expireat('user:123:session', Math.floor(Date.now() / 1000) + 86400)

// ✅ Set if not exists (SETNX) with TTL
await redis.set('lock:order:456', '1', 'EX', 30, 'NX')

// ❌ No TTL — key lives forever; fill memory; evicted unpredictably
await redis.set('user:123:profile', JSON.stringify(user))
```

TTL guidelines:
| Data | TTL |
|---|---|
| User sessions | 1–24 hours |
| Cached DB queries | 30–300 seconds |
| Rate limit counters | 60 seconds (sliding window) |
| Distributed locks | 5–30 seconds |
| Feature flags | 60 seconds |
| One-time tokens (email verify) | 15–60 minutes |

---

## Cache-aside pattern

```typescript
// src/repositories/user.repository.ts
import redis from '../lib/redis'
import { db } from '../lib/db'

const TTL = 300  // 5 minutes

export async function getUserById(id: string) {
  const cacheKey = `user:${id}:profile`

  // 1. Check cache
  const cached = await redis.get(cacheKey)
  if (cached) {
    return JSON.parse(cached)
  }

  // 2. Cache miss — fetch from DB
  const user = await db.query('SELECT * FROM users WHERE id = $1', [id])
  if (!user) return null

  // 3. Write to cache with TTL
  await redis.set(cacheKey, JSON.stringify(user), 'EX', TTL)
  return user
}

// Invalidate on update
export async function updateUser(id: string, data: Partial<User>) {
  await db.query('UPDATE users SET ... WHERE id = $1', [id])
  await redis.del(`user:${id}:profile`)   // invalidate cache immediately
}
```

---

## Rate limiting

```typescript
// Sliding window rate limiter using INCR + EXPIRE
export async function checkRateLimit(ip: string, limit = 100, windowSeconds = 60) {
  const key = `rate-limit:${ip}:${Math.floor(Date.now() / (windowSeconds * 1000))}`

  const current = await redis.incr(key)

  // Set TTL on first request
  if (current === 1) {
    await redis.expire(key, windowSeconds)
  }

  if (current > limit) {
    throw new RateLimitError(`Rate limit exceeded: ${limit} requests per ${windowSeconds}s`)
  }

  return { current, limit, remaining: limit - current }
}
```

---

## Distributed locks

```typescript
// Prevent concurrent processing of the same resource
export async function acquireLock(resource: string, ttlSeconds = 30): Promise<boolean> {
  const key = `lock:${resource}`
  const result = await redis.set(key, '1', 'EX', ttlSeconds, 'NX')
  return result === 'OK'
}

export async function releaseLock(resource: string): Promise<void> {
  await redis.del(`lock:${resource}`)
}

// Usage
async function processOrder(orderId: string) {
  const acquired = await acquireLock(`order:${orderId}`)
  if (!acquired) {
    throw new Error('Order is already being processed')
  }
  try {
    await doProcessing(orderId)
  } finally {
    await releaseLock(`order:${orderId}`)
  }
}
```

---

## Data structures

```typescript
// String — simple key-value cache
await redis.set('key', 'value', 'EX', 3600)
const value = await redis.get('key')

// Hash — structured object (avoids JSON serialisation)
await redis.hset('user:123', { name: 'Alice', email: 'alice@example.com' })
await redis.expire('user:123', 3600)
const user = await redis.hgetall('user:123')

// List — ordered queue or recent items
await redis.lpush('notifications:123', JSON.stringify(notification))
await redis.ltrim('notifications:123', 0, 99)  // keep only last 100
const recent = await redis.lrange('notifications:123', 0, 9)

// Set — unique collection
await redis.sadd('online-users', userId)
await redis.srem('online-users', userId)
const isOnline = await redis.sismember('online-users', userId)

// Sorted set — leaderboards, scheduled jobs
await redis.zadd('leaderboard', score, userId)
const top10 = await redis.zrevrange('leaderboard', 0, 9, 'WITHSCORES')
```

---

## Pub/Sub

```typescript
// Publisher
async function publishEvent(channel: string, data: object) {
  await redis.publish(channel, JSON.stringify(data))
}

// Subscriber — use a separate connection (subscribe blocks the connection)
const subscriber = redis.duplicate()

await subscriber.subscribe('order:events', (err) => {
  if (err) console.error('Subscribe error', err)
})

subscriber.on('message', (channel, message) => {
  const event = JSON.parse(message)
  console.log('Received:', channel, event)
})
```

---

## Scanning keys safely

```typescript
// ✅ SCAN — non-blocking, iterates in chunks
async function deleteUserCache(userId: string) {
  let cursor = '0'
  do {
    const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', `user:${userId}:*`, 'COUNT', 100)
    if (keys.length > 0) {
      await redis.del(...keys)
    }
    cursor = nextCursor
  } while (cursor !== '0')
}

// ❌ KEYS — blocks Redis until complete; dangerous on large datasets
await redis.keys('user:*')  // never in production
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| No TTL on keys | Always `SET key value EX ttl` |
| Creating a Redis client per request | Module-level singleton — one connection per process |
| `KEYS *` in production | Use `SCAN` with `MATCH` and `COUNT` |
| Storing sensitive data unencrypted | Encrypt before storing; never store passwords |
| Catching Redis errors silently | Log all errors; implement alerting for connection failures |
| JSON.parse without try/catch | Wrap parsing in try/catch; handle corrupted cache gracefully |
