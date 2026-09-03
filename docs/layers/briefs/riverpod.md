# Brief — `state/riverpod`

**Kind:** layer · **Issue:** #2 · **Cookbook:** `#provider`, `#pagination`, `#realtime`

## Globs
```yaml
paths:
  - "**/application/providers/*.dart"
  - "**/application/controllers/*.dart"
  - "**/*_providers.dart"
  - "**/*_provider.dart"
```

## Rules to encode
1. Current API only — `Notifier` / `AsyncNotifier` / `@riverpod`. An import of
   `flutter_riverpod/legacy.dart` is a migration marker whose count only decreases.
2. Screen-scoped providers auto-dispose. Hand-written providers do **not** by default.
   `ref.keepAlive()` for a conditional hold, not a permanently-alive provider.
3. `ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for side effects.
4. Async state is one `AsyncValue`; never a loading/data/error triple.
5. `AsyncValue.guard` for actions, never a bare try/catch that sets three fields.
6. Nothing reaches for `X.instance` inside a provider body — that is the test seam.
7. State has exactly one writer.
8. **Pagination:** cursor not offset; `Paged<T>` holding `items` + `pageError` side by side
   so a failed page keeps loaded pages; `loadMore` idempotent and guarded; refresh resets
   the cursor; dedupe by id; prefetch ahead of the viewport.
9. **Realtime:** connection lifetime == provider lifetime via `ref.onDispose`; capped
   backoff with jitter, reset only after a stable period; disconnect on background; REST is
   the source of truth and the stream is an accelerator; messages idempotent by id.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | A provider fetching a list, cancelled on dispose | `@riverpod`, `ref.onDispose`, `CancelToken` | `StateProvider`, `legacy.dart` |
| 02 | A paginated feed provider with load-more | `Paged`, `pageError`, `nextCursor` | `page:`, `offset` |
| 03 | An action provider that enrols a student | `AsyncValue.guard`, `AsyncLoading` | `bool isLoading`, `try {` |
| 04 | A socket-backed provider for a room | `ref.onDispose`, `yield*` | connection held past dispose |

## Boundaries
Session state is `auth/flutter-session`. Widgets that consume providers are
`frontend/flutter-ui`.
