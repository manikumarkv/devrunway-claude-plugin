---
name: flutter
description: Flutter app-shell standards — feature-first project structure with four layers per feature and inward dependencies, one shared bootstrap behind every flavor entrypoint, the three error channels, first-frame gating and a startup failure screen with retry, the composition root, ThemeData for light and dark with semantic colours as a ThemeExtension, white-label branding at runtime, platform branching that is overridable in tests, platform code behind an interface with Pigeon channels, the app size budget, and when to split a monorepo. Load when working with entrypoints, bootstrap, theme, app config, dependency wiring, pubspec, or any Dart file with no more specific layer.
user-invocable: false
stack: mobile/flutter
paths:
  - "**/main.dart"
  - "**/main_*.dart"
  - "**/bootstrap.dart"
  - "**/core/theme/*.dart"
  - "**/core/config/*.dart"
  - "**/core/di/*.dart"
  - "pubspec.yaml"
  - "**/lib/**/*.dart"
---

Full standards in [flutter.md](flutter.md). Always-on summary:

**Scope:** the app shell and the fallback for Dart files no other layer claims. Models are `language/dart-models`; services and errors `api-style/dio`; providers `state/riverpod`; widgets `frontend/flutter-ui`; routes `frontend/go-router`; session `auth/flutter-session`; stores `storage/flutter-local`; logger, crash reporter and flags `logging/flutter-observability`; tests `testing/flutter-test`; ARB `i18n/flutter-l10n`; build config, flavors and `analysis_options.yaml` `ci/flutter-release`; push `notifications/fcm`.

**Structure — feature-first, four layers per feature:**
- `lib/src/features/<feature>/{domain,data,application,presentation}/`, shared infrastructure in `lib/src/core/`.
- Dependencies point inward: `presentation → application → data → domain`. `domain/` imports no Flutter and nothing from the app.
- A feature never imports another feature's `presentation/` or `application/`. It depends on the other feature's abstract contract from `domain/`, bound at the composition root.
- Package imports only (`import 'package:app/...'`), never `../`. Files under ~400 lines; a `build` method under ~60.

**Bootstrap — one function, every entrypoint:**
- `lib/bootstrap.dart` exports one `bootstrap(...)`; each `main_<flavor>.dart` is a few lines that calls it. Nothing is duplicated per flavor.
- Everything runs inside `runZonedGuarded`, starting with `WidgetsFlutterBinding.ensureInitialized()`. Install `FlutterError.onError` and `PlatformDispatcher.instance.onError` too — all three, or a whole class of crash is lost.
- Await only what the first frame needs, and run those in parallel — `final (a, b, c) = await (openA(), openB(), openC()).wait;` (`Future.wait([...])` is the same thing; prefer the record form, it keeps the types). Anything slower — remote config, catalogue warm-up, migrations — goes behind a `FutureProvider` the screen that needs it watches.
- A required dependency that fails must not be swallowed: `runApp(StartupFailureApp(error: e, onRetry: _start))`, a screen naming what failed with a retry that re-runs bootstrap.
- `runApp(ProviderScope(overrides: [...], child: App()))` — the composition root is the `overrides` list, and it is the only place a concrete implementation is named.

**Theme — one definition, two brightnesses, shipped together:**
- `AppTheme.light` and `AppTheme.dark` are built from `ColorScheme.fromSeed(seedColor:, brightness:)` and both are passed to `MaterialApp` as `theme:`/`darkTheme:` with `themeMode:`. Material 3 only.
- `Colors.*` and `Color(0x…)` literals appear **only** inside `core/theme/`. Widgets read `Theme.of(context).colorScheme`. No literal `fontSize` outside the theme — widgets read `Theme.of(context).textTheme`.
- Colours with meaning (success, warning, danger, on-brand surfaces) are a `ThemeExtension` with `copyWith` and `lerp`, registered in `ThemeData(extensions:)`, defined once per brightness with contrast verified, and read as `Theme.of(context).extension<AppStatusColors>()!`.
- White-label: `ThemeData` built at runtime from tenant branding, with a safe default when branding is missing or unparseable, covered by a golden under two tenant themes.

**Platform:**
- In widget code branch on `Theme.of(context).platform`; where there is no context, `defaultTargetPlatform`. Both are overridable in a test and defined on web — the `dart:io` operating-system check is neither.
- Use `.adaptive` constructors first. Every branch is a `switch` with a real `_ =>` arm, so Linux, Windows, macOS, Fuchsia and web get a working screen, not a crash or a blank.
- Native code sits behind an `abstract interface class` bound at the composition root; channels are generated with Pigeon (`@HostApi`), never hand-written; `PlatformException` is mapped to the app's error type at that boundary.

**Size and packages:** a release-artifact size budget enforced in CI, App Bundle not universal APK, fonts subset. Split into packages only for a real boundary — the graph stays acyclic and shallow, with one command running analyze, test and codegen across all of it.

**Related:** `ci/flutter-release`, `frontend/flutter-ui`, `state/riverpod`, `logging/flutter-observability`, `testing/flutter-test`.
