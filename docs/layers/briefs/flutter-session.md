# Brief — `auth/flutter-session`

**Kind:** layer · **Issue:** #8 (parent #2) · **Cookbook:** `#session`, `#biometrics`, `#payments`

## Globs
```yaml
paths:
  - "**/features/auth/**/*.dart"
  - "**/core/network/auth_interceptor.dart"
  - "**/core/lifecycle/*.dart"
```

## Rules to encode
1. Tokens in platform secure storage — Keychain / Android Keystore. Never SharedPreferences,
   never a DB row.
2. **Three** session states: `unknown` | `active` | `none`. Without `unknown`, the router
   guard flashes sign-in at signed-in users on every cold start.
3. The session notifier is the only writer. Headers are read from it at request time.
4. Refresh is single-flight: N concurrent 401s await one refresh future; replay once; a
   second failure signs out rather than looping.
5. User-scoped providers `ref.watch(sessionProvider)`, so sign-out disposes the graph
   automatically — no manual invalidation list.
6. Sign-out clears everything user-scoped: tokens, DB rows, cached responses, image cache.
7. Revalidate on resume after a meaningful background gap — tokens can be revoked.
8. Expiry mid-task re-authenticates in place and resumes; it does not discard the user's work.
9. **Biometrics** gate access to a stored secret; a `true` from the plugin authenticates
   nothing to your server. `NSFaceIDUsageDescription` + `USE_BIOMETRIC` +
   `FlutterFragmentActivity` declared before the first call. Three-way availability check.
   Always a device-credential fallback. Secret bound to `biometryCurrentSet`. Lock is an
   overlay, not a route.
10. **Payments:** store policy picks the rail (IAP for digital goods, card for physical).
    The client never decides a purchase succeeded — the server validates the receipt and
    grants entitlement. Complete the purchase only after the server accepted. Restore is a
    visible working button.

## Eval cases
*Assertions below are sketches of intent, not literal strings. Replace any prose
with a discriminating code token — see AUTHORING.md section 6.*

| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Model session state and restore on cold start | `sealed`, `SessionUnknown` | two-state bool `isLoggedIn` |
| 02 | An interceptor that refreshes on 401 | `QueuedInterceptor`, `extra['retried']` | a refresh per failed request |
| 03 | Sign out completely | `deleteToken`, `imageCache`, `clearUserScoped` | clearing only the token |
| 04 | Unlock the app with biometrics | `localizedReason`, `biometryCurrentSet` | `if (ok) isLoggedIn = true` |

## Boundaries
Route guarding is `frontend/go-router`. Secure storage mechanics are `storage/flutter-local`.
