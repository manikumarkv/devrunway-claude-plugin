---
name: flutter-ui
description: Flutter widget standards — page shape and the four real states, lazy lists and slivers, no work in build, ref.listen for side effects, context.mounted after await, dumb components, semantics and touch targets, RTL-safe padding, design-system promotion, motion tokens, forms and controller disposal, wizard drafts, debounced search, and WebView allowlisting. Load when writing or reviewing pages, widgets, forms, or shared UI components.
user-invocable: false
stack: frontend/flutter-ui
paths:
  - "**/presentation/pages/*.dart"
  - "**/presentation/widgets/*.dart"
  - "**/core/widgets/*.dart"
---

Full standards in [flutter-ui.md](flutter-ui.md). Always-on summary:

**Scope:** the widget tree. Colors, typography and spacing tokens are `mobile/flutter` (theme); route declaration and navigation are `frontend/go-router`; provider shape is `state/riverpod`.

**Pages** (`ConsumerWidget` / `ConsumerStatefulWidget`) take ids and primitives, never models:
- Render four real states via `.when(data:, error:, loading:)` — skeleton, error, empty, data. `data:` branches on `isEmpty` before building the list.
- The error branch has a retry that **re-fetches**: `onPressed: () => ref.invalidate(xProvider)`. A retry that only pops is not a retry.
- No business logic, no sorting, filtering, parsing or date formatting in `build` — derive it in a provider.
- Any list that can exceed a screen uses `ListView.builder` / `SliverList`. `shrinkWrap: true` + `NeverScrollableScrollPhysics()` means a sliver was the answer.
- `ref.listen` for snackbars and navigation; `ref.watch` of them double-fires on rebuild.
- After every `await` in a callback: `if (!context.mounted) return;`.

**Components** (`presentation/widgets/`, `core/widgets/`) take data and callbacks:
- Never a `WidgetRef`, never `ConsumerWidget`, never a fetch of their own — N cards must not mean N requests, and a fetching component cannot be golden-tested.
- `const` constructor and `super.key` on every widget; `required this.x` for data, `VoidCallback` / `ValueChanged<T>` for events.
- `tooltip:` on every icon-only button; `ExcludeSemantics` around decorative images; `MergeSemantics` so a card announces once.
- 48×48dp minimum touch target; no fixed-height box around text; survives 200% text scale (`TextScaler`, never `textScaleFactor`).
- `EdgeInsetsDirectional` with `start`/`end`, `AlignmentDirectional`, `PositionedDirectional` — from the first screen, not at localisation time.

**Design system:** promote to `core/widgets/` on the third use, not the first. A shared component knows no domain type. Variants are an `enum`, never boolean flags.

**Motion:** honour `MediaQuery.disableAnimationsOf(context)`; implicit animations (`AnimatedOpacity`, `AnimatedSlide`) by default; animate transform and opacity, not layout; durations and curves come from theme tokens.

**Forms:** every `TextEditingController` and `FocusNode` created in `initState` is disposed in `dispose()`. Submit is disabled while in flight. Validators come from the shared `Validators` class (localized) — never an inline `RegExp`. Set `textInputAction` on every field, and `autofillHints` on every field that maps to a known autofill category.

**Wizards:** one immutable draft object, steps derived from it, draft persisted on every change.

**Search:** debounce with a cancellable `Timer(const Duration(milliseconds: 300), …)` — never `await Future.delayed`. Cancel the superseded request with a `CancelToken` so an out-of-order response cannot win. Never filter client-side in `build`.

**WebView:** `onNavigationRequest` allowlists by `uri.host` and returns `NavigationDecision.prevent` otherwise. Never a login form in an embedded WebView. Never inject a token — no `Authorization` header, no `runJavaScript` — hand over a short-lived exchange code in the URL.

**Related:** `mobile/flutter`, `frontend/go-router`, `state/riverpod`, `i18n/flutter-l10n`, `testing/flutter-test`.
