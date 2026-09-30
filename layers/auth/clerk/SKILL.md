---
name: clerk-auth
description: Clerk authentication standards — middleware route protection, server-side auth checks, webhook verification, key handling. Load when working with Clerk.
user-invocable: false
stack: auth/clerk
paths:
  - "**/*clerk*"
  - "**/middleware.{ts,js}"
  - "**/webhooks/clerk*"
  - "**/webhooks/clerk/**"
  - "**/sign-in/**"
  - "**/sign-up/**"
---

Full standards in [clerk-auth.md](clerk-auth.md). Always-on summary:

- **Protect routes in middleware** with `clerkMiddleware()` and `createRouteMatcher()`. Deny by default, allow public routes explicitly.
- **Check auth on the server** with `auth()` / `currentUser()` in every API route and server action. Client hooks (`useAuth`, `<SignedIn>`) are for UI only.
- **Keys.** `CLERK_SECRET_KEY` and `CLERK_WEBHOOK_SIGNING_SECRET` are server-only. Only the publishable key may reach the browser.
- **Webhooks.** Verify every webhook signature (`verifyWebhook()` or svix) before trusting the payload.
- **Authorize by role or permission** (`has({ role })` / `has({ permission })`), not by hiding buttons.
- **Never** store Clerk session tokens yourself or trust a user ID sent from the client.
