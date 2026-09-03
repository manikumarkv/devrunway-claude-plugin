# Flutter Observability Standards

Everything the app says about itself at runtime: the logging facade and its redaction, the
crash reporter's context and the three channels that feed it, the analytics event catalogue
and the consent gate in front of it, and the feature flags — including the version gate —
that change behaviour without a release.

**Scope boundaries.** This layer does not define **error types**. The sealed `AppError`
hierarchy, `DioException` mapping, and the `isReportable` property that decides whether an
error is a crash or UI state all belong to `api-style/dio`; here we consume `isReportable`
and never re-derive it. It does not cover **crash triage as a practice** — reading
Crashlytics, deobfuscating a stack trace, setting an alert threshold, running a
crash-free-sessions target — that is the `/flutter-monitoring` command, which has no file
context to route on. Provider wiring for the logger, analytics service and flag store is
`state/riverpod`; the `NavigatorObserver` is *registered* by `frontend/go-router` and
*defined* here. Flavor and build-time configuration is `ci/flutter-release`. The
pseudonymous user id comes from `auth/flutter-session`; this layer only reads it.

Sections are independent. Read the one you need.

| § | Concern |
|---|---|
| 1 | One logging facade, injected |
| 2 | Levels, and what a release build does |
| 3 | `print` and `debugPrint` are both banned |
| 4 | Redaction lives in the facade |
| 5 | Crash reporter context and breadcrumbs |
| 6 | The three global error channels |
| 7 | What actually gets reported |
| 8 | Analytics events are a sealed set of types |
| 9 | Consent is checked before collection |
| 10 | Feature flags and the version gate |
| 11 | Testing observability |
| 12 | Common mistakes |
| 13 | Never |

---

## 1. One logging facade

**Rule: the app has exactly one logging abstraction, `AppLogger`, injected through a
provider. Nothing calls a logging package, a crash reporter, or the console directly.**

Two logging systems means there is no single place to raise a level, no single place to add
redaction, and no way to promise that a release build is quiet. The facade is also the seam
that makes logging assertable in a test — a `FakeLogger` records what the code claimed
happened.

```dart
// lib/core/observability/app_logger.dart
enum LogLevel { debug, info, warn, error }

/// The only logging surface in the app.
abstract interface class AppLogger {
  void debug(String message, {Map<String, Object?> fields});
  void info(String message, {Map<String, Object?> fields});
  void warn(String message, {Map<String, Object?> fields, Object? error, StackTrace? stackTrace});
  void error(
    String message, {
    required Object error,
    required StackTrace stackTrace,
    Map<String, Object?> fields,
  });

  /// Scoped child; `component` is attached to every record.
  AppLogger forComponent(String component);
}
```

**Rule: the message is a short human-readable constant; everything variable goes in
`fields`.**

```dart
// ✅ the message is greppable, the variables are structured and redactable
_log.info('Device registered', fields: {'endpoint': redactUri(uri), 'retry': attempt});

// ❌ nothing can redact this, and no two occurrences group together in a log search
_log.info('Registered device at $uri after $attempt retries');
```

A message built by interpolation defeats redaction (§4) completely: by the time the facade
sees the string, the secret is already inside it.

**Rule: the facade is taken from a provider, never constructed or reached for as a
singleton.**

```dart
// lib/core/observability/observability_providers.dart
@Riverpod(keepAlive: true)
AppLogger appLogger(Ref ref) => throw UnimplementedError('bound in bootstrap');

// In a feature:
final log = ref.read(appLoggerProvider).forComponent('enrolment');
```

An unbound provider that throws fails loudly at startup if the composition root forgot to
bind it, instead of silently writing to nowhere. Provider lifetime rules are
`state/riverpod`.

---

## 2. Levels, and what a release build does

**Rule: the minimum level is configuration, not a scatter of `if (kDebugMode)`.** One
threshold, set at bootstrap per flavor.

| Build | Minimum level | Console sink | Crash-reporter breadcrumb sink |
|---|---|---|---|
| debug | `debug` | ✓ | ✗ |
| profile | `info` | ✓ | ✓ |
| release | `warn` | ✗ | ✓ |

**Rule: a release build writes nothing to the device console.** Not for privacy theatre —
because `adb logcat` and the iOS unified log are readable by any app on a rooted device and
by anyone with a cable, and because a chatty release build costs measurable battery on the
log-writing thread.

```dart
// lib/core/observability/logger_impl.dart
final class CompositeLogger implements AppLogger {
  CompositeLogger({
    required LogLevel minimumLevel,
    required List<LogSink> sinks,
    Map<String, Object?> context = const {},
  })  : _minimumLevel = minimumLevel,
        _sinks = sinks,
        _context = context;

  final LogLevel _minimumLevel;
  final List<LogSink> _sinks;
  final Map<String, Object?> _context;

  void _emit(LogLevel level, String message, Map<String, Object?> fields,
      {Object? error, StackTrace? stackTrace}) {
    if (level.index < _minimumLevel.index) return;
    final record = LogRecord(
      level: level,
      message: message,
      // Redaction happens here, once, for every sink. See §4.
      fields: redact({..._context, ...fields}),
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now().toUtc(),
    );
    for (final sink in _sinks) {
      sink.write(record);
    }
  }
  // debug/info/warn/error delegate to _emit.
}
```

The sinks are the only place that knows about a concrete backend: `ConsoleSink` (debug and
profile only), `CrashReporterBreadcrumbSink`, and — if the product needs it — a remote sink.
Swapping Crashlytics for Sentry is a sink change, not an app-wide change.

**Rule: a `debug` call must be free when it is below the threshold.** If a field is
expensive to compute, guard the call site or pass a thunk — never build a 200-entry map on
every frame so that `_emit` can discard it.

---

## 3. `print` and `debugPrint` are both banned

**Rule: no `print`, no `debugPrint`, anywhere in `lib/`.**

`print` is the one everyone knows. `debugPrint` is the one that gets through review, because
the name says "debug" — but it is **not** compiled out of a release build. It writes to the
platform log in release exactly like `print`, only throttled. Every "temporary" `debugPrint`
of a response body is a release-build data leak.

**Rule: the analyzer enforces both, because a review will not.** `avoid_print` catches only
`print`.

```yaml
# analysis_options.yaml — `ci/flutter-release` owns this file; this is the observability slice
linter:
  rules:
    avoid_print: true

analyzer:
  errors:
    avoid_print: error
```

`debugPrint` needs a custom lint (`custom_lint` with a forbidden-identifier rule) or, at
minimum, a CI grep that fails the build:

```bash
! grep -rn --include='*.dart' -E '(^|[^A-Za-z0-9_])(print|debugPrint)\(' lib/
```

Also banned for the same reason: `log()` from `dart:developer` at a call site,
`stdout.writeln`, and `debugPrintStack`. Use the facade.

The one legal exception is inside `ConsoleSink`, which is constructed only in debug and
profile builds and is the single place the ban is lifted — with a comment saying so.

---

## 4. Redaction lives in the facade

**Rule: never log a credential, token, password, or full URI. The redaction runs inside the
facade so a call site cannot forget it.**

Redaction at the call site is redaction that will be skipped — by the developer in a hurry,
by the one who copied the line from another file, by the third who did not know the value
was sensitive. Putting it in `_emit` means every record, from every sink, is redacted once.

```dart
// lib/core/observability/redaction.dart

const _deniedKeySubstrings = <String>{
  'token', 'password', 'passwd', 'secret', 'authorization', 'auth',
  'apikey', 'api_key', 'cookie', 'session', 'signature', 'pin', 'otp',
  'email', 'phone', 'ssn', 'dob', 'address',
};

const _mask = '<redacted>';

/// Applied to every log record's fields. See CompositeLogger._emit.
Map<String, Object?> redact(Map<String, Object?> fields) {
  return fields.map((key, value) {
    final lower = key.toLowerCase();
    if (_deniedKeySubstrings.any(lower.contains)) {
      return MapEntry(key, _mask);
    }
    return MapEntry(key, _redactValue(value));
  });
}

Object? _redactValue(Object? value) => switch (value) {
      Uri() => redactUri(value),
      Map<String, Object?>() => redact(value),
      String() when _looksLikeJwt(value) => _mask,
      _ => value,
    };

bool _looksLikeJwt(String value) =>
    value.startsWith('ey') && value.split('.').length == 3;
```

**Rule: log the method and the path. Redact the query string — that is where emails,
referral codes and account identifiers travel.**

A URI looks harmless, which is why it is the most common leak in a mobile log. `GET
/v1/devices?userId=amelia@example.com&locale=en-GB` puts a real email address in the device
log and in every breadcrumb attached to every crash report for that session.

```dart
/// `POST /v1/devices?<redacted>` — never the query, never the host's credentials.
String redactUri(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?$_mask' : path;
}
```

Also redact path *segments* that are identifiers if your paths carry them and your log
retention is long: `/v1/users/8f1c…/orders` is pseudonymous, `/v1/users/amelia@example.com`
is not.

| Never logged | Instead |
|---|---|
| Access, refresh, FCM or CSRF token | The fact a token exists, and its expiry |
| `Authorization` header | Nothing; the interceptor is `api-style/dio` |
| Full request or response body | Status code, `redactUri`, byte length, duration |
| Email, phone, full name, address | The pseudonymous user id (§5) |
| Card number, even masked | The payment intent id |
| Full URI | `redactUri(uri)` |

**Rule: redaction is a deny-list *plus* a shape check, and the shape check is the one that
saves you.** A field named `deviceIdentifier` holding a JWT is not caught by the key
deny-list. `_looksLikeJwt` is.

---

## 5. Crash reporter context and breadcrumbs

**Rule: the crash reporter's context is set once, at bootstrap, and updated only when the
underlying value changes.** A crash report with no context costs an hour per triage; the
fields below are what turn "null check on null" into a reproducible bug.

```dart
// lib/core/observability/crash_context.dart
Future<void> installCrashContext(CrashReporter reporter, AppEnvironment env) async {
  await reporter.setCustomKey('flavor', env.flavor);            // dev | staging | prod
  await reporter.setCustomKey('app_version', env.version);      // 3.4.1
  await reporter.setCustomKey('build_number', env.buildNumber); // 2214
  await reporter.setCustomKey('device_locale', env.locale);
}
```

| Key | Set at | Why triage needs it |
|---|---|---|
| `flavor` | bootstrap | Staging crashes must not page anyone |
| `app_version`, `build_number` | bootstrap | "Fixed in 3.4.2" is unanswerable without it |
| `user_id` (pseudonymous) | sign-in / sign-out | Groups a user's crashes; supports "this one customer" |
| `route` | every navigation | The screen the crash happened on |
| breadcrumbs | every navigation + key actions | The path that got there |

**Rule: the user identifier is the pseudonymous id, never an email or a name.**

```dart
// On sign-in — the id is opaque and revocable; an email is neither.
await reporter.setUserIdentifier(session.userId);
// On sign-out:
await reporter.setUserIdentifier('');
```

An email in a crash reporter is personal data in a third-party US-hosted system, retained
for as long as the vendor keeps crashes, and it survives the user's deletion request.

**Rule: navigation is a breadcrumb, and the current route is a custom key.** One
`NavigatorObserver` does both, and it is the same class that emits screen-view analytics
(§8.4) — one observer, two sinks, so the two can never disagree about what screen the user
was on.

```dart
final class ObservabilityNavigatorObserver extends NavigatorObserver {
  ObservabilityNavigatorObserver(this._reporter, this._analytics, this._log);

  final CrashReporter _reporter;
  final AnalyticsService _analytics;
  final AppLogger _log;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(previousRoute);
    super.didPop(route, previousRoute);
  }

  void _record(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null) return;                       // unnamed routes are not tracked
    _reporter.setCustomKey('route', name);
    _reporter.log('nav $name');                     // breadcrumb
    _analytics.log(ScreenViewed(screenName: name)); // §8.4
    _log.debug('Route changed', fields: {'route': name});
  }
}
```

Registering the observer on the router is `frontend/go-router`. Route *names* must be static
(`/courses/:id`, not `/courses/8f1c…`) or the breadcrumb trail becomes a list of identifiers
you cannot group by — and a path segment that is a real identifier is a §4 leak.

---

## 6. The three global error channels

**Rule: install all three. Each catches a class the others do not; missing one loses that
class of crash silently.**

| Channel | Catches | Missing it means |
|---|---|---|
| `FlutterError.onError` | Errors inside the framework: `build`, `layout`, `paint`, gesture callbacks | The red screen is the only record; nothing reaches the reporter |
| `PlatformDispatcher.instance.onError` | Uncaught async errors reaching the engine — unawaited futures, stream errors | The most common production crash class is invisible |
| `runZonedGuarded` | Errors raised in the same zone but off the engine's path, including during bootstrap **before** `runApp` | A crash in initialisation looks like "the app just doesn't start" |

```dart
// lib/main.dart
void main() {
  // Hoisted so the zone's error handler can reach it: the handler runs after the
  // body, but it is a sibling closure, not a nested one.
  CrashReporter? reporter;

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized(); // must be inside the guarded zone
      final env = await AppEnvironment.load();
      reporter = await CrashReporter.initialise(env);
      final logger = buildLogger(env);
      await installCrashContext(reporter!, env);

      FlutterError.onError = (FlutterErrorDetails details) {
        logger.error(
          'Flutter framework error',
          error: details.exception,
          stackTrace: details.stack ?? StackTrace.current,
          fields: {'library': details.library ?? 'unknown'},
        );
        reporter!.recordFlutterError(details, fatal: true);
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        logger.error('Uncaught async error', error: error, stackTrace: stack);
        reporter!.recordError(error, stack, fatal: true);
        return true; // handled — see below
      };

      runApp(ProviderScope(child: const App()));
    },
    (Object error, StackTrace stack) {
      // Bootstrap-time and off-path zone errors. The reporter may not exist yet if the
      // failure was in its own initialisation — that case must not throw from the handler.
      reporter?.recordError(error, stack, fatal: true);
    },
  );
}
```

**Rule: `PlatformDispatcher.instance.onError` returns `true`.** `true` means "handled, do not
fall through". Returning `false` hands the error on to the platform default, which in a
release build prints it to the system log and, on some paths, terminates the process — so
you get a duplicate report *and* a crash you thought you had contained.

**Rule: `WidgetsFlutterBinding.ensureInitialized()` and `runApp` are inside the same zone as
the guard.** A binding initialised in the root zone while `runApp` runs in a guarded zone is
a documented mismatch: the guard receives nothing, and you have a zone that only costs you.

Two honest caveats, both worth knowing before you delete something:

- Since `PlatformDispatcher.onError` landed, it covers most of what `runZonedGuarded` was
  used for. The zone still earns its place for errors thrown during bootstrap, before the
  binding's handler is installed. Keep all three.
- Neither channel sees a crash in native code or in a background isolate. An isolate needs
  its own `Isolate.current.addErrorListener`, and native crashes come from the reporter's own
  NDK/Apple hooks.

**Rule: fatal for uncaught, non-fatal for handled.** An error you caught and showed the user
a message for is `fatal: false` — it must not count against the crash-free-sessions metric
that decides whether you ship.

---

## 7. What actually gets reported

**Rule: `isReportable` on the error type decides, not the catch site.** That property is
defined in `api-style/dio`; this layer only obeys it.

```dart
// The single reporting funnel. Nothing else calls recordError for a handled error.
void reportHandled(AppError error, StackTrace stackTrace, {Map<String, Object?> fields = const {}}) {
  _log.warn('Handled error', error: error, stackTrace: stackTrace, fields: fields);
  if (!error.isReportable) return;             // an expected 4xx is UI state
  _reporter.recordError(error, stackTrace, fatal: false);
}
```

Reporting every caught exception turns the crash dashboard into a log of users on trains and
users mistyping passwords, and the one real regression is buried under ten thousand
`NetworkError`s. The rule is not "report less" — it is "report the things a human must act
on".

**Rule: never `catch (_) {}`.** If an error is genuinely ignorable, log it at `debug` with a
one-line reason. A swallowed exception is the bug you will spend a week not finding.

---

## 8. Analytics events are a sealed set of types

### 8.1 The event type

**Rule: events are a sealed hierarchy, not strings passed to a generic `log` call.**

Free-form `analytics.log('course_enrol', {'id': id})` is unreviewable and undiscoverable: the
name is typo-able, the property set drifts between the two call sites that emit "the same"
event, nobody can list what the app collects, and the data team's dashboard breaks silently
when a rename ships. A sealed hierarchy makes the catalogue a file you can read, a rename a
compile error, and the property set a constructor signature.

```dart
// lib/core/observability/analytics_event.dart

/// Every event the app is allowed to emit. Adding one is a reviewed change.
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  /// snake_case, object_verb, past tense. See §8.2.
  String get name;

  /// Non-personal properties only. See §8.3.
  Map<String, Object?> get parameters => const {};
}

final class CourseEnrolled extends AnalyticsEvent {
  const CourseEnrolled({required this.courseId, required this.source});

  final String courseId;
  final EnrolmentSource source;

  @override
  String get name => 'course_enrolled';

  @override
  Map<String, Object?> get parameters => {
        'course_id': courseId,
        'source': source.name,   // 'search' | 'catalogue'
      };
}

final class ScreenViewed extends AnalyticsEvent {
  const ScreenViewed({required this.screenName});

  final String screenName;

  @override
  String get name => 'screen_viewed';

  @override
  Map<String, Object?> get parameters => {'screen_name': screenName};
}
```

The service takes the type, never a name and a bag:

```dart
abstract interface class AnalyticsService {
  void log(AnalyticsEvent event);
  Future<void> setUser(String? pseudonymousUserId);
}
```

### 8.2 Naming

**Rule: one convention, `object_verb`, snake_case, past tense — `course_enrolled`,
`checkout_completed`, `push_permission_granted`.**

Past tense because an event is a record of something that already happened; object first
because that is what sorts usefully in a dashboard with three hundred event names. The
convention matters more than which convention it is: mixed `EnrolCourse`, `course_enrol` and
`courseEnrolled` in one property make every funnel a manual join.

| Rule | Because |
|---|---|
| snake_case, `[a-z0-9_]` only | Firebase rejects other characters; BigQuery column names |
| ≤ 40 characters | Firebase event-name limit |
| No `firebase_`, `google_`, `ga_` prefix | Reserved; the event is silently dropped |
| Parameter keys snake_case, ≤ 40 chars, ≤ 25 per event | Firebase limits; extras are dropped without an error |
| String parameter values ≤ 100 chars | Truncated silently |

A silently dropped event is the failure mode that costs the most: nobody notices for a
quarter, and then the funnel has a hole where the data should be.

### 8.3 No personal data as a property

**Rule: no email, phone, name, address, free-text the user typed, precise location, or any
raw identifier that resolves to a person, as an event property — ever.**

Analytics properties go to a third-party system, are copied into every downstream export,
and are outside the deletion path you built for your own database. The user identity you
*are* allowed to attach is the pseudonymous id, set once via `setUser`, which the vendor's
own deletion API can clear.

```dart
// ❌ every one of these is a subject-access-request problem and a vendor-policy breach
'email': user.email,
'search_query': query,            // users type their own names and phone numbers into search
'lat': position.latitude,

// ✅
'user_type': user.isStaff ? 'staff' : 'learner',
'query_length': query.length,
'result_count': results.length,
'city': coarseCity,               // if the product genuinely needs it
```

**Rule: an id in an event is the opaque backend id, never something human-readable.**
`course_id: '8f1c…'` is fine. `course_name` is fine. `learner_email` is not.

### 8.4 Screen views come from a nav observer

**Rule: screen views are emitted by the `NavigatorObserver` in §5, never by `initState` in a
page.**

Per-page emission gets it wrong in four ways that all look fine in review: a page pushed
twice logs once (the state object was kept alive), a page returned to via pop logs not at
all, a tab switch logs nothing because no state was created, and eventually somebody adds a
page and forgets. One observer sees every transition by construction.

### 8.5 A debug build never writes to production analytics

**Rule: debug and test builds write to a `DebugAnalyticsService` that logs the event locally,
or to a separate analytics property. Never to the production one.**

Otherwise the funnel you are optimising contains a developer hot-reloading the checkout
screen forty times, and a QA run looks like a conversion spike.

```dart
AnalyticsService buildAnalytics(AppEnvironment env, ConsentStore consent) {
  if (kDebugMode || env.flavor != 'prod') {
    return DebugAnalyticsService(logger); // prints via the facade at debug level
  }
  return FirebaseAnalyticsService(FirebaseAnalytics.instance, consent);
}
```

The same rule covers integration-test runs on CI: they must not be able to reach the
production property, and the way to guarantee that is that the credentials are not in the
build.

---

## 9. Consent is checked before collection

**Rule: consent gates *collection*, not *reporting*. An event queued while awaiting consent
is data that was collected without permission.**

The tempting design is a buffer: record events from launch, hold them, and flush once the
user accepts. It is wrong on the only reading that matters. If the user declines, you built
and held a record of their behaviour anyway; if the process is killed mid-session you have
still processed it. Under GDPR and the ATT rules the collection is the regulated act. It is
also fragile — the buffer grows unbounded on a user who never answers.

```dart
enum ConsentStatus { unknown, granted, denied }

final class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._analytics, this._consent);

  final FirebaseAnalytics _analytics;
  final ConsentStore _consent;

  /// Called at bootstrap and again whenever the user changes their answer.
  Future<void> applyConsent(ConsentStatus status) async {
    // The SDK itself is off until consent is granted: no automatic screen views,
    // no session pings, no app-instance id generated.
    await _analytics.setAnalyticsCollectionEnabled(status == ConsentStatus.granted);
    if (status != ConsentStatus.granted) {
      await _analytics.resetAnalyticsData();
    }
  }

  @override
  void log(AnalyticsEvent event) {
    // Not "queue until granted" — drop. Unknown and denied are both a no.
    if (_consent.status != ConsentStatus.granted) return;
    unawaited(_analytics.logEvent(name: event.name, parameters: event.parameters));
  }
}
```

**Rule: the default is `ConsentStatus.unknown`, and `unknown` behaves exactly like
`denied`.** Anything else means the first launch — before the prompt has been answered — is
collected.

**Rule: `setAnalyticsCollectionEnabled(false)` must be the shipped default too.** Set it in
the manifest / `Info.plist` so the SDK is off before any Dart code runs; the automatic
collection Firebase does on its own (`session_start`, `first_open`, the app-instance id) is
not routed through your `log` method and your Dart-side gate cannot stop it.

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data android:name="firebase_analytics_collection_enabled" android:value="false" />
```

**Rule: crash reporting has its own consent decision, and it is a different one.** Crash
reports are usually justifiable as legitimate interest where analytics is not — but that is a
decision for whoever owns your privacy policy, made once, and written down next to the
consent store. Do not assume one answer covers both.

**Rule: a consent change to `denied` deletes what you have.** `resetAnalyticsData()` and
clearing the user identifier are part of honouring the answer, not a nicety.

---

## 10. Feature flags and the version gate

### 10.1 Typed, with a compiled-in default that is the safe behaviour

**Rule: every flag is a typed `Flag<T>` declared in one catalogue file, with a compiled-in
default. The default is whatever is correct when the app has never reached the network.**

A first launch on a plane, a fetch that times out, a config service outage — in all three the
app runs on the defaults. If the default is "new checkout on" and the new checkout is the
thing you are still rolling out, your riskiest code path is what an offline first-launch
gets. The default is the old, known-good behaviour.

```dart
// lib/core/observability/feature_flags.dart

final class Flag<T> {
  const Flag({
    required this.key,
    required this.defaultValue,
    required this.owner,
    required this.removeBy,
    this.description = '',
  });

  /// Remote key, snake_case.
  final String key;

  /// Compiled-in fallback. Must be the safe behaviour: what ships if no config arrives.
  final T defaultValue;

  /// Team or individual answerable for this flag. See §10.4.
  final String owner;

  /// ISO date. A flag past this date is a review failure. See §10.4.
  final String removeBy;

  final String description;
}

/// The whole catalogue. Nothing reads a flag key that is not declared here.
abstract final class Flags {
  static const checkoutV2 = Flag<bool>(
    key: 'checkout_v2_enabled',
    defaultValue: false,          // old checkout is the safe behaviour
    owner: 'payments',
    removeBy: '2026-03-01',
    description: 'Routes checkout through the new payment sheet.',
  );

  static const minimumSupportedVersion = Flag<String>(
    key: 'minimum_supported_version',
    defaultValue: '0.0.0',        // gate off by default — see §10.2
    owner: 'mobile-platform',
    removeBy: '2027-01-01',
    description: 'Builds below this are blocked from using the API.',
  );

  static const recommendedVersion = Flag<String>(
    key: 'recommended_version',
    defaultValue: '0.0.0',        // no prompt by default
    owner: 'mobile-platform',
    removeBy: '2027-01-01',
    description: 'Builds below this see a dismissible update prompt.',
  );

  static const uploadChunkBytes = Flag<int>(
    key: 'upload_chunk_bytes',
    defaultValue: 1048576,
    owner: 'media',
    removeBy: '2026-06-01',
  );
}
```

**Rule: call sites read through the store, never through the vendor SDK.**

```dart
abstract interface class FlagStore {
  /// The remote value if one was fetched and parses as T, otherwise flag.defaultValue.
  T value<T>(Flag<T> flag);

  /// False until a successful fetch-and-activate has completed this process.
  bool get hasFetched;
}

// ✅
if (flags.value(Flags.checkoutV2)) { ... }

// ❌ untyped, undeclared, no default, no owner, and a typo compiles
if (FirebaseRemoteConfig.instance.getBool('checkout_v2')) { ... }
```

A direct `getBool` returns `false` for a misspelled key — so a typo silently ships the flag
permanently off, and it looks exactly like a flag that is working.

**Rule: fetch is bounded and non-blocking.** Set `fetchTimeout` and start the app on defaults
if it expires; never hold a splash screen on a config fetch.

```dart
await remoteConfig.setDefaults(_defaultsFromCatalogue()); // from Flags, so they cannot drift
await remoteConfig.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: const Duration(seconds: 5),
  minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
));
```

### 10.2 The minimum-version gate fails open

**Rule: if config has not been fetched, the app is not blocked. Ever.**

A blocking "please update" screen driven by a value the app could not fetch is a
self-inflicted total outage: a config-service blip, a captive-portal wifi, or a throttled
fetch locks out every user at once, and the fix requires the very network the user does not
have. Blocking is the most dangerous thing a flag can do, so it is the one that must be
hardest to trigger by accident.

```dart
enum UpdateRequirement { none, recommended, blocking }

UpdateRequirement checkUpdateRequirement({
  required FlagStore flags,
  required Version currentVersion,
}) {
  // Fail open. No fetch means no gate — the app must work on a cold, offline launch.
  if (!flags.hasFetched) return UpdateRequirement.none;

  final minimum = _tryParseVersion(flags.value(Flags.minimumSupportedVersion));
  if (minimum == null) return UpdateRequirement.none;   // unparseable config is not a gate

  if (currentVersion < minimum) return UpdateRequirement.blocking;

  final recommended = _tryParseVersion(flags.value(Flags.recommendedVersion));
  if (recommended != null && currentVersion < recommended) {
    return UpdateRequirement.recommended;
  }
  return UpdateRequirement.none;
}

/// `pub_semver`'s `Version.parse` throws; a bad value in the remote console must not
/// become an exception on the splash screen.
Version? _tryParseVersion(String raw) {
  try {
    return Version.parse(raw);
  } on FormatException {
    return null;
  }
}
```

| Situation | Result | Because |
|---|---|---|
| Config never fetched | `none` | The blip must not become an outage |
| Fetched, value absent | `none` (default `0.0.0`) | An unset key is not a gate |
| Fetched, value unparseable | `none` | A typo in the console must not lock out the estate |
| Fetched, below minimum | `blocking` | Deliberate, verified, and reversible from the console |
| Fetched, below recommended | `recommended` | Dismissible prompt, not a wall |

**Rule: `blocking` is reversible in under a minute and is tested before it is needed.** Raise
it in a staging config and confirm on a real build that the screen appears, that lowering it
again releases the app, and that the release happens on the next foreground — not only on a
cold start.

### 10.3 Kill switches

**Rule: every risky feature ships with a kill switch that has been verified off.**

Risky means: touches payments, writes user data irreversibly, calls a brand-new backend, or
is a rewrite of something that works. A kill switch nobody has tried is a hope, not a
control — the two common ways it fails are that the flag is read once at startup and cached
for the session, and that turning it off leaves the user stranded in a half-finished flow.

- Read the flag at the decision point, not once at boot into a `final`.
- Define what happens to a user who is mid-flow when it flips — usually: finish the current
  attempt, route the next one to the old path.
- Verify by flipping it in staging on a real device, foregrounding, and observing the switch.

### 10.4 Every flag has an owner and a removal date

**Rule: `owner` and `removeBy` are required constructor parameters, so a flag cannot be
added without them.**

Flags are debt with a nice interface. Ten stale flags is 2^10 nominal configurations, none of
them tested, and the code under a permanently-on flag is dead branch that still compiles and
still gets refactored. The date is not a wish; it is what makes removal a scheduled task
rather than an act of courage.

| Flag lifecycle | Action |
|---|---|
| Rolled out to 100% and stable for two weeks | Delete the flag, the branch, and the console key — in that order |
| Past `removeBy`, still rolling out | Someone renegotiates the date in review; it does not lapse quietly |
| Kill switch for a permanent risk (payments provider) | Long-lived by design; `removeBy` far out and `description` says why |

A CI check that lists flags past `removeBy` costs ten lines and is the only thing that
actually gets them removed.

### 10.5 Flags never gate security

**Rule: a flag may change what the UI offers. It may never be the thing that decides whether
an action is permitted.**

Remote config is client-side state: it is cached on disk, readable, and modifiable on a
rooted device. `if (flags.value(Flags.adminToolsEnabled)) showAdminPanel()` is a UI
convenience; if the backend does not independently authorise every admin call, it is the
authorisation, and it is bypassable with a text editor. Same for entitlements, paywalls, and
age gates: the flag hides the button, the server refuses the request.

---

## 11. Testing observability

**Rule: a `FakeLogger` and a `RecordingAnalyticsService` are part of the test kit, and the
rules above are asserted, not reviewed.**

```dart
test('a failed enrolment reports once and logs no personal data', () async {
  final logger = FakeLogger();
  final analytics = RecordingAnalyticsService();
  // ... run the action against a failing repository ...

  expect(analytics.events, isEmpty);                 // no event for a failed action
  expect(logger.records.single.level, LogLevel.warn);
  expect(logger.records.single.fields['auth_token'], '<redacted>');
});

test('the update gate is open when config was never fetched', () {
  final flags = FakeFlagStore(hasFetched: false);
  expect(
    checkUpdateRequirement(flags: flags, currentVersion: Version(1, 0, 0)),
    UpdateRequirement.none,
  );
});

test('consent unknown drops events rather than queueing them', () {
  final analytics = FirebaseAnalyticsService(fakeSdk, ConsentStore(ConsentStatus.unknown));
  analytics.log(const CourseEnrolled(courseId: 'c1', source: EnrolmentSource.search));
  expect(fakeSdk.logged, isEmpty);
});
```

Two tests worth writing once and keeping forever: a redaction test that feeds every key in
the deny-list through `redact` and asserts the mask, and a catalogue test that asserts every
`AnalyticsEvent` subtype's `name` matches `^[a-z][a-z0-9_]{0,39}$` and carries no
deny-listed parameter key. General test structure is `testing/flutter-test`.

---

## 12. Common mistakes

| Mistake | Why it hurts | Instead |
|---|---|---|
| `debugPrint` left in a release path | Writes to the system log in release; `avoid_print` never flagged it | Ban both, enforce in CI (§3) |
| Message built by interpolation | The secret is inside the string before redaction runs | Constant message + `fields:` (§1) |
| `redact()` called at the call site | The next call site will forget | Redact inside `_emit` (§4) |
| Logging the full URI | The query string carries emails and ids | `redactUri(uri)` (§4) |
| Email as the crash reporter's user id | Personal data in a third-party system, outside deletion | Pseudonymous id (§5) |
| Only `FlutterError.onError` installed | Every uncaught async error is invisible | All three channels (§6) |
| `PlatformDispatcher.onError` returning `false` | Duplicate report, and the process may still die | `return true;` (§6) |
| Binding initialised outside the guarded zone | The zone guard receives nothing | Both inside `runZonedGuarded` (§6) |
| `recordError` at every catch site | Real regressions buried under expected 4xx | `isReportable` (§7) |
| `analytics.log('name', {...})` | Typos, drift, no catalogue, silent dashboard breakage | Sealed `AnalyticsEvent` (§8.1) |
| Mixed event-name casing | Every funnel becomes a manual join | `object_verb` snake_case past tense (§8.2) |
| `search_query` as a property | Users type their own names and numbers into search | `query_length` (§8.3) |
| Screen views from `initState` | Misses pops and tab switches, double-counts pushes | Nav observer (§8.4) |
| Debug builds writing to the production property | QA runs look like conversion spikes | Separate service/property (§8.5) |
| Queue events until consent | Collection already happened; that is the regulated act | Drop; SDK off until granted (§9) |
| `FirebaseRemoteConfig.instance.getBool('...')` at a call site | A typo returns `false` and ships the flag permanently off | Typed `Flag<T>` via the store (§10.1) |
| Default `true` for the new path | Offline first launch gets the riskiest code | Default is the old behaviour (§10.1) |
| Version gate blocking on unfetched config | A config blip becomes a total outage | Fail open on `!hasFetched` (§10.2) |
| Flag read once into a `final` at boot | The kill switch does nothing until a restart | Read at the decision point (§10.3) |
| Flag with no owner or removal date | Ten flags, 1024 untested configurations | Required constructor params (§10.4) |
| `if (flags.adminEnabled)` as the only check | Client-side state; editable on a rooted device | Server authorises (§10.5) |

---

## 13. Never

- `print`, `debugPrint`, `dart:developer`'s `log`, or `stdout.writeln` in `lib/`.
- A second logging system alongside `AppLogger`.
- A token, password, `Authorization` header, response body, or full URI in a log record.
- An email, phone number or name as a crash-reporter key, an analytics property, or a user id.
- Ship with fewer than three global error channels installed.
- `PlatformDispatcher.instance.onError` returning `false`.
- `catch (_) {}`.
- `recordError` for an error whose type says `isReportable == false`.
- A free-form string event name at a call site.
- An analytics event emitted before consent is `granted` — including into a queue.
- A debug build writing to the production analytics property.
- A flag read straight from the vendor SDK, or one whose compiled-in default is the new path.
- A blocking update screen reachable when config has not been fetched.
- A flag as the only thing standing between a user and a privileged action.
