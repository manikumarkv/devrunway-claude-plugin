# Brief — `notifications/fcm`

**Kind:** layer · **Issue:** #11 (parent #2) · **Cookbook:** `#push`, `#background`

Currently the only layer in the plan with no existing content in the repo at all.

## Globs
```yaml
paths:
  - "**/features/notifications/**/*.dart"
  - "**/*notification*.dart"
  - "**/*push*.dart"
  - "**/firebase_messaging*.dart"
```

## Rules to encode
1. **Three delivery states, three handlers.** Foreground (`onMessage` — OS shows nothing by
   default), background-tap (`onMessageOpenedApp` — fires only on tap), terminated
   (`getInitialMessage` + a top-level background handler).
2. The background handler is `@pragma('vm:entry-point')`, top-level, runs in its **own
   isolate** with no access to providers, router or session. It initializes its own
   dependencies and defers anything needing app state to next launch.
3. Payload carries a **route location**, resolved through the router — so the auth guard
   applies and a signed-out tap continues after sign-in. Never a screen name switched on.
4. Token registered on sign-in, re-registered on refresh, **deleted on sign-out**. A token
   outliving a session means the next user on that device receives the previous user's
   notifications, with content in the preview.
5. Permission asked in context, never on first launch. iOS gives one prompt per install;
   consider provisional authorization. Android 13+ needs runtime `POST_NOTIFICATIONS`.
6. Channels created before first use and immutable afterwards — importance, sound and
   vibration cannot be changed later, only replaced.
7. Notification content assumes a lock screen. No personal detail in title or body.
8. Category opt-out honoured server-side, not by dropping messages on the device.
9. **Background work** is opportunistic. Nothing user-visible may depend on it having run.
   Prefer a server-triggered silent push over a device-side schedule. Declare constraints;
   make work idempotent and resumable; verify with battery optimization on, on a real device.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Wire up FCM handlers for all app states | `@pragma('vm:entry-point')`, `getInitialMessage`, `onMessageOpenedApp` | only `onMessage` |
| 02 | Handle a notification tap that opens a program | `data['route']`, `.go(` | `switch (data['screen'])` |
| 03 | Register and clear the push token | `deleteToken`, `sessionProvider` | register with no sign-out path |
| 04 | Schedule a periodic sync | `Constraints`, idempotent marker | a guarantee of interval timing |

## Boundaries
Route resolution is `frontend/go-router`. Token storage is `auth/flutter-session`.
