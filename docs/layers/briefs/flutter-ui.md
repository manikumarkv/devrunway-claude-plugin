# Brief — `frontend/flutter-ui`

**Kind:** layer · **Issue:** #2 · **Cookbook:** `#page`, `#component`, `#designsystem`, `#motion`, `#form`, `#wizard`, `#search`, `#webview`

The largest layer. Consider splitting into `flutter-ui` (pages, components, design system,
motion) and `flutter-forms` (forms, wizards, search) if the detail file exceeds ~400 lines.

## Globs
```yaml
paths:
  - "**/presentation/pages/*.dart"
  - "**/presentation/widgets/*.dart"
  - "**/core/widgets/*.dart"
```

## Rules to encode
1. **Pages** take IDs and primitives, watch providers, render four real states — skeleton,
   error *with a retry that re-fetches*, empty distinct from loaded, data. No business logic.
2. Any list that can exceed a screen uses a lazy builder. `shrinkWrap` +
   `NeverScrollableScrollPhysics` means a sliver was the answer.
3. No work in `build` — no sorting, filtering, parsing, date formatting. Derive in a provider.
4. `ref.listen` for snackbars and navigation; watching them double-fires on rebuild.
5. Guard context after every `await` with `if (!context.mounted) return;`.
6. **Components** take data and callbacks. Never a `WidgetRef`, never a fetch of their own —
   N cards must not mean N requests, and a fetching component cannot be golden-tested.
7. `const` constructor + `super.key` on every widget.
8. Accessible name on every interactive element; `tooltip` on icon-only buttons;
   `ExcludeSemantics` on decorative images; `MergeSemantics` so a card announces once.
9. 48×48dp minimum touch target; no fixed-height boxes around text; survives 200% text scale.
10. `EdgeInsetsDirectional` and `start`/`end` from the first screen.
11. **Design system:** promote on the third use, not the first. Shared components know no
    domain. Variants are enums, not boolean flags.
12. **Motion:** honour `MediaQuery.disableAnimationsOf`; implicit animations by default;
    animate transform and opacity, not layout; durations and curves are theme tokens.
13. **Forms:** dispose every controller and focus node; submit disabled while in flight;
    localized validators from a shared `Validators`; `textInputAction` + `autofillHints`.
14. **Wizards:** one draft object, steps derived from it, draft persisted on every change.
15. **Search:** debounce and cancel superseded requests so an out-of-order response cannot win.
16. **WebView:** allowlist navigation; never a login form in an embedded WebView; never
    inject a token — hand over a short-lived exchange code.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | A list screen for programs | `.when(`, `ListView.builder`, `onRetry` | `ListView(children:` |
| 02 | A reusable program card | `const`, `required this.program`, `VoidCallback` | `WidgetRef`, `ref.watch` |
| 03 | An icon-only filter button | `tooltip:` | bare `IconButton(icon:` with no tooltip |
| 04 | A contact form with email + submit | `dispose()`, `context.mounted`, `validator:` | missing `dispose` |
| 05 | A search field backed by a provider | `Duration(milliseconds:`, `CancelToken` | direct call per keystroke |

## Boundaries
Colors and type come from `mobile/flutter`'s theme rules. Navigation is `frontend/go-router`.
Provider shape is `state/riverpod`.
