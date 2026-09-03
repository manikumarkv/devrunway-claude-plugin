# Brief — `mobile/flutter`

**Kind:** layer · **Issue:** #15 (parent #2) · **Cookbook:** `#skeleton`, `#bootstrap`, `#theme`, `#platform`, `#appsize`, `#monorepo`

The **only** layer permitted a broad fallback glob, because something must answer for a Dart
file in no recognised directory. Keep the specific globs first so more precise layers win
the dispatcher's specificity ordering.

## Globs
```yaml
paths:
  - "**/main.dart"
  - "**/bootstrap.dart"
  - "**/core/theme/*.dart"
  - "**/core/config/*.dart"
  - "pubspec.yaml"
  - "**/lib/**/*.dart"      # fallback — no other layer may do this
```

## Rules to encode
1. **Structure:** feature-first; four layers inside each feature (`domain`, `data`,
   `application`, `presentation`); shared infra in `core/`. Dependencies point inward;
   domain imports nothing from the app and no Flutter. Features never import each other's
   widgets, pages or providers — only the other feature's abstract service, through DI.
   Package imports only. Files under ~400 lines, `build` under ~60.
2. **Bootstrap:** one `bootstrap` shared by every flavor entrypoint; all three error channels
   installed; block only on what the first frame needs; slow init behind a provider the UI
   watches; parallelize with `Future.wait`; flavor and API host as crash keys.
3. A failed startup dependency renders a screen naming what failed, with retry — never a
   silent continue.
4. **Theme:** `Colors.*` only inside the theme definition; everything else reads
   `colorScheme`. No literal `fontSize` outside the theme. Semantic colors are a
   `ThemeExtension` with light and dark variants and verified contrast. Light and dark ship
   together. White-label branding builds `ThemeData` at runtime with a safe default and is
   covered by a golden under two tenant themes.
5. **Platform:** branch on `Theme.of(context).platform` / `defaultTargetPlatform`, never
   `Platform.isIOS` in widget code — the former is overridable in tests and safe on web.
   Prefer `.adaptive` constructors. Every branch has a real default for untargeted
   platforms. Platform code sits behind an interface bound at the composition root.
   Channels generated with Pigeon. `PlatformException` mapped to the typed error hierarchy.
6. **App size:** budget checked in CI on release builds; App Bundle not universal APK; R8 and
   resource shrinking with reviewed keep rules; fonts subset; measured on the release artifact.
7. **Monorepo:** split only when the boundary is real; acyclic and shallow graph; one command
   runs analyze/test/codegen across packages.

## Eval cases
*Assertions below are sketches of intent, not literal strings. Replace any prose
with a discriminating code token — see AUTHORING.md section 6.*

| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | App entrypoint with error capture and startup gating | `runZonedGuarded`, `PlatformDispatcher`, `ProviderScope` | awaiting five inits before `runApp` |
| 02 | A status badge coloured by state | `Theme.of(context)`, `extension<` | `Colors.green` |
| 03 | Platform-specific share behaviour | `defaultTargetPlatform`, `TargetPlatform.iOS` | `Platform.isIOS` |
| 04 | Where a new feature's files go | `domain/`, `data/services/`, `application/providers/`, `presentation/` | flat `lib/` layout |

## Boundaries
This layer is the fallback. Anything matching a role-specific layer belongs there instead.
