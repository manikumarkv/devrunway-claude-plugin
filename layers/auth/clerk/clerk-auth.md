# Clerk authentication standards

Short rules for apps using Clerk. They apply to every SDK: `@clerk/nextjs`, `@clerk/astro`, `@clerk/express`, `@clerk/clerk-react`.

## 1. Keys

| Variable | Where it may live |
|---|---|
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` / `PUBLIC_CLERK_PUBLISHABLE_KEY` | Browser (safe) |
| `CLERK_SECRET_KEY` | Server only |
| `CLERK_WEBHOOK_SIGNING_SECRET` | Server only |

Never prefix the secret key with `NEXT_PUBLIC_` or `PUBLIC_`. Never commit any key; use `.env.local` and your secrets manager.

## 2. Protect routes in middleware

Deny by default, and list public routes:

```ts
// middleware.ts (Next.js)
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server';

const isPublic = createRouteMatcher(['/', '/sign-in(.*)', '/sign-up(.*)', '/api/webhooks(.*)']);

export default clerkMiddleware(async (auth, req) => {
  if (!isPublic(req)) await auth.protect();
});

export const config = { matcher: ['/((?!_next|.*\\..*).*)', '/(api|trpc)(.*)'] };
```

Middleware is the first line, not the only one. Check again where the data is read.

## 3. Check auth on the server

- In API routes, server actions and loaders, call `auth()` and use its `userId`. Return 401 when it is null.
- Never take a user ID from the request body, query or headers.
- Use `currentUser()` only when you need the profile; it costs an API call.

```ts
import { auth } from '@clerk/nextjs/server';

export async function GET() {
  const { userId } = await auth();
  if (!userId) return new Response('Unauthorized', { status: 401 });
  return Response.json(await getOrdersFor(userId));
}
```

## 4. Authorization

- Use organizations with roles and permissions for multi-tenant apps.
- Check with `has({ permission: 'org:invoices:read' })` or `auth.protect({ role: 'org:admin' })` on the server.
- Hiding a button with `<Protect>` is UX, not security.

## 5. Webhooks (user sync)

- Sync users into your database from `user.created`, `user.updated` and `user.deleted` webhooks, not from the client.
- Verify the signature before reading the body. Make the handler idempotent on the event ID.

```ts
import { verifyWebhook } from '@clerk/nextjs/webhooks';

export async function POST(req: Request) {
  const evt = await verifyWebhook(req); // throws on a bad signature
  if (evt.type === 'user.created') await upsertUser(evt.data);
  return new Response('ok');
}
```

- Keep the webhook route public in middleware (Clerk calls it without a session).

## 6. Client UI

- Use `<SignedIn>`, `<SignedOut>`, `<UserButton>` and `useAuth()` for display only.
- Use Clerk's hosted or prebuilt `<SignIn />` / `<SignUp />` components rather than building password forms.

## Never

- The secret key in client code or a public env var.
- A user ID taken from the client for data access.
- An unverified webhook payload.
- Role checks only in the UI.
