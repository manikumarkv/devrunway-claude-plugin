---
name: redis
description: Redis conventions — key naming, TTL discipline, connection pooling with ioredis, caching patterns, and pub/sub. Load when working with Redis.
user-invocable: false
stack: cache-queue/redis
paths:
  - "**/redis*"
  - "**/cache/**"
---

Full standards in [redis.md](redis.md). Always-on summary:

**Key naming — always structured:**
- Pattern: `<resource>:<id>:<field>` — e.g. `user:123:profile`, `session:abc123`
- Prefix by environment in multi-tenant setups: `prod:user:123:profile`
- Never use spaces or special chars in key names

**TTL — required on every key:**
- Every key written must have a TTL — unbounded keys fill memory and cause OOM evictions
- Set TTL at write time: `SET key value EX 3600`
- Exception: append-only structures like rate-limit counters (use `EXPIRE` separately)

**Connection:**
- One ioredis client per process — never create per-request
- Use `ioredis.Cluster` for Redis Cluster; plain `ioredis` for single-node/Sentinel
- Always handle `error` events — unhandled Redis errors crash the process

**Caching patterns:**
- Cache-aside: check cache → on miss, fetch from DB → write to cache with TTL
- Never cache stale data silently — invalidate on write, or set a short TTL
- Cache only serialisable data — functions and class instances break

**Never:**
- `KEYS *` in production — it blocks Redis for the duration of the scan; use `SCAN` instead
- Store sensitive data (passwords, tokens) in Redis without encryption
- Use Redis as a primary database — it's a cache/broker; data can be evicted

**Related skills:** `cache-queue/bullmq` (BullMQ uses Redis as its backbone), `api-conventions` (cache headers complement Redis caching)
