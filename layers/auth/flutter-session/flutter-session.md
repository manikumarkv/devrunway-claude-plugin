# Flutter Session, Biometrics and Payments Standards

Everything about *who the user is*: how that fact is represented, where the tokens live, how
they are refreshed and revalidated, what happens when they expire mid-task, how biometrics
gate re-entry, and how a purchase becomes an entitlement.

**Scope boundaries.** This layer owns session **state and tokens**. It does not own
**routing**: redirect logic, `GoRouter.refreshListenable`, guard placement and deep-link
restoration after sign-in are `frontend/go-router` — here the router is only ever a consumer
of `sessionProvider`. It does not own **secure-storage mechanics**: which package,
`IOSOptions`/`AndroidOptions`, accessibility constants, migration and the encrypted local
database are `storage/flutter-local` — here `TokenStore` is a contract with four methods. It
does not own **transport**: `Dio` construction, timeouts, retry, the `AppError` hierarchy and
error mapping are `api-style/dio`, which describes the same `AuthInterceptor` from the
transport side; this layer describes it from the session side — who is signed out, and when.
Provider lifetime rules are `state/riverpod`. Sign-in *UI* is `frontend/flutter-ui`. Log and
analytics emission — including the rule that a token never reaches a log line — is
`logging/flutter-observability`; this layer says only where the hook goes.

Sections are independent. Read the one you need.

| § | Concern |
|---|---|
| 1 | Three session states, never two |
| 2 | One writer: the session notifier |
| 3 | Token storage — the `TokenStore` contract |
| 4 | Refresh — single-flight, replay once, sign out on second failure |
| 5 | User-scoped providers dispose themselves |
| 6 | Sign-out — the complete teardown |
| 7 | Resume revalidation after a background gap |
| 8 | Expiry mid-task — re-authenticate in place |
| 9 | Biometrics |
| 10 | Payments |
| 11 | Never |

---

## 1. Three session states, never two

**Rule: session state is a `sealed class SessionState` with exactly three subclasses —
`SessionUnknown`, `SessionActive`, `SessionNone`. `SessionUnknown` is the value before secure
storage has been read, and it is the cold-start default.**

Two states is the default wrong answer and it produces a bug every signed-in user sees on
every cold start. Secure storage is asynchronous: reading the Keychain takes tens of
milliseconds, sometimes longer behind a first-unlock accessibility flag. A `bool isLoggedIn`
initialised to `false` is *lying* during that window, so the router guard redirects to
sign-in, the read completes, and the guard redirects back — a visible flash of the sign-in
screen at a user who never signed out. `SessionUnknown` says "I do not know yet", the guard
holds on the splash, and there is nothing to flash.

```dart
// lib/features/auth/domain/session_state.dart
sealed class SessionState {
  const SessionState();
}

/// Secure storage has not been read yet. The cold-start value.
/// The router holds on the splash screen; it does not redirect.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

/// A usable session. Carries the user, so no screen needs a second
/// "who am I" round trip, and the expiry, so refresh can be proactive.
final class SessionActive extends SessionState {
  const SessionActive({required this.user, required this.accessTokenExpiry});

  final AuthUser user;
  final DateTime accessTokenExpiry;

  bool get isExpired => DateTime.now().isAfter(accessTokenExpiry);
}

/// No session. Either never signed in, or signed out, or the refresh
/// token was rejected. [reason] is what the sign-in screen renders.
final class SessionNone extends SessionState {
  const SessionNone({this.reason = SignedOutReason.userInitiated});

  final SignedOutReason reason;
}

enum SignedOutReason { userInitiated, refreshRejected, revokedRemotely }
```

| State | Router does | UI shows |
|---|---|---|
| `SessionUnknown` | nothing — stays put | splash / the native launch screen |
| `SessionActive` | allows app routes; bounces `/sign-in` to home | the app |
| `SessionNone` | redirects to `/sign-in`, saving the intended location | sign-in, with `reason` if not user-initiated |

`SignedOutReason` exists because "you signed out" and "your session was revoked on another
device" are different messages, and a user who sees the first when the second happened files
a bug about being logged out at random.

**Do not add a fourth state for "refreshing".** A refresh in flight is still `SessionActive`;
the interceptor queues the requests. A `SessionRefreshing` state forces every consumer to
handle a transient it does not care about.

---

## 2. One writer: the session notifier

**Rule: exactly one notifier writes `SessionState`. Everything else reads it. Headers are
read from the token store at request time, never captured into a variable at sign-in.**

```dart
// lib/features/auth/application/session_notifier.dart
@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  SessionState build() {
    // Synchronous build so there is never a null hole; the async restore
    // below flips Unknown -> Active/None when storage answers.
    unawaited(_restore());
    return const SessionUnknown();
  }

  Future<void> _restore() async {
    final store = ref.read(tokenStoreProvider);
    final tokens = await store.read();
    if (tokens == null) {
      state = const SessionNone();
      return;
    }
    // A stored access token that already expired is not a signed-out user —
    // the refresh token is usually still good. Let the first request refresh.
    state = SessionActive(
      user: tokens.user,
      accessTokenExpiry: tokens.accessTokenExpiry,
    );
  }

  Future<void> signIn(Credentials credentials) async { /* ... */ }

  Future<void> signOut({
    SignedOutReason reason = SignedOutReason.userInitiated,
  }) async { /* §6 */ }
}
```

Two consequences worth stating explicitly:

- **No screen writes session state.** A sign-in screen calls `signIn`; it does not assign
  `state`. A 401 handler calls `signOut`; it does not assign `state`.
- **No component caches the access token.** Not `dio.options.headers`, not a
  `String? _token` field with a setter, not a captured closure. It is read from the
  `TokenStore` inside `onRequest`, per request (see `api-style/dio` §4.1). A cached header is
  stale after the first refresh and, worse, survives sign-out — so the next user's first
  request carries the previous user's credentials.

---

## 3. Token storage — the `TokenStore` contract

**Rule: tokens live in platform secure storage — iOS Keychain, Android Keystore-backed
`EncryptedSharedPreferences`. Never `SharedPreferences`, never a row in the app database,
never a file in the documents directory.**

`SharedPreferences` is a plaintext plist / XML file. On a rooted or jailbroken device, on a
device with an unencrypted backup, and in any `adb backup` output, it is readable. A DB row is
worse: it is also copied by every "export my data" and analytics-of-local-DB feature someone
adds later.

The contract this layer depends on — the implementation, package choice and platform options
are `storage/flutter-local`:

```dart
// lib/features/auth/domain/token_store.dart
abstract interface class TokenStore {
  Future<StoredTokens?> read();
  Future<String?> readAccessToken();
  Future<void> save(StoredTokens tokens);
  Future<void> clear();
}
```

| Datum | Where |
|---|---|
| Access token, refresh token | Secure storage, via `TokenStore` |
| User id / display name for the shell UI | Secure storage alongside the tokens, or re-fetched |
| "Has the user completed onboarding" | `SharedPreferences` — not security-bearing, fine |
| "Is the user premium" | Server. Never local — see §10 |
| A biometric-gated secret | Secure storage under an access-control policy — §9.4 |

---

## 4. Refresh — single-flight, replay once, sign out on second failure

**Rule: one `QueuedInterceptor` owns refresh. N concurrent 401s await one refresh future,
each original request is replayed exactly once (guarded by `options.extra`), and a second
failure signs the user out rather than looping.**

Three distinct failures are being prevented, and they are worth separating because a fix for
one does not fix the others:

| Failure | Cause | Symptom |
|---|---|---|
| Refresh stampede | `InterceptorsWrapper`, which does not serialise | Ten 401s fire ten refreshes; the first rotates the token, the other nine present a dead one, the backend revokes the whole family, and the user is signed out *for having a fast connection* |
| Infinite loop | Replaying without a flag | The replay also 401s, which triggers a refresh, which replays… until the request tree exhausts memory or the backend rate-limits the device |
| Deadlock | Replaying through the same `Dio` | The replayed request re-enters the interceptor queue that is still blocked on the refresh; nothing ever completes and the UI spins forever |

```dart
// lib/core/network/auth_interceptor.dart
final class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required Dio refreshDio,
    required Future<void> Function(SignedOutReason) onSignOut,
  })  : _tokenStore = tokenStore,
        _refreshDio = refreshDio,
        _onSignOut = onSignOut;

  final TokenStore _tokenStore;

  /// A bare Dio: same baseUrl, no interceptors. Replaying or refreshing
  /// through the main Dio re-enters this queue and deadlocks.
  final Dio _refreshDio;
  final Future<void> Function(SignedOutReason) _onSignOut;

  static const String _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Read per request. Never a cached field, never dio.options.headers.
    final accessToken = await _tokenStore.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final alreadyRetried = options.extra[_retriedKey] == true;

    if (err.response?.statusCode != 401 || alreadyRetried) {
      // Not an auth failure, or the replay itself failed: stop here.
      handler.next(err);
      return;
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      await _onSignOut(SignedOutReason.refreshRejected);
      handler.next(err);
      return;
    }

    options.extra[_retriedKey] = true;
    final accessToken = await _tokenStore.readAccessToken();
    options.headers['Authorization'] = 'Bearer $accessToken';
    try {
      handler.resolve(await _refreshDio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refresh_token': tokens.refreshToken},
      );
      await _tokenStore.save(StoredTokens.fromJson(response.data!));
      return true;
    } on DioException catch (_) {
      await _tokenStore.clear();
      return false;
    }
  }
}
```

**Why `QueuedInterceptor` and not a `Completer` you manage yourself.** You can write correct
single-flight with a `Future<bool>? _inFlight` field, and if you are refreshing outside Dio
(a GraphQL link, a websocket handshake) you have to. Inside Dio, `QueuedInterceptor` already
serialises its handlers, so the second 401 does not even enter `onError` until the first has
called a handler — the queue *is* the lock, and a hand-rolled one on top is a second lock to
get wrong.

If you do need it outside Dio, the shape is:

```dart
Future<bool>? _inFlight;

Future<bool> refreshOnce() {
  // Everyone awaits the same future; the last one clears the field.
  return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
}
```

**Refresh failure is the one place a non-user-initiated sign-out is correct**, and it carries
`SignedOutReason.refreshRejected` so the sign-in screen can say "your session expired"
instead of nothing.

---

## 5. User-scoped providers dispose themselves

**Rule: every provider holding user-scoped data watches the session:
`ref.watch(sessionProvider)`. Sign-out then disposes the whole graph automatically. Do not
maintain a manual invalidation list.**

```dart
@riverpod
Future<List<Enrolment>> myEnrolments(Ref ref) async {
  // Watching the session makes this provider user-scoped by construction.
  final session = ref.watch(sessionProvider);
  if (session is! SessionActive) return const <Enrolment>[];

  return ref.watch(enrolmentRepositoryProvider).list(userId: session.user.id);
}
```

The alternative — a `signOut()` that calls `ref.invalidate(a); ref.invalidate(b); …` — is a
list that is correct on the day it is written and wrong the first time someone adds a
provider without updating it. The failure mode is the worst kind: user B signs in and sees
user A's data, in a screen nobody thought to check, and it looks like a backend bug.

The same argument applies to keeping a user id in a global: if a provider reads
`currentUserId` from anywhere but the session it watches, it has no reason to rebuild when
that user changes.

**`@Riverpod(keepAlive: true)` providers are the exception you must audit.** A keepAlive
provider that caches user data does not dispose on sign-out — either make it session-scoped
or clear it explicitly in §6's teardown.

---

## 6. Sign-out — the complete teardown

**Rule: sign-out clears everything user-scoped, in a fixed order, and only then sets
`SessionNone`. Clearing the token alone is not signing out.**

The token is the smallest part of what identifies the user on the device. What is left after
a token-only sign-out: their name in the profile cache, their rows in the local database,
their avatar in the image cache (visible in the app bar of the *next* user's session), their
API responses in the HTTP cache, and their id in analytics.

```dart
// lib/features/auth/application/session_notifier.dart
Future<void> signOut({
  SignedOutReason reason = SignedOutReason.userInitiated,
}) async {
  // 1. Revoke server-side first — best effort. If the device is offline we
  //    still clear locally; a token we cannot revoke is not a reason to
  //    leave the user signed in on a shared device.
  await _bestEffort('revoke', () => ref.read(authApiProvider).revoke());

  // 2. Credentials.
  await _bestEffort('tokens', () => ref.read(tokenStoreProvider).clear());
  await _bestEffort('biometric', () => ref.read(biometricSecretStoreProvider).clear());

  // 3. Local persistence. One method on the DB that drops every
  //    user-scoped table, so adding a table cannot silently skip this.
  await _bestEffort('db', () => ref.read(databaseProvider).clearUserScoped());

  // 4. Caches.
  await _bestEffort('http', () => ref.read(responseCacheProvider).clear());
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  await _bestEffort('files', () => DefaultCacheManager().emptyCache());

  // 5. Identity in third-party SDKs.
  await _bestEffort('analytics', () => ref.read(analyticsProvider).reset());
  await _bestEffort('push', () => ref.read(pushProvider).deleteToken());

  // 6. Only now. Every user-scoped provider watches this and disposes.
  state = SessionNone(reason: reason);
}

/// One failing step must not abandon the rest of the teardown — a half
/// signed-out device is worse than either end state.
Future<void> _bestEffort(String step, Future<void> Function() action) async {
  try {
    await action();
  } on Object catch (error, stackTrace) {
    ref.read(loggerProvider).warn('sign-out step "$step" failed', error, stackTrace);
  }
}
```

| Step | Skipping it means |
|---|---|
| `tokenStore.clear()` | The obvious one — the next launch restores the session |
| `biometricSecretStore.clear()` | Biometric unlock still opens the *previous* user's session |
| `database.clearUserScoped()` | The next user opens the app offline and reads user A's rows |
| `responseCache.clear()` | User B's first screen renders user A's cached JSON |
| `imageCache.clear()` + `clearLiveImages()` | User A's avatar renders in user B's app bar until eviction |
| `analytics.reset()` | User B's events are attributed to user A |
| `push.deleteToken()` | User A's notifications keep arriving on a device they gave away |

**`clear()` alone is not enough for the image cache.** `imageCache.clear()` drops the pending
and cached entries; `clearLiveImages()` drops the ones currently referenced by a live widget,
which is exactly the avatar on screen when the user tapped sign out.

**Order matters in one place:** `state = SessionNone(...)` is last. Set it first and the
provider graph tears down while the teardown code is still reading providers out of it, which
throws on a disposed container.

**Sign-out must not fail.** Every step is best-effort — a network revoke that times out, a
cache directory that is already gone. Wrap each so one failure cannot leave the user half
signed out; log the failure, continue the sequence.

---

## 7. Resume revalidation after a background gap

**Rule: on resume, revalidate the session only if the app was backgrounded longer than a
threshold. Record the timestamp on `AppLifecycleState.paused`, compare on
`AppLifecycleState.resumed`. Never poll on a `Timer.periodic`.**

An access token is valid until it expires *or until it is revoked* — a password change, an
admin action, a "sign out everywhere". Nothing pushes that to a backgrounded app. A device
resumed after two days holds a token the server rejected yesterday, and the user's next tap
gets a 401 instead of a clean re-auth.

Revalidating on *every* resume is the opposite failure: every app-switch, every notification
banner, every share sheet fires a request, which on a bad connection is a spinner on a screen
the user was already looking at.

```dart
// lib/core/lifecycle/session_lifecycle_observer.dart
class SessionLifecycleObserver with WidgetsBindingObserver {
  SessionLifecycleObserver(this._session);

  final Session _session;

  /// Long enough that app-switching is free; short enough that a revoked
  /// token does not survive a lunch break.
  static const Duration _revalidateAfter = Duration(minutes: 5);

  DateTime? _backgroundedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _backgroundedAt = DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) return;
        if (DateTime.now().difference(since) < _revalidateAfter) return;
        unawaited(_session.revalidate());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }
}
```

- Use **`paused`**, not `inactive`, as the "went away" signal. `inactive` fires for a pulled-
  down notification shade and for the iOS app switcher preview, so timing from it treats a
  glance at the clock as a background session.
- The observer **changes session state and nothing else.** It does not navigate, does not show
  a dialog, does not `context.go(...)`. The router reacts to `SessionNone` — that is
  `frontend/go-router`'s job, and a lifecycle callback has no reliable `BuildContext` anyway.
- `revalidate()` is a cheap authenticated call (`GET /me`). A 401 goes through the normal
  interceptor: it refreshes, and only a failed refresh signs out. Do not special-case it.
- Also revalidate on a foreground push that implies a permission change, and after the
  biometric lock is cleared.

---

## 8. Expiry mid-task — re-authenticate in place

**Rule: when a session expires while the user is working, re-authenticate over the current
screen and resume. Never navigate away from unsaved work.**

The default wrong answer pushes `/sign-in` as a route. The user was on step 4 of a 6-step
enrolment form; they sign back in, land on home, and every field they typed is gone. They do
not fill it in again.

```dart
// The lock/re-auth prompt is an overlay above the current route, not a route.
final entry = OverlayEntry(builder: (_) => const ReauthSheet());
Overlay.of(context, rootOverlay: true).insert(entry);
```

| Requirement | Why |
|---|---|
| Overlay, not a route | The route below stays mounted, so its form state, scroll position and controllers survive |
| `rootOverlay: true` | A nested navigator's overlay disappears with the tab, and the lock must cover the whole app |
| The in-flight request is retried, not dropped | The user's tap should complete after re-auth, not need repeating |
| Draft state persisted before the prompt | An overlay survives re-auth but not a process kill; a long form autosaves regardless |

The same overlay is the biometric lock (§9.5). One component, two triggers: session expired,
or the app resumed into a locked state.

---

## 9. Biometrics

### 9.1 What a biometric prompt actually proves

**Rule: biometrics gate access to a *stored secret*. A `true` from the plugin authenticates
nothing to your server.**

```dart
// ❌ The entire security model is a boolean in the app's own memory.
final ok = await auth.authenticate(localizedReason: 'Unlock');
if (ok) isLoggedIn = true;
```

`local_auth` returns a bool from the app's own process. A patched binary, a hooked method, an
emulator with a fake fingerprint HAL — all return `true`, and there is no server round trip
anywhere in that snippet to notice. The user is now "signed in" as someone else.

```dart
// ✅ The prompt unwraps a real credential. Without the OS releasing the
//    secret there is no refresh token, so there is no session to have.
final refreshToken = await biometricSecretStore.read(
  localizedReason: 'Unlock LeapStar',
);
if (refreshToken == null) return;              // cancelled or failed
await session.restoreFrom(refreshToken);       // the server decides
```

The security property comes from the *Keychain / Keystore access control policy*, which the
OS enforces outside your process, not from the bool. The bool is a UI signal.

### 9.2 Platform prerequisites — declare before the first call

**Rule: all three declarations are in place before the first `authenticate()` ships. Two of
them fail at runtime, not at build time, and one of those is a hard crash.**

| Platform | Declaration | Where | If missing |
|---|---|---|---|
| iOS | `NSFaceIDUsageDescription` (a real user-facing string) | `ios/Runner/Info.plist` | **Hard crash.** iOS terminates the app the first time Face ID is requested — release builds, App Review, every Face ID device |
| Android | `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>` | `android/app/src/main/AndroidManifest.xml` | The prompt never appears; `authenticate` fails with `notAvailable` |
| Android | `MainActivity` extends `FlutterFragmentActivity` | `MainActivity.kt` | `PlatformException` — `BiometricPrompt` requires a `FragmentActivity`, and Flutter's default `FlutterActivity` is not one |

```xml
<!-- ios/Runner/Info.plist -->
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to unlock LeapStar without typing your password.</string>
```

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

Touch ID needs no plist key, so a Touch-ID-only test device hides the iOS crash entirely.
Test biometric changes on a Face ID device or a Face ID simulator, every time.

### 9.3 The three-way availability check

**Rule: check all three before offering biometrics in settings, and again before prompting.
They answer different questions.**

```dart
Future<BiometricAvailability> check() async {
  final auth = LocalAuthentication();

  // 1. Does this hardware/OS support any biometric at all?
  if (!await auth.isDeviceSupported()) return BiometricAvailability.unsupported;

  // 2. Is biometry currently usable? False when locked out after too many
  //    failures, or when the user revoked the app's permission.
  if (!await auth.canCheckBiometrics) return BiometricAvailability.unavailable;

  // 3. Has the user actually enrolled a face or finger?
  final enrolled = await auth.getAvailableBiometrics();
  if (enrolled.isEmpty) return BiometricAvailability.notEnrolled;

  return BiometricAvailability.ready;
}
```

`canCheckBiometrics` alone is the common mistake: it is `true` on a device that supports
biometrics but has none enrolled, so the settings toggle appears, the user turns it on, and
the prompt fails on the next launch with no explanation.

The three answers need three different UI responses — hide the toggle, show it disabled with
"temporarily locked", and show it with "set up Face ID in Settings first".

### 9.4 Bind the secret to the current enrolment

**Rule: the biometric-gated secret is stored under an access-control policy bound to the
*current* enrolment set, so adding or removing a fingerprint invalidates it.**

Without this, an attacker with the device passcode adds their own fingerprint in Settings and
the app now unlocks for them — the stored refresh token was protected by "any enrolled
biometric", and they just enrolled one.

| Platform | Policy | Effect |
|---|---|---|
| iOS | `kSecAccessControlBiometryCurrentSet` (`biometryCurrentSet`) | The Keychain item is destroyed when the enrolment set changes |
| iOS (wrong) | `kSecAccessControlBiometryAny` (`biometryAny`) | Survives a new enrolment — the attack above works |
| Android | `KeyGenParameterSpec.Builder(...).setUserAuthenticationRequired(true).setInvalidatedByBiometricEnrollment(true)` | The Keystore key is permanently invalidated on enrolment change |

Invalidation is not an error state to hide. It is *the feature working*: catch the resulting
`KeyPermanentlyInvalidatedException` / `errSecItemNotFound`, clear the local secret, and fall
back to a full sign-in with "biometric unlock was reset because your Face ID or fingerprints
changed."

Store the **refresh token**, not the password and not the access token. A refresh token is
already revocable server-side, which is what makes losing the device recoverable.

### 9.5 Always offer a device-credential fallback

**Rule: `AuthenticationOptions(biometricOnly: false, stickyAuth: true, useErrorDialogs:
true)`.**

```dart
final ok = await LocalAuthentication().authenticate(
  localizedReason: 'Unlock LeapStar to see your enrolments',
  options: const AuthenticationOptions(
    biometricOnly: false,   // passcode/PIN/pattern fallback stays available
    stickyAuth: true,       // survives the app being backgrounded by the prompt
    useErrorDialogs: true,  // the OS explains "not enrolled" better than you will
  ),
);
```

`biometricOnly: true` is the trap. A wet finger, a mask, a cut, a cracked front camera, a
temporary lockout after five failures — with no fallback the user is locked out of their own
account with no path forward except reinstalling. It also breaks accessibility for users who
cannot reliably present a biometric.

`localizedReason` is shown to the user by the OS. Write it as a sentence they understand, and
localise it — it is a user-facing string, not a log line.

### 9.6 The lock is an overlay, not a route

**Rule: the biometric lock is an `Overlay` entry above the current route (§8), inserted when
the app resumes into a locked state, removed when it clears.**

A lock pushed as a route rebuilds the stack underneath, so unlocking lands the user on home
instead of the screen they left. It is also bypassable by a deep link that pushes a route on
top of it, and by the Android back button popping it.

| Requirement | Reason |
|---|---|
| `rootOverlay: true` | Covers nested navigators and tabs |
| Inserted on `paused`, not on `resumed` | The iOS app-switcher snapshot is taken as the app leaves; insert late and the snapshot shows the user's data |
| Blocks input beneath it | An `AbsorbPointer`/modal barrier, or a stray tap reaches the screen behind |
| No back-button dismissal | `PopScope(canPop: false)` |
| A "sign out" affordance | The fallback when biometry is permanently unavailable |

---

## 10. Payments

### 10.1 Store policy picks the rail — you do not

**Rule: digital goods and services consumed in the app go through in-app purchase. Physical
goods and services consumed outside the app must not.**

This is not a preference. Using a card processor for digital content gets the app rejected
under App Store Review 3.1.1 and the Play Payments policy; using IAP for physical goods gets
it rejected too, and Apple takes a 15–30% cut of a transaction it is not supposed to be in.

| Selling | Rail |
|---|---|
| Subscription, unlock, in-app currency, digital content | `in_app_purchase` (StoreKit / Play Billing) |
| Physical merchandise, shipped goods | Card / PSP (Stripe, etc.) — IAP is *not allowed* |
| Real-world services (a class, a delivery, a booking) | Card / PSP |
| Person-to-person payment, tips to another user | Card / PSP |
| Donations to a registered non-profit | Card / PSP |

Where a case is genuinely ambiguous, it is a product-and-legal decision recorded in an ADR,
not something the implementing developer decides in a service class.

### 10.2 The client never decides a purchase succeeded

**Rule: the store's callback is a *claim*. Send `verificationData.serverVerificationData` to
your backend, let it validate with Apple/Google and grant the entitlement, and only then call
`completePurchase`.**

A `PurchaseStatus.purchased` in the client is trivially forgeable — a patched binary, a
proxy, a jailbreak tweak whose entire purpose is returning it. Every entitlement decision
belongs to the server, which holds the receipt and the credentials to check it.

```dart
// lib/features/billing/application/purchase_controller.dart
void _listen() {
  _sub = InAppPurchase.instance.purchaseStream.listen(_onUpdates);
}

Future<void> _onUpdates(List<PurchaseDetails> purchases) async {
  for (final purchase in purchases) {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        state = const PurchaseState.pending();

      case PurchaseStatus.error:
        state = PurchaseState.failed(purchase.error);

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // The server validates the receipt and grants entitlement.
        final granted = await ref.read(billingApiProvider).verify(
              token: purchase.verificationData.serverVerificationData,
              productId: purchase.productID,
              platform: Platform.isIOS ? 'ios' : 'android',
            );
        if (!granted) {
          state = const PurchaseState.rejected();
          continue;   // `continue`, NOT `break`. `break` leaves the switch and
                      // falls into the completion block below, telling the store
                      // the goods were delivered for a purchase the server
                      // rejected: charged, no entitlement, and no replay.
        }
        ref.invalidate(entitlementProvider);   // re-read server state
        state = const PurchaseState.success();

      case PurchaseStatus.canceled:
        state = const PurchaseState.idle();
    }

    // Completing tells the store the goods were delivered. It must happen
    // after the server accepted, and it must always happen once it has.
    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }
}
```

Two ordering rules, both of which cause support tickets when broken:

- **Complete only after the server accepted.** Complete first and a failed verification loses
  the purchase — the store considers it delivered and will not replay it.
- **Always complete once it has.** An uncompleted iOS transaction is re-delivered on every
  launch forever; an unacknowledged Play purchase is **auto-refunded after three days**, so
  the user paid, got the feature, and then silently lost both.

**Entitlement is server state.** Read it from your API and cache it as data with a TTL. Never
`prefs.setBool('isPremium', true)` — that is a one-line jailbreak-free bypass, it does not
follow the user to a second device, and it does not notice a refund or a lapsed subscription.

Where the purchase is a subscription, the server also needs **App Store Server Notifications
V2 / Play Real-Time Developer Notifications** for renewals, cancellations and refunds. A
client that only learns about billing when the app is open cannot revoke on a chargeback.

### 10.3 Restore is a visible, working button

**Rule: a `restorePurchases()` affordance exists in settings, is reachable without an
account, and is tested on a real second device.**

```dart
Future<void> restore() async {
  state = const PurchaseState.pending();
  await InAppPurchase.instance.restorePurchases();
  // Restored purchases arrive on purchaseStream as PurchaseStatus.restored
  // and go through the same server verification as a new purchase.
}
```

Apple rejects apps with non-consumable or subscription IAP and no restore mechanism. The
functional reason matters more: a user on a new phone, or after a reinstall, otherwise has to
buy the thing twice, and the second charge is the one that becomes a refund request and a
one-star review.

Restored purchases go through the **same** server verification path. There is no shortcut
branch that trusts a restore more than a purchase.

### 10.4 Payments — never

- Grant an entitlement from a client-side `PurchaseStatus`.
- Store `isPremium` in `SharedPreferences` or any local flag as the source of truth.
- Call `completePurchase` before the server accepted the receipt.
- Skip `completePurchase` after it did.
- Ship a hardcoded price string — read it from `ProductDetails.price`, which is already
  localised and currency-correct.
- Use IAP for physical goods, or a card for digital ones.
- Forget the `purchaseStream` subscription is app-wide: subscribe in a `keepAlive` provider at
  startup, so a purchase that completes while the paywall is closed is still processed.

---

## 11. Never

- Two session states. `SessionUnknown` exists so the guard does not flash sign-in.
- A `bool isLoggedIn` anywhere, in any form, as session state.
- Tokens in `SharedPreferences`, in the app database, or in a file.
- A cached `Authorization` header on `dio.options` or in a mutable field.
- More than one writer of `SessionState`.
- `InterceptorsWrapper` for refresh, or a refresh per failed request.
- Replaying a request without an `options.extra` guard, or through the main `Dio`.
- A manual `ref.invalidate(...)` list at sign-out instead of `ref.watch(sessionProvider)`.
- A sign-out that clears the token and nothing else.
- Setting `SessionNone` before the teardown has run.
- `Timer.periodic` to check the session; or revalidating on every `resumed`.
- Navigating from a lifecycle observer or an interceptor.
- Pushing a sign-in route over unsaved work.
- Calling `authenticate()` before `NSFaceIDUsageDescription`, `USE_BIOMETRIC` and
  `FlutterFragmentActivity` are all in place.
- `if (ok) isLoggedIn = true` — the prompt must unwrap a secret.
- `biometricOnly: true`, or a biometric-gated secret bound to `biometryAny`.
- A biometric lock implemented as a route.
- A client-side entitlement decision.
