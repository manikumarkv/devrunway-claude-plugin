# Brief — `api-style/dio`

**Kind:** layer · **Issue:** #4 (parent #2) · **Cookbook:** `#service`, `#errors`, `#offline`, `#media`, `#contract`

## Globs
```yaml
paths:
  - "**/data/services/*.dart"
  - "**/data/api/*.dart"
  - "**/core/network/*.dart"
  - "**/core/error/*.dart"
```

## Rules to encode
1. Abstract contract + REST impl + optional decorator. The abstract provider is unbound and
   thrown from; the composition root binds it.
2. One private `_request`; the five verbs are thin wrappers. Cross-cutting concerns live in
   interceptors, never in call sites.
3. Auth and tenant headers read from providers **at request time** — never mutable fields
   with public setters.
4. One interceptor refreshes on 401 and replays exactly once, single-flight
   (`QueuedInterceptor`), signs out on a second failure.
5. Retry idempotent verbs with backoff + jitter. POST only with an idempotency key.
6. Every call accepts a `CancelToken` bound to provider disposal.
7. All four timeouts set — connect, send, receive, overall.
8. Sealed `AppError` hierarchy; foreign exceptions converted at the boundary exactly once;
   classify by **type**, never by `e.toString()` substring.
9. `isReportable` is a property of the error type. Expected 4xx is UI state, not a crash report.
10. Offline policy declared per resource (`networkOnly` / `networkFirst` / `cacheFirst` /
    `cacheThenNetwork`) in a decorator. Fall back to cache on connectivity/network errors
    only — never on 4xx or a parse failure.
11. Staleness travels with cached data and reaches the UI.
12. Media: compress, bake EXIF orientation and re-encode before upload; generated filename;
    progress + cancel + idempotency key; resumable chunks for large files.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Write a service method fetching a list of programs | `CancelToken`, `abstract` | `dynamic>` cast at call site |
| 02 | Map a `DioException` to an app error | `switch`, `ServerError`, `NetworkError` | `e.toString()`, `contains(` |
| 03 | Add a cache fallback to a list endpoint | `CachePolicy`, `isStale` | `catch (_)` returning cache |
| 04 | Prepare a picked photo for upload | `bakeOrientation`, `encodeJpg` | `readAsBytes()` straight to upload |

## Boundaries
Model shape is `language/dart-models`. Provider wiring is `state/riverpod`. Logging is
`logging/flutter-observability`.
