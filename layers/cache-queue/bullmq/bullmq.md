# BullMQ Standards

---

## Setup

```bash
npm install bullmq ioredis
```

---

## Redis connection (shared)

```typescript
// src/lib/redis-queue.ts — shared connection for BullMQ
import { Redis } from 'ioredis'

// BullMQ requires maxRetriesPerRequest: null
export const redisConnection = new Redis(process.env.REDIS_URL!, {
  maxRetriesPerRequest: null,   // required for BullMQ blocking commands
  enableReadyCheck:     false,
  lazyConnect:          true,
})
```

---

## Queue definition

```typescript
// src/queues/email.queue.ts
import { Queue } from 'bullmq'
import { redisConnection } from '../lib/redis-queue'

// Job payload types
export interface WelcomeEmailJob {
  userId:    string
  email:     string
  firstName: string
}

export interface PasswordResetJob {
  userId:    string
  email:     string
  resetToken: string
}

// One Queue per job type
export const welcomeEmailQueue = new Queue<WelcomeEmailJob>('welcome-email', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts:          3,
    backoff: {
      type:  'exponential',
      delay: 2000,        // 2s, 4s, 8s
    },
    removeOnComplete: {
      age:   24 * 60 * 60,   // keep for 24 hours
      count: 100,             // keep last 100 completed jobs
    },
    removeOnFail: {
      age: 7 * 24 * 60 * 60,  // keep failed jobs for 7 days
    },
  },
})

export const passwordResetQueue = new Queue<PasswordResetJob>('password-reset', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 1000 },
    removeOnComplete: true,
    removeOnFail:     { age: 3 * 24 * 60 * 60 },
  },
})
```

---

## Enqueue jobs

```typescript
// src/features/users/user.service.ts
import { welcomeEmailQueue } from '../../queues/email.queue'

export async function registerUser(data: RegisterUserInput) {
  const user = await db.users.create({ data })

  // Enqueue — do not send email inline in the request
  await welcomeEmailQueue.add(
    'send-welcome',             // job name (for filtering/monitoring)
    {
      userId:    user.id,
      email:     user.email,
      firstName: user.firstName,
    },
    {
      // Idempotency: same userId = won't add duplicate if job exists
      jobId: `welcome-${user.id}`,
      delay: 5000,    // optional: delay 5 seconds before processing
    }
  )

  return user
}

// Bulk enqueue
async function notifyAllUsers(users: User[]) {
  const jobs = users.map((user) => ({
    name: 'send-promo',
    data: { userId: user.id, email: user.email, firstName: user.firstName },
    opts: { jobId: `promo-${user.id}-${Date.now()}` },
  }))

  await welcomeEmailQueue.addBulk(jobs)
}
```

---

## Worker

```typescript
// src/workers/email.worker.ts
import { Worker, type Job, UnrecoverableError } from 'bullmq'
import { redisConnection } from '../lib/redis-queue'
import { emailService } from '../services/email.service'
import type { WelcomeEmailJob } from '../queues/email.queue'

const worker = new Worker<WelcomeEmailJob>(
  'welcome-email',
  async (job: Job<WelcomeEmailJob>) => {
    const { userId, email, firstName } = job.data

    // Log progress
    await job.updateProgress(10)

    try {
      await emailService.sendWelcome({ email, firstName })
    } catch (err) {
      // Non-retryable error — move to failed immediately
      if ((err as any).statusCode === 400) {
        throw new UnrecoverableError(`Invalid email address: ${email}`)
      }
      // Retryable — re-throw and BullMQ will retry with backoff
      throw err
    }

    await job.updateProgress(100)
    return { sent: true, timestamp: new Date().toISOString() }
  },
  {
    connection:  redisConnection,
    concurrency: 5,     // 5 jobs processed simultaneously
    limiter: {
      max:      10,     // max 10 jobs
      duration: 1000,   // per 1 second (rate limiting)
    },
  }
)

// Event listeners
worker.on('completed', (job, result) => {
  console.log(`Job ${job.id} completed:`, result)
})

worker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed on attempt ${job?.attemptsMade}:`, err.message)
  // Alert: if all retries exhausted
  if (job && job.attemptsMade >= (job.opts.attempts ?? 1)) {
    alertPagerDuty(`Welcome email failed for ${job.data.email}: ${err.message}`)
  }
})

// Graceful shutdown
process.on('SIGTERM', async () => {
  await worker.close()
  await redisConnection.quit()
})

export { worker }
```

---

## Scheduled / recurring jobs

```typescript
import { Queue } from 'bullmq'

const reportQueue = new Queue('reports', { connection: redisConnection })

// Cron job — run every day at 9am UTC
await reportQueue.add(
  'daily-summary',
  { reportType: 'daily' },
  {
    repeat: {
      pattern: '0 9 * * *',   // cron syntax
      tz:      'UTC',
    },
    jobId: 'daily-summary-repeat',  // fixed ID prevents duplicates on restart
  }
)

// Remove a repeating job
await reportQueue.removeRepeatable('daily-summary', { pattern: '0 9 * * *' })
```

---

## Job flow (dependencies)

```typescript
import { FlowProducer } from 'bullmq'

const flowProducer = new FlowProducer({ connection: redisConnection })

// Fan-in: children must complete before parent runs
await flowProducer.add({
  name:    'generate-invoice',
  queueName: 'invoices',
  data:    { orderId },
  children: [
    {
      name:      'fetch-order-data',
      queueName: 'data-fetch',
      data:      { orderId },
    },
    {
      name:      'calculate-tax',
      queueName: 'tax',
      data:      { orderId },
    },
  ],
})
```

---

## Bull Board (dashboard)

```bash
npm install @bull-board/express @bull-board/api
```

```typescript
// src/lib/bull-board.ts
import { createBullBoard } from '@bull-board/api'
import { BullMQAdapter }   from '@bull-board/api/bullMQAdapter'
import { ExpressAdapter }  from '@bull-board/express'
import { welcomeEmailQueue, passwordResetQueue } from '../queues/email.queue'

const serverAdapter = new ExpressAdapter()
serverAdapter.setBasePath('/admin/queues')

createBullBoard({
  queues: [
    new BullMQAdapter(welcomeEmailQueue),
    new BullMQAdapter(passwordResetQueue),
  ],
  serverAdapter,
})

// Mount in Express app (behind auth)
app.use('/admin/queues', requireAdminAuth, serverAdapter.getRouter())
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `maxRetriesPerRequest` not set to `null` | BullMQ blocking commands fail without it — always set `null` |
| No `removeOnComplete`/`removeOnFail` | Redis fills up with completed/failed job metadata |
| One giant queue for all job types | One queue per job type — easier to monitor, rate-limit, and scale |
| Processing jobs synchronously in the API handler | Always enqueue — the API returns immediately, worker processes async |
| No concurrency set | Default is 1 — tune based on I/O vs CPU; I/O-heavy jobs can handle 10–50 |
| Retrying non-recoverable errors | Throw `UnrecoverableError` to skip all remaining retries |
| No graceful shutdown | Workers in-flight jobs get abandoned — always `await worker.close()` on SIGTERM |
