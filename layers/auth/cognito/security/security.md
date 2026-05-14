# Security Standards

---

## Authentication — Cognito JWT verification

Every protected route must verify the JWT with `aws-jwt-verify`. Decoding without verifying means the token is not trusted.

```ts
// src/middleware/auth.ts
import { CognitoJwtVerifier } from 'aws-jwt-verify'
import { UnauthorizedError } from '../utils/errors'

const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID!,
  tokenUse: 'access',
  clientId: process.env.COGNITO_CLIENT_ID!,
})

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization

  if (!header?.startsWith('Bearer ')) {
    throw new UnauthorizedError()
  }

  try {
    const token = header.slice(7)
    const payload = await verifier.verify(token)
    req.user = {
      sub: payload.sub,
      email: payload.email as string,
      groups: (payload['cognito:groups'] as string[]) ?? [],
    }
    next()
  } catch {
    throw new UnauthorizedError('Invalid or expired token')
  }
}
```

```ts
// ❌ Decoding without verification — token is untrusted
import jwt from 'jsonwebtoken'
const payload = jwt.decode(token)   // never do this for auth decisions

// ❌ Trusting Authorization header value without verification
req.user = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString())
```

---

## Authorization — group-based, not claim-based

Cognito groups are the source of truth for roles. Never read a `role` field from the token body or request — it can be forged.

```ts
// src/middleware/requireGroup.ts
import { ForbiddenError } from '../utils/errors'

export function requireGroup(...groups: string[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const userGroups = req.user?.groups ?? []
    const hasGroup = groups.some(g => userGroups.includes(g))
    if (!hasGroup) throw new ForbiddenError()
    next()
  }
}
```

```ts
// src/routes/orders.ts
ordersRouter.post('/:id/refund', requireGroup('admin'), ordersController.refund)
ordersRouter.get('/reports', requireGroup('admin', 'manager'), ordersController.report)
```

```ts
// ❌ Trusting a role claim from the token payload
if (req.user.role === 'admin') { ... }    // role field is user-controlled

// ❌ Client-sent role
if (req.body.isAdmin) { ... }
```

---

## IDOR — always check ownership

Every service method that reads or mutates a resource must verify the requesting user owns it. A valid JWT does not mean the user owns this specific record.

```ts
// src/services/orders.service.ts

// ✅ Ownership check on every operation
export async function getById(id: string, user: AuthUser) {
  const order = await orderRepository.findById(id)
  if (!order) throw new NotFoundError('Order', id)
  if (order.userId !== user.sub) throw new ForbiddenError()  // ← ownership check
  return order
}

export async function update(id: string, input: UpdateOrderInput, user: AuthUser) {
  await getById(id, user)   // reuses the check — throws if not owner
  return orderRepository.update(id, input)
}

// ❌ No ownership check — any authenticated user can read any order
export async function getByIdUnsafe(id: string) {
  return orderRepository.findById(id)
}
```

---

## Input validation — Zod on everything

Never access `req.body`, `req.params`, or `req.query` fields directly. Parse first, use the typed result.

```ts
// ✅ Parse all inputs before use
export const createOrder = asyncHandler(async (req, res) => {
  const body = createOrderSchema.parse(req.body)     // validated + typed
  const { id } = orderParamsSchema.parse(req.params) // validated UUID
  const query = listQuerySchema.parse(req.query)     // validated + coerced
  // body, id, query are now safe to use
})

// ❌ Direct access — no validation, no type safety
export const createOrderBad = asyncHandler(async (req, res) => {
  const productId = req.body.productId    // could be anything
  const quantity = req.body.quantity      // could be a string, negative, NaN
})
```

**Zod schema rules:**
- `z.string().uuid()` for all ID fields — rejects non-UUID strings
- `z.coerce.number().int().positive()` for quantities — rejects negatives and floats
- `z.string().max(1000)` on all free-text fields — prevents oversized payloads
- `z.enum([...])` for status fields — rejects arbitrary strings

---

## SQL injection prevention

Prisma uses parameterized queries by default. Never bypass this.

```ts
// ✅ Prisma — always parameterized
prisma.order.findMany({ where: { userId, status } })

// ❌ Raw query with string interpolation — SQL injection
prisma.$queryRaw`SELECT * FROM orders WHERE user_id = '${userId}'`

// ✅ Raw query when needed — use Prisma.sql tagged template
prisma.$queryRaw(Prisma.sql`SELECT * FROM orders WHERE user_id = ${userId}`)
```

---

## XSS prevention

React escapes all JSX expressions by default. The only risk is opting out.

```tsx
// ✅ Safe — React escapes this
<p>{userContent}</p>

// ❌ Bypasses escaping — XSS if userContent is user-controlled
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// ✅ If HTML rendering is required — sanitize first
import DOMPurify from 'dompurify'
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />
```

Never use `dangerouslySetInnerHTML` with unsanitized user content. If you need rich text rendering, use a sanitizer (`dompurify`) or a safe renderer (`react-markdown` with no raw HTML).

---

## Security headers — helmet

```ts
// src/app.ts
import helmet from 'helmet'

// Mount before all routes
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],   // relax if Tailwind requires it
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", process.env.API_URL!],
    },
  },
  crossOriginEmbedderPolicy: false,   // required for some CDN assets
}))
```

**Never disable helmet entirely** — even in development, run it so you catch CSP violations early.

---

## CORS

```ts
// src/app.ts
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') ?? []

app.use((req, res, next) => {
  const origin = req.headers.origin
  if (origin && allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin)
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization')
  res.setHeader('Access-Control-Max-Age', '86400')
  if (req.method === 'OPTIONS') return res.status(204).end()
  next()
})
```

```
# .env
ALLOWED_ORIGINS=https://app.myapp.com,https://staging.myapp.com
```

```ts
// ❌ Wildcard — allows any origin to call your API with credentials
res.setHeader('Access-Control-Allow-Origin', '*')

// ❌ Reflecting Origin without allowlist check
res.setHeader('Access-Control-Allow-Origin', req.headers.origin)
```

---

## Rate limiting

```ts
// src/middleware/rateLimiter.ts
import rateLimit from 'express-rate-limit'

// Tight limit on auth routes — brute force protection
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutes
  max: 5,
  message: { error: { message: 'Too many attempts. Try again in 15 minutes.', code: 'RATE_LIMITED' } },
  standardHeaders: true,
  legacyHeaders: false,
})

// General API limit
export const apiRateLimiter = rateLimit({
  windowMs: 60 * 1000,         // 1 minute
  max: 100,
  message: { error: { message: 'Too many requests.', code: 'RATE_LIMITED' } },
  standardHeaders: true,
  legacyHeaders: false,
})
```

```ts
// src/routes/index.ts
app.use('/api/v1/auth', authRateLimiter, authRouter)
app.use('/api/v1', apiRateLimiter, v1Router)
```

---

## S3 file uploads — presigned URLs only

Never expose your S3 bucket publicly or stream files through your API. Use presigned URLs so uploads and downloads go directly from the browser to S3.

```ts
// src/services/upload.service.ts
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { randomUUID } from 'crypto'

const s3 = new S3Client({ region: process.env.AWS_REGION })

export async function getUploadUrl(userId: string, mimeType: string) {
  const allowedTypes = ['image/jpeg', 'image/png', 'application/pdf']
  if (!allowedTypes.includes(mimeType)) {
    throw new ValidationError('File type not allowed')
  }

  const key = `uploads/${userId}/${randomUUID()}`   // never use user-supplied filenames

  const url = await getSignedUrl(
    s3,
    new PutObjectCommand({
      Bucket: process.env.S3_BUCKET!,
      Key: key,
      ContentType: mimeType,
    }),
    { expiresIn: 900 }   // 15 minutes — shortest practical window
  )

  return { url, key }
}

export async function getDownloadUrl(key: string, userId: string) {
  // Validate the user owns this file before generating a download URL
  const file = await fileRepository.findByKey(key)
  if (!file) throw new NotFoundError('File', key)
  if (file.userId !== userId) throw new ForbiddenError()

  return getSignedUrl(
    s3,
    new GetObjectCommand({ Bucket: process.env.S3_BUCKET!, Key: key }),
    { expiresIn: 900 }
  )
}
```

```ts
// ❌ User-controlled filename — path traversal risk
const key = `uploads/${req.body.filename}`

// ❌ Exposing the bucket URL directly
res.json({ url: `https://${bucket}.s3.amazonaws.com/${key}` })

// ❌ Streaming through API — wastes Lambda compute + memory
res.pipe(s3.getObject(...).createReadStream())
```

---

## Secrets management

```ts
// ❌ Hard-coded
const secret = 'abc123secretkey'

// ❌ Committed .env file
// DATABASE_URL=postgres://user:realpassword@host/db  ← in git history forever

// ✅ SSM at runtime (Lambda)
const dbUrl = await ssmClient.send(new GetParameterCommand({
  Name: '/myapp/prod/database-url',
  WithDecryption: true,
}))

// ✅ Local dev — .env file that is gitignored, values from .env.example
```

```
# .env.example — commit this (no real values)
DATABASE_URL=
COGNITO_USER_POOL_ID=
COGNITO_CLIENT_ID=
S3_BUCKET=
ALLOWED_ORIGINS=

# .env — gitignored (real values here)
```

```
# .gitignore
.env
.env.local
.env.production
```

Never commit a `.env` file with real values. Run `git log --all -S 'SECRET_VALUE'` to check if a secret was ever committed — if so, rotate it immediately.

---

## Dependency security

```bash
# Run before every PR merge
npm audit --audit-level=high

# Fix automatically where safe
npm audit fix

# Check for outdated packages monthly
npm outdated
```

Add to CI:

```yaml
- name: Security audit
  run: npm audit --audit-level=high
```

---

## Pre-PR security checklist

Before raising a PR, verify:

**Auth**
- [ ] Every route that returns user data is behind `requireAuth`
- [ ] Admin/manager routes are behind `requireGroup`
- [ ] Every service method that touches a record checks ownership

**Input**
- [ ] All `req.body`, `req.params`, `req.query` parsed with Zod
- [ ] No raw SQL string concatenation (use Prisma parameterized or `Prisma.sql`)
- [ ] No `dangerouslySetInnerHTML` with unsanitized content

**Output**
- [ ] Error responses use `AppError.code`, not `err.message` or stack traces
- [ ] No secrets, tokens, or internal paths in response bodies

**Infrastructure**
- [ ] helmet mounted before all routes
- [ ] Rate limiter on auth routes (tight) and API routes (general)
- [ ] CORS allowlist — not `*` in production
- [ ] S3 keys are UUIDs, not user-supplied filenames
- [ ] Presigned URL expiry ≤ 15 minutes

**Secrets**
- [ ] No hard-coded secrets, keys, or passwords in code
- [ ] `.env` is in `.gitignore`
- [ ] `npm audit --audit-level=high` passes
