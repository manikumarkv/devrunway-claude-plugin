---
name: fcm
description: Firebase Cloud Messaging standards for Flutter — the three delivery states and their handlers, the top-level background isolate entry point, route-location payloads resolved through the router, permission asked in context on iOS and Android 13+, the register/refresh/delete token lifecycle, immutable Android notification channels, lock-screen-safe content, server-side category opt-out, and opportunistic background work. Load when writing or reviewing push notification handling, token registration, notification channels, or background sync.
user-invocable: false
stack: notifications/fcm
paths:
  - "**/features/notifications/**/*.dart"
  - "**/*notification*.dart"
  - "**/*push*.dart"
  - "**/firebase_messaging*.dart"
---

Full standards in [fcm.md](fcm.md). Always-on summary:

**Scope:** delivery — handlers, the background isolate, payloads, permission, tokens, channels, background work. Where a tap *goes* is `frontend/go-router`; the sign-out sequence the token deletion belongs to is `auth/flutter-session`.

**Three delivery states, three handlers, plus the background entry point:**
- Foreground: `FirebaseMessaging.onMessage.listen(...)` — the OS draws nothing on Android, so decide per category: refresh the screen, show an in-app banner, or post it locally on a created channel. On iOS, `setForegroundNotificationPresentationOptions(...)`.
- Background then tapped: `FirebaseMessaging.onMessageOpenedApp.listen(...)`. It fires on the **tap**, never on delivery — it cannot count deliveries.
- Terminated then tapped: `await FirebaseMessaging.instance.getInitialMessage()`, read once, after the router exists. Non-null exactly once per launch. This is the state teams skip, because a debug build attached to the IDE is never terminated.
- Registered in `main()` before `runApp`: `FirebaseMessaging.onBackgroundMessage(handler)` — a **static** call on the class, not on `FirebaseMessaging.instance`.

**The background handler is a different isolate:**
- Top-level (or static) function annotated `@pragma('vm:entry-point')`. Without it, release builds tree-shake it and background messages silently do nothing while debug works.
- It must `await Firebase.initializeApp(...)` itself. There are no providers, no router, no navigator key, no session, no `BuildContext` — a second isolate has its own memory, so anything the handler needs it constructs.
- Anything needing app state is deferred: write a durable record keyed by `message.messageId`, drained by the UI isolate at next launch. iOS only wakes it for `content-available`, and may not wake it at all.

**Payload carries a route location, resolved through the router:**
- `final location = message.data['route']; if (location == null || !location.startsWith('/')) return; router.go(location);` — one handler for both tap paths.
- That `go` runs the route table's redirect, so a tap while signed out lands on sign-in and continues to the target afterwards. A payload naming a screen, switched on in the handler, is a hand-maintained second copy of the route table that skips the auth guard and produces a screen with no URL.
- The payload announces that something happened at a location; the screen fetches current state. It is never rendered as truth.

**Token lifecycle — the deletion is a privacy rule, not housekeeping:**
- On sign-in: `getToken()`, then `registerDevice(token)` on your backend. On iOS `getToken()` can return null before APNs registers — not an error.
- `onTokenRefresh.listen(...)` re-registers, and checks the session is `SessionActive` first so a rotation is attributed to whoever is signed in now.
- On sign-out: cancel the refresh subscription, `unregisterDevice(token)` server-side **while the access token is still valid**, then `deleteToken()` on the device. Skip it and the next person to sign in on that tablet receives the previous user's notifications, with the content on the lock screen. Both halves are required: server-only leaves a live token, device-only leaves a dead row your backend keeps sending to.
- Never address a specific user by subscribing their device to a per-user topic — it is invisible to your backend, unrevocable server-side, and survives sign-out. Topics are for genuine broadcast.

**Permission in context, never on first launch:** iOS shows the system prompt **once per install**, so spend it right after the user did the thing that needs it. `requestPermission(alert: true, badge: true, sound: true)`; accept `AuthorizationStatus.authorized` and `AuthorizationStatus.provisional`. `provisional: true` delivers quietly to Notification Center with no prompt at all and leaves the one-shot unspent. On `AuthorizationStatus.denied` there is no second prompt — explain, then `openAppSettings()`. Android 13+ needs `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` in the manifest or the request returns denied with no dialog.

**Channels are created before first use and immutable afterwards:** create every `AndroidNotificationChannel` at app start via `createNotificationChannel(...)`. Importance, sound and vibration cannot be changed later — a second `createNotificationChannel` with the same id updates only the name, description and group and silently ignores the rest, and recreating a deleted id restores the old settings. To change behaviour, ship a channel with a **new versioned id** (`session_reminders_v2`, `Importance.high`) and `deleteNotificationChannel('session_reminders')` for the old one, or the user sees two identical rows in settings. A notification naming a channel that was never created is dropped silently on Android 8+.

**Content assumes a lock screen:** no names, amounts, diagnoses or message bodies in title or body — "New message", not who sent it or what it says. Identifying detail travels in `data` and is rendered after unlock. `NotificationVisibility.private` on Android hides content on a secure lock screen.

**Category opt-out is enforced server-side, before sending.** The device never receives a message it then discards — the OS has already drawn it, the preference would not follow the user to their other device, and the background handler is not guaranteed to run. The only legitimate client-side suppression is a duplicate `messageId`.

**Background work is opportunistic — nothing user-visible may depend on it having run.** Prefer a server-triggered silent push over a device-side schedule. When you do schedule: `@pragma('vm:entry-point')` on the dispatcher, `Workmanager().registerPeriodicTask(...)` with `constraints: Constraints(networkType: NetworkType.connected)`, `return Future.value(true)` when done and `false` to ask for backoff. Every write is idempotent (a cursor, an upsert on a stable key) because the OS will re-run it; every task is resumable because it can be killed mid-flight. The frequency is a floor, never a promise. An in-process timer is not background work — it dies the moment the app is suspended. Verify on a real device with battery optimization on.

**Related:** `frontend/go-router`, `auth/flutter-session`, `storage/flutter-local`, `logging/flutter-observability`, `state/riverpod`.
