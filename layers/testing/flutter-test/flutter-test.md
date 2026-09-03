# Flutter Testing Standards

How a Flutter app is tested: the harness every test is built on, which kind of test each layer
gets, and the four specialised suites — goldens, contract tests, integration journeys and
performance budgets — with the CI wiring that makes them mean something.

**Scope boundaries.** This layer owns *how*. *What* is tested comes from the layer that owns
the thing. It does not define the **service contract** — `abstract interface class`, `Cached<T>`,
`CancelToken` on every method and the `AppError` hierarchy are `api-style/dio`; here the
contract is only the seam a fake is written against. It does not define **provider shape or
lifetime** — auto-dispose, `ref.onDispose`, `AsyncValue`, `AsyncValue.guard` and `Paged<T>` are
`state/riverpod`; here they are what a container test asserts on. It does not define the **four
screen states** — that is `frontend/flutter-ui`; here it is the checklist a screen test must
cover. Model shape, `@JsonKey(unknownEnumValue: ...)` and the `unknown` enum member are
`language/dart-models`. The pipeline that runs these suites is `ci/flutter-release`.

Sections are independent. Read the one you need.

| § | Concern |
|---|---|
| 1 | The harness, and why it comes first |
| 2 | Which test for which layer |
| 3 | Substituting at the service interface |
| 4 | Model unit tests |
| 5 | Notifier container tests |
| 6 | Screen widget tests — the four states |
| 7 | Golden tests |
| 8 | Consumer-driven contract tests |
| 9 | Integration journeys |
| 10 | Performance budgets |
| 11 | Coverage, CI wiring and the flake policy |
| 12 | Common mistakes |

---

## 1. The harness, and why it comes first

**Rule: the test harness is written before the first test, and it is the first thing written
in a new app.**

Apps end up untested because nothing was substitutable, not from indifference. When the first
test costs a day — stand up a fake service, work out how to override a provider, discover the
screen needs localizations, discover the cache writes to real disk — the developer writes no
test, and the second developer writes no test because there is still no example. The harness
is what makes the *second* test cost ten minutes.

```
test/
  flutter_test_config.dart      loads fonts once for every test in the run
  support/
    harness.dart                pumpApp + createContainer
    golden.dart                 loadAppFonts + the golden scenario matrix
    clock.dart                  the frozen instant every test shares
    fakes/
      fake_program_service.dart hand-written, implements the contract
      in_memory_cache_store.dart
      recording_logger.dart
    fixtures/                   JSON copied from the contract spec's examples
  features/
    programs/
      program_test.dart              model, unit
      programs_controller_test.dart  notifier, container
      program_list_page_test.dart    screen, widget
  design_system/
    program_card_golden_test.dart
integration_test/
  enrolment_journey_test.dart
```

### 1.1 `createContainer` — the container half

```dart
// test/support/harness.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A container with every ambient dependency already faked.
/// Pass [overrides] for the one or two providers the test is actually about.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(
    overrides: <Override>[
      appConfigProvider.overrideWithValue(seededTestConfig),
      clockProvider.overrideWithValue(fixedTestClock),
      programCacheStoreProvider.overrideWithValue(InMemoryProgramCacheStore()),
      appLoggerProvider.overrideWithValue(RecordingLogger()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}
```

Four things the defaults buy, all of which are otherwise re-litigated in every test file:

| Default override | What it prevents |
|---|---|
| `appConfigProvider` seeded | A test reading `--dart-define` values that only exist in CI |
| `clockProvider` fixed | "Expires tomorrow" passing until the suite runs at 23:59 |
| Cache store in memory | Tests that pass alone and fail in a batch because state leaked through disk |
| Logger recording | Console noise, and a crash reporter initialised in a unit test |

`addTearDown(container.dispose)` is not optional. A leaked container keeps its timers,
subscriptions and `CancelToken`s alive into the next test — see `state/riverpod` §11.

### 1.2 `pumpApp` — the widget half

**Rule: no widget test calls `tester.pumpWidget` directly. It calls `pumpApp`.**

A screen needs a `ProviderScope`, the app theme, the localization delegates and a router-free
`MaterialApp` wrapper. Written at each call site, three of the four get forgotten and the
fourth is spelled differently every time; a missing delegate surfaces as a null-check crash
inside `AppLocalizations.of(context)!` that reads like a bug in the screen.

```dart
// test/support/harness.dart
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget child, {
    List<Override> overrides = const [],
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(seededTestConfig),
          clockProvider.overrideWithValue(fixedTestClock),
          programCacheStoreProvider.overrideWithValue(InMemoryProgramCacheStore()),
          appLoggerProvider.overrideWithValue(RecordingLogger()),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: textScaler),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

`pumpApp` is the single place a new ambient dependency gets wired. When the app gains a
feature-flag client, one file changes, not two hundred test files.

### 1.3 Delete the counter scaffold

**Rule: `test/widget_test.dart` — the generated "Counter increments smoke test" — is deleted in
the first commit of the project.**

It tests Flutter's own counter demo, not the app. Kept, it makes `flutter test` green while the
app has no coverage at all, which is worse than a red suite: a green badge stops anyone asking.
Its presence in a repo is a reliable signal that the suite was never started.

---

## 2. Which test for which layer

**Rule: each layer has exactly one default test type. Reaching for a heavier one is a
decision, not a habit.**

| Subject | Test type | Runs in | Must cover |
|---|---|---|---|
| Model / DTO | unit (`test`) | ms | round-trip, missing optional fields, unknown enum value, malformed payload |
| Pure function, formatter, validator | unit | ms | the boundary cases, not the happy path twice |
| Service implementation | unit against a fake client | ms | error mapping, cancellation, cache fallback |
| Notifier / controller | `ProviderContainer` | ms | transitions, error path, disposal cancels in-flight work |
| Screen / page | widget | tens of ms | loading, error + working retry, empty, data, semantics |
| Design-system component | golden | tens of ms | light, dark, 200% text |
| Route guard / redirect | widget with a real router | tens of ms | each guarded transition (`frontend/go-router`) |
| User journey | integration | seconds–minutes | 5–8 journeys total, no more |

The cost gradient is real: a unit test is ~1 ms, a widget test ~30 ms, an integration test
~30 s. **Push each assertion to the cheapest layer that can make it.** "Does the enrol button
enable for an eligible user" is a notifier test, not a journey — and it is the notifier test
that will still be readable in a year.

**A test that needs the widget tree to assert business logic is telling you the logic is in the
widget.** Move it to a provider (`state/riverpod`) and the test gets cheaper for free.

---

## 3. Substituting at the service interface

**Rule: substitute the service contract. Never stub the HTTP client, the adapter, or a raw
response body.**

```dart
// ✅ the seam is the contract from api-style/dio
final class FakeProgramService implements ProgramService {
  FakeProgramService({this.pages = const [], this.failures = const []});

  final List<List<Program>> pages;
  final List<AppError> failures;

  int callCount = 0;
  CancelToken? lastCancelToken;

  @override
  Future<Cached<List<Program>>> fetchPrograms({
    required int page,
    CancelToken? cancelToken,
  }) async {
    lastCancelToken = cancelToken;
    final index = callCount++;
    if (index < failures.length) throw failures[index];
    return Cached<List<Program>>(
      value: pages.isEmpty ? const [] : pages[index.clamp(0, pages.length - 1)],
      fetchedAt: fixedTestClock.now(),
      isStale: false,
    );
  }

  @override
  Future<Program> fetchProgram(String id, {CancelToken? cancelToken}) async {
    lastCancelToken = cancelToken;
    return pages.expand((p) => p).firstWhere((p) => p.id == id);
  }
}
```

```dart
// ❌ what a competent developer writes by default
final adapter = DioAdapter(dio);
adapter.onGet('/programs', (server) => server.reply(200, {'data': [ ... ]}));
```

Why the second one fails, concretely. It encodes the wire format — the path, the envelope key,
the field names — into the *test*. Then:

- The backend renames `data` to `items` and ships a compatible change. Forty tests go red, none
  of which is about pagination envelopes.
- A refactor moves pagination from a query parameter to a cursor header. Every test breaks and
  none of them was testing pagination.
- The service starts returning `Cached<T>` with staleness. The stub has no way to express
  stale, so no test covers the stale path.
- Conversely, a genuine break — the service now throws `ServerError` where it threw
  `NetworkError` — is invisible, because the stub was replying `200` all along.

The contract is the thing the feature depends on. Test against the thing the feature depends on.

**Fakes over mocks, by default.** A hand-written fake is a small class you can read; a
`when(...).thenAnswer(...)` chain re-states the contract in a DSL and drifts from it silently. Use
`mocktail` where you genuinely need call verification on a wide interface, and even then type it
as `implements ProgramService` so a contract change is a compile error rather than a runtime null.

**Where the HTTP layer itself is the subject** — the interceptors, the retry policy, the error
mapping in `api-style/dio` — a transport-level fake is correct, because there the wire format
*is* the behaviour under test. That is one file, not the whole suite.

---

## 4. Model unit tests

**Rule: every model gets four tests — round-trip, missing optional fields, unknown enum value,
malformed payload.** Model shape itself is `language/dart-models`; this is the coverage
contract for it.

```dart
void main() {
  group('Program', () {
    test('round-trips through JSON', () {
      final json = fixture('program.json');
      expect(Program.fromJson(json).toJson(), equals(json));
    });

    test('parses when every optional field is absent', () {
      final json = fixture('program.json')
        ..remove('startsAt')
        ..remove('tags');
      final program = Program.fromJson(json);
      expect(program.startsAt, isNull);
      expect(program.tags, isEmpty);
    });

    test('a status the app does not know degrades to unknown', () {
      final json = fixture('program.json')..['status'] = 'suspended';
      expect(Program.fromJson(json).status, ProgramStatus.unknown);
    });

    test('a malformed payload fails at the boundary', () {
      final json = fixture('program.json')..['id'] = 42;
      expect(() => Program.fromJson(json), throwsA(isA<TypeError>()));
    });
  });
}
```

The round-trip test is the one people skip and the one that catches the most. It fails the day
someone adds a field to the constructor and forgets the `@JsonKey`, which otherwise surfaces as
data silently dropped on the next write.

**Fixtures are shared with §8** — one `test/support/fixtures/program.json`, copied from the
contract spec's example, read by both the model tests and the contract tests. Two divergent
copies of "what the server sends" is how a suite passes against a payload the server stopped
sending.

---

## 5. Notifier container tests

**Rule: a notifier is tested with a `ProviderContainer` and overrides. No widget tree, no
pumping a frame.** The container API and provider lifetime rules are `state/riverpod` §11; this
section is what the test must assert.

Three things every notifier test covers.

### 5.1 The transitions

```dart
test('loads the first page', () async {
  final container = createContainer(overrides: [
    programServiceProvider.overrideWithValue(
      FakeProgramService(pages: [[program(id: 'p_1')]]),
    ),
  ]);

  expect(container.read(programsControllerProvider), isA<AsyncLoading<Paged<Program>>>());

  final value = await container.read(programsControllerProvider.future);

  expect(value.items, hasLength(1));
  expect(container.read(programsControllerProvider), isA<AsyncData<Paged<Program>>>());
});
```

### 5.2 The error path

**Rule: the error path asserts the `AsyncError` *and* the error type, never just "it failed".**

```dart
test('surfaces a network failure as AsyncError', () async {
  final container = createContainer(overrides: [
    programServiceProvider.overrideWithValue(
      FakeProgramService(failures: [const NetworkError()]),
    ),
  ]);

  await expectLater(
    container.read(programsControllerProvider.future),
    throwsA(isA<NetworkError>()),
  );

  final state = container.read(programsControllerProvider);
  expect(state, isA<AsyncError<Paged<Program>>>());
  expect(state.error, isA<NetworkError>());
});
```

Asserting only `isA<AsyncError>` passes when the notifier swallows a `NetworkError` and
re-throws `Exception('failed')` — which is exactly the change that turns a retryable "you're
offline" into an unretryable "something went wrong", and the crash reporter into a firehose
(`api-style/dio` `isReportable`).

### 5.3 Disposal cancels in-flight work

**Rule: every notifier that starts a request has a test proving the request is cancelled when
the provider is disposed.** This is the assertion that keeps `ref.onDispose` from being deleted
by someone tidying up.

```dart
test('disposing the container cancels the in-flight request', () async {
  final service = FakeProgramService(pages: [[program(id: 'p_1')]]);
  final container = createContainer(overrides: [
    programServiceProvider.overrideWithValue(service),
  ]);

  unawaited(container.read(programsControllerProvider.future));
  await pumpEventQueue();          // let build() reach its first await
  container.dispose();

  expect(service.lastCancelToken, isNotNull);
  expect(service.lastCancelToken!.isCancelled, isTrue);
});
```

The fake recording `lastCancelToken` (§3) is what makes this expressible. Without the
cancellation, leaving a screen mid-request holds the socket open, resolves into a disposed
provider, and — on a list the user scrolls in and out of quickly — stacks up a dozen live
requests the user will never see.

`addTearDown(container.dispose)` in `createContainer` makes the explicit `container.dispose()`
here idempotent; disposing twice is safe and the tear-down still runs.

---

## 6. Screen widget tests — the four states

**Rule: every screen backed by async data has four tests: loading, error with a retry that
re-fetches, empty, and data.** The states themselves are `frontend/flutter-ui` §2; this is the
proof they exist.

Three of the four are routinely skipped, and each omission has a signature production bug:

| Skipped state | The bug it lets through |
|---|---|
| Loading | A spinner over a blank screen, or a flash of the empty state before data arrives |
| Error | A retry button that pops the route instead of re-running the request |
| Empty | The empty state rendering as a zero-height list — a screen that looks broken |

```dart
void main() {
  group('ProgramListPage', () {
    testWidgets('renders a skeleton while loading', (tester) async {
      final completer = Completer<Cached<List<Program>>>();
      await tester.pumpApp(
        const ProgramListPage(schoolId: 's_1'),
        overrides: [
          programServiceProvider.overrideWithValue(PendingProgramService(completer)),
        ],
      );
      await tester.pump();

      expect(find.byType(ProgramListSkeleton), findsOneWidget);
      expect(find.byType(ProgramCard), findsNothing);
    });

    testWidgets('renders the empty state when there are no programs', (tester) async {
      await tester.pumpApp(
        const ProgramListPage(schoolId: 's_1'),
        overrides: [
          programServiceProvider.overrideWithValue(FakeProgramService(pages: [[]])),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.byType(ProgramCard), findsNothing);
    });

    testWidgets('renders the programs when data arrives', (tester) async {
      await tester.pumpApp(
        const ProgramListPage(schoolId: 's_1'),
        overrides: [
          programServiceProvider.overrideWithValue(
            FakeProgramService(pages: [[program(id: 'p_1', name: 'Beginner Ballet')]]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Beginner Ballet'), findsOneWidget);
    });

    testWidgets('the error state retry re-runs the request', (tester) async {
      final service = FakeProgramService(
        failures: [const NetworkError()],
        pages: [[], [program(id: 'p_1', name: 'Beginner Ballet')]],
      );
      await tester.pumpApp(
        const ProgramListPage(schoolId: 's_1'),
        overrides: [programServiceProvider.overrideWithValue(service)],
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);

      await tester.tap(find.byKey(const Key('error_state_retry')));
      await tester.pumpAndSettle();

      expect(service.callCount, 2);                       // it actually re-fetched
      expect(find.text('Beginner Ballet'), findsOneWidget);
      expect(find.byType(ErrorStateView), findsNothing);
    });
  });
}
```

**Rule: the retry test asserts the service was called again, not merely that the error view is
gone.** A retry implemented as `Navigator.pop` makes the error view disappear and passes a test
that only looks at the widget tree. `expect(service.callCount, 2)` is the whole point of the case.

### 6.1 Semantics

**Rule: every screen test asserts the semantics of the controls a screen-reader user needs.**
Accessibility that is not asserted regresses on the next redesign.

```dart
testWidgets('meets the accessibility guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpApp(const ProgramListPage(schoolId: 's_1'), overrides: [...]);
  await tester.pumpAndSettle();

  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  expect(find.bySemanticsLabel('Enrol in Beginner Ballet'), findsOneWidget);
  handle.dispose();
});
```

`labeledTapTargetGuideline` is the one that catches the icon-only button with no tooltip, which
a sighted reviewer never notices.

### 6.2 Finders

| Prefer | Over | Why |
|---|---|---|
| `find.byType(ErrorStateView)` | `find.text('Something went wrong')` | Survives a copy change and works in every locale |
| `find.bySemanticsLabel(...)` | `find.byIcon(Icons.refresh)` | Asserts what the user perceives |
| `find.byKey(const Key('error_state_retry'))` | `find.widgetWithText(ElevatedButton, 'Retry')` | Stable when the button becomes a `TextButton` |

Keys are for test targets that have no other stable identity. A screen where every widget has a
key has keys as a substitute for structure.

---

## 7. Golden tests

Goldens exist to catch the visual regression no assertion describes: the padding that halved,
the colour that no longer meets contrast in dark mode, the label that overflows at 200% text.
They are worth having only if they are deterministic — a flaky golden gets `--update-goldens`
run on it, and from that moment it asserts nothing.

### 7.1 Load the fonts

**Rule: fonts are loaded explicitly, once, in `flutter_test_config.dart`.**

Without it the test binding uses Ahem, a font whose every glyph is a filled box. The golden is
then a picture of boxes: it is stable, it passes, and it cannot detect a text regression of any
kind.

```dart
// test/flutter_test_config.dart — flutter_test runs this around the whole suite
import 'dart:async';
import 'support/golden.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  return testMain();
}
```

```dart
// test/support/golden.dart
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifest = (json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
```

`golden_toolkit` provided a `loadAppFonts()` and is no longer maintained. Keep the same entry
point name in `test/support/golden.dart` whether it comes from a package or from the twenty
lines above, so swapping the implementation is not a suite-wide rename.

### 7.2 Freeze everything that moves

**Rule: a golden test pins the clock, the random seed, image loading and animations. Anything
left un-frozen is a future flake.**

| Source of drift | Freeze it with |
|---|---|
| `DateTime.now()` | `clockProvider` overridden to `fixedTestClock` (§1.1) — never call `now()` in a widget |
| `Random()` | A seeded `Random(42)` behind a provider |
| Network images | An override serving bytes from `test/support/fixtures/`; a real `NetworkImage` renders as empty in tests |
| Animations | Pump a fixed duration, never `pumpAndSettle` on a repeating animation — it never settles |
| Device size / DPR | `tester.view.physicalSize` and `devicePixelRatio` set explicitly, with `addTearDown(tester.view.reset)` |

### 7.3 The scenario matrix

**Rule: every component golden covers at minimum light, dark, and 200% text scale.**

Dark mode and large text are where design systems actually break, and both are invisible in a
single default-scenario golden.

```dart
@Tags(['golden'])
library;

void main() {
  const scenarios = <GoldenScenario>[
    GoldenScenario('light', themeMode: ThemeMode.light, textScale: 1.0),
    GoldenScenario('dark', themeMode: ThemeMode.dark, textScale: 1.0),
    GoldenScenario('dark_text_200', themeMode: ThemeMode.dark, textScale: 2.0),
  ];

  for (final scenario in scenarios) {
    testWidgets('ProgramCard — ${scenario.name}', (tester) async {
      tester.view
        ..physicalSize = const Size(1170, 800)
        ..devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        Center(
          child: ProgramCard(program: program(id: 'p_1'), onTap: () {}),
        ),
        themeMode: scenario.themeMode,
        textScaler: TextScaler.linear(scenario.textScale),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProgramCard),
        matchesGoldenFile('goldens/program_card_${scenario.name}.png'),
      );
    });
  }
}
```

Add an RTL scenario (`locale: Locale('ar')`) for any component with directional padding, and a
narrow-width scenario for anything that wraps.

### 7.4 One platform, zero tolerance

**Rule: goldens are generated and verified inside the same container image, and nowhere else.**

Font rasterization, subpixel positioning and anti-aliasing differ between macOS and Linux — the
same widget produces images that differ in thousands of pixels on two machines that are both
correct. A suite whose goldens were captured on a designer's Mac fails permanently in CI, and
the fix that gets applied is to loosen the comparison, which ends the value of the suite.

```makefile
# generate — the ONLY sanctioned way to update a golden
goldens-update:
	docker run --rm -v $(PWD):/app -w /app $(FLUTTER_IMAGE) \
	  flutter test --tags golden --update-goldens

# verify — what CI runs
goldens-verify:
	docker run --rm -v $(PWD):/app -w /app $(FLUTTER_IMAGE) \
	  flutter test --tags golden
```

`$(FLUTTER_IMAGE)` is pinned by digest, not by tag. A `:stable` tag that moves re-rasterizes
every golden in the repo on an unrelated Tuesday.

Locally, developers run `flutter test --exclude-tags golden`, so a wrong-platform golden failure
is never something anyone has to learn to ignore.

**Rule: zero pixel difference. A golden matches the committed image exactly or the test fails.**

A "0.5% of pixels may differ" allowance is calibrated to nothing. It is above the noise floor of
a single-platform suite (which is zero) and below a real regression that moves a 4 px label — so
it silences the flake *and* the regression, which is the entire population of things the suite
detects. If a golden is unstable at zero difference, something in §7.2 is not frozen; find it.

### 7.5 Reviewing a golden change

**Rule: a PR that changes a golden shows the before/after/diff images in the PR, and a human
looks at them.**

A golden diff reviewed as `Binary files differ` is not reviewed. CI uploads the
`failures/*_masterImage.png`, `*_testImage.png` and `*_maskedDiff.png` artefacts that
`flutter test` writes on a mismatch, and the PR template asks for the intended visual change in
one sentence. `--update-goldens` run without looking at the diff is how a regression gets
committed as the new expectation.

---

## 8. Consumer-driven contract tests

The app is a consumer of an API it does not own. A contract test proves the app's assumptions
about that API still hold, and — more usefully — proves the app survives the API changing in
the ways it is allowed to change.

### 8.1 The schema is committed

**Rule: the API schema lives in the repo, versioned, at a pinned version. Never fetched at
build time.**

```
contract/
  programs.v3.yaml     the OpenAPI document, committed
  CHANGELOG.md         what changed between v2 and v3, and what the app did about it
```

A build step that downloads `https://api.example.com/openapi.json` makes the build
unreproducible: the same commit compiles differently on Tuesday, a checkout from six months ago
cannot be built at all, and an outage in the API's docs host is an outage in CI. The committed
copy is also the thing a code review can look at — a schema change becomes a diff a human
approves.

**Rule: where the API publishes a machine-readable spec, the DTOs are generated from it, not
hand-written.** Generated DTOs are `data/dto/`; they are mapped to domain models per
`language/dart-models`. Where no spec is published, models are hand-written and §8.3 carries the
whole weight.

### 8.2 A scheduled job diffs committed against deployed

**Rule: a nightly job fetches the deployed spec, diffs it against the committed one, and opens
an issue on a difference. It never blocks a PR.**

```yaml
# .github/workflows/contract-drift.yml
on:
  schedule: [{ cron: '0 6 * * *' }]
jobs:
  drift:
    steps:
      - uses: actions/checkout@v4
      - run: curl -fsSL "$API_BASE/openapi.json" -o /tmp/deployed.json
      - run: npx oasdiff breaking contract/programs.v3.yaml /tmp/deployed.json
      - if: failure()
        uses: actions/github-script@v7   # open an issue, assign the mobile on-call
```

Blocking PRs on this makes an unrelated backend deploy stop every mobile merge, and the job gets
disabled within a fortnight. As a scheduled alarm it does its job: the mobile team learns about
a breaking change from a ticket, days before a user does.

### 8.3 Fixtures come from the spec's examples

**Rule: every fixture in `test/support/fixtures/` is copied from an `example:` in the committed
spec, and a test asserts that every example in the spec parses.**

A fixture invented by the developer writing the test encodes what that developer *believed* the
server sends. The two diverge quietly, and the suite ends up verifying a payload that has not
existed for a year.

```dart
test('every example in the committed spec parses', () {
  for (final example in loadSpecExamples('contract/programs.v3.yaml', '#/components/schemas/Program')) {
    expect(() => Program.fromJson(example), returnsNormally, reason: 'example: $example');
  }
});
```

### 8.4 Forward compatibility, proven

**Rule: unknown fields are ignored and unknown enum values fall back — and there is a test for
each.** The mechanism is `language/dart-models` (`@JsonKey(unknownEnumValue: ...)`, an `unknown`
enum member, `json_serializable` ignoring extra keys). This is where it is *proved*, because it
is a property no one notices is broken until the server ships a new value.

```dart
group('Program forward compatibility', () {
  test('a field the app does not know is ignored', () {
    final json = fixture('program.json')..['loyaltyTier'] = 'gold';
    final program = Program.fromJson(json);
    expect(program.id, 'p_1');
  });

  test('an enum value the app does not know falls back to unknown', () {
    final json = fixture('program.json')..['status'] = 'suspended';
    expect(Program.fromJson(json).status, ProgramStatus.unknown);
  });
});
```

The second test is the one that matters. Without the fallback, `json_serializable` throws — and
it throws for the *whole response*, so a backend adding one status value to one program blanks
the entire list for every user on an old build. Users cannot upgrade fast enough for that to be
recoverable; the fix ships as a hotfix and the incident lasts as long as the app-store review.

**A `switch` over the enum must handle `unknown` explicitly.** `frontend/flutter-ui` renders it
as a neutral chip, never as a crash and never as "active".

---

## 9. Integration journeys

**Rule: 5–8 journeys, chosen because failure is unacceptable, not because the flow exists.**

| Journey | Why it is on the list |
|---|---|
| Sign in → land on home | Nobody can use the app if this breaks |
| Browse → enrol → confirmation | The revenue path |
| Offline: open a cached list, act, reconnect, sync | The behaviour unit tests approximate least well |
| Push notification → deep link → correct screen | Crosses the process boundary; nothing else covers it |
| Sign out → all user data gone | A privacy commitment, and a `auth/flutter-session` invariant |

Thirty journeys is a suite that takes forty minutes, fails twice a week for unrelated reasons,
and gets skipped. Every additional journey is paid for in flake budget, and the budget is small.

### 9.1 Seeded and torn down, on a dedicated environment

**Rule: each journey seeds its own data in `setUp` and destroys it in `tearDown`, against a
dedicated test environment. Never production, never a shared staging account.**

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SeededTenant tenant;

  setUp(() async {
    tenant = await TestDataApi.seedTenant(programs: 3, member: true);
  });

  tearDown(() async {
    await TestDataApi.destroyTenant(tenant.id);
  });

  testWidgets('a member enrols in a program', (tester) async {
    app.main();
    await pumpUntil(tester, find.byType(SignInPage));

    await tester.enterText(find.byKey(const Key('email')), tenant.member.email);
    await tester.enterText(find.byKey(const Key('password')), tenant.member.password);
    await tester.tap(find.byKey(const Key('sign_in_submit')));

    await pumpUntil(tester, find.byType(ProgramListPage));
    await tester.tap(find.text(tenant.programs.first.name));

    await pumpUntil(tester, find.byKey(const Key('enrol_button')));
    await tester.tap(find.byKey(const Key('enrol_button')));

    await pumpUntil(tester, find.byType(EnrolmentConfirmation));
    expect(find.text(tenant.programs.first.name), findsOneWidget);
  });
}
```

Shared fixture data produces the worst failure mode a suite has: two journeys running in
parallel mutate the same record, one fails, and the failure is not reproducible locally. A
per-run tenant makes every journey independent and parallelisable.

A journey that leaves data behind also poisons the *next* run — the "enrol" journey fails on the
second run because the member is already enrolled. `tearDown` runs even when the test fails,
which is exactly when the cleanup matters most.

### 9.2 Wait on conditions, never durations

**Rule: never wait for a duration. Wait until a condition is true, with a timeout that fails
loudly.** A sleep is a flake with a timer: it is too long on every fast run and too short on the
one slow run that matters.

```dart
// test/support/pump_until.dart
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out after $timeout waiting for: $finder');
}
```

`pumpAndSettle` is a condition wait (it pumps until no frame is scheduled) and is correct for
finite animations. It hangs forever on a looping animation or a live stream, which is why
`pumpUntil` exists alongside it.

The timeout message names the finder. "Timed out" with no subject sends whoever triages the
nightly failure back into the test to work out what it was waiting for.

### 9.3 Flakes are quarantined, then fixed or deleted

**Rule: a journey that fails twice without a code change is tagged `quarantine`, excluded from
the merge job, assigned an owner and a date. Fixed by the date or deleted.**

```dart
@Tags(['quarantine'])   // owner: @mani · fix or delete by 2026-09-17 · see #482
library;
```

A retried flaky test is worse than a deleted one: it still costs the runtime, it still fails
sometimes, and it has taught the team that a red build means nothing. Quarantine makes the debt
visible and dated; the count is reviewed at sprint end (`/evolve`).

### 9.4 Where they run

**Rule: journeys run on merge to the main branch and nightly. Never in the PR gate.**

| Suite | PR gate | On merge | Nightly |
|---|---|---|---|
| Unit + container + widget | ✅ | ✅ | ✅ |
| Golden | ✅ | ✅ | ✅ |
| Contract (fixtures) | ✅ | ✅ | ✅ |
| Contract drift (deployed spec) | ✗ | ✗ | ✅ |
| Integration journeys | ✗ | ✅ | ✅ |
| Performance budgets | ✗ | ✅ | ✅ |

A thirty-minute device-farm run in the PR gate means developers stop opening small PRs, which
costs more quality than the gate buys. On merge, a failure is caught within minutes of landing
and before the release branch is cut.

---

## 10. Performance budgets

**Rule: performance is measured in profile mode, on a physical device, on one pinned baseline
device model. Debug mode, simulators and "whatever the runner had" produce numbers that cannot
be compared to last week's.**

Debug-mode Flutter is 5–20× slower and JIT-compiled; a simulator has desktop-class CPU and no
thermal throttling. Both produce numbers that move for reasons unrelated to the code.

```dart
// integration_test/perf/scroll_perf_test.dart
testWidgets('program list scroll stays within budget', (tester) async {
  await binding.watchPerformance(() async {
    await tester.fling(find.byType(ProgramListView), const Offset(0, -500), 3000);
    await tester.pumpAndSettle();
  }, reportKey: 'scroll_timeline');
});
```

Run with `flutter drive --profile`, and publish `build/integration_response_data.json` as a CI
artefact.

### 10.1 Ceilings and deltas

**Rule: every budget has an absolute ceiling *and* a per-PR delta. Both, always.**

| Metric | Ceiling | Per-PR delta |
|---|---|---|
| Cold start → first frame | 2000 ms | +5% |
| Cold start → first meaningful paint | 3000 ms | +5% |
| p90 frame build time | 16 ms | +10% |
| Janky frames during the scroll journey | < 1% | +0.2 pt |
| Release APK size | 60 MB | +2% |
| Steady-state memory after the enrol journey | 250 MB | +5% |

The ceiling alone is not enough: a feature that adds 40 ms to a 900 ms start-up passes every
time, and twenty such features arrive at 1700 ms with no single commit to blame. By the time the
ceiling is breached the regression is spread over six months of history and cannot be bisected.
The delta catches each one at the commit that caused it, when the author still remembers why.

The delta alone is not enough either: a legitimately expensive feature can be waved through on
"it's only 4%" until the absolute number is untenable.

**Rule: the baseline device is pinned and named in the repo** (`perf/BASELINE.md`: model, OS
version, why it was chosen — typically the cheapest device in the top decile of the user base).
Changing it invalidates the history, so it is a deliberate decision with a re-baselining commit,
not a silent runner change.

**Where they run:** on merge and nightly, alongside the journeys (§9.4). A device-farm run does
not belong in the PR gate, and a budget breach is an issue on the author, not a blocked merge.

---

## 11. Coverage, CI wiring and the flake policy

### 11.1 Coverage is a ratchet, never a target

**Rule: coverage is reported on every PR against a floor that only ever rises.**

An absolute target — "we should be at 80%" — is argued about, never agreed, and never set. A
ratchet needs no agreement: whatever coverage is today is the floor tomorrow.

```yaml
# .github/workflows/test.yml
- run: flutter test --coverage --exclude-tags golden
- run: |
    lcov --remove coverage/lcov.info \
      '*/generated/*' '*.g.dart' '*.freezed.dart' '*/l10n/*' \
      -o coverage/lcov.info
- run: dart run tool/check_coverage.dart --floor "$(cat coverage/FLOOR)"
```

- Generated files are excluded before the number is computed. A repo full of `*.g.dart` reports
  a coverage figure that measures how much codegen it uses.
- The floor lives in a committed `coverage/FLOOR` file, so raising it is a reviewed diff.
- A nightly job raises the floor when coverage has exceeded it by more than one point for a
  week. Raising it manually in the same PR that adds tests is also fine.
- Report the number as a PR comment with the per-file delta. "Coverage 71.4% (floor 70.0%,
  +0.8)" gets read; a badge on the README does not.

**Coverage measures what was executed, not what was asserted.** A 90% figure with no `expect` in
half the tests is worth less than 60% with real assertions. It is a ratchet against *decline*,
not evidence of quality — do not let it become the review.

### 11.2 What runs where

The gate is fast and hermetic; everything slow or externally-dependent is on merge or nightly
(§9.4). The PR gate should finish in under five minutes:

```
flutter analyze
flutter test --exclude-tags golden --exclude-tags quarantine --coverage
make goldens-verify        # in the pinned container image
```

### 11.3 Test naming and structure

- One `group` per unit under test, named after the class: `group('ProgramsController', ...)`.
- Test names state the behaviour and the condition: `'keeps loaded items when a page fails'` —
  not `'test loadMore'`. The name is what a CI failure shows; it should say what broke.
- Arrange / act / assert, in that order, separated by blank lines. No assertion in the arrange.
- No conditionals in a test body. `if (Platform.isIOS)` in a test is two tests.
- Builders (`program(id: 'p_1', name: ...)`) over literal model construction, so adding a
  required field is one edit rather than eighty.

---

## 12. Common mistakes

| Mistake | Why it hurts | Instead |
|---|---|---|
| Writing the first test before the harness | The first test costs a day, so the second is never written | §1 — harness first |
| Stubbing the HTTP client | Couples every test to the wire format; behaviour-neutral refactors go red | §3 — fake the contract |
| Keeping `widget_test.dart` | A green suite that tests Flutter's counter demo | §1.3 — delete it |
| A screen test that only covers data | Ships a retry button that pops the route | §6 — four states, assert the re-fetch |
| Asserting only `isA<AsyncError>` | Passes when a typed error is flattened to `Exception` | §5.2 |
| No disposal test on a notifier | `ref.onDispose` gets deleted in a tidy-up and nothing notices | §5.3 |
| Goldens without loaded fonts | Every glyph is a box; the golden can never detect a text change | §7.1 |
| Goldens generated on a Mac, verified on Linux | Permanent CI failure, "fixed" by loosening the comparison | §7.4 |
| An allowed-difference percentage on goldens | Silences the flake and the regression together | §7.4 |
| Only a light-mode golden | Dark mode and 200% text are where design systems break | §7.3 |
| Fixtures invented by hand | The suite verifies a payload the server stopped sending | §8.3 |
| No unknown-enum test | One new server value blanks the list for every user on an old build | §8.4 |
| Fetching the spec at build time | The same commit builds differently on different days | §8.1 |
| Thirty integration journeys | Forty minutes, weekly flakes, then universally skipped | §9 |
| Waiting a fixed duration | Too long on every fast run, too short on the slow one | §9.2 |
| Retrying a flaky test | Teaches the team that red means nothing | §9.3 |
| Journeys in the PR gate | Developers stop opening small PRs | §9.4 |
| Perf measured in debug or on a simulator | Numbers that move for reasons unrelated to the code | §10 |
| A ceiling with no per-PR delta | A slow creep, unbisectable by the time it breaches | §10.1 |
| Arguing an absolute coverage target | Never agreed, so never set | §11.1 |
| Coverage including `*.g.dart` | Measures how much codegen the repo uses | §11.1 |
