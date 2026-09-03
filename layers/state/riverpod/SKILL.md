---
name: riverpod
description: Riverpod 3 state standards for Flutter — Notifier/AsyncNotifier and @riverpod codegen, auto-dispose vs keepAlive, watch/read/listen discipline, AsyncValue and AsyncValue.guard, cursor pagination with a Paged<T> state shape, and provider-scoped realtime streams. Load when writing or reviewing providers and controllers.
user-invocable: false
stack: state/riverpod
paths:
  - "**/application/providers/*.dart"
  - "**/application/controllers/*.dart"
  - "**/*_providers.dart"
  - "**/*_provider.dart"
---

Full standards in [riverpod.md](riverpod.md). Always-on summary:

**Scope:** providers, controllers, and the async state they hold. Session and token state is `auth/flutter-session`; widgets that consume providers are `frontend/flutter-ui`.

**Current API only:**
- `@riverpod` codegen with `Notifier` / `AsyncNotifier`. `StateProvider`, `StateNotifierProvider` and `ChangeNotifierProvider` live behind `package:flutter_riverpod/legacy.dart` — an import of it is a migration marker whose count only goes down
- `@riverpod` is auto-dispose by default; `@Riverpod(keepAlive: true)` is the deliberate exception. Hand-written providers are **not** auto-dispose unless you make them so
- `ref.keepAlive()` for a conditional, time-boxed hold — never to make a provider permanently alive

**Ref discipline:**
- `ref.watch` in `build` only · `ref.read` in callbacks only · `ref.listen` for side effects (snackbar, navigation)
- `ref.onDispose` for every subscription, timer, `CancelToken` and socket a provider opens
- Never `FirebaseAuth.instance` / `Dio()` / any `X.instance` inside a provider body — take it from `ref.watch(clientProvider)`, which is the test seam

**Async state:**
- One `AsyncValue<T>`, never `data` + `isLoading` + `error` as three separate fields
- Actions: `state = const AsyncLoading();` then `final r = await AsyncValue.guard(() => repo.doThing()); if (!ref.mounted) return; state = r;` — never assign `state` straight from an `await`; the notifier may be disposed by then and the assignment throws
- Exactly one writer per piece of state

**Pagination:** cursor, never `page`/`offset`. State is `Paged<T> { items, nextCursor, isLoadingMore, pageError }` so a failed page keeps the pages already loaded. `loadMore` guards on `isLoadingMore` and a null cursor; refresh is `ref.invalidateSelf()`, which resets the cursor; dedupe by id on merge.

**Realtime:** connection lifetime == provider lifetime via `ref.onDispose`; `yield*` the stream rather than an uncancelled `.listen`; capped backoff with jitter; messages idempotent by id; REST stays the source of truth and the stream is an accelerator.

**Related:** `auth/flutter-session`, `frontend/flutter-ui`, `api-style/dio`, `language/dart-models`, `testing/flutter-test`.
