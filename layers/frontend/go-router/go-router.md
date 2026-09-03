# go_router Navigation Standards

The route table is the app's public API. Everything that can start the app from outside —
a deep link, a push notification, a marketing email, the OS restoring a killed process, an
integration test — enters through it, and can only reach what the table can express as a
URL. Almost every rule below is a consequence of that.

**Scope boundaries.** This layer covers the route table and the deep-link contract: route
shape, path parameters, `extra`, typed routes, the top-level redirect, `errorBuilder`, and
the two server-side well-known files. It does **not** cover screens — `Scaffold`, widget
composition, what a not-found screen looks like, loading and empty states are
`frontend/flutter-ui`; here a screen is only ever a constructor signature. It does **not**
own session state — sign-in, token refresh, the current user and role, and the
`Listenable`/stream the router listens to are `auth/flutter-session`; the router *reads*
that state and never mutates it. Providers that hold route-derived data are `state/riverpod`.
Widget and route tests are shared with `testing/flutter-test`.

**Version.** Targets go_router 14+ with `go_router_builder` for typed routes
(`GoRouteData` + the generated `_$Route` mixin, `TypedGoRoute`, `StatefulShellRoute`,
`state.matchedLocation`, `state.uri`). Older majors spell some of these differently
(`state.location`, `params`, no mixin). If a detail below disagrees with the version pinned
in `pubspec.yaml`, the pubspec wins — check it before assuming.

| § | Concern |
|---|---|
| 1 | The cold-start rule |
| 2 | The route table — one file, typed routes |
| 3 | Path parameters vs `extra` |
| 4 | Authorization: one redirect, one `refreshListenable` |
| 5 | Preserving the intended destination |
| 6 | `errorBuilder` — links are hostile input |
| 7 | External entry points: push, email, share |
| 8 | Shells, tabs and nested navigation |
| 9 | Android App Links — `assetlinks.json` |
| 10 | iOS Universal Links — `apple-app-site-association` |
| 11 | Serving and verifying both files |
| 12 | Testing routes |
| 13 | Never |

---

## 1. The cold-start rule

**Rule: every screen must be reachable from a cold start with nothing but a URL.**

This is not a deep-linking feature request. It is the single constraint that buys five
things at once, and every one of them is lost together the moment a screen depends on
having been pushed from somewhere:

| Capability | Why it needs URL-addressability |
|---|---|
| Deep links | The OS hands the app a `Uri` and nothing else |
| Push targets | The notification tap resumes into a location, with no back stack |
| Process-death restore | Android kills the app; the OS restores the *location*, not your objects |
| Web / PWA builds | The address bar is the only state |
| Tests and demos | `flutter run --route=/programs/42`, `GoRouter(initialLocation: …)` |

The test is mechanical, and it is worth actually running before a screen is considered
done:

```bash
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "https://app.leapstar.com/programs/42" com.leapstar.app

# iOS simulator
xcrun simctl openurl booted "https://app.leapstar.com/programs/42"

# No links wired yet? The router still answers:
flutter run --route=/programs/42
```

If the screen renders with real data, the route is correct. If it throws, renders empty,
or bounces to home, something on the path from URL to screen is carrying state the URL
does not contain — §3 is where that always turns out to be.

---

## 2. The route table — one file, typed routes

**Rule: one `GoRouter` for the app, declared in `lib/core/router/app_router.dart`. Route
paths appear in that file and nowhere else.**

A path string at a call site is a name with no compiler behind it. It survives a rename,
survives a parameter being added, and fails at runtime in front of the user — usually on
the one screen nobody re-tested.

**Rule: routes are generated with `go_router_builder`. Call sites use the generated route
objects, never an interpolated string.**

```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part 'app_router.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: <TypedGoRoute<GoRouteData>>[
    TypedGoRoute<ProgramsRoute>(
      path: 'programs',
      routes: <TypedGoRoute<GoRouteData>>[
        TypedGoRoute<ProgramRoute>(path: ':id'),
      ],
    ),
  ],
)
class HomeRoute extends GoRouteData with _$HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

class ProgramsRoute extends GoRouteData with _$ProgramsRoute {
  const ProgramsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ProgramsScreen();
}

class ProgramRoute extends GoRouteData with _$ProgramRoute {
  const ProgramRoute({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ProgramDetailScreen(id: id);
}
```

Call sites become type-checked:

```dart
// ✅ the compiler knows this route needs an id
ProgramRoute(id: program.id).push(context);

// ❌ a string that compiles whatever you type into it
context.push('/programs/${program.id}');
```

| Navigation intent | Use |
|---|---|
| Go to a place, replacing the branch | `ProgramRoute(id: x).go(context)` |
| Push on top, back button returns | `ProgramRoute(id: x).push(context)` |
| Replace current entry, no back | `ProgramRoute(id: x).pushReplacement(context)` |
| Programmatic, outside a widget | `router.go(ProgramRoute(id: x).location)` |

**Query parameters are for optional, non-identifying state** — filters, sort, tab index,
`?from=`. They are strings, and every reader must tolerate them being absent or garbage.
Anything the screen cannot render without belongs in the path.

---

## 3. Path parameters vs `extra`

**Rule: identity goes in the path; the screen fetches by that identity.**

```dart
// ✅ the URL contains everything the screen needs
class ProgramRoute extends GoRouteData with _$ProgramRoute {
  const ProgramRoute({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ProgramDetailScreen(id: id);
}

// The screen loads by id — same code path for a tap and for a deep link.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider(id));
    // …
  }
}
```

**Rule: `extra` is an optional render-ahead hint, never the only copy of anything.**

`extra` is an in-memory Dart object attached to a navigation call. It exists only when the
navigation happened inside the running app. It is not part of the URL, it is not
serialisable, and it does not survive:

| Entry | Is `extra` present? |
|---|---|
| In-app `push` / `go` that set it | Yes |
| Deep link / Universal Link | **No** |
| Notification tap | **No** |
| Process-death restore | **No** |
| Web reload, back/forward | **No** |
| `flutter run --route=…` | **No** |
| Widget test that starts at the location | **No** |

So:

```dart
// ❌ throws on every entry that is not an in-app push.
//    Crashlytics will show this as a top crash with no reproduction steps,
//    because the developer who wrote it only ever reached the screen by tapping.
final program = state.extra as Program;

// ✅ nullable, and only ever used to paint the first frame early
final Program? hint = state.extra as Program?;
```

The legitimate use is latency, not data flow: the list already holds the row, so the
detail screen can paint the title and hero image immediately while the full fetch runs.

```dart
class ProgramRoute extends GoRouteData with _$ProgramRoute {
  const ProgramRoute({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) => ProgramDetailScreen(
        id: id,
        // Optional. Absent for every external entry — the screen must not need it.
        placeholder: state.extra as Program?,
      );
}
```

**Rule: the screen's constructor must be satisfiable from the URL alone.** If
`ProgramDetailScreen` takes `required this.program`, the rule is already broken — no URL
can produce a `Program`, so the screen is unreachable from outside the app no matter what
the route table says.

| Data | Where it goes |
|---|---|
| Which entity (`id`, `slug`) | Path parameter |
| Optional filter, tab, sort | Query parameter |
| A full model already in memory | `extra`, nullable, as a hint |
| Large payloads, files, callbacks | Nowhere — put it in a provider keyed by the id |

Callbacks in `extra` deserve their own warning: a `VoidCallback onSaved` passed through
`extra` is null on restore and captures the pushing widget's `BuildContext`. Return a
result with `context.pop(value)`, or write to a provider the previous screen watches.

---

## 4. Authorization: one redirect, one `refreshListenable`

**Rule: authorization is a property of the route table, not of a screen.**

A screen-level guard is checked only when that screen builds. The route is still
reachable, still in the back stack, and its `initState` — the analytics event, the fetch,
the `ref.watch` that hits the API — has already run by the time the guard redirects.
Worse, the guard has to exist on every screen, and the one screen added next sprint is
the one that will not have it.

```dart
GoRouter buildRouter(Ref ref) {
  final session = ref.watch(sessionProvider.notifier);

  return GoRouter(
    routes: $appRoutes,                 // generated by go_router_builder
    refreshListenable: session,         // re-runs redirect on every auth change
    initialLocation: const HomeRoute().location,
    redirect: (context, state) {
      final auth = ref.read(sessionProvider);
      final location = state.matchedLocation;

      // 1. Never redirect while auth is still unknown — that races the splash
      //    and bounces a signed-in user to sign-in on every cold start.
      if (auth.isRestoring) return null;

      final isPublic = _publicLocations.any(
        (p) => location == p || location.startsWith('$p/'),
      );

      // 2. Signed out, private destination → sign-in, remembering where.
      if (!auth.isSignedIn && !isPublic) {
        return '/sign-in?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      // 3. Signed in, sitting on sign-in → forward to the intended target.
      if (auth.isSignedIn && location == '/sign-in') {
        return state.uri.queryParameters['from'] ?? const HomeRoute().location;
      }

      // 4. Role check, same table, same place.
      if (location.startsWith('/admin') && !auth.roles.contains('admin')) {
        return '/forbidden';
      }

      return null;                      // null means "carry on"
    },
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
  );
}

const _publicLocations = <String>['/sign-in', '/legal', '/reset-password'];
```

**Rule: `refreshListenable` is not optional.** Without it the redirect runs on navigation
only, so signing out from a settings screen leaves the user sitting on an authenticated
screen until they navigate. With it, the sign-out notifies, the redirect re-runs, and the
user lands on `/sign-in` immediately. Wrap a stream if that is what the session exposes:

```dart
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

**Four rules the code above encodes:**

1. `redirect` is **pure and synchronous**. No `await`, no network, no writes. It runs on
   every navigation and on every listenable tick; an async guard here deadlocks
   navigation or fires the same fetch dozens of times. Read state that is already loaded.
2. **Return `null` while auth is unknown.** The most common auth-routing bug is redirecting
   during token restore.
3. **One redirect, one file.** Per-route `redirect:` callbacks are permitted only for a
   rule that is genuinely local to that subtree, and even then the top-level redirect owns
   signed-in/signed-out.
4. **Never redirect to a location that redirects back.** go_router throws after a
   redirect limit; the public allowlist must include every destination the redirect can
   produce (`/sign-in`, `/forbidden`).

**Never do this:**

```dart
// ❌ guard inside the screen — the route is still reachable, initState already ran
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!ref.read(sessionProvider).isSignedIn) context.go('/sign-in');
  });
}

// ❌ StreamBuilder swapping the whole app — there is now no URL for anything,
//    and every deep link lands on whichever subtree the stream picked
StreamBuilder<User?>(
  stream: auth.userChanges(),
  builder: (c, snap) => snap.hasData ? const AppShell() : const SignInScreen(),
)
```

---

## 5. Preserving the intended destination

**Rule: a guarded redirect carries the destination with it and returns to it after
sign-in.**

A user taps a link to `/programs/42` in an email, is not signed in, signs in, and lands on
the home screen. The link is now lost — they have to find the email again. The fix is one
query parameter, and it must survive the whole round trip.

```dart
// In the redirect — encode the full URI, not just the path, so query
// parameters on the destination are not silently dropped.
return '/sign-in?from=${Uri.encodeComponent(state.uri.toString())}';
```

```dart
// In the sign-in screen, after a successful sign-in.
Future<void> _onSignedIn(BuildContext context) async {
  final from = GoRouterState.of(context).uri.queryParameters['from'];
  final target = (from != null && from.startsWith('/'))
      ? from
      : const HomeRoute().location;
  context.go(target);
}
```

| Detail | Why |
|---|---|
| `Uri.encodeComponent` on the way in | The destination has its own `?` and `&`; unencoded, they are parsed as sign-in's own parameters |
| Validate `from` starts with `/` on the way out | `from` is attacker-controlled — an absolute `https://…` value is an open-redirect handed to a phishing page |
| Fall back to the home *location*, not `'/'` literal | One source of truth for where home is |
| Do not `pop()` back | There is no back stack after a cold start from a link |

The redirect in §4 already handles the case where the session restores while the user is
sitting on `/sign-in` — rule 3 there reads the same `from`, so both paths converge.

---

## 6. `errorBuilder` — links are hostile input

**Rule: `errorBuilder` renders a real screen with a way out. Never leave the default.**

Everything reaching the router from outside is untrusted text: a truncated link in a chat
app, a link to a route deleted two releases ago, a scanner probing paths, an old email.
The default go_router error page shows a raw exception on a red background, which is a
crash to a user and an information leak to anyone probing.

```dart
errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
```

The not-found screen belongs to `frontend/flutter-ui`; from this layer it must:

- offer navigation home (`const HomeRoute().go(context)`), because after a cold start from
  a bad link there is nothing to pop to;
- not print `state.error` or the raw path back to the user;
- log the attempted location once, so a genuinely broken published link is visible in
  telemetry rather than inferred from support tickets.

Validation of path parameters is the route's job, not the screen's. An id is a string from
the URL — `/programs/%20` and `/programs/../admin` both arrive as strings. Where a
parameter must have a shape, check it in the route and treat a failure as not-found:

```dart
@override
Widget build(BuildContext context, GoRouterState state) {
  if (!_isValidId(id)) return NotFoundScreen(uri: state.uri);
  return ProgramDetailScreen(id: id);
}
```

Authorization still happens in the redirect (§4), not here — a 404-shaped response for a
resource the user may not see is a deliberate choice made in the API layer, not something
the router should improvise.

---

## 7. External entry points: push, email, share

**Rule: every external entry point carries a route *location*, resolved through the same
table.**

A push payload that carries `{"screen": "program", "programId": "42"}` requires a second,
hand-written mapping from payload to screen — which will drift from the route table, and
which usually reaches for `Navigator.push` and therefore bypasses the redirect in §4
entirely. A payload that carries a location needs no mapping at all.

```jsonc
// FCM data payload — server side
{
  "route": "/programs/42"
}
```

```dart
void _handleNotificationTap(RemoteMessage message) {
  final location = message.data['route'];
  if (location == null || !location.startsWith('/')) return; // ignore malformed
  router.go(location);
}
```

That single `go` runs the redirect, so a notification tapped while signed out routes to
sign-in with `?from=/programs/42` and lands correctly afterwards, and a notification for a
deleted program lands on the not-found screen instead of crashing.

| Entry point | Handler | Notes |
|---|---|---|
| Cold start from a link | go_router's own platform integration | Nothing to write; do not read the initial link yourself as well, or it navigates twice |
| Notification tap (background) | `FirebaseMessaging.onMessageOpenedApp` | `router.go(data['route'])` |
| Notification tap (terminated) | `getInitialMessage()` after the router exists | Guard against running before `MaterialApp.router` builds |
| In-app banner tap | Same handler | One code path |
| Share / branch link | Resolve to a location first, then `go` | Resolution belongs in the service, not the router |

**Never** build a screen directly from payload fields:

```dart
// ❌ bypasses redirect, bypasses errorBuilder, produces a screen with no URL,
//    and is the second implementation of the route table
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => ProgramDetailScreen(id: message.data['programId'])),
);
```

---

## 8. Shells, tabs and nested navigation

**Rule: a bottom-navigation shell is a `StatefulShellRoute`, and every tab's content has
its own URL.**

`StatefulShellRoute.indexedStack` keeps one `Navigator` per branch, so each tab keeps its
own stack and scroll position, and a deep link into a tab's third level restores that tab
with a real back stack.

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => AppScaffold(shell: shell),
  branches: [
    StatefulShellBranch(routes: [ /* /home … */ ]),
    StatefulShellBranch(routes: [ /* /programs, /programs/:id … */ ]),
    StatefulShellBranch(routes: [ /* /profile … */ ]),
  ],
)
```

| Symptom | Cause |
|---|---|
| Tab index kept in a `setState` and screens swapped in an `IndexedStack` | No URL per tab; nothing is deep-linkable |
| Tab loses its stack on switch | Plain `ShellRoute` instead of `StatefulShellRoute` |
| Deep link opens the right screen but the wrong tab is highlighted | Route is outside the branch it visually belongs to |

A modal that changes what the user is looking at — a full-screen editor, a filter sheet
the user can link to — is a route with `pageBuilder` and a dialog/fullscreen transition.
A transient sheet with no addressable content (a confirm dialog, an action sheet) is not a
route; `showModalBottomSheet` is correct there.

---

## 9. Android App Links — `assetlinks.json`

Android verifies an App Link by fetching
`https://<domain>/.well-known/assetlinks.json` and checking that it lists your package
name **and the SHA-256 of the certificate the installed APK is actually signed with**.

**Rule: `assetlinks.json` carries the Play app signing certificate fingerprint, not the
upload key fingerprint.**

This is the single most common cause of App Links failing to verify, and it fails
silently: links keep opening in the browser and nothing is logged. With Play App Signing
(mandatory for new apps), you sign the bundle with your *upload* key, Google verifies and
strips that signature, and Play **re-signs** the app with the *app signing* key before
distributing it. The certificate on the user's device is therefore never the upload key.

| Build | Certificate on device | Where the SHA-256 comes from |
|---|---|---|
| Play (production, internal testing, closed/open tracks) | **App signing key** | Play Console → Test and release → Setup → App integrity → App signing key certificate |
| A locally built release APK sideloaded for QA | Upload/release keystore | `keytool -list -v -keystore …` |
| `flutter run` debug | Debug keystore | `keytool -list -v -keystore ~/.android/debug.keystore` |

All of the fingerprints you need can be listed at once, and should be — an app link that
verifies on Play but not on the QA sideload wastes a day of triage.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.leapstar.app.staging",
      "sha256_cert_fingerprints": [
        "PLAY_APP_SIGNING_SHA256",
        "QA_RELEASE_KEYSTORE_SHA256"
      ]
    }
  }
]
```

**Rule: in a checked-in template, the placeholder names the *source* of the fingerprint —
`PLAY_APP_SIGNING_SHA256` — and the deploy step substitutes the value.** One 95-character
hex string is indistinguishable from another in review; naming the source at the point of
use is the only form a reviewer can actually check. Never paste an upload-key fingerprint
into this file, and never leave a generic `YOUR_SHA256_HERE`.

**Rule: one file per flavor domain, with that flavor's `applicationId`.** Flavors have
different application ids (`com.leapstar.app`, `com.leapstar.app.staging`) and usually
different domains. A staging file listing the production package name verifies nothing.
If two apps share a domain, the array holds two objects.

The manifest side, per flavor:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="staging.leapstar.com" />
</intent-filter>
```

Without `android:autoVerify="true"` the link opens a disambiguation dialog instead of the
app. With it, but with a mismatched fingerprint, the link opens the browser and the app is
never offered.

---

## 10. iOS Universal Links — `apple-app-site-association`

**Rule: the file is named `apple-app-site-association`, with no extension.**

`apple-app-site-association.json` is not fetched, and — like the Android case — nothing
reports the error; links simply open Safari. Serve it from `/.well-known/` with
`Content-Type: application/json`.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.leapstar.app.staging"],
        "components": [
          { "/": "/programs/*", "comment": "Program detail" },
          { "/": "/invites/*", "comment": "Invite acceptance" },
          { "/": "/admin/*", "exclude": true, "comment": "Web only" }
        ]
      }
    ]
  }
}
```

| Element | Rule |
|---|---|
| `appIDs` | `<TeamID>.<bundleId>`, one entry per flavor bundle id served by this domain. `appIDs` (plural) replaces the old single `appID` |
| `components` | Use `components`, not the legacy flat `paths` array; it supports query and fragment matching and `exclude` |
| `exclude: true` | The way to keep a path web-only. There is no negation syntax in the path string |
| Team ID | Apple Developer → Membership. Not the bundle id prefix, which is unrelated |

The app side: the Associated Domains capability with `applinks:staging.leapstar.com` in
the entitlements for that flavor. The entitlement domain, the AASA host and the bundle id
in `appIDs` must all describe the same app; one mismatch and the link is a browser link.

iOS caches the AASA aggressively — via Apple's CDN for App Store builds, and per-install
for development. After changing the file, delete and reinstall the app to retest. A stale
CDN copy is why "it worked yesterday" and why a fix appears not to have landed.

---

## 11. Serving and verifying both files

**Rule: both files are served over HTTPS, with no redirect, no authentication, no
user-agent sniffing, and `Content-Type: application/json`.**

| Requirement | Failure mode when missed |
|---|---|
| HTTPS with a valid, non-self-signed chain | Verification fails; no user-visible error |
| **No redirect**, including `http→https` and `www→apex` and a trailing-slash rewrite | Both platforms treat a 3xx as failure. Serve on *every* host you claim |
| No auth, no Cloudflare challenge, no geo-block, no robots gate | The fetcher is not a browser and will not solve a challenge |
| `application/json` | iOS rejects `text/plain`; some Android versions do too |
| No BOM, no trailing comma, no comment syntax | Both parse strictly |
| A real page behind every deep-linkable path | A link that 404s on the web is a broken link for every user without the app, and for previews in chat apps |

That last row is a product rule, not a technical one, and it is the one most often
skipped: `/programs/42` must render something meaningful for a signed-out browser user,
because that is what a shared link looks like to everyone who does not have the app.

Verification, worth putting in CI as a smoke test per environment:

```bash
# Must be 200, application/json, and no redirect (-L omitted deliberately).
curl -sSI https://staging.leapstar.com/.well-known/assetlinks.json
curl -sSI https://staging.leapstar.com/.well-known/apple-app-site-association

# Android's own verifier, on a connected device (API 31+):
adb shell pm verify-app-links --re-verify com.leapstar.app.staging
adb shell pm get-app-links com.leapstar.app.staging   # expect: verified
```

If `get-app-links` reports anything other than `verified`, the fingerprint is the first
thing to check — and in practice it is the upload key nine times out of ten.

---

## 12. Testing routes

**Rule: a route test starts at a location, never at a widget.** Starting at the widget
tests the screen; starting at the location tests the thing that actually breaks.

```dart
testWidgets('a deep link to a program renders it without any in-app navigation',
    (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [programRepositoryProvider.overrideWithValue(FakeRepo())],
      child: MaterialApp.router(
        routerConfig: buildRouter(initialLocation: '/programs/42'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(ProgramDetailScreen), findsOneWidget);
});
```

Three tests worth having per guarded area:

| Test | Asserts |
|---|---|
| Signed out, private location | Lands on `/sign-in?from=…` with the destination encoded |
| Sign-in completes with `from` set | Lands on the original destination, not home |
| Unknown location | Renders the not-found screen, does not throw |

---

## 13. Never

- Never `state.extra as X` with a non-nullable cast.
- Never a screen constructor that requires a model object a URL cannot produce.
- Never an interpolated path string at a call site once typed routes exist.
- Never an auth check in a screen's `build` or `initState`, and never a top-level
  `StreamBuilder` that swaps the app based on auth.
- Never an `async` top-level `redirect`, and never a redirect that runs while auth state is
  still restoring.
- Never redirect to a location that is not in the public allowlist.
- Never send a signed-in user "home" after sign-in when a `from` destination exists, and
  never `go` to a `from` value that does not start with `/`.
- Never leave the default `errorBuilder`.
- Never `Navigator.push` a screen built from a notification payload.
- Never put the upload-key fingerprint in `assetlinks.json`, and never add `.json` to
  `apple-app-site-association`.
- Never serve either well-known file through a redirect.
