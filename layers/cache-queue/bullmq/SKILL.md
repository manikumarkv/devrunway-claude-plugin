---
name: bullmq
description: BullMQ standards — queue setup, job types, retry strategies, concurrency, delays, and the Bull Board dashboard. Load when working with BullMQ.
user-invocable: false
stack: cache-queue/bullmq
paths:
  - "**/queues/**"
  - "**/workers/**"
  - "**/jobs/**"
  - "**/bullmq*"
---

Full standards in [bullmq.md](bullmq.md). Always-on summary:

**Queue setup:**
- One `Queue` per job type — not one giant queue for everything
- Share the Redis connection across Queue and Worker instances — use `IORedis` with `maxRetriesPerRequest: null`
- Always define `defaultJobOptions` with `removeOnComplete` and `removeOnFail` — otherwise Redis fills up

**Job definition:**
- Define job payload types with TypeScript interfaces — never `any`
- Use `jobId` for idempotent jobs (same ID = won't add duplicates) — prevents double-processing
- Add job data that is sufficient to process the job independently — don't assume in-memory state

**Workers:**
- Set `concurrency` explicitly — default is 1; tune based on job type (CPU vs I/O)
- Always handle errors in the processor function — unhandled rejections become failed jobs
- Use `Worker.on('failed')` to log or alert on job failures — don't rely on queue inspection only

**Retry strategy:**
- Use `attempts` + `backoff: { type: 'exponential', delay: 1000 }` — prevents thundering herd
- For non-retryable errors, throw a special error class and `moveToFailed()` to skip retries

**Flow / dependencies:**
- Use `FlowProducer` for jobs that must run in sequence or fan-out patterns
- Never chain jobs by having one job add the next inside the processor — use `FlowProducer` or events

**Never:**
- Use Redis without persistence (AOF or RDB) for BullMQ — jobs will be lost on Redis restart
- Process jobs inline in the API request handler — always enqueue and return immediately
- Ignore the `removeOnComplete`/`removeOnFail` settings — Redis memory grows unboundedly

**Related skills:** `cache-queue/redis` (underlying Redis client), `cache-queue/sqs` (AWS-native alternative)
