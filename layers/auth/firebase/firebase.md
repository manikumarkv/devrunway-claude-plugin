# Firebase Authentication Standards

---

## Client-side setup

```typescript
// src/lib/firebase.ts — initialise once at app startup
import { initializeApp, getApps } from 'firebase/app'
import { getAuth } from 'firebase/auth'

const firebaseConfig = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain:        process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket:     process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

// Guard against re-initialisation in hot reload environments
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0]
export const auth = getAuth(app)
```

---

## Authentication state

```typescript
// src/hooks/useAuth.ts — canonical auth state hook
import { useEffect, useState } from 'react'
import { onAuthStateChanged, User } from 'firebase/auth'
import { auth } from '../lib/firebase'

export function useAuth() {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (firebaseUser) => {
      setUser(firebaseUser)
      setLoading(false)
    })
    return unsubscribe  // cleanup on unmount
  }, [])

  return { user, loading, isAuthenticated: !!user }
}
```

**Rules:**
- `onAuthStateChanged` fires once immediately with `null` (logged out) or a `User` — always handle the loading state
- `auth.currentUser` may be null during initialisation — never rely on it synchronously
- The observer fires again when the token is refreshed

---

## Sign-in methods

```typescript
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  signOut,
  sendPasswordResetEmail,
} from 'firebase/auth'
import { auth } from '../lib/firebase'

// Email + password
async function loginWithEmail(email: string, password: string) {
  const credential = await signInWithEmailAndPassword(auth, email, password)
  return credential.user
}

// Google OAuth
async function loginWithGoogle() {
  const provider = new GoogleAuthProvider()
  provider.addScope('email')
  const result = await signInWithPopup(auth, provider)
  return result.user
}

// Sign out
async function logout() {
  await signOut(auth)
  // Now navigate — never navigate before signOut completes
}

// Password reset
async function resetPassword(email: string) {
  await sendPasswordResetEmail(auth, email)
}
```

---

## Getting the ID token

```typescript
// Get a fresh ID token for API requests
async function getAuthHeader(): Promise<string> {
  const user = auth.currentUser
  if (!user) throw new Error('Not authenticated')

  // Pass true to force refresh if token is about to expire
  const token = await user.getIdToken(/* forceRefresh */ false)
  return `Bearer ${token}`
}

// Use in API calls
async function fetchOrders() {
  const authHeader = await getAuthHeader()
  const res = await fetch('/api/v1/orders', {
    headers: { Authorization: authHeader },
  })
  return res.json()
}
```

**Token lifecycle:**
- ID tokens expire after 1 hour
- `getIdToken()` returns the cached token if still valid, or auto-refreshes it
- Pass `true` to `getIdToken(true)` to force a refresh (e.g. after setting custom claims)

---

## Server-side — Firebase Admin

```bash
npm install firebase-admin
```

```typescript
// src/lib/firebase-admin.ts — server-side only
import admin from 'firebase-admin'

// Initialise with service account (environment variables, never hardcoded)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId:   process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      // Replace escaped newlines in private key (common env var issue)
      privateKey:  process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  })
}

export const adminAuth = admin.auth()
```

---

## Server-side token verification

```typescript
// src/middleware/auth.ts
import { adminAuth } from '../lib/firebase-admin'

export async function requireAuth(req: Request): Promise<DecodedIdToken> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing Authorization header')
  }

  const token = authHeader.split('Bearer ')[1]

  try {
    // Verifies: signature, expiry, audience (project), issuer
    const decoded = await adminAuth.verifyIdToken(token)
    return decoded
  } catch (err) {
    throw new UnauthorizedError('Invalid or expired token')
  }
}
```

```typescript
// Express route
app.get('/api/v1/profile', async (req, res) => {
  const decoded = await requireAuth(req)
  // decoded.uid — verified user ID
  // decoded.email — user's email
  // decoded.role — custom claim (if set)

  const user = await userRepository.findById(decoded.uid)
  res.json({ success: true, data: user })
})
```

---

## Custom claims — roles and permissions

```typescript
// Set custom claims (server-side only — Admin SDK)
await adminAuth.setCustomUserClaims(uid, {
  role: 'admin',         // string
  orgId: 'org-123',      // arbitrary data
})

// The user must refresh their ID token to get the new claims
// Force refresh on the client after a role change:
await auth.currentUser?.getIdToken(true)
```

```typescript
// Verify claims server-side
const decoded = await adminAuth.verifyIdToken(token)
if (decoded.role !== 'admin') {
  throw new ForbiddenError('Admin access required')
}
```

**Custom claims limits:**
- Max 1000 bytes total
- Keep claims minimal — roles and IDs, not full user profiles
- Claims are included in every token — no extra DB lookup for auth checks

---

## Security rules (Firestore/Storage)

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Admin-only collection
    match /admin/{document=**} {
      allow read, write: if request.auth != null
        && request.auth.token.role == 'admin';
    }

    // Public read, authenticated write
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

**Deploy security rules:**
```bash
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

---

## Environment variables

```bash
# .env.example

# Client-side (safe to expose — these are public config)
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSy...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=myapp.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=myapp
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=myapp.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:abc123

# Server-side only — NEVER expose these
FIREBASE_PROJECT_ID=myapp
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@myapp.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

**The Firebase client API key is NOT a secret** — it identifies your project but does not grant admin access. Security is enforced by Security Rules and ID token verification.

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Using `auth.currentUser.uid` without verifying the token server-side | Always call `adminAuth.verifyIdToken()` on the server |
| Navigating before `await signOut()` completes | Await signOut; then navigate |
| Checking auth state with `auth.currentUser` synchronously | Use `onAuthStateChanged` — it fires when the state is ready |
| Storing ID tokens in localStorage | Keep in-memory or HttpOnly cookie; localStorage is XSS-accessible |
| Not refreshing token after setting custom claims | Call `getIdToken(true)` after an admin sets new claims |
| Committing `serviceAccountKey.json` | Add to `.gitignore`; use environment variables |
