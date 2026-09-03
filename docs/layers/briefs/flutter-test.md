# Brief — `testing/flutter-test`

**Kind:** layer · **Issue:** #13 (parent #2) · **Cookbook:** `#tests`, `#goldens`, `#e2e`, `#contract`, `#perfbudget`

## Globs
```yaml
paths:
  - "**/test/**/*.dart"
  - "**/integration_test/**/*.dart"
  - "**/*_test.dart"
```

## Rules to encode
1. Build the harness first: a `ProviderContainer` with fake services, a seeded config, an
   in-memory cache, and a `pumpApp` wrapping in `ProviderScope` + theme + localizations.
   Apps end up untested because nothing was substitutable, not from indifference.
2. Mock at the **service interface**, never the HTTP client. Tests that stub raw responses
   couple to the wire format and break on refactors that changed no behaviour.
3. Test type per layer: models → unit (round-trip, missing fields, unknown enum, malformed);
   notifiers → container (transitions, error path, disposal cancels in-flight work);
   screens → widget (four states, semantics); design system → golden; journeys → integration.
4. Every screen test covers loading, error with a working retry, empty, and data.
5. Coverage reported per PR with a floor that only rises.
6. Delete the generated `widget_test.dart` counter scaffold.
7. **Goldens:** load fonts explicitly; freeze time, randomness, images, animations. Generate
   and verify on one platform (a container) — font rasterization differs between macOS and
   Linux. Light, dark and 200% text minimum. Zero pixel tolerance. Diffs reviewed as images.
8. **E2E:** a handful of journeys, not thirty. Seeded and torn down test data on a dedicated
   environment; never production. Wait on conditions, never durations. Flakes quarantined and
   fixed or deleted. Runs on merge and nightly, never in the PR gate.
9. **Contract:** schema versioned and committed; models generated from it where published; a
   scheduled job diffs committed against deployed; fixtures come from the spec's examples;
   unknown fields ignored and unknown enums fall back, with a test proving it.
10. **Perf budgets:** profile mode, physical device, one pinned baseline device; absolute
    ceilings *and* per-PR deltas; on merge and nightly, not in the gate.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Test a list screen's four states | `pumpApp`, `overrides:`, `findsOneWidget` | `MockDio`, raw HTTP stub |
| 02 | Test a notifier's error path | `ProviderContainer`, `AsyncError` | testing via a widget |
| 03 | A golden for a card component | `loadAppFonts`, `dark`, text-scale scenario | a tolerance threshold |
| 04 | Assert an unknown enum value parses | `unknown`, `fromJson` | expecting a throw |

## Boundaries
What is *tested* comes from every other layer. This layer owns only how.
