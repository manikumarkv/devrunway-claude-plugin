# Flutter App Structure, Bootstrap and Theming

The app shell: where files live and which direction dependencies run, the single `bootstrap`
that every flavor entrypoint calls, the error channels and first-frame gating installed
there, the composition root, the `ThemeData` pair and its semantic-colour extension, how
widget code branches on platform, how native code is reached, the size budget, and when a
monorepo split is worth it.

**Scope boundaries.** This layer is the **fallback**. Its last glob claims any Dart file
under `lib/` that no other layer claims, so it must not restate what a role-specific layer
owns. If a file matches one of these, the rules for it are there, not here:

| Layer | Owns |
|---|---|
| `language/dart-models` | Model shape — freezed, `fromJson`, enums, nullability, dates |
| `api-style/dio` | Services, `ApiClient`, interceptors, the sealed `AppError` hierarchy |
| `state/riverpod` | Provider and controller shape, `AsyncValue`, disposal, pagination |
| `frontend/flutter-ui` | The widget tree — page states, components, semantics, forms, motion |
| `frontend/go-router` | Route declaration, redirects, deep links, `.well-known` |
| `auth/flutter-session` | `SessionState`, token storage, sign-out teardown, resume revalidation |
| `storage/flutter-local` | Which store for which data class, encryption, backup exclusion |
| `logging/flutter-observability` | `AppLogger`, the crash reporter, analytics, feature flags |
| `testing/flutter-test` | The harness, fakes, goldens, contract and integration tests |
| `i18n/flutter-l10n` | ARB catalogue, `l10n.yaml`, ICU plurals, locale resolution |
| `ci/flutter-release` | Workflows, Gradle, manifests, plists, `.env_*`, `analysis_options.yaml` |
| `notifications/fcm` | Delivery states, background isolate, permission, token lifecycle |

Two boundaries are easy to get wrong:

- **The analyzer configuration is not this layer's.** `analysis_options.yaml` — the strict
  language modes, `always_use_package_imports`, `use_build_context_synchronously: error` —
  is the canonical file in `ci/flutter-release` §8. This layer states the *rules* the
  analyzer happens to enforce; it does not restate the file.
- **Flavor resolution is not this layer's either.** The two build switches, the
  `String.fromEnvironment('FLAVOR')` read with no fallback, the startup assertion and the
  crash keys are `ci/flutter-release` §§1–3. This layer says only *where in bootstrap* that
  work sits.

Sections are independent. Read the one you need.

| § | Concern |
|---|---|
| 1 | The skeleton — feature-first, four layers |
| 2 | Dependency direction inside a feature |
| 3 | The feature boundary — how one feature uses another |
| 4 | `core/` — what earns a place there |
| 5 | Imports, file size, `build` size |
| 6 | `bootstrap` — one function behind every entrypoint |
| 7 | The three error channels |
| 8 | What blocks the first frame, and what does not |
| 9 | Startup failure: a screen with retry, never a silent continue |
| 10 | The composition root |
| 11 | `ThemeData` — light and dark, shipped together |
| 12 | Semantic colours as a `ThemeExtension` |
| 13 | Typography and spacing come from the theme |
| 14 | White-label branding built at runtime |
| 15 | Platform branching in widget code |
| 16 | Native code behind an interface; Pigeon; `PlatformException` |
| 17 | App size: budget, artifact, measurement |
| 18 | Monorepo: when a split is real |
| 19 | Common mistakes |
| 20 | Never |

---

## 1. The skeleton — feature-first, four layers

**Rule: the top-level split is by feature, not by technical kind. Inside a feature the split
is by the four layers, always the same four, always those names.**

A `lib/models/`, `lib/services/`, `lib/screens/` layout looks tidy at ten files and stops
working at a hundred: every change touches four distant directories, nothing can be deleted
with confidence, and no directory tells you what the app does. Feature-first puts everything
one change needs in one subtree, and makes deleting a feature a `rm -rf`.

```
lib/
  main.dart                    # one per flavor: main_dev.dart, main_staging.dart, main.dart
  bootstrap.dart               # §6 — the one shared startup path
  src/
    app.dart                   # the MaterialApp.router widget
    core/                      # §4 — shared infrastructure, no domain knowledge
      config/                  # AppConfig, AppEnvironment
      di/                      # the composition root's override list
      theme/                   # §§11-14
      network/                 # api-style/dio
      error/                   # api-style/dio
      storage/                 # storage/flutter-local
      observability/           # logging/flutter-observability
      router/                  # frontend/go-router
      widgets/                 # frontend/flutter-ui (design system)
      platform/                # §16 — generated Pigeon channels and their bindings
      utils/                   # pure Dart helpers with no dependencies
    features/
      orders/
        domain/                # entities, value objects, service contracts — language/dart-models
          models/
          order_service.dart   # abstract interface class — the contract
        data/                  # implementations of the domain contracts
          dto/
          services/            # api-style/dio
        application/           # providers and controllers — state/riverpod
          providers/
          controllers/
        presentation/          # widgets — frontend/flutter-ui
          pages/
          widgets/
      profile/
        domain/ data/ application/ presentation/
```

The `src/` directory is not decoration. Everything under `lib/` is publicly importable by
anyone who depends on the package; everything under `lib/src/` is private by convention and
flagged by the analyzer when reached from outside. In a monorepo (§18) that convention is
the only thing keeping one package out of another's internals.

**Rule: the four layer names are fixed — `domain`, `data`, `application`, `presentation`.**
Not because those four words are uniquely correct, but because the other layers' globs are
written against them. A feature that calls its providers directory `state/` gets no
`state/riverpod` rules, silently. The directory names are the routing table.

| Directory | Holds | Knows about |
|---|---|---|
| `domain/` | Entities, value objects, abstract service contracts | Nothing. Not Flutter, not Dio, not Riverpod |
| `data/` | DTOs, REST/local implementations of the contracts | `domain/`, transport packages |
| `application/` | Providers, controllers, derived state | `domain/`, `data/` contracts only through DI |
| `presentation/` | Pages and widgets | `application/`, `domain/` types |

---

## 2. Dependency direction inside a feature

**Rule: dependencies point inward. `presentation → application → data → domain`, never the
other way and never a shortcut across.**

The two rules that carry the weight:

**`domain/` imports no Flutter.** No `package:flutter/material.dart`, no `BuildContext`, no
`Color`, no `IconData`. The moment an entity carries a `Color`, the business rules can only
run in a widget test, the model cannot be shared with a Dart-only backend or CLI, and the
design system cannot change without editing the domain.

```dart
// ✅ lib/src/features/orders/domain/models/order_status.dart
enum OrderStatus { pending, shipped, delivered, cancelled, unknown }

// ❌ the same file, with the presentation layer's job moved into it
enum OrderStatus {
  pending(Colors.orange, Icons.schedule),   // needs package:flutter/material.dart
  shipped(Colors.blue, Icons.local_shipping);
  const OrderStatus(this.color, this.icon);
  final Color color;
  final IconData icon;
}
```

The mapping from `OrderStatus` to a colour belongs in `presentation/`, reading the theme
extension from §12 — which is also the only way it can differ between light and dark.

**`presentation/` does not reach into `data/`.** A page that constructs a
`RestOrderService`, or calls one directly, has bound a screen to a transport. It cannot be
golden-tested without a network stub, and the offline decorator (`api-style/dio` §7) cannot
be inserted without editing the page. `presentation/` watches a provider; the provider holds
the contract.

```dart
// ❌ lib/src/features/orders/presentation/pages/order_list_page.dart
final orders = await RestOrderService(ApiClient()).fetchOrders();

// ✅ the page watches; state/riverpod owns the provider's shape
final orders = ref.watch(orderListProvider);
```

---

## 3. The feature boundary — how one feature uses another

**Rule: a feature never imports another feature's `presentation/` or `application/`. It may
import only the other feature's `domain/` — its entities and its abstract contracts — and
receives the implementation through DI.**

This is the rule that decides whether the app still has features in a year. Two features
that reach into each other's widgets and providers are one feature with a directory
separator in the middle: neither can be tested, moved to a package, or deleted alone, and a
change to a "private" widget breaks a screen nobody thought was related.

Concretely — `orders` needs the signed-in user's display name, owned by `profile`:

```dart
// ✅ profile publishes a contract in its domain layer
// lib/src/features/profile/domain/profile_service.dart
abstract interface class ProfileService {
  Future<Profile> currentProfile();
}

// ✅ orders depends on the contract, not on profile's internals
// lib/src/features/orders/application/providers/order_summary_providers.dart
import 'package:app/src/features/profile/domain/profile_service.dart';

@riverpod
Future<OrderSummary> orderSummary(Ref ref) async {
  final profile = await ref.watch(profileServiceProvider).currentProfile();
  ...
}
```

```dart
// ❌ every one of these welds the two features together
import 'package:app/src/features/profile/presentation/widgets/avatar.dart';
import 'package:app/src/features/profile/application/providers/profile_providers.dart';
import 'package:app/src/features/profile/data/services/rest_profile_service.dart';
```

**Shared widgets are promoted, not borrowed.** If `orders` wants profile's avatar widget,
the avatar moves to `core/widgets/` and loses its domain type — `frontend/flutter-ui` has
the promotion rule (on the third use, and a shared component knows no domain type).

**Shared entities move down, not sideways.** If two features need the same entity, it is not
either feature's — it belongs in `core/` or, in a monorepo, a `domain` package.

**Enforce it, don't just document it.** A boundary rule that only lives in a review comment
is gone in a quarter. Either add an import-boundary lint, or a test that walks
`lib/src/features/*/` and asserts no file imports another feature's `presentation/`,
`application/` or `data/`.

```dart
// test/architecture/feature_boundaries_test.dart — one test, catches the whole class
test('no feature imports another feature internals', () {
  final offenders = <String>[];
  for (final file in Directory('lib/src/features').listSync(recursive: true)
      .whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    final owner = RegExp(r'lib/src/features/([^/]+)/').firstMatch(file.path)!.group(1);
    for (final line in file.readAsLinesSync().where((l) => l.startsWith('import'))) {
      final m = RegExp(r"features/([^/]+)/(domain|data|application|presentation)")
          .firstMatch(line);
      if (m != null && m.group(1) != owner && m.group(2) != 'domain') {
        offenders.add('${file.path} -> ${m.group(0)}');
      }
    }
  }
  expect(offenders, isEmpty);
});
```

---

## 4. `core/` — what earns a place there

**Rule: `core/` holds infrastructure with no domain knowledge. A file that names a business
concept is not core, however many features use it.**

`core/` is where structure goes to die if the entry test is "more than one feature uses it".
By that test everything ends up there, and the features become empty shells. The test is
"could this be published as a package and still make sense".

| In `core/` | Not in `core/` |
|---|---|
| `ApiClient`, interceptors, `AppError` | `OrderService` |
| `AppLogger`, crash reporter, analytics facade | `checkout_analytics.dart` |
| `SecureStore`, `AppDatabase`, cache | `OrderCacheStore` — lives in `features/orders/data/` |
| Theme, design-system widgets, `AppSpacing` | `OrderStatusBadge` — feature presentation |
| `Result`, `Debouncer`, date/format helpers | `PricingRules` |
| Pigeon-generated channels and their bindings | `BiometricUnlockController` |

`core/` has the same inward rule as a feature: `core/` never imports `features/`. If a core
file needs a feature's type, the type is in the wrong place.

---

## 5. Imports, file size, `build` size

**Rule: package imports only. `import 'package:app/src/…'`, never `import '../../..'`.**

Relative imports break on every file move, produce diffs where the whole import block
changed for no reason, and — the real cost — Dart treats `package:app/x.dart` and
`../x.dart` as **two different libraries**. Import the same file both ways and you get two
copies of its statics, two enum identities, and `is` checks that fail on objects that are
obviously the right type. `always_use_package_imports` in the canonical
`analysis_options.yaml` (`ci/flutter-release` §8) makes this an analyzer error.

**Rule: a file over ~400 lines is a refactor, not a style opinion; a `build` method over
~60 lines is extracted into widgets.**

These are review triggers, not hard gates. The number matters less than what it catches: a
600-line file has stopped being one thing, and a 200-line `build` rebuilds all of itself
when any one part of its state changes.

| Symptom | Split |
|---|---|
| A page's `build` is 200 lines | Extract each section as a `const`-constructible widget class |
| A controller has eight unrelated methods | Two controllers, or the logic belongs in `domain/` |
| A service file has 900 lines | One file per resource group |

Extract into **widget classes, not `Widget _buildHeader()` methods**. A helper method is
part of the enclosing widget: it rebuilds whenever the parent rebuilds, cannot be `const`,
cannot have its own `State`, and does not appear in the devtools tree. A class can be all
four. `frontend/flutter-ui` owns the widget-level detail.

---

## 6. `bootstrap` — one function behind every entrypoint

**Rule: there is exactly one startup path, `lib/bootstrap.dart`. Every `main_<flavor>.dart`
is a handful of lines that calls it.**

The failure this prevents is specific and common: three flavor entrypoints, each with its
own copy of the zone, the error handlers and the init list. Someone adds a fourth channel or
a new required init to `main.dart` and the staging build silently keeps the old startup.
Nothing looks wrong until staging stops reporting crashes.

```dart
// lib/main.dart — production
import 'package:app/bootstrap.dart';
Future<void> main() => bootstrap(AppFlavor.prod);

// lib/main_staging.dart
import 'package:app/bootstrap.dart';
Future<void> main() => bootstrap(AppFlavor.staging);

// lib/main_dev.dart
import 'package:app/bootstrap.dart';
Future<void> main() => bootstrap(AppFlavor.dev);
```

An entrypoint contains no `runZonedGuarded`, no `runApp`, no error handler and no init call.
If it does, the next difference between flavors will be an accident.

```dart
// lib/bootstrap.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> bootstrap(AppFlavor flavor) async {
  // Hoisted: the zone's error handler is a sibling closure of the body, not nested
  // inside it, so anything it needs must be reachable from out here.
  CrashReporter? reporter;
  AppLogger? logger;

  Future<void> start() async {
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();   // inside the zone, always

        final env = AppEnvironment.resolve(flavor);  // ci/flutter-release §2
        reporter = await CrashReporter.initialise(env);
        logger = buildLogger(env);
        installErrorChannels(logger!, reporter!);    // §7 — all three

        // §8 — only what the first frame needs, in parallel.
        final (secureStore, prefs, database) = await (
          SecureStore.open(),
          SharedPreferences.getInstance(),
          AppDatabase.open(),
        ).wait;

        runApp(
          ProviderScope(
            overrides: buildOverrides(              // §10 — the composition root
              env: env,
              secureStore: secureStore,
              prefs: prefs,
              database: database,
              logger: logger!,
            ),
            child: const App(),
          ),
        );
      },
      (error, stackTrace) {
        logger?.error('Uncaught zone error', error: error, stackTrace: stackTrace);
        reporter?.recordFatal(error, stackTrace);
      },
    );
  }

  await start();
}
```

`Future.wait` and the record-`.wait` form above are the same thing; use whichever reads
better. What matters is that independent initialisations do not run one after another —
three 300 ms opens in series is a second of white screen that no user attributes to
"initialisation".

**Flavor resolution, the startup assertion and the crash keys are `ci/flutter-release` §§2–3.**
They sit here, in this order, but their content is that layer's.

---

## 7. The three error channels

**Rule: install all three, inside the zone, before any work that can throw.**

Each catches a class the others do not. `logging/flutter-observability` §6 owns what each
handler *does* with the error — the logger call, the redaction, what reaches the reporter.
This layer owns only that all three are installed here, once, in the shared bootstrap.

| Channel | Catches |
|---|---|
| `FlutterError.onError` | Framework errors — `build`, layout, paint, gesture callbacks |
| `PlatformDispatcher.instance.onError` | Uncaught async errors reaching the engine |
| `runZonedGuarded` | Errors in the zone off the engine's path, including before `runApp` |

```dart
void installErrorChannels(AppLogger logger, CrashReporter reporter) {
  FlutterError.onError = (details) {
    logger.error('Flutter framework error',
        error: details.exception, stackTrace: details.stack ?? StackTrace.current);
    reporter.recordFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logger.error('Uncaught platform error', error: error, stackTrace: stackTrace);
    reporter.recordFatal(error, stackTrace);
    return true;   // handled — returning false lets it reach the default handler too
  };
}
```

`WidgetsFlutterBinding.ensureInitialized()` goes **inside** `runZonedGuarded`, not before
it. Called outside, the binding is created in the root zone and framework callbacks are
scheduled there — the guarded zone then catches nothing the framework raises.

---

## 8. What blocks the first frame, and what does not

**Rule: `await` before `runApp` only what the first frame cannot render without. Everything
else moves behind a provider the screen that needs it watches.**

Every await before `runApp` is native splash time. On a cold start on a mid-range Android
device with no network, five sequential initialisations is routinely two to four seconds of
a screen the user cannot cancel — and it is the first thing they see.

| Init | Blocks? | Why |
|---|---|---|
| `WidgetsFlutterBinding.ensureInitialized()` | Yes | Nothing works before it |
| Env resolution, crash reporter, logger | Yes | Cheap, and they must catch the rest of startup |
| Secure store / prefs / database open | Yes, in parallel | The router's first redirect reads the session |
| Locale resolution | Yes | Avoids a visible re-layout on the first frame |
| Remote config, feature flags | **No** | Ship last-known values; refresh in the background |
| Catalogue / reference-data warm-up | **No** | A screen's loading state, not the splash |
| Analytics SDK start, notification registration | **No** | Nothing on the first frame reads them |
| Data migrations over a large table | **No** | Behind a provider with real progress |

Non-blocking work becomes a provider the UI can render a state for:

```dart
// lib/src/features/catalogue/application/providers/catalogue_providers.dart
@riverpod
Future<Catalogue> catalogue(Ref ref) =>
    ref.watch(catalogueServiceProvider).warmUp();
```

```dart
// the screen that needs it — not the splash — shows the wait
final catalogue = ref.watch(catalogueProvider);
return catalogue.when(
  data: (c) => CatalogueGrid(catalogue: c),
  loading: () => const CatalogueSkeleton(),
  error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(catalogueProvider)),
);
```

That shape is `state/riverpod` and `frontend/flutter-ui`'s; what this layer fixes is which
side of `runApp` the work sits on.

**A `FutureProvider` is also how a slow init becomes retryable.** Awaited in bootstrap, its
only recovery is force-quit and relaunch.

---

## 9. Startup failure: a screen with retry, never a silent continue

**Rule: a required startup dependency that fails renders a screen naming what failed, with a
retry that re-runs bootstrap. It never swallows the error and continues into the app.**

Continuing past a failed database open does not produce a working app — it produces an app
that crashes later, somewhere else, with a stack trace that points at a screen rather than
at startup. The user's report is "it just closes", and the crash report agrees.

```dart
Future<void> bootstrap(AppFlavor flavor) async {
  CrashReporter? reporter;
  AppLogger? logger;

  Future<void> start() async {
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        final env = AppEnvironment.resolve(flavor);
        reporter = await CrashReporter.initialise(env);
        logger = buildLogger(env);
        installErrorChannels(logger!, reporter!);

        try {
          final (secureStore, prefs, database) = await (
            SecureStore.open(),
            SharedPreferences.getInstance(),
            AppDatabase.open(),
          ).wait;

          runApp(ProviderScope(
            overrides: buildOverrides(env: env, secureStore: secureStore,
                prefs: prefs, database: database, logger: logger!),
            child: const App(),
          ));
        } on Object catch (error, stackTrace) {
          logger!.error('Startup failed', error: error, stackTrace: stackTrace);
          reporter!.recordFatal(error, stackTrace);
          runApp(StartupFailureApp(error: error, onRetry: start));
        }
      },
      (error, stackTrace) {
        logger?.error('Uncaught zone error', error: error, stackTrace: stackTrace);
        reporter?.recordFatal(error, stackTrace);
      },
    );
  }

  await start();
}
```

The failure app is deliberately dependency-free — no `ProviderScope`, no localisations, no
theme extension, no router. Whatever failed may be exactly what those need.

```dart
// lib/src/core/startup/startup_failure_app.dart
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.error, required this.onRetry, super.key});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("The app couldn't start"),
                // Names the stage, not the raw exception: users cannot act on a
                // stack trace, and it can carry a path, a host or a token.
                Text(describeStartupFailure(error)),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
}
```

| Failure | Blocking? | Behaviour |
|---|---|---|
| Database open / migration | Yes | Failure screen, retry; offer "reset local data" after a second failure |
| Secure store unavailable | Yes | Failure screen — the session cannot be read |
| Crash reporter init | No | Log it and continue; losing reporting must not stop the app |
| Remote config fetch | No | Last-known values; the app starts |
| Force-upgrade check | Yes, once fetched | A blocking upgrade screen — a different screen, not this one |

**Retry re-runs the work, it does not just repaint.** `onRetry` calls `start` again; a button
that pops or calls `setState` is a retry in name only. And retry is bounded — after the
second or third failure of the same stage, offer the destructive recovery (clear local data,
sign out) rather than a fourth identical attempt.

---

## 10. The composition root

**Rule: concrete implementations are named in exactly one place — the `overrides` list
passed to `ProviderScope` in bootstrap. Nowhere else constructs one.**

Contracts are declared as unbound providers that throw (`api-style/dio` §1). The binding
happens once. A `RestOrderService(...)` constructed anywhere else is a dependency a test
cannot replace, and it is invisible until the test is written.

```dart
// lib/src/core/di/overrides.dart
List<Override> buildOverrides({
  required AppConfig env,
  required SecureStore secureStore,
  required SharedPreferences prefs,
  required AppDatabase database,
  required AppLogger logger,
}) {
  return [
    appConfigProvider.overrideWithValue(env),
    secureStoreProvider.overrideWithValue(secureStore),
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDatabaseProvider.overrideWithValue(database),
    appLoggerProvider.overrideWithValue(logger),
    // The platform-specific binding, chosen once (§16).
    biometricGatewayProvider.overrideWithValue(PigeonBiometricGateway()),
  ];
}
```

Three properties this buys:

- **Tests reuse it.** `testing/flutter-test`'s harness builds the same list with fakes; a
  test never has to know the production wiring, only which entry to swap.
- **A forgotten binding fails at startup**, loudly, on the first run — not as a
  `UnimplementedError` in one screen three weeks later.
- **A synchronous dependency stays synchronous.** Async singletons opened in bootstrap and
  overridden with a value mean no `AsyncValue` in every provider that reads them.

`overrideWithValue` for something already constructed; `overrideWith` when the replacement
itself needs `ref`. Never a top-level mutable `late` variable assigned in bootstrap — that
is a global with extra steps, and two tests in one process will fight over it.

---

## 11. `ThemeData` — light and dark, shipped together

**Rule: `AppTheme.light` and `AppTheme.dark` are written in the same file, at the same time,
and both are handed to `MaterialApp`. Dark mode is not a later ticket.**

Retrofitting dark mode means auditing every widget written since, because each one that
hardcoded a colour has to be found by eye. Building both from the start makes the mistake
visible on the day it is made: the widget looks wrong in the dark golden.

```dart
// lib/src/core/theme/app_theme.dart
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: buildTextTheme(scheme),          // §13
      extensions: <ThemeExtension<dynamic>>[
        AppStatusColors.of(brightness),           // §12
        AppSpacing.standard,
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}
```

```dart
// lib/src/app.dart
MaterialApp.router(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ref.watch(themeModeProvider),   // system by default, user-overridable
  routerConfig: ref.watch(routerProvider),
);
```

**Rule: `Colors.*` and `Color(0x…)` literals appear only under `core/theme/`.** Everywhere
else reads `Theme.of(context).colorScheme` or the extension from §12.

A literal in a widget is invisible in dark mode, invisible in a white-label build, invisible
to a contrast audit, and impossible to grep for as a set. The rule is easy to enforce
precisely because it is absolute — one directory is allowed, so any other hit is a defect.

```dart
// ❌ in a widget
Container(color: const Color(0xFF2E7D32), child: Text('Delivered',
    style: TextStyle(color: Colors.white, fontSize: 12)));

// ✅ in a widget
final status = Theme.of(context).extension<AppStatusColors>()!;
Container(
  color: status.successContainer,
  child: Text('Delivered', style: Theme.of(context).textTheme.labelSmall!
      .copyWith(color: status.onSuccessContainer)),
);
```

**Do not read the platform brightness by hand.** `MediaQuery.platformBrightnessOf(context)`
in a widget re-derives what `themeMode` already decided and ignores a user override; the
widget then renders dark colours inside a light app. Read `Theme.of(context).brightness`
when a widget genuinely needs to know.

---

## 12. Semantic colours as a `ThemeExtension`

**Rule: a colour that means something the `ColorScheme` has no slot for — success, warning,
danger, a brand surface — is a field on a `ThemeExtension`, with a value per brightness and
verified contrast. Not a constant, not a `switch` in a widget.**

`ColorScheme` covers primary/secondary/tertiary/error and their containers. It has no
`success`. The default answer is `Colors.green` at the call site, which is the literal ban
in §11 wearing a semantic hat: it is wrong in dark mode, wrong in a white-label build, and
it will be `Colors.green.shade600` in the next widget and `Colors.lightGreen` in the one
after.

```dart
// lib/src/core/theme/app_status_colors.dart
import 'package:flutter/material.dart';

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;

  static const AppStatusColors _light = AppStatusColors(
    success: Color(0xFF1B5E20),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFC8E6C9),
    onSuccessContainer: Color(0xFF0B2E0D),
    warning: Color(0xFF8A5300),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
  );

  // Not the light values darkened by eye: re-picked so each pair clears contrast
  // against the dark surface it actually sits on.
  static const AppStatusColors _dark = AppStatusColors(
    success: Color(0xFF7CD98C),
    onSuccess: Color(0xFF00390B),
    successContainer: Color(0xFF1F4B25),
    onSuccessContainer: Color(0xFFC8E6C9),
    warning: Color(0xFFFFB95C),
    onWarning: Color(0xFF442B00),
    danger: Color(0xFFF2B8B5),
    onDanger: Color(0xFF601410),
  );

  static AppStatusColors of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
    );
  }
}
```

`copyWith` and `lerp` are not boilerplate to skip. `lerp` is what animates the extension
during a theme change; return `this` from it and every semantic colour snaps while the rest
of the app cross-fades. `copyWith` is what makes the white-label override in §14 possible.

**Every foreground/background pair ships with a contrast test.** "Verified contrast" that
lives in a designer's file is verified once; a test is verified on every commit.

```dart
// test/theme/contrast_test.dart
double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  final (hi, lo) = l1 > l2 ? (l1, l2) : (l2, l1);
  return (hi + 0.05) / (lo + 0.05);
}

for (final brightness in Brightness.values) {
  final c = AppStatusColors.of(brightness);
  test('status contrast — $brightness', () {
    expect(_contrast(c.onSuccess, c.success), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.onSuccessContainer, c.successContainer), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.onWarning, c.warning), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.onDanger, c.danger), greaterThanOrEqualTo(4.5));
  });
}
```

4.5:1 for body text, 3:1 for large text and non-text indicators (WCAG AA). Reading:

```dart
final status = Theme.of(context).extension<AppStatusColors>()!;
```

The `!` is deliberate. The extension is registered in §11's `extensions:` list, so a null
here means the theme was not applied — usually a widget test pumping a bare `MaterialApp`,
which is a broken harness (`testing/flutter-test` — `pumpApp` applies the app theme).
Defaulting to a fallback colour hides it.

---

## 13. Typography and spacing come from the theme

**Rule: no literal `fontSize`, `fontWeight` or `fontFamily` outside `core/theme/`. Widgets
name a role from `textTheme`.**

A literal size does not scale with the user's accessibility setting in any coordinated way,
cannot be adjusted globally, and produces the familiar drift where a screen has 13, 14 and
15 px text that was all meant to be "body".

```dart
// ❌
Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600));

// ✅
Text('Total', style: Theme.of(context).textTheme.titleMedium);

// ✅ a deliberate variation on a role, not a new size
Text('Total', style: Theme.of(context).textTheme.titleMedium!
    .copyWith(color: Theme.of(context).colorScheme.primary));
```

Spacing follows the same shape — a second `ThemeExtension` (or a plain constants class if it
never varies by tenant), so `EdgeInsets.all(12)` scattered through the app becomes
`AppSpacing.of(context).md`. Text scaling, touch targets and directional padding are
`frontend/flutter-ui`.

---

## 14. White-label branding built at runtime

**Rule: a white-label app builds `ThemeData` from tenant branding at runtime, behind a
provider, with a safe default when branding is absent, late or unparseable.**

Compile-time-per-tenant means N builds, N store listings and N release trains. Runtime
theming means one binary. What makes it survive contact with production is the default: the
branding call is a network response, so it can be missing, slow, or contain
`"primary": "not-a-colour"`, and none of those may produce a blank or unreadable app.

```dart
// lib/src/core/theme/tenant_theme.dart
ThemeData buildTenantTheme(Branding? branding, Brightness brightness) {
  final seed = _parseHex(branding?.seedColor) ?? AppPalette.seed;   // safe default
  final base = AppTheme.of(brightness, seed: seed);
  if (branding == null) return base;

  final status = base.extension<AppStatusColors>()!;
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      status.copyWith(success: _parseHex(branding.successColor) ?? status.success),
      base.extension<AppSpacing>()!,
    ],
  );
}

/// Returns null on anything unexpected. A tenant with a typo gets the default
/// theme, not a crash and not an invisible app.
Color? _parseHex(String? value) {
  if (value == null) return null;
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6 && hex.length != 8) return null;
  final parsed = int.tryParse(hex.padLeft(8, 'F'), radix: 16);
  return parsed == null ? null : Color(parsed);
}
```

| Branding state | Behaviour |
|---|---|
| Not yet fetched | Default theme, app usable — never a spinner over the whole app |
| Fetch failed | Last cached branding, else default |
| Field missing or unparseable | That field falls back; the rest of the branding still applies |
| Tenant switched | Theme rebuilds from the provider; no restart |

**Rule: the white-label path is covered by a golden under at least two tenant themes.** One
tenant proves nothing — the bug is a widget that ignored the theme, and it looks correct for
whichever tenant it was written against. Two different palettes over the same screen make it
obvious. `testing/flutter-test` owns golden mechanics (fonts loaded, frozen time, one
platform, zero pixel tolerance).

```dart
for (final tenant in [_acmeBranding, _globexBranding]) {
  testGoldens('order card — ${tenant.name}', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTenantTheme(tenant, Brightness.light),
      home: const OrderCard(...),
    ));
    await screenMatchesGolden(tester, 'order_card_${tenant.name}');
  });
}
```

---

## 15. Platform branching in widget code

**Rule: in widget code branch on `Theme.of(context).platform`. Where there is no context,
`defaultTargetPlatform`. Never the operating-system check from `dart:io`.**

Three reasons, in order of how much they cost:

1. **`Theme.of(context).platform` is overridable.** A widget test wraps the subject in a
   theme with `platform: TargetPlatform.iOS` and asserts the iOS branch. The `dart:io` check
   reads the *host* — so on a CI Linux runner every test takes the Android branch, and the
   iOS branch is never executed by any test you can write.
2. **It throws on web.** `dart:io` is unavailable there; the import fails to compile for a
   web target and the same code cannot ship to Flutter web at all.
3. **It respects the app's own override.** An app that sets `platform:` on its `ThemeData`
   — to give everyone Material behaviour, or to demo iOS on Android — is ignored by an OS
   check, so half the widgets obey it and half do not.

```dart
// ✅ lib/src/features/orders/presentation/widgets/share_button.dart
import 'package:flutter/material.dart';

class ShareButton extends StatelessWidget {
  const ShareButton({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share order',
      icon: const Icon(Icons.share),
      onPressed: () => _share(context),
    );
  }

  Future<void> _share(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        showCupertinoModalPopup<void>(context: context, builder: _cupertinoSheet),
      // Every other platform gets the Material sheet — a real screen, not a
      // no-op and not a throw. Linux, Windows, Fuchsia and web land here.
      _ => showModalBottomSheet<void>(context: context, builder: _materialSheet),
    };
  }
}
```

```dart
// ❌ the default answer: untestable, and it will not compile for web
import 'dart:io';
if (Platform.isIOS) { ... } else { ... }
```

**Rule: prefer an `.adaptive` constructor to a branch you write.** They already handle the
platform matrix, the default arm, and the "looks native" details.

| Instead of branching | Use |
|---|---|
| Cupertino vs Material switch | `Switch.adaptive` |
| Two dialogs | `showAdaptiveDialog` + `AlertDialog.adaptive` |
| Two spinners | `CircularProgressIndicator.adaptive` |
| Two sliders / checkboxes / radios | `Slider.adaptive`, `Checkbox.adaptive`, `Radio.adaptive` |
| Two scroll physics | The default — `ScrollConfiguration` already adapts |

**Rule: every branch has a real default arm.** A `switch` over `TargetPlatform` with only
`android` and `iOS` handled and a `throw` (or nothing) at the end is a crash on macOS,
Windows, Linux, Fuchsia and web — including the desktop debug run a developer uses on
Monday. Use `_ =>` with the branch that degrades best, usually Material.

`defaultTargetPlatform` is for code with no `BuildContext` — a provider, a repository, a
platform binding in `core/`. It is `debugDefaultTargetPlatformOverride`-able in tests, so it
keeps property (1).

```dart
// no context here; still testable
@riverpod
StoreLinks storeLinks(Ref ref) => switch (defaultTargetPlatform) {
      TargetPlatform.iOS => StoreLinks.appStore,
      TargetPlatform.android => StoreLinks.playStore,
      _ => StoreLinks.web,
    };
```

---

## 16. Native code behind an interface; Pigeon; `PlatformException`

**Rule: platform code sits behind an `abstract interface class` in `domain/` or `core/`,
bound at the composition root (§10). Callers never touch a channel.**

A widget or provider that calls a channel directly cannot be tested off-device, cannot be
compiled for a platform where the channel is unimplemented, and spreads
`PlatformException` handling across every call site.

```dart
// lib/src/core/platform/biometric_gateway.dart — the contract
abstract interface class BiometricGateway {
  Future<bool> isAvailable();
  Future<BiometricResult> authenticate({required String reason});
}
```

**Rule: channels are generated with Pigeon, never hand-written with `MethodChannel`.**

A `MethodChannel` is a stringly-typed RPC: the method name, the argument map keys and the
return shape are agreed by convention across three languages, and the compiler checks none
of it. Renaming a key on the Kotlin side is a runtime `null` on a device you did not test.
Pigeon generates the Dart, Kotlin and Swift from one declaration, so the same rename is a
compile error on all three sides.

```dart
// pigeons/biometrics.dart — the single source of truth, not shipped in the app
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/core/platform/generated/biometrics.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/example/app/Biometrics.g.kt',
  swiftOut: 'ios/Runner/Biometrics.g.swift',
))
class BiometricStatus {
  BiometricStatus({required this.available, required this.enrolled});
  final bool available;
  final bool enrolled;
}

@HostApi()
abstract class BiometricsHostApi {
  BiometricStatus status();
  bool authenticate(String reason);
}
```

Generated files are committed and regenerated in CI, with `git diff --exit-code` proving
they are current — that check is `ci/flutter-release` §9.

**Rule: `PlatformException` is caught at the binding and mapped to the app's error type. It
never escapes into `application/` or `presentation/`.**

`PlatformException.code` is a string agreed with the native side; leaking it means every
call site pattern-matches on strings, and the user sees `PlatformException(NO_ENROLLED, …)`.
The sealed hierarchy is `api-style/dio` §5; this layer only fixes where the conversion is.

```dart
// lib/src/core/platform/pigeon_biometric_gateway.dart
final class PigeonBiometricGateway implements BiometricGateway {
  PigeonBiometricGateway([BiometricsHostApi? api]) : _api = api ?? BiometricsHostApi();

  final BiometricsHostApi _api;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      return await _api.authenticate(reason)
          ? BiometricResult.success
          : BiometricResult.rejected;
    } on PlatformException catch (e, stackTrace) {
      throw switch (e.code) {
        'NO_ENROLLED' => const BiometricUnavailableError.notEnrolled(),
        'LOCKED_OUT' => const BiometricUnavailableError.lockedOut(),
        _ => PlatformBridgeError(e.code, stackTrace: stackTrace),
      };
    } on MissingPluginException catch (_) {
      // Desktop and web: the channel is not implemented at all.
      return BiometricResult.unsupported;
    }
  }
}
```

`MissingPluginException` is the one every implementation forgets. It is what a real device
throws when the plugin is not registered for that platform, and it is not a
`PlatformException` — an `on PlatformException` alone lets it through as a crash.

---

## 17. App size: budget, artifact, measurement

**Rule: the app has a size budget, it is checked in CI on the release artifact, and
exceeding it fails the build.**

Size regresses one dependency at a time and is never anyone's ticket. A budget converts an
invisible slow decline into a red check on the PR that caused it, while the person who added
the dependency is still looking at it. On a slow connection, download size is the largest
single term in install conversion.

| Rule | Why |
|---|---|
| Measure the **release** artifact | A debug APK is 2–3× larger and moves for unrelated reasons — a debug measurement is noise |
| Ship an **App Bundle** (`flutter build appbundle`) | Play delivers per-device ABI and density; a universal APK ships every ABI to every device, roughly doubling it |
| iOS: read App Store Connect's **App Thinning report** | The `.ipa` is not what a device downloads |
| Budget the download size, and record the install size too | The download number is the one that affects conversion |
| Enable R8 and resource shrinking, review the keep rules | Broad `-keep class **` rules undo the shrink silently |
| **Subset custom fonts** | A full CJK or variable font is megabytes; icon fonts are tree-shaken automatically in release |
| Compare against the base branch, not only the ceiling | A creep of 200 KB per PR never breaches a ceiling until it is too late to bisect |

```
# what CI measures — the workflow step itself is ci/flutter-release's file
flutter build appbundle --release --flavor prod --dart-define=FLAVOR=prod \
  --analyze-size --target-platform android-arm64
```

`--analyze-size` writes a JSON breakdown; open it in the DevTools app-size tool to see which
dependency, asset or font moved. Assets and fonts are usually the first two findings, native
libraries the third.

The budget belongs in the repo (a small JSON or YAML next to the workflow), not in a
person's memory, and raising it is a reviewed diff with a reason.

---

## 18. Monorepo: when a split is real

**Rule: stay in one package until a boundary is genuinely there. Split for a reason you can
name in one sentence.**

Multi-package Flutter repos are not free: every cross-package change is a coordinated set of
edits, tooling has to be taught to run everywhere, and a cycle in the graph is much harder to
undo than to create. Directories give most of the benefit at none of the cost — the feature
boundary in §3 is enforceable with a lint or a test inside one package.

| Reason to split | Real? |
|---|---|
| A second app (consumer + courier) shares domain and design system | Yes — the sharing is the boundary |
| A package is published, or consumed by a non-Flutter Dart target | Yes |
| A native plugin with its own platform code and its own release cadence | Yes |
| Build times — one team's changes rebuild everyone's tests | Sometimes; measure first |
| "Feature packages enforce boundaries" | No — a lint does that without the tax |
| "It looks more professional" | No |

**Rule: the graph is acyclic and shallow.** Depth two or three, never a chain of eight.

```
app_consumer   app_courier
      \           /
       core_ui  (design system, theme)
          |
      core_domain  (entities, contracts — no Flutter)
```

Nothing at a lower level imports a higher one. `core_domain` in particular has no Flutter
dependency, which is what lets it be tested with plain `dart test` in seconds.

**Rule: one command runs analyze, test and codegen across every package.** Melos or a
workspace script — the point is that a developer never has to know how many packages there
are, and CI runs exactly what a developer runs.

```yaml
# melos.yaml
scripts:
  analyze: melos exec -- flutter analyze --fatal-infos --fatal-warnings
  test: melos exec --dir-exists=test -- flutter test
  codegen: melos exec --depends-on=build_runner -- dart run build_runner build -d
```

Version internal packages by path, not by number: `core_domain: {path: ../core_domain}`.
Publishing internal packages to a registry to consume them within the same repo adds a
release step to every change and buys nothing.

---

## 19. Common mistakes

| Mistake | Why it hurts | Instead |
|---|---|---|
| `lib/models/`, `lib/screens/`, `lib/services/` | Every change touches four directories; nothing is deletable | Feature-first, four layers (§1) |
| A providers directory named `state/` | The `state/riverpod` globs miss it — no rules load, silently | The fixed four names (§1) |
| `Color` or `IconData` on a domain enum | Domain only runs in a widget test; theme cannot change it | Map in `presentation/` (§2) |
| A page constructing a `RestXService` | Not golden-testable; no offline decorator | Watch a provider (§2) |
| `import '…/profile/presentation/widgets/avatar.dart'` | Two features welded; neither is deletable | Promote to `core/widgets/` (§3) |
| Relative imports | Two library identities for one file; `is` checks fail | `package:` imports (§5) |
| `Widget _buildHeader()` | Rebuilds with the parent, never `const`, invisible in devtools | A widget class (§5) |
| Startup logic copied into each `main_*.dart` | Flavors drift; staging keeps the old startup | One `bootstrap` (§6) |
| `ensureInitialized()` before `runZonedGuarded` | Binding lands in the root zone; the guard catches nothing | Inside the zone (§7) |
| `PlatformDispatcher.instance.onError` returning `false` | The error also reaches the default handler | `return true` (§7) |
| Five sequential awaits before `runApp` | Seconds of splash the user cannot cancel | Parallel, and only what the frame needs (§8) |
| Remote config awaited in bootstrap | Cold start blocked on the network; no retry but a relaunch | `FutureProvider` (§8) |
| `try { await init(); } catch (_) {}` then `runApp` | Crashes later somewhere unrelated; report points at a screen | Failure screen with retry (§9) |
| Retry that pops or calls `setState` | Nothing re-runs; user taps forever | `onRetry` re-runs bootstrap (§9) |
| `late AppDatabase db;` assigned in bootstrap | A global; two tests in one process fight over it | `ProviderScope(overrides:)` (§10) |
| Dark theme "later" | Every widget since has to be audited by eye | Both from day one (§11) |
| `Colors.green` in a widget | Wrong in dark, wrong white-label, ungreppable as a set | `ThemeExtension` (§§11–12) |
| `lerp` returning `this` | Semantic colours snap while the app cross-fades | Real `Color.lerp` per field (§12) |
| Dark values derived by darkening the light ones | Contrast fails on the dark surface | Re-picked and contrast-tested (§12) |
| `MediaQuery.platformBrightnessOf` in a widget | Ignores the user's theme override | `Theme.of(context).brightness` (§11) |
| `TextStyle(fontSize: 16)` | Uncoordinated sizes; drifts to 13/14/15 | `textTheme.titleMedium` (§13) |
| Tenant theme with no default | One bad hex string from the API blanks the app | `_parseHex` returning null (§14) |
| One tenant in the goldens | The bug looks correct for the tenant it was written against | Two tenants (§14) |
| `Platform.isIOS` in a widget | Untestable on CI; will not compile for web; ignores the app override | `Theme.of(context).platform` (§15) |
| `switch` over `TargetPlatform` with no `_` arm | Crash or blank on desktop and web, including local debug runs | A real default arm (§15) |
| A hand-written `MethodChannel` | Stringly-typed across three languages; a rename is a runtime null | Pigeon `@HostApi` (§16) |
| `on PlatformException` only | `MissingPluginException` on desktop/web escapes as a crash | Catch both (§16) |
| Size measured on a debug build | The number is noise; the budget means nothing | Release artifact (§17) |
| Universal APK to the store | Every ABI on every device, roughly double | App Bundle (§17) |
| Package-per-feature from day one | Coordination tax with no boundary behind it | Directories plus a lint (§18) |

---

## 20. Never

- A `main_<flavor>.dart` containing anything but a call to `bootstrap`.
- `runApp` outside `runZonedGuarded`, or `ensureInitialized()` outside it.
- Fewer than three error channels installed.
- A swallowed startup failure followed by `runApp` of the real app.
- A concrete implementation constructed anywhere but the composition root.
- `Colors.*`, `Color(0x…)`, `fontSize:` or `fontFamily:` outside `core/theme/`.
- A `ThemeExtension` without `copyWith` and `lerp`.
- Shipping `theme:` without `darkTheme:`.
- `dart:io`'s platform check inside `lib/src/features/**/presentation/`.
- A platform `switch` with no default arm.
- A hand-written `MethodChannel` where Pigeon would do.
- A `PlatformException` reaching a widget.
- A relative import.
- A cycle in the package graph.
