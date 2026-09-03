# Firebase Cloud Messaging and Background Work Standards

A push notification is the only part of the app that runs when nobody is looking at it. It
arrives in three different process states, each with a different handler, each with a
different set of things that exist — and the state teams forget is the one where the app is
not running, which is the state most notifications are actually delivered in.

**Scope boundaries.** This layer owns **delivery**: registering the three handlers, the
background isolate, the payload contract, permission, the token lifecycle, Android channels,
what a notification is allowed to say, and opportunistic background work. It does **not** own
**routing**: the route table, the redirect, `?from=` destination preservation and
`errorBuilder` are `frontend/go-router` — this layer's obligation ends at handing that layer
a validated location string. It does **not** own **session state**: `SessionState`, the token
store and the sign-out teardown sequence are `auth/flutter-session` — §7 below specifies what
the push step of that teardown must do and where in the order it must sit, and nothing more.
Local persistence is `storage/flutter-local`; the in-app banner widget is
`frontend/flutter-ui`; log and analytics emission is `logging/flutter-observability`;
`Dio` and error mapping are `api-style/dio`.

**Version.** Targets `firebase_messaging` 15+ (`RemoteMessage`, `FirebaseMessaging.onMessage`,
`FirebaseMessaging.onBackgroundMessage`, `NotificationSettings`), `flutter_local_notifications`
17+ (`AndroidNotificationChannel`, `AndroidFlutterLocalNotificationsPlugin`) and `workmanager`
0.5+. If a detail below disagrees with the versions pinned in `pubspec.yaml`, the pubspec wins.

| § | Concern |
|---|---|
| 1 | Three delivery states, three handlers |
| 2 | Initialization order — what must exist before the first message |
| 3 | The background handler runs in its own isolate |
| 4 | The payload contract — a location, not a screen name |
| 5 | Deferring a tap until the app can act on it |
| 6 | Permission — asked in context, not on first launch |
| 7 | The token lifecycle — register, refresh, delete |
| 8 | Android channels — created once, immutable afterwards |
| 9 | Foreground — the OS shows nothing by default |
| 10 | Content assumes a lock screen |
| 11 | Category preferences are server state |
| 12 | Background work is opportunistic |
| 13 | Testing push |
| 14 | Never |

---

## 1. Three delivery states, three handlers

**Rule: a message can arrive in three process states, and each needs its own registration.
Wiring one and testing it is how the other two ship broken.**

| Process state | Delivery | Tap | What exists |
|---|---|---|---|
| **Foreground** — app visible | `FirebaseMessaging.onMessage` | n/a — nothing is shown unless you show it | Everything: providers, router, session |
| **Background** — app alive, not visible | Data messages wake the background handler; the OS draws the tray notification | `FirebaseMessaging.onMessageOpenedApp` | Everything, on resume |
| **Terminated** — process not running | The background handler runs in a fresh isolate | `FirebaseMessaging.instance.getInitialMessage()` at next launch | Almost nothing, in the handler |

Two facts about that table do most of the damage when they are not known:

- **`onMessageOpenedApp` fires on the tap, not on delivery.** A message that arrives while
  the app is backgrounded and is never tapped never reaches your Dart code through this
  stream. It is not a delivery callback and cannot be used to count deliveries, mark
  something read, or refresh a badge.
- **`getInitialMessage()` returns non-null exactly once,** for the notification that caused
  this launch. Call it a second time and it is null. It is the *only* way to learn that the
  app was opened from a notification while terminated, and it is the case teams skip because
  a debug build attached to the IDE is never terminated.

```dart
// lib/features/notifications/application/push_service.dart
Future<void> registerHandlers() async {
  // 1. Foreground. The OS shows nothing here — see §9.
  _onMessage = FirebaseMessaging.onMessage.listen(_showForeground);

  // 2. Backgrounded, then tapped.
  _onOpened = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

  // 3. Terminated, then tapped. Exactly one message, exactly once.
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) _handleTap(initial);
}
```

`_handleTap` is one function for both tap paths (§4). Two copies drift, and the terminated
copy is the one nobody exercises.

The fourth registration — the top-level background handler — is not in this method, because
it cannot be. It is §3.

---

## 2. Initialization order — what must exist before the first message

**Rule: the background handler is registered in `main()`, before `runApp`, immediately after
Firebase is initialized. The tap handlers are registered after the router exists.**

```dart
// lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Must be registered before runApp. The plugin hands this to the platform
  // side at registration; a message arriving before it is registered is lost.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: App()));
}
```

`FirebaseMessaging.onBackgroundMessage` is a **static** function on the class. It is not a
method on `FirebaseMessaging.instance`, and reaching for it there is the first thing an IDE
autocomplete will suggest, because everything else on this API is an instance member.

| Registration | Where | Why there |
|---|---|---|
| `onBackgroundMessage` | `main()`, before `runApp` | The platform side needs the entry point before a message can arrive |
| `onMessage`, `onMessageOpenedApp` | A service created once the app is running | They need the router and providers |
| `getInitialMessage()` | After the router is built (§5) | `router.go` before `MaterialApp.router` exists throws |
| Channel creation (§8) | App start, before the first notification is posted | A notification naming a channel that does not exist is silently dropped on Android 8+ |
| `requestPermission()` (§6) | Never at start. In context, at the moment the value is obvious | One prompt per install on iOS |

---

## 3. The background handler runs in its own isolate

**Rule: the background handler is a top-level function (or a static method) annotated
`@pragma('vm:entry-point')`, and it initializes every dependency it uses.**

```dart
// lib/features/notifications/application/push_background_handler.dart

/// Runs in a background isolate with no shared memory. Nothing this file
/// touches is the same object the UI isolate is using.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Its own Firebase app. The UI isolate's initialization did not happen here.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Keep it small, keep it fast, and keep it independent of app state.
  await _appendToOutbox(message);
}
```

Three things the annotation and the isolate imply, in order of how often they are missed:

**`@pragma('vm:entry-point')` is load-bearing in release builds only.** Dart's tree shaker
removes code with no reachable call site, and the only caller of this function is the native
side — which the compiler cannot see. Without the annotation, debug works, profile works, and
the release build silently does nothing when a message arrives in the background. It must
also be top-level or static: a closure or an instance method has no address the engine can
resolve.

**There are no providers, no router, no session, no `BuildContext`.** A second isolate has its
own memory. `ref.read(...)` here reads a `ProviderContainer` that does not exist in this
isolate; a global set during app start is at its default value; the singleton the UI holds is
a different object. Anything the handler needs, it constructs.

**Anything needing app state is deferred, not forced.** The handler writes a durable record;
the UI isolate picks it up at next launch or next resume.

```dart
// ✅ deferred: a row in a store, drained by the app when it next runs
Future<void> _appendToOutbox(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getStringList('push.pending') ?? <String>[];
  pending.add(jsonEncode({
    'id': message.messageId,          // dedupe key, see §12
    'route': message.data['route'],
    'at': DateTime.now().toUtc().toIso8601String(),
  }));
  await prefs.setStringList('push.pending', pending);
}
```

```dart
// ❌ every line of this is a no-op or a crash in the background isolate
@pragma('vm:entry-point')
Future<void> handler(RemoteMessage message) async {
  ref.read(badgeProvider.notifier).increment();   // no container here
  router.go(message.data['route']!);              // no router, no UI
  navigatorKey.currentState!.pushNamed('/inbox'); // null in this isolate
}
```

| Safe in the background isolate | Not safe |
|---|---|
| `Firebase.initializeApp()` and a fresh Firebase client | The UI isolate's providers or singletons |
| A plain HTTP call with credentials read from storage | `Dio` configured with the app's interceptors |
| Writing to `SharedPreferences` or a database opened here | Anything holding a `BuildContext` |
| Showing a local notification via a locally initialized plugin | Navigation of any kind |

**Budget it.** The OS gives a background wake-up seconds, not minutes, and kills the isolate
when the future completes. Long work belongs in §12's scheduler, triggered by the message,
not done inside the handler.

**iOS only wakes it for `content-available`.** On Android a data message wakes the handler;
on iOS the APNs payload must carry `"content-available": true` with `apns-priority: 5`, and
even then the system throttles it hard and may not deliver it at all when the user has force
quit the app or the device is in Low Power Mode. Design for it not running (§12).

---

## 4. The payload contract — a location, not a screen name

**Rule: the data payload carries a route *location*. The handler validates it and hands it to
the router. It never names a screen and never switches on a name.**

```jsonc
// Server side. `notification` is what the OS draws; `data` is what the app acts on.
{
  "notification": { "title": "New message", "body": "You have a new message" },
  "data": {
    "route": "/programs/42/messages",
    "category": "messages",
    "id": "msg_8831"
  },
  "android": { "priority": "high", "notification": { "channel_id": "messages_v2" } },
  "apns": { "headers": { "apns-priority": "10" } }
}
```

```dart
void _handleTap(RemoteMessage message) {
  final location = message.data['route'];
  // The payload is attacker-adjacent input: anything with your server key can
  // send it, and a truncated or stale value must not navigate anywhere.
  if (location == null || !location.startsWith('/')) return;
  router.go(location);
}
```

That single `go` is what makes the whole thing work, and the reasons are all in
`frontend/go-router` rather than here — the route table's redirect runs, so a tap while
signed out lands on sign-in with the destination remembered and continues to it after
sign-in; a location for a deleted resource lands on the not-found screen; the screen is
restorable after process death because it has a URL. This layer's only job is to hand that
layer a string that starts with `/`.

The alternative — a payload naming a screen, and a `switch` in the handler mapping names to
screens — is a second implementation of the route table maintained by hand in a different
repository from the first (the server writes the names). It drifts on the first rename,
it usually reaches for imperative navigation and therefore skips the authorization redirect
entirely, and the screen it produces has no URL.

| Payload key | Purpose | Rule |
|---|---|---|
| `route` | Where a tap goes | Must start with `/`. Validated before use, every time |
| `category` | Which product category this is (§11) | Used for analytics and channel selection, never to drop the message |
| `id` | The entity, for prefetch and dedupe | Never the only source — the screen fetches by the route's own path parameter |
| `messageId` (from FCM) | Delivery dedupe | Set by FCM, not by you. See §12 |

**Never put content in `data` that the app then renders as truth.** The payload is a
notification, not an API response: it says *something happened at this location*, and the
screen fetches the current state. A payload carrying a full object renders yesterday's copy
if the user opens the notification tomorrow.

---

## 5. Deferring a tap until the app can act on it

**Rule: `getInitialMessage()` is read after the router exists, and a tap that arrives before
the session is known is held, not dropped.**

Two races, both of which show up as "the notification opens the home screen sometimes":

```dart
// lib/features/notifications/application/push_service.dart

/// Called once, from the first frame of the widget that owns the router —
/// not from main(), where `router.go` has nothing to go to yet.
Future<void> drainInitialMessage() async {
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial == null) return;
  _handleTap(initial);
}
```

The second race is authorization, and it is not this layer's to solve: the route table's
redirect returns "carry on" while the session is still restoring, so a `go` issued during
restore resolves correctly once it lands. That behaviour is specified in `frontend/go-router`
and `auth/flutter-session`; do not build a second waiting mechanism here that duplicates it.

The background isolate's outbox (§3) drains on the same trigger: read the pending list, act
on entries whose `id` has not been seen, clear it. That is the general shape of "the
background isolate could not do this, so it left a note".

---

## 6. Permission — asked in context, not on first launch

**Rule: the permission prompt appears at the moment the user has just expressed the intent
that needs it. Never on first launch, never behind a splash screen.**

On iOS the system prompt can be shown **once per install**. A user who declines it at a
moment when they have no idea what notifications this app would send has declined
permanently, and the only recovery is a trip to Settings that almost nobody makes. The prompt
is a one-shot resource; spend it on a screen where the answer is obviously yes — after the
user enables session reminders, after they join a program, after they send their first
message.

```dart
// lib/features/notifications/application/notification_permission.dart
Future<bool> requestInContext() async {
  final messaging = FirebaseMessaging.instance;

  final current = await messaging.getNotificationSettings();
  if (current.authorizationStatus == AuthorizationStatus.denied) {
    // iOS will not show the prompt again, and Android has hit "don't ask again".
    // The only path left is the OS settings screen — say so, then open it.
    return false;
  }

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false, // see the table below
  );

  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}
```

And when it is already denied, the in-app affordance is an explanation plus
`openAppSettings()` — an app cannot re-prompt, and a toggle that silently does nothing is
worse than one that explains why.

| `AuthorizationStatus` | Meaning | What the app does |
|---|---|---|
| `notDetermined` | Never asked | Ask, in context |
| `authorized` | Full delivery | Register the token (§7) |
| `provisional` | iOS quiet delivery, no prompt was shown | Register the token. Notifications land in Notification Center, silently |
| `denied` | Asked and refused, or "don't ask again" | Explain, offer `openAppSettings()`. Never re-prompt |

**Provisional authorization is the right default for a low-stakes category.** Requesting with
`provisional: true` shows no prompt at all: notifications are delivered quietly to
Notification Center with "Keep" / "Turn off" buttons on them, and the user promotes them to
full delivery from a real example rather than from a modal about a hypothetical. It costs
nothing to try — a user who taps "Keep" has granted more than most prompts win — and it
leaves the one-shot prompt unspent for a moment where it matters.

**Android 13 (API 33) added a runtime permission.** Below 33, notifications are granted at
install and there is no prompt. From 33, `POST_NOTIFICATIONS` must be declared in the
manifest and requested at runtime — `requestPermission()` triggers the system dialog, but
only if the declaration exists.

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Without that line the call returns `denied` on Android 13+ with no dialog and no error, on a
device that would have granted it. The symptom is "push works on my Pixel 6 and not on my
Pixel 8", which is an OS version difference, not a device difference.

| Platform | Behaviour |
|---|---|
| iOS | One prompt per install. `provisional` bypasses it. Recovery is Settings only |
| Android < 13 | Granted at install. No prompt exists |
| Android 13+ | Runtime `POST_NOTIFICATIONS`, manifest declaration required, two refusals is permanent |

---

## 7. The token lifecycle — register, refresh, delete

**Rule: the token is registered when a user signs in, re-registered when FCM rotates it, and
deleted from the device *and* unregistered on the server when the user signs out.**

The last clause is not housekeeping. A device token that outlives a session is addressed to a
*device*, while your backend has it filed against a *user*. When the next person signs in on
that tablet, the previous user's notifications arrive on it — with title and body rendered on
the lock screen, to someone who is not that user. That is a data disclosure with a UI, and it
is trivially reproducible on any shared or resold device.

```dart
// lib/features/notifications/application/push_token_registrar.dart
class PushTokenRegistrar {
  PushTokenRegistrar(this._messaging, this._api, this._ref);

  final FirebaseMessaging _messaging;
  final PushApi _api;
  final Ref _ref;
  StreamSubscription<String>? _refreshSub;

  /// Called when the session becomes SessionActive, after permission is granted.
  Future<void> register() async {
    final token = await _messaging.getToken();
    if (token == null) return;              // iOS before APNs registration lands
    await _api.registerDevice(token);

    // FCM rotates tokens on reinstall, restore, and at its own discretion.
    // The rotation must be attributed to whoever is signed in *now*.
    _refreshSub ??= _messaging.onTokenRefresh.listen((token) async {
      if (_ref.read(sessionProvider) is! SessionActive) return;
      await _api.registerDevice(token);
    });
  }

  /// One step of the sign-out teardown in `auth/flutter-session`.
  Future<void> unregister() async {
    await _refreshSub?.cancel();
    _refreshSub = null;

    final token = await _messaging.getToken();
    if (token != null) {
      // Server first, while the access token is still valid.
      await _api.unregisterDevice(token);
    }
    // Then invalidate it on the device, so the old token cannot be re-sent.
    await _messaging.deleteToken();
  }
}
```

**Both halves are required and they are not interchangeable.**

| Only `unregisterDevice` server-side | Only `deleteToken()` on device |
|---|---|
| The token stays valid; anything still holding it — a stale row, a queued job, a topic subscription — still delivers | Your backend keeps sending to a dead token, which FCM answers with `UNREGISTERED`, and nothing cleans up the row until someone reads the error |

**Ordering inside sign-out matters, and the sequence belongs to `auth/flutter-session`.**
`unregisterDevice` is an authenticated call, so it must run **before** the token store is
cleared. In that layer's teardown it is a step in the credentials/identity group, ahead of
`state = SessionNone(...)`, and like every other step it is best-effort: a failed unregister
logs and continues, because a device that cannot reach the network must still finish signing
out locally.

**Do not address users by subscribing the device to a per-user topic.** A topic subscription
lives on the device and is invisible to your backend: you cannot list it, audit it, or revoke
it server-side, and it survives sign-out unless the device happens to be online and running
your unsubscribe. Topics are for genuine broadcast — a release announcement, a region-wide
alert — where no user identity is involved.

**iOS: `getToken()` can return null.** Before APNs has handed the app its device token,
`getToken()` returns null rather than throwing. Register on `onTokenRefresh` as well as on
the initial read — that is why the subscription above is not conditional on the first read
succeeding — and never treat null as an error to report.

---

## 8. Android channels — created once, immutable afterwards

**Rule: every channel is created at app start, before any notification names it. After
creation, its importance, sound, vibration and lights belong to the user and cannot be
changed by the app — only replaced with a new channel.**

Android 8 moved notification behaviour from the notification to the channel and gave the user
final say over it. Calling `createNotificationChannel` again with the same id is not an error
and not a warning: the system matches on the id and applies only the **name, description and
group** from the new object. Importance, sound, vibration and lights are ignored on a channel
that already exists. The build succeeds, the code looks right, the channel's name updates —
which is why the change appears to have worked — and the notification is still silent.

```dart
// lib/features/notifications/application/notification_channels.dart
const messagesChannel = AndroidNotificationChannel(
  'messages_v2',                       // versioned id — see below
  'Messages',                          // shown verbatim in OS settings
  description: 'Someone sent you a message',
  importance: Importance.high,         // heads-up + sound
  sound: RawResourceAndroidNotificationSound('message_tone'),
);

Future<void> registerChannels(FlutterLocalNotificationsPlugin plugin) async {
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;

  await android.createNotificationChannel(messagesChannel);
}
```

**Changing a channel's behaviour means shipping a new channel and deleting the old one.**

```dart
// v1.5: reminders must be heads-up with a sound. v1.4 shipped them at
// default importance, and that channel can never be raised.
await android.createNotificationChannel(
  const AndroidNotificationChannel(
    'session_reminders_v2',
    'Session reminders',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('reminder'),
  ),
);

// Delete the superseded one, or the user sees two "Session reminders"
// rows in OS settings and toggles the wrong one.
await android.deleteNotificationChannel('session_reminders');
```

Two traps inside the replacement:

- **Deleting and recreating with the *same* id does not reset it.** Android retains a deleted
  channel's settings and restores them if an id is recreated, specifically to stop apps
  laundering a user's "silence this" decision through a delete. The new channel needs a new
  id. Versioning the id (`_v2`) makes the migration legible in review and in the OS settings
  screen.
- **Anything the user changed stays changed.** If a user muted `messages_v2`, it is muted.
  That is the feature. A product request to "make them louder again" is a request for a new
  channel, and shipping one repeatedly to overrule a user is what gets an app reported.

| Property | Set on | Changeable after creation |
|---|---|---|
| Importance (heads-up, sound, badge) | Channel | No — by the app. Yes — by the user |
| Sound, vibration pattern, lights | Channel | No — by the app |
| Channel name, description, group | Channel | Yes — this is the only part a re-create updates |
| Title, body, icon, colour, `visibility` | The individual notification | Yes, every time |

**A notification naming a channel that was never created is dropped silently on Android 8+.**
Server-sent payloads that set `android.notification.channel_id` must name a channel this
build creates. Declare a fallback in the manifest so a payload with no channel id, or one
naming a channel from a future release, still lands:

```xml
<meta-data
  android:name="com.google.firebase.messaging.default_notification_channel_id"
  android:value="general_v1" />
```

Channel **groups** are worth it once there are more than about four channels: they are the
difference between a settings screen the user can navigate and a list they give up on and
mute wholesale.

---

## 9. Foreground — the OS shows nothing by default

**Rule: a message arriving while the app is in the foreground displays nothing on Android
unless you display it. Decide per category whether it should be a tray notification, an in-app
banner, or nothing at all.**

`onMessage` gives you a `RemoteMessage` and no UI. On iOS the system banner can be turned on
with one call; on Android there is no equivalent and the notification must be posted locally.

```dart
// iOS: let the system draw its own banner while the app is open.
await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
  alert: true,
  badge: true,
  sound: true,
);
```

```dart
// Android: post it yourself, on a channel that exists (§8).
Future<void> _showForeground(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;      // data-only: handled, not displayed

  await _plugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        messagesChannel.id,
        messagesChannel.name,
        importance: Importance.high,
        visibility: NotificationVisibility.private,   // §10
      ),
    ),
    payload: jsonEncode(message.data),   // the tap goes through §4
  );
}
```

**Whether to show it at all is a product decision made per category, in one place.** A
message about the screen the user is already looking at should refresh that screen, not
interrupt it with a banner announcing what is already visible.

| Situation | Foreground behaviour |
|---|---|
| The user is on the screen the message is about | Refresh the data. No notification |
| The message is about somewhere else in the app | In-app banner, tappable, routing through §4 |
| The message needs the user to leave what they are doing | Tray notification, high-importance channel |
| Data-only message (no `notification` block) | Handle it. Show nothing |

The banner widget itself is `frontend/flutter-ui`; the routing of its tap is §4.

---

## 10. Content assumes a lock screen

**Rule: write every title and body as though it will be read by someone who is not the user,
over their shoulder, on a locked phone. No names, no amounts, no diagnoses, no message
bodies.**

A notification is rendered by the OS on the lock screen, mirrored to a watch, read aloud by a
car, and shown on a shared-desktop mirror. None of those surfaces authenticated anybody.

| Instead of | Send |
|---|---|
| "Aisha Khan sent you a message: can we move Thursday?" | "New message" |
| "Your test result for HIV is ready" | "A new result is available" |
| "Payment of £2,400 to Miller & Co failed" | "A payment needs your attention" |
| "Dr Okafor cancelled your 3pm appointment" | "An appointment changed" |

The identifying detail travels in `data` — which is never rendered — and the app fetches and
displays it *after* the user has unlocked the device and the session has been checked.

```jsonc
{
  "notification": { "title": "New message", "body": "You have a new message" },
  "data": { "route": "/programs/42/messages", "id": "msg_8831" }
}
```

Two mitigations for the cases where a generic body genuinely hurts engagement:

- **Android `visibility`.** `NotificationVisibility.private` shows the notification on a
  secure lock screen with its content replaced by the app name, and the full content once
  unlocked. `secret` hides it from the lock screen entirely. `public` is the default and
  shows everything — pick it deliberately, never by omission.
- **iOS notification service extension.** With `mutable-content: 1`, an extension can fetch
  and substitute the real content on the device before display. It is real work and it does
  not change the lock-screen exposure, so it buys personalisation, not privacy.

**This rule outranks a product request.** "Show the sender's name so people open it" is a
measurable uplift and a disclosure; the answer is a richer generic body ("New message in
Mathematics"), not a name.

---

## 11. Category preferences are server state

**Rule: a user's per-category opt-out is stored server-side and enforced before the message is
sent. The device never receives a message it then discards.**

Dropping a message on the device fails in every direction that matters:

- The background handler is not guaranteed to run, so the "drop" is not guaranteed to happen —
  but the OS has *already drawn the tray notification* for a message with a `notification`
  block, before any of your code sees it. There is nothing left to suppress.
- The preference then lives only on the device that set it, so the user's other device keeps
  notifying them.
- Sending to a user who opted out and discarding on arrival still consumes their attention on
  a locked screen, and still counts as sending for every compliance regime that cares.

```jsonc
// The device tells the server the preference; the server decides delivery.
PUT /me/notification-preferences
{ "messages": true, "reminders": true, "marketing": false }
```

The `category` key in the payload (§4) is for the client's own routing and analytics —
choosing a channel, choosing whether to show a foreground banner — not a gate.

| Layer | Owns |
|---|---|
| Server | Whether to send at all, per user, per category |
| Channel (§8) | How Android presents it, once sent — the user's own control |
| iOS notification settings | Whether iOS presents it, once sent — the user's own control |
| Client code | Nothing. It does not decide whether a delivered message counts |

The one legitimate client-side suppression is a **duplicate**: the same `messageId` seen
twice (§12).

---

## 12. Background work is opportunistic

**Rule: background execution is a hint the OS may ignore. Nothing the user can see may depend
on a background task having run.**

Doze, App Standby buckets, per-manufacturer battery managers, Low Power Mode, force-quit on
iOS, and an aggressive OEM task killer all suppress background work silently and none of them
report it. A device that has not been touched in two days may run nothing at all. Whatever
the task produces, the foreground path must be able to produce as well.

**Prefer a server-triggered silent push over a device-side schedule.** A schedule asks every
device to poll on the chance something changed; a push runs only when something did, arrives
promptly, and gives the server the record of what was sent to whom.

| Need | Mechanism |
|---|---|
| React to a server-side change | Silent push (`content-available` on iOS, data-only on Android) |
| Retry an upload the user started | `workmanager` one-off task with constraints |
| Keep a local cache warm | Refresh on app open. Optionally *also* a periodic task |
| Anything with a deadline the user is told about | The server. Not the device |

```dart
// lib/features/notifications/application/background_sync.dart

@pragma('vm:entry-point')   // §3 applies here too, for the same reason
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Idempotent: a cursor, not "everything since I last ran". Re-running with
    // the same cursor writes the same rows, and the OS *will* re-run this.
    final since = inputData?['since'] as String?;
    await SyncClient().pullSummary(since: since);

    // false asks the OS to retry with backoff; true means done.
    return Future.value(true);
  });
}

Future<void> scheduleSummarySync() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'progress-summary-sync',      // stable unique name — re-registering replaces
    'progressSummarySync',
    frequency: const Duration(hours: 1),   // a floor, never a promise
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );
}
```

**Four properties every background task needs:**

| Property | Why |
|---|---|
| **Declared constraints** | `Constraints(networkType: NetworkType.connected)` lets the OS schedule the task when it can succeed, instead of waking it to fail. A task that runs and fails still spent the battery |
| **Idempotent** | The OS retries on failure and may run a task twice. Every write is keyed — an upsert on `messageId`, a `since` cursor, a server-side idempotency key — so a second run changes nothing |
| **Resumable** | It can be killed mid-flight. Progress is committed incrementally; the next run continues from what was committed, not from the beginning |
| **Interval is a floor** | `Duration(minutes: 15)` is the platform minimum and even that is best-effort. A task registered hourly may run in three hours, or not today |

**Never a `Timer` for background work.** A timer lives in the app's isolate and stops the
moment the process is suspended, which is immediately after the user leaves the app. It works
perfectly on a device sitting in front of you with the app open, which is exactly why it
survives review.

**Verify on a real device with battery optimization on.** The emulator, and a physical device
with the app whitelisted from battery optimization, both run background work far more
reliably than a user's phone will. Test the way the app is actually installed: not
whitelisted, screen off, unplugged, overnight.

```bash
# Force Android into Doze and watch what still runs.
adb shell dumpsys deviceidle force-idle
adb shell dumpsys deviceidle unforce

# Inspect scheduled work.
adb shell dumpsys jobscheduler | grep -A 20 com.leapstar.app
```

---

## 13. Testing push

**Rule: every state in §1's table is exercised on a real device before the feature is done,
and the terminated state is exercised by actually terminating the app.**

A debug build attached to the IDE is never terminated: stopping it from the IDE detaches the
debugger rather than reproducing an OS kill, and hot restart re-runs `main()`, so
`getInitialMessage()` behaves nothing like it does in the field.

| State | How to get there |
|---|---|
| Foreground | App open. Send |
| Background | Home button, wait, send, then tap the notification |
| Terminated | Swipe the app away from the recents switcher, send, then tap |
| Terminated + signed out | Sign out first. The tap must land on sign-in and continue afterwards |
| Denied permission | Revoke in OS settings. The in-app affordance must explain, not silently fail |

```bash
# Data-only message to one device, via the v1 HTTP API.
curl -X POST "https://fcm.googleapis.com/v1/projects/$PROJECT/messages:send" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{"message":{"token":"'"$DEVICE_TOKEN"'",
       "data":{"route":"/programs/42/messages"},
       "android":{"priority":"high"},
       "apns":{"headers":{"apns-priority":"5"},
               "payload":{"aps":{"content-available":1}}}}}'
```

The unit-testable parts are the ones worth unit tests: the payload validator (a location that
does not start with `/` is rejected; a missing `route` is a no-op), the token registrar
(register on active session, unregister on sign-out, refresh attributed to the current user),
and the outbox drain (a duplicate `messageId` is applied once). The delivery itself is the
platform's and is verified on a device.

---

## 14. Never

- Never wire only `onMessage` and call push done. Three states, three registrations, plus the
  background handler.
- Never register the background handler as a closure, an instance method, or without
  `@pragma('vm:entry-point')` — release builds tree-shake it away and fail silently.
- Never reach for providers, the router, a navigator key, or any app singleton inside the
  background isolate.
- Never call `getInitialMessage()` before the router exists, and never call it twice expecting
  the same message.
- Never put a screen name in the payload, and never build a screen directly from payload
  fields — the location goes through the router.
- Never use a payload location without checking it starts with `/`.
- Never request notification permission on first launch or from a splash screen, and never
  re-prompt after a denial — open OS settings instead.
- Never ship Android 13+ without `POST_NOTIFICATIONS` in the manifest.
- Never expect `createNotificationChannel` to change an existing channel; never recreate a
  channel under its old id and expect its settings to reset.
- Never send a notification whose title or body names a person, an amount, or a condition.
- Never enforce a category opt-out on the device.
- Never address a specific user by subscribing their device to a per-user topic.
- Never register a push token without a matching sign-out path that unregisters it
  server-side and calls `deleteToken()`.
- Never use a `Timer` for background work, and never let a user-visible feature depend on a
  background task having run.
