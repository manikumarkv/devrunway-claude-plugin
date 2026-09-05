# Environment Variable Standards

---

## File hierarchy

```
.env                ← NEVER commit — real secrets for local dev
.env.local          ← NEVER commit — local overrides (highest priority)
.env.example        ← ALWAYS commit — documents every key, no real values
.env.test           ← COMMIT only if all values are fake/safe
.env.development    ← COMMIT only if all values are fake/safe
```

**Production:** Environment variables are set in the deployment platform (Vercel, Railway, AWS, etc.). `.env.production` should not exist as a file.

---

## .env.example

Every env var the app reads must appear in `.env.example` with a placeholder:

```bash
# .env.example — commit this file; update it when you add a new env var

# Application
NODE_ENV=development
PORT=3000
APP_URL=http://localhost:3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/myapp_dev

# Auth
JWT_SECRET=replace-with-a-random-64-char-string
SESSION_SECRET=replace-with-a-random-64-char-string

# Third-party APIs
STRIPE_SECRET_KEY=sk_test_replace_me
STRIPE_WEBHOOK_SECRET=whsec_replace_me
SENDGRID_API_KEY=SG.replace_me

# Storage
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1
S3_BUCKET=my-app-assets
```

**Rules for .env.example:**
- Every variable the app reads must be present
- Values are fake but realistic-looking (helps devs understand the format)
- Add a comment group for each service
- Update `.env.example` in the same PR that adds a new env var to the code

---

## Centralised config module

Never scatter `process.env.FOO` reads across the codebase. One file reads and validates everything:

```typescript
// src/config.ts
import { z } from 'zod'   // or any validation library, or plain if-checks

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_WEBHOOK_SECRET: z.string().startsWith('whsec_'),
})

// Validate at module load time — the app fails immediately if anything is missing.
//
// safeParse, not parse. A thrown ZodError leaves module load with the whole
// environment in the frame, and whatever catches it — a crash reporter, an APM
// breadcrumb, a CI job log — captures the frame with it. safeParse keeps the
// failure in a value, and you decide what is printed from it.
const parsed = envSchema.safeParse(process.env)

if (!parsed.success) {
  // Field names and validation messages. Never the values, never process.env.
  console.error('❌ Invalid environment variables:')
  console.error(parsed.error.flatten().fieldErrors)
  process.exit(1)
}

// This object now holds every secret the process has, which puts the whole set
// one `console.log` away from a log aggregator. So it defends itself: both routes
// out of a JS value — util.inspect, which is what console.log uses, and
// JSON.stringify, which is what most loggers use — are overridden to redact.
// Reading `config.JWT_SECRET` still returns the real value.
const SECRET_KEYS = ['DATABASE_URL', 'JWT_SECRET', 'STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET']

function redact(): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(parsed.data).map(([key, value]) =>
      SECRET_KEYS.includes(key) ? [key, '[redacted]'] : [key, value],
    ),
  )
}

export const config = Object.freeze({
  ...parsed.data,
  toJSON: redact,
  [Symbol.for('nodejs.util.inspect.custom')]: redact,
})
```

Redaction is a backstop, not a licence. The rule is still that a secret is never
logged: pass `config.STRIPE_SECRET_KEY` to the client that needs it, never into a
message. What the backstop buys you is that the accidents — a debug `console.log`
left in, an error object serialised with its context, a startup dump — do not turn
the one place that holds everything into the one line that leaks everything.

```typescript
// ✅ Startup log — names and counts, never values
console.log(`config ok: ${Object.keys(parsed.data).length} variables, NODE_ENV=${config.NODE_ENV}`)
```

```typescript
// Every other file imports from config, not process.env
import { config } from './config'

const client = new StripeClient(config.STRIPE_SECRET_KEY)
```

**Why:** If a variable is missing, the error appears at startup with a clear message — not deep in a request handler hours later.

---

## Environment separation

| Environment | Secret source | Who sets it |
|---|---|---|
| Local dev | `.env` file (not committed) | Each developer runs from `.env.example` |
| CI / test | Platform environment variables | CI config (GitHub Actions secrets, etc.) |
| Staging | Platform environment variables | DevOps / deployment config |
| Production | Platform environment variables or secrets manager | DevOps / deployment config |

**Principle:** Code never knows or cares which environment it's running in — it only reads env vars. The _platform_ decides what values to inject.

---

## .gitignore — required entries

```gitignore
# Environment files — NEVER commit these
.env
.env.local
.env.*.local

# Safe to commit (only if values are fake):
# .env.example   ← commit this
# .env.test      ← commit only if fake values
```

---

## Naming conventions

```bash
# All caps, underscores, no special chars
DATABASE_URL=...
STRIPE_SECRET_KEY=...

# Group by service — prefix with service name
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=...
STRIPE_PUBLISHABLE_KEY=...

AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=...

# Boolean vars — use TRUE/FALSE strings, coerce in code
FEATURE_NEW_CHECKOUT=true
```

```typescript
// Coerce booleans in the config module
const envSchema = z.object({
  FEATURE_NEW_CHECKOUT: z.coerce.boolean().default(false),
})
```

---

## Loading .env in different runtimes

```typescript
// Node.js — load with dotenv
import 'dotenv/config'     // at the very top of your entrypoint

// or in package.json scripts:
// "dev": "dotenv -e .env node src/index.js"
```

```python
# Python — load with python-dotenv
from dotenv import load_dotenv
load_dotenv()  # at the top of main entry point
import os
database_url = os.environ["DATABASE_URL"]
```

```
# Bun — no package needed; Bun loads .env automatically
```

```
# Next.js — no package needed; Next.js loads .env.* automatically
# NEXT_PUBLIC_ prefix makes a variable available in the browser
```

---

## Never do this

```typescript
// ❌ Hardcoded secret
const stripe = new Stripe('sk_live_abc123...')

// ❌ Reading process.env directly outside config module
const url = process.env.DATABASE_URL  // in a repository file

// ❌ Logging env var values — including indirectly, through the config object
console.log('Connecting to', process.env.DATABASE_URL)

// ❌ Committing .env
git add .env   // ← NEVER

// ❌ Same secret in multiple environments
// dev DATABASE_URL = postgres://user:pass@prod-db.example.com/...
```

```typescript
// ✅ Always
import { config } from './config'
const stripe = new Stripe(config.STRIPE_SECRET_KEY)
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `.parse(process.env)` at module load | Use `safeParse`; a thrown ZodError carries the environment in the frame that a crash reporter captures |
| Printing the parse failure's data instead of its field names | Print `fieldErrors` — keys and messages, never values |
| Exporting the validated object with no protection | One object holds every secret; override `toJSON` and the inspect symbol to redact, so an accidental log line cannot dump the set |
| Logging a secret "just this once" in debug | Debug logs ship to the same aggregator as everything else, and stay there for the retention period |
| Interpolating a secret into a message or URL for a log | Pass it as an argument to the client that needs it; it should never be part of a string you might print |
| Treating redaction as permission to log the config | It is a backstop for accidents, not a licence |

## Rotating a secret

When a secret is accidentally committed or otherwise compromised:

1. **Rotate immediately** — generate a new secret in the provider's console
2. **Update all environments** — staging, production, CI
3. **Remove from git history** — `git filter-repo --path .env --invert-paths`
4. **Verify** — `git log --all -- .env` should return nothing
5. **Force-push to all remotes** — coordinate with team
6. **Audit access logs** — check if the old secret was used by an attacker
