# Riverpod 3 Standards

Riverpod is the only place application state lives. A provider is a unit of state plus its
lifetime plus its dependencies — the rules below are almost all about lifetime, because that
is what leaks, and about dependencies, because that is what makes a screen untestable.

**Scope boundaries.** This layer covers providers and controllers: how state is shaped, when
it is disposed, how async work is guarded, and the pagination and realtime patterns built on
top. It does **not** cover session, token refresh, or sign-in state — that is
`auth/flutter-session`, and a provider here reads the session, never owns it. It does not
cover widgets: `ConsumerWidget`, `ref.watch` inside `build`, list rendering, scroll
thresholds and loading UI are `frontend/flutter-ui`. HTTP clients, interceptors and error
mapping are `api-style/dio`. Model classes, `copyWith` and JSON are `language/dart-models`.
Provider overrides in tests are shared with `testing/flutter-test`.

**Version.** Targets Riverpod 3.x (`flutter_riverpod` / `riverpod_annotation` /
`riverpod_generator`). Where a signature is known to have moved between 2.x and 3.x it is
called out in [§12](#12-riverpod-3-migration-notes). If a detail below disagrees with the
version pinned in `pubspec.yaml`, the pubspec wins — check it before assuming.

---

## 1. The current API is `Notifier`, `AsyncNotifier` and `@riverpod`

**Rule: every new provider is written with `@riverpod` code generation.** Hand-written
providers are permitted only where codegen genuinely cannot express the thing (rare) and the
reason is in a comment.

| Need | Write |
|---|---|
| Derived / computed value, sync | `@riverpod T thing(Ref ref)` |
| One-shot async read | `@riverpod Future<T> thing(Ref ref)` |
| Stream | `@riverpod Stream<T> thing(Ref ref) async*` |
| Mutable sync state + methods | `@riverpod class X extends _$X` with `T build()` |
| Async state + methods | `@riverpod class X extends _$X` with `Future<T> build()` |
| Parameterised (family) | Add parameters to the function or to `build` |

```dart
// lib/features/courses/application/providers/courses_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'courses_providers.g.dart';

@riverpod
Future<List<Course>> courses(Ref ref, {required String schoolId}) async {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.listCourses(schoolId: schoolId);
}
// generates: coursesProvider(schoolId: ...)
```

**`StateProvider`, `StateNotifier`, `StateNotifierProvider` and `ChangeNotifierProvider` are
legacy.** In Riverpod 3 they are no longer exported from the main entry point; they live in
`package:flutter_riverpod/legacy.dart` (and `package:riverpod/legacy.dart`).

**Rule: an import of `legacy.dart` is a migration marker, not an API choice. Its count across
the repo only ever decreases.** Never add one to a new file. When you touch a file that has
one, migrating it is in scope for that change.

| Legacy | Replacement |
|---|---|
| `StateProvider<T>` | `@riverpod class X extends _$X` with `T build()` |
| `StateNotifierProvider` | `NotifierProvider` / `@riverpod` class |
| `StateNotifier<AsyncValue<T>>` | `AsyncNotifier` (`Future<T> build()`), `state` already an `AsyncValue` |
| `ChangeNotifierProvider` | A `Notifier` holding an immutable model |

Why it matters beyond tidiness: `StateProvider` has no place to put a method, so business
logic migrates into widgets. `StateNotifier` keeps its own `state` outside the `Ref`
lifecycle, so `ref.onDispose`, `ref.listen` and auto-dispose do not compose with it.

---

## 2. Lifetime: auto-dispose is the default you must not lose

**Rule: a screen-scoped provider disposes with the screen. `@riverpod` already does this.**

```dart
@riverpod                                   // ✅ auto-dispose
Future<Course> course(Ref ref, String id) => ref.watch(repoProvider).fetch(id);

@Riverpod(keepAlive: true)                  // ✅ deliberate, and justify it in a comment
Dio dio(Ref ref) => buildDio();
```

**Hand-written providers are not auto-dispose by default.** If you write one, you are opting
out of disposal unless you say otherwise, which is the single most common source of "stale
data reappears after leaving the screen" and of memory held by a closed screen's socket.

Riverpod 3 unified the auto-dispose classes (there is no longer a separate
`AutoDisposeNotifier` hierarchy) and the way you flag a hand-written provider as
auto-disposing changed from 2.x. **Do not guess the modifier — use `@riverpod` and let the
generator emit it.** That is the main reason codegen is mandatory here.

**`ref.keepAlive()` is a conditional hold, not a permanent one.** Use it to keep a
*successful* result for a bounded window; never as a way to make a provider immortal.

```dart
@riverpod
Future<Profile> profile(Ref ref, String userId) async {
  final result = await ref.watch(profileRepositoryProvider).fetch(userId);

  // Cache a success for 5 minutes; a failure is not worth caching at all.
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);

  return result;
}
```

| You want | Use |
|---|---|
| Data valid only while the screen is open | plain `@riverpod` |
| Long-lived singleton (Dio, database, socket client) | `@Riverpod(keepAlive: true)` |
| Cache a success for N seconds/minutes | `ref.keepAlive()` + `Timer` + `link.close` |
| Keep alive "because it kept refetching" | Nothing — fix the rebuild instead |

---

## 3. `watch` / `read` / `listen`

**Rule: `ref.watch` in `build` only. `ref.read` in callbacks only. `ref.listen` for side
effects.** Each of the three wrong pairings has a distinct, recognisable failure.

| API | Where | Failure when misused |
|---|---|---|
| `ref.watch` | `build`, and provider bodies | In a callback: subscribes on every tap; the provider never settles |
| `ref.read` | button handlers, notifier methods | In `build`: reads once, never updates — the classic "stale UI" bug |
| `ref.listen` | `build` (registers), fires on change | Doing navigation/snackbars in `build` instead: fires during layout |

```dart
@riverpod
class EnrolmentController extends _$EnrolmentController {
  @override
  FutureOr<void> build() {}

  Future<void> enrol(String courseId) async {
    // ✅ read, not watch — this is a callback, not a dependency
    final repository = ref.read(enrolmentRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repository.enrol(courseId));
    if (state.hasValue) {
      ref.invalidate(myCoursesProvider);
    }
  }
}
```

`ref.listen` belongs in the widget for UI side effects and in a provider body only for
cross-provider reactions:

```dart
// in a provider body — react to sign-out by dropping cached course state
ref.listen(sessionProvider, (previous, next) {
  if (next.valueOrNull == null) ref.invalidateSelf();
});
```

---

## 4. Async state is one `AsyncValue`, never three fields

**Rule: async state is a single `AsyncValue<T>`. Never a `data` + `isLoading` + `error`
triple.** Three fields have eight combinations, six of which are illegal, and every widget
that reads them has to re-derive which one wins.

```dart
// ❌ the default wrong answer
class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final String? error;
}

// ✅
@riverpod
class FeedController extends _$FeedController {
  @override
  Future<List<Post>> build() => ref.watch(feedRepositoryProvider).fetchFeed();
}
// state is AsyncValue<List<Post>>: exactly one of loading / data / error, plus
// isRefreshing and isReloading for the "have old data, fetching new" case.
```

Read it with a Dart 3 switch on the sealed type, or with `.when` in widgets:

```dart
final label = switch (state) {
  AsyncData(:final value) => 'Loaded ${value.length}',
  AsyncError(:final error) => 'Failed: $error',
  _ => 'Loading',
};
```

**Do not flatten `AsyncValue` into a bool at the provider boundary.** A widget wanting only
"is it busy" can use `ref.watch(p.select((s) => s.isLoading))`; the provider still exposes
the whole value.

---

## 5. Actions use `AsyncValue.guard`

**Rule: an action that can fail is `state = const AsyncLoading();` followed by
`state = await AsyncValue.guard(() => ...);`. Never a bare `try`/`catch` that sets three
fields by hand.**

```dart
Future<void> submit(EnrolmentDraft draft) async {
  state = const AsyncLoading();
  state = await AsyncValue.guard(() => ref.read(repoProvider).submit(draft));
}
```

`guard` catches the error *and* its stack trace and puts both in `AsyncError`. Hand-written
`catch (e)` drops the stack trace, which is what you need in Crashlytics.

Two legitimate exceptions, both narrow:

1. **You need the error out-of-band from the value** — pagination, §9. There the failure
   must not replace the loaded pages, so the error goes in a `pageError` field on the state.
   Even then, prefer `AsyncValue.guard` and *unpack* the result rather than writing a
   `try`/`catch`.
2. **You must distinguish one error type to act on it** (e.g. a 409 that means "already
   enrolled" and is not really a failure). Map it in the repository — `api-style/dio` — so
   the controller still sees a typed result, not an exception.

**Never swallow.** `guard` with no rethrow is not swallowing: the error is in `state`, and
something must render it. A `catch (_) {}` is swallowing.

---

## 6. Nothing reaches for a singleton inside a provider body

**Rule: a provider body never contains `X.instance`, `new Dio()`, `DateTime.now()` in a
decision, or a direct `SharedPreferences.getInstance()`. It takes every collaborator from
another provider.** That indirection is the entire test seam.

```dart
// ❌ untestable — the test cannot replace Firebase or the clock
@riverpod
Future<Profile> profile(Ref ref) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return Dio().get('/profiles/$uid').then(Profile.fromResponse);
}

// ✅ every dependency arrives through ref
@riverpod
Future<Profile> profile(Ref ref) async {
  final session = await ref.watch(sessionProvider.future);   // auth/flutter-session
  final repository = ref.watch(profileRepositoryProvider);
  return repository.fetch(session.userId);
}
```

The leaf providers that *do* construct the singleton are `keepAlive`, live in one
`infrastructure` file, and are the ones tests override:

```dart
ProviderScope(
  overrides: [
    profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  ],
  child: const App(),
);
```

---

## 7. One writer per piece of state

**Rule: exactly one provider may write a given piece of state. Everything else derives from
it with `ref.watch`.** Two writers means the last write wins non-deterministically, and no
stack trace tells you which one it was.

- A list and its filter are **one** notifier or a derived provider — never two notifiers that
  both mutate the list.
- Cross-provider updates go through `ref.invalidate(other)` or `ref.listen`, not through a
  method that reaches into another notifier and sets its `state`.
- A widget never assigns `state`. It calls a method on the notifier.

```dart
// ✅ derived, not duplicated
@riverpod
List<Course> visibleCourses(Ref ref) {
  final all = ref.watch(coursesControllerProvider).valueOrNull ?? const <Course>[];
  final query = ref.watch(courseFilterControllerProvider).query;
  return all.where((c) => c.title.toLowerCase().contains(query.toLowerCase())).toList();
}
```

---

## 8. Lifetime of work: cancel everything the provider started

**Rule: every subscription, timer, `CancelToken` and socket opened in a provider is released
in `ref.onDispose`, registered at the point of creation.** Not at the end of `build` — an
early return or a throw would skip it.

```dart
@riverpod
Future<List<Course>> courses(Ref ref, String schoolId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);          // registered before the await

  final repository = ref.watch(courseRepositoryProvider);
  return repository.listCourses(schoolId, cancelToken: cancelToken);
}
```

Without the `CancelToken`, leaving the screen mid-request keeps the socket open, burns
mobile data, and resolves into a disposed provider.

**Assigning `state` after disposal throws.** Any `await` inside a notifier method must be
followed by a mounted check before the next `state = `:

```dart
final result = await AsyncValue.guard(() => repo.fetchPage(cursor));
if (!ref.mounted) return;                     // Riverpod 3; see §12
state = ...;
```

---

## 9. Pagination

The highest-value section in this layer. Get the state shape right and load-more, retry,
refresh and prefetch all fall out of it; get it wrong and every one of them is a special
case.

### 9.1 Cursor, never offset

**Rule: paginate by opaque cursor. `page:` / `offset:` are not acceptable in a feed.**

| | Offset / page number | Cursor |
|---|---|---|
| Item inserted while you scroll | Page 2 repeats an item, or skips one | Stable — the cursor points at a row, not a position |
| Item deleted while you scroll | Same, in reverse | Stable |
| Backend cost | `OFFSET n` scans and discards n rows | Index seek |
| Jump to page 7 | Possible | Not possible — and a feed never needs it |

The cursor is **opaque**: never parse it, never construct one, never compare two. It is a
string the server gave you and the only thing you do with it is send it back.

### 9.2 The `Paged<T>` state shape

**Rule: page state holds `items` and `pageError` side by side, so a failed page keeps the
pages already loaded.** This is why the state is not just `AsyncValue<List<T>>`: an
`AsyncError` replaces the value, and the user watching 60 loaded posts vanish because page 4
timed out is the bug this shape exists to prevent.

```dart
// lib/features/feed/application/providers/feed_providers.dart
@immutable
class Paged<T> {
  const Paged({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.pageError,
  });

  factory Paged.empty() => Paged<T>(items: <T>[]);

  final List<T> items;
  final String? nextCursor;     // null == no more pages
  final bool isLoadingMore;     // a page request is in flight
  final Object? pageError;      // the *last page* failed; items are still valid

  bool get hasMore => nextCursor != null;
  bool get isEmpty => items.isEmpty && nextCursor == null && pageError == null;

  Paged<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
    Object? pageError,
    bool clearPageError = false,
  }) {
    return Paged<T>(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pageError: clearPageError ? null : (pageError ?? this.pageError),
    );
  }
}
```

The outer `AsyncValue<Paged<T>>` still means what it always meant — *the first page* is
loading, loaded, or failed. `pageError` means *a subsequent page* failed. They are different
states and the UI renders them differently: a full-screen spinner versus a retry row at the
bottom of a populated list.

| Situation | `AsyncValue` | `Paged` field |
|---|---|---|
| First load in flight | `AsyncLoading` | — |
| First load failed | `AsyncError` | — |
| Loaded, more available | `AsyncData` | `nextCursor != null` |
| Loading page 3 | `AsyncData` | `isLoadingMore == true` |
| Page 3 failed | `AsyncData` | `pageError != null`, `items` unchanged |
| End of feed | `AsyncData` | `nextCursor == null` |

### 9.3 The controller

```dart
@riverpod
class FeedController extends _$FeedController {
  static const _pageSize = 20;

  @override
  Future<Paged<Post>> build() async {
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);

    final page = await ref.watch(feedRepositoryProvider).fetchFeed(
          cursor: null,
          limit: _pageSize,
          cancelToken: cancelToken,
        );

    return Paged<Post>(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;            // first page still loading or failed
    if (current.isLoadingMore) return;      // idempotent: one page request at a time
    if (current.nextCursor == null) return; // end of feed

    state = AsyncData(current.copyWith(isLoadingMore: true, clearPageError: true));

    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);

    final result = await AsyncValue.guard(
      () => ref.read(feedRepositoryProvider).fetchFeed(
            cursor: current.nextCursor,
            limit: _pageSize,
            cancelToken: cancelToken,
          ),
    );

    if (!ref.mounted) return;

    final latest = state.valueOrNull ?? current;
    state = AsyncData(
      switch (result) {
        AsyncData(:final value) => latest.copyWith(
            items: dedupeById([...latest.items, ...value.items], (Post p) => p.id),
            nextCursor: value.nextCursor,
            clearCursor: value.nextCursor == null,
            isLoadingMore: false,
            clearPageError: true,
          ),
        // The page failed. Keep every item already loaded and every cursor;
        // the UI shows a retry row, and retry() below re-issues the same cursor.
        AsyncError(:final error) =>
          latest.copyWith(isLoadingMore: false, pageError: error),
        _ => latest.copyWith(isLoadingMore: false),
      },
    );
  }

  /// Retry the page that failed. Same cursor, so no gap in the feed.
  Future<void> retryPage() async {
    final current = state.valueOrNull;
    if (current?.pageError == null) return;
    await loadMore();
  }

  /// Pull-to-refresh: reset the cursor by rebuilding from scratch.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

List<T> dedupeById<T>(Iterable<T> items, String Function(T) id) {
  final seen = <String>{};
  return [
    for (final item in items)
      if (seen.add(id(item))) item,
  ];
}
```

### 9.4 The four rules the code above encodes

**`loadMore` is idempotent and guarded.** Three early returns, checked before any state
write: no first page yet, a request already in flight, no cursor left. A `ListView` fires its
scroll callback many times per second; without the `isLoadingMore` guard you issue six
identical requests and append the same page six times.

**Refresh resets the cursor.** `ref.invalidateSelf()` re-runs `build`, which starts from
`cursor: null`. Never hand-reset a cursor field — that leaves `items` from the old query
merged with page 1 of the new one. During the rebuild `state.isRefreshing` is true and the
previous value is still readable, so the list does not blank out.

**Dedupe by id on every merge.** Cursor pagination is stable but not exclusive: a row edited
between two requests can legitimately appear in both. Duplicate keys in a `ListView` are a
runtime error, not a cosmetic issue.

**Prefetch ahead of the viewport.** The controller exposes `loadMore()` and imposes no
scroll policy; the widget calls it when the last visible index is within roughly one screen
of the end. The threshold is a UI concern and lives in `frontend/flutter-ui` — the guard
that makes calling it early harmless lives here.

### 9.5 Never

- Store `pageNumber` or `offset` in the state.
- Put the page error in the outer `AsyncValue` — that discards `items`.
- Call `loadMore()` from `build`.
- Append without dedupe.
- Reset `nextCursor` without also resetting `items`.

---

## 10. Realtime

**Rule: the connection's lifetime is the provider's lifetime.** The provider opens it, and
`ref.onDispose` closes it. Nothing else opens or closes that socket.

```dart
@riverpod
Stream<List<Message>> roomMessages(Ref ref, String roomId) async* {
  final client = ref.watch(socketClientProvider);
  final channel = client.channel('room:$roomId');
  ref.onDispose(channel.close);               // registered before the first yield

  // REST is the source of truth: seed from the API, then accelerate with the socket.
  final seed = await ref.watch(messageRepositoryProvider).fetchRecent(roomId);

  final seen = <String>{...seed.map((m) => m.id)};
  final buffer = <Message>[...seed];
  yield List<Message>.unmodifiable(buffer);

  await for (final message in channel.messages) {
    if (!seen.add(message.id)) continue;      // idempotent by id
    buffer.add(message);
    yield List<Message>.unmodifiable(buffer);
  }
}
```

**Rule: `yield*` or `await for` the stream inside an `async*` provider — never a bare
`.listen(` you do not cancel.** A `StreamSubscription` created in a provider body outlives
the provider unless you both keep the handle and cancel it in `ref.onDispose`; the `async*`
form makes cancellation automatic when the provider is disposed. If you genuinely need
`.listen(`, the subscription handle is captured and `ref.onDispose(sub.cancel)` is the very
next line.

**Rule: REST is the source of truth; the stream is an accelerator.** Seed from the API,
merge socket events on top, and re-seed after any reconnect. A UI that can only be correct
if every socket frame arrived is a UI that is wrong after the first tunnel.

**Rule: messages are idempotent by id.** At-least-once delivery is the norm; a set of seen
ids is the whole implementation.

**Rule: reconnect with capped exponential backoff plus jitter, and reset the attempt counter
only after a stable period.** Resetting on connect turns a server that accepts and instantly
drops connections into a client-side DoS loop.

```dart
import 'dart:math';

Duration reconnectDelay(int attempt) {
  final shift = attempt < 6 ? attempt : 6;          // cap the exponent, not just the result
  final baseMs = min(500 * (1 << shift), 30000);    // 0.5s → 30s ceiling
  final jitterMs = Random().nextInt(baseMs ~/ 4 + 1);
  return Duration(milliseconds: baseMs + jitterMs);
}
```

Reset `attempt` to 0 only after the connection has stayed up for, say, 30 seconds — not on
the `connected` event.

**Rule: disconnect when the app is backgrounded.** iOS suspends the socket anyway and you
get a silent half-open connection; Android keeps it and drains the battery.

```dart
@riverpod
Stream<List<Message>> roomMessages(Ref ref, String roomId) async* {
  final lifecycle = ref.watch(appLifecycleProvider);
  if (lifecycle != AppLifecycleState.resumed) {
    return;                                         // no socket while backgrounded;
  }                                                 // watching lifecycle rebuilds on resume
  // ... open the channel as above
}
```

---

## 11. Testing providers

**Rule: a provider test builds a `ProviderContainer` with overrides and disposes it.** No
widget, no pump, no Firebase.

```dart
test('loadMore keeps loaded items when the page fails', () async {
  final container = ProviderContainer(
    overrides: [
      feedRepositoryProvider.overrideWithValue(FlakyFeedRepository()),
    ],
  );
  addTearDown(container.dispose);

  await container.read(feedControllerProvider.future);
  await container.read(feedControllerProvider.notifier).loadMore();

  final state = container.read(feedControllerProvider).requireValue;
  expect(state.items, isNotEmpty);      // pages already loaded survive
  expect(state.pageError, isNotNull);   // and the failure is visible
});
```

`addTearDown(container.dispose)` is not optional — a leaked container keeps its timers and
subscriptions running into the next test. Widget-level provider testing (`ProviderScope` +
`pumpWidget`) is `testing/flutter-test`.

---

## 12. Riverpod 3 migration notes

Things that moved between 2.x and 3.x, and where to check rather than guess.

| Area | 2.x | 3.x |
|---|---|---|
| `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider` | exported from the main entry point | moved behind `package:flutter_riverpod/legacy.dart` |
| Generated ref types | `FooRef`, `BarRef` per provider | one `Ref` type — codegen functions take `Ref ref` |
| Auto-dispose classes | `AutoDisposeNotifier`, `AutoDisposeAsyncNotifier` | unified into `Notifier` / `AsyncNotifier`; auto-dispose is a property of the provider |
| `ref.mounted` | not reliably available | available on `Ref` |

**Where you are unsure, do not assert.** The exact spelling of the auto-dispose modifier on a
*hand-written* provider, the current signature of `AsyncValue.guard`'s optional `test`
parameter, and the status of the experimental mutation (`@mutation`) and offline-persistence
APIs all changed or arrived recently. Using `@riverpod` codegen sidesteps every one of them,
which is why §1 makes it mandatory. If you must hand-write, check the installed version's
own source in `.dart_tool/package_config.json` rather than recalling a signature.

Riverpod 3 also retries a failed provider build automatically with a backoff by default,
which changes error UX from 2.x: a provider that throws no longer stays in `AsyncError`
forever. Confirm the retry configuration in the version you have before building UI that
assumes an error state is terminal.

---

## 13. Never

- Import `package:flutter_riverpod/legacy.dart` in a new file.
- `ref.watch` in a callback, or `ref.read` in `build`.
- Model async state as `data` + `isLoading` + `error`.
- `X.instance` or a constructor call for an I/O client inside a provider body.
- Two providers writing the same state.
- Open a subscription, timer, socket or `CancelToken` without a matching `ref.onDispose`.
- Assign `state` after an `await` without a mounted check.
- Paginate by `page` or `offset`.
- Let a failed page erase the pages already loaded.
- `catch (_) {}`.
