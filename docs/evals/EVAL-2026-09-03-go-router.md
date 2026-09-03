# Eval Report — go-router
_Date: 2026-09-03_  _Version: 1_  _File: layers/frontend/go-router/go-router.eval.yaml_

Rules loaded (only these): `layers/frontend/go-router/SKILL.md`

## Summary
Cases: 6 | Passed: 6 | Failed: 0 | Overall: ✅ PASS

## Results
| Case | Name | Result | Failed assertions |
|---|---|---|---|
| go-router-01 | A detail route carries the id in the path, not the model object | ✅ PASS | — |
| go-router-02 | Authorization is a top-level redirect with refreshListenable, not a screen guard | ✅ PASS | — |
| go-router-03 | A guarded redirect returns the user to the destination they asked for | ✅ PASS | — |
| go-router-04 | assetlinks.json carries the Play app signing fingerprint, per flavor | ✅ PASS | — |
| go-router-05 | The Apple association file has no extension and uses components | ✅ PASS | — |
| go-router-06 | A notification tap goes through the route table, and unknown links land somewhere real | ✅ PASS | — |

## Failing Case Details

None.

---

## Appendix — generated output per case

### go-router-01 ✅
**Assertions:** must_contain `@TypedGoRoute` ✓, `:id` ✓, `required this.id` ✓ · must_not_contain `ProgramDetailScreen(program:` absent ✓, `as Program;` absent ✓ (only the nullable `as Program?` hint form is used)

```dart
// lib/core/router/app_router.dart
part 'app_router.g.dart';

@TypedGoRoute<ProgramRoute>(path: '/programs/:id')
class ProgramRoute extends GoRouteData with _$ProgramRoute {
  const ProgramRoute({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) => ProgramDetailScreen(
        id: id,
        hint: state.extra as Program?,
      );
}
```

```dart
// lib/features/programs/presentation/program_list_tile.dart
ListTile(
  onTap: () => ProgramRoute(id: program.id).push(context),
  title: Text(program.title),
);
```

```dart
// lib/features/programs/presentation/program_detail_screen.dart
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({required this.id, this.hint, super.key});

  final String id;
  final Program? hint; // render-ahead hint only, never the only copy

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider(id));
    return program.when(
      data: (value) => _Body(program: value),
      loading: () => hint == null ? const _Loading() : _Body(program: hint!),
      error: (error, stackTrace) => _Error(error: error),
    );
  }
}
```

### go-router-02 ✅
**Assertions:** must_contain `redirect:` ✓, `refreshListenable` ✓, `matchedLocation` ✓, `isRestoring` ✓ · must_not_contain `addPostFrameCallback` absent ✓, `StreamBuilder` absent ✓

```dart
// lib/core/router/app_router.dart
const _publicLocations = <String>{'/sign-in', '/legal', '/reset-password'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: $appRoutes,
    initialLocation: '/',
    refreshListenable: ref.watch(sessionProvider.notifier),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isPublic = _publicLocations.contains(location);

      // Pure and synchronous: no await, no fetch, no writes.
      if (session.isRestoring) return null;

      if (!session.isSignedIn) {
        if (isPublic) return null;
        return '/sign-in?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      if (location.startsWith('/admin') && !session.roles.contains('admin')) {
        return '/';
      }

      if (location == '/sign-in') return '/';

      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
});
```

### go-router-03 ✅
**Assertions:** must_contain `?from=` ✓, `Uri.encodeComponent` ✓, `queryParameters['from']` ✓, `startsWith('/')` ✓ · must_not_contain `context.pop()` absent ✓, `Navigator.pop` absent ✓

```dart
// lib/core/router/app_router.dart — the guarded branch of the top-level redirect
if (!session.isSignedIn && !_publicLocations.contains(state.matchedLocation)) {
  // state.uri keeps the whole destination, query string included:
  // /programs/42?tab=sessions
  return '/sign-in?from=${Uri.encodeComponent(state.uri.toString())}';
}
```

```dart
// lib/features/auth/presentation/sign_in_screen.dart
Future<void> _onSignInSucceeded(BuildContext context) async {
  final from = GoRouterState.of(context).uri.queryParameters['from'];

  // `from` is attacker-controlled; only app-relative locations are honoured,
  // otherwise an absolute https:// value is an open redirect.
  final destination = (from != null && from.startsWith('/')) ? from : '/';

  // go, not pop: a cold start from an email link has no back stack.
  context.go(destination);
}
```

### go-router-04 ✅
**Assertions:** must_contain `delegate_permission/common.handle_all_urls` ✓, `android_app` ✓, `com.leapstar.app.staging` ✓, `sha256_cert_fingerprints` ✓, `PLAY_APP_SIGNING_SHA256` ✓, `android:autoVerify="true"` ✓ · must_not_contain `UPLOAD_KEY` absent ✓, `upload-keystore` absent ✓

```jsonc
// web/staging/.well-known/assetlinks.json
// served at https://staging.leapstar.com/.well-known/assetlinks.json
// HTTPS, no redirect, no auth, Content-Type: application/json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.leapstar.app.staging",
      "sha256_cert_fingerprints": ["__PLAY_APP_SIGNING_SHA256__"]
    }
  }
]
```

`__PLAY_APP_SIGNING_SHA256__` is substituted by the deploy pipeline with the SHA-256 from
Play Console → App integrity → App signing key certificate for `com.leapstar.app.staging`.
That is the certificate Play re-signs with; the certificate in the repo is never on a device.

```xml
<!-- android/app/src/staging/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application>
    <activity android:name=".MainActivity">
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="staging.leapstar.com" />
      </intent-filter>
    </activity>
  </application>
</manifest>
```

### go-router-05 ✅
**Assertions:** must_contain `apple-app-site-association` ✓, `applinks` ✓, `appIDs` ✓, `ABCDE12345.com.leapstar.app.staging` ✓, `components` ✓, `exclude` ✓ · must_not_contain `apple-app-site-association.json` absent ✓, `NOT /admin` absent ✓

File path — no extension:
`web/staging/.well-known/apple-app-site-association`, served at
`https://staging.leapstar.com/.well-known/apple-app-site-association`
(HTTPS, no redirect, no auth, `Content-Type: application/json`).

```jsonc
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.leapstar.app.staging"],
        "components": [
          { "/": "/admin/*", "exclude": true, "comment": "admin stays on the web" },
          { "/": "/programs/*", "comment": "program deep links" },
          { "/": "/invites/*", "comment": "invite deep links" }
        ]
      }
    ]
  }
}
```

### go-router-06 ✅
**Assertions:** must_contain `data['route']` ✓, `startsWith('/')` ✓, `router.go(` ✓, `errorBuilder` ✓, `NotFoundScreen` ✓ · must_not_contain `Navigator.push` absent ✓, `MaterialPageRoute` absent ✓

```dart
// lib/core/notifications/notification_router.dart
void handleNotificationTap(RemoteMessage message) {
  final route = message.data['route'];

  // The payload is untrusted: only an app-relative location is routable.
  if (route is! String || !route.startsWith('/')) return;

  // Through the table, so the top-level redirect still applies: a tap while
  // signed out lands on /sign-in?from=... and arrives here after sign-in.
  router.go(route);
}
```

```dart
// lib/core/router/app_router.dart
final router = GoRouter(
  routes: $appRoutes,
  errorBuilder: (context, state) => NotFoundScreen(location: state.uri.toString()),
);
```
