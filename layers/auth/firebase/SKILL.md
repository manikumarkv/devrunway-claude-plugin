---
name: firebase-auth
description: Firebase Authentication conventions — initializeApp, onAuthStateChanged, ID token verification server-side, custom claims, and security rules. Load when working with Firebase Auth.
user-invocable: false
stack: auth/firebase
paths:
  - "firebase.json"
  - ".firebaserc"
  - "**/firebase/**"
  - "**/firebaseConfig*"
---

Full standards in [firebase.md](firebase.md). Always-on summary:

**Client-side:**
- Call `initializeApp()` once at app startup — never per-request or in a component
- `onAuthStateChanged(auth, user => { ... })` is the canonical way to track auth state — not `currentUser` directly
- Always `await signOut()` — never navigate away without completing sign-out

**Server-side verification:**
- Never trust a UID sent from the client — always verify the Firebase ID token server-side
- Use `admin.auth().verifyIdToken(token)` — returns `decodedToken` with uid, email, and custom claims
- Extract the token from `Authorization: Bearer <token>` header

**Custom claims:**
- Roles and permissions go in custom claims: `admin.auth().setCustomUserClaims(uid, { role: 'admin' })`
- Check `claims.role` in the server middleware after verifying the token — no extra DB lookup needed
- Custom claims have a 1000 byte limit — keep them small (role names, IDs only)

**Security:**
- ID tokens expire after 1 hour — refresh automatically via `getIdToken(true)` when needed
- Never store ID tokens in `localStorage` — use in-memory or `sessionStorage` for SPAs
- Enable only the sign-in methods your app uses — disable everything else in Firebase Console

**Never:**
- Trust `firebase.auth().currentUser.uid` without verifying the ID token server-side
- Use the Firebase client SDK on the server — use `firebase-admin` SDK
- Expose your Firebase service account key in client code or version control

**Related skills:** `security-principles` (token verification, OWASP auth rules), `data-governance` (PII in user profiles)
