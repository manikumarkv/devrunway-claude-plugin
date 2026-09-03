# Dio API Service Standards

Everything between a Flutter feature and the network: the service contract it depends on, the
single `ApiClient` that owns `Dio`, the interceptors that carry auth, retry and refresh, the
typed error hierarchy the UI switches on, the offline cache policy, and media upload.

**Scope boundaries.** This layer does not define **model shape** — `fromJson`/`toJson`,
freezed/json_serializable, nullability and enum decoding all belong to `language/dart-models`;
here a model is only ever a type name. It does not define **provider wiring** — how a service
is constructed, scoped, kept alive, or how a `CancelToken` is tied to disposal belongs to
`state/riverpod`; here the composition root is a one-line reference. Log and analytics
emission belongs to `logging/flutter-observability`; this layer says only *where* the hook goes.

Sections are independent. Read the one you need.

| § | Concern |
|---|---|
| 1 | Service contract — abstract, REST impl, decorator |
| 2 | `ApiClient` — one `_request`, thin verbs |
| 3 | Timeouts and cancellation |
| 4 | Interceptors — headers, refresh, retry, order |
| 5 | The sealed `AppError` hierarchy |
| 6 | `isReportable` — what reaches the crash reporter |
| 7 | Offline cache policy and staleness |
| 8 | Media upload |
| 9 | Common mistakes |

---

## 1. The service contract

**Rule: every service is three things — an abstract contract, a REST implementation, and
optionally a decorator. Features depend on the contract only.**

The reason is testability and substitution. A feature that types its dependency as
`RestProgramService` cannot be given a fake, a cached variant, or a mock-server double
without editing the feature. A feature that types it as `ProgramService` gets all three for
free, and the offline decorator in §7 becomes a composition change rather than a rewrite.

```dart
// lib/features/programs/data/services/program_service.dart
import 'package:dio/dio.dart';

/// Contract. Unbound — the composition root decides the implementation.
abstract interface class ProgramService {
  Future<Cached<List<Program>>> fetchPrograms({
    required int page,
    CancelToken? cancelToken,
  });

  Future<Program> fetchProgram(
    String id, {
    CancelToken? cancelToken,
  });
}
```

**Rule: the contract's provider is unbound and throws.** The composition root binds it, so a
forgotten binding fails loudly at startup instead of silently reaching the network in a test.

```dart
// state/riverpod owns this file; shown only to fix the shape
final programServiceProvider = Provider<ProgramService>((ref) {
  throw UnimplementedError('programServiceProvider must be overridden');
});
```

The REST implementation holds an `ApiClient`, never a `Dio`:

```dart
// lib/features/programs/data/services/rest_program_service.dart
final class RestProgramService implements ProgramService {
  const RestProgramService(this._client);

  final ApiClient _client;

  @override
  Future<Cached<List<Program>>> fetchPrograms({
    required int page,
    CancelToken? cancelToken,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/programs',
      queryParameters: <String, dynamic>{'page': page, 'per_page': 20},
      cancelToken: cancelToken,
    );
    final items = (json['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    return Cached<List<Program>>(
      value: items.map(Program.fromJson).toList(growable: false),
      fetchedAt: DateTime.now(),
      isStale: false,
    );
  }

  @override
  Future<Program> fetchProgram(String id, {CancelToken? cancelToken}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/programs/$id',
      cancelToken: cancelToken,
    );
    return Program.fromJson(json);
  }
}
```

**Rule: a service method never touches `Response`, `Options`, headers, or `DioException`.**
Those are `ApiClient`'s concern. A service that reads `response.statusCode` has moved a
cross-cutting rule into one call site, where the next twenty call sites will not have it.

**Cacheable resources return `Cached<T>` from the contract itself.** Staleness is part of what
the caller is promised, not something a decorator bolts on invisibly — see §7. Resources with
`CachePolicy.networkOnly` return the bare type.

---

## 2. `ApiClient` — one `_request`, five thin verbs

**Rule: exactly one private method performs a request. The five verbs are wrappers with no
logic of their own.**

Every rule in §3 (timeouts, cancellation) and §5 (error conversion) is enforced in one place.
Five parallel implementations means five places to forget one of them, and they diverge within
a sprint.

```dart
// lib/core/network/api_client.dart
import 'dart:async';
import 'package:dio/dio.dart';

final class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Duration? overallTimeout,
  }) =>
      _request<T>(
        'GET',
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        overallTimeout: overallTimeout,
      );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? overallTimeout,
  }) =>
      _request<T>(
        'POST',
        path,
        body: body,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        overallTimeout: overallTimeout,
      );

  // put / patch / delete are identical wrappers — omitted for brevity.

  Future<T> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? overallTimeout,
  }) async {
    final overall = overallTimeout ?? const Duration(seconds: 30);
    try {
      final response = await _dio
          .request<T>(
            path,
            data: body,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
            options: Options(method: method, headers: headers),
          )
          .timeout(
        overall,
        onTimeout: () {
          cancelToken?.cancel('overall timeout');
          throw TimeoutException('$method $path exceeded $overall', overall);
        },
      );
      return response.data as T;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TimeoutException catch (_) {
      throw const TimeoutError();
    } on FormatException catch (e) {
      throw ParseError(detail: e.message);
    } on TypeError catch (_) {
      throw const ParseError(detail: 'unexpected response shape');
    }
  }
}
```

**Rule: cross-cutting concerns live in interceptors, not in `_request`.** Auth headers, tenant
headers, retry, refresh, logging and telemetry are all §4. `_request` does transport, the
overall timeout, and error conversion — nothing else. If `_request` grows an `if`, the rule
probably belongs in an interceptor.

---

## 3. Timeouts and cancellation

**Rule: set all four timeouts. Three are Dio options; the fourth is yours.**

| Timeout | Where | Covers | Typical |
|---|---|---|---|
| `connectTimeout` | `BaseOptions` | TCP + TLS handshake | 10s |
| `sendTimeout` | `BaseOptions` | Writing the request body | 30s (longer for upload) |
| `receiveTimeout` | `BaseOptions` | Gap between response bytes | 20s |
| Overall | `.timeout()` in `_request` | Whole call, end to end | 30s |

Dio has **no overall timeout**. `receiveTimeout` resets on every chunk, so a server dribbling
one byte a second holds the request open forever and the user watches a spinner that will
never resolve. The `.timeout()` in §2 is what bounds that — and it must `cancel` the token, or
the socket stays open behind a future nobody is awaiting.

```dart
// lib/core/network/dio_factory.dart
Dio createDio({required String baseUrl}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      // Let non-2xx reach the error path so §5 classifies it once.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );
}
```

**Rule: every service method accepts a `CancelToken`, and the caller binds it to disposal.**

A user who leaves a screen mid-request should not pay for the response, and a provider that
completes after disposal is a state-after-dispose crash. Binding is `state/riverpod`'s
business; the contract's job is to make it possible:

```dart
// Caller side — riverpod owns this pattern, shown for the token's lifecycle only.
final token = CancelToken();
ref.onDispose(() => token.cancel('provider disposed'));
final page = await ref.read(programServiceProvider).fetchPrograms(
      page: 1,
      cancelToken: token,
    );
```

A cancelled request surfaces as `CancelledError` (§5). It is never reported and never shown.

---

## 4. Interceptors

Registration order is the execution order for requests, and the reverse for responses. Put
auth first so retry and refresh see a signed request.

```dart
dio.interceptors.addAll([
  AuthInterceptor(tokens: tokens, refreshDio: refreshDio, onSignOut: onSignOut),
  TenantInterceptor(tenants: tenants),
  RetryInterceptor(dio),
  TelemetryInterceptor(),  // logging/flutter-observability owns the body
]);
```

### 4.1 Headers are read at request time

**Rule: auth and tenant headers are read from a store inside `onRequest`. Never a mutable
field with a public setter, and never `dio.options.headers`.**

A token cached in a field is stale the moment a refresh, a sign-out, or a tenant switch
happens on another code path. The symptom is a request signed with a dead token minutes after
the app already holds a live one — and because `dio.options.headers` is set once at sign-in,
sign-out leaves the header behind and the next user's request carries the previous user's
credentials.

```dart
// ✅ read per request
@override
Future<void> onRequest(
  RequestOptions options,
  RequestInterceptorHandler handler,
) async {
  final accessToken = await _tokens.readAccessToken();
  if (accessToken != null) {
    options.headers['Authorization'] = 'Bearer $accessToken';
  }
  options.headers['X-Tenant-Id'] = await _tenants.currentTenantId();
  handler.next(options);
}
```

```dart
// ❌ what gets written by default — stale on every refresh, leaks across sign-out
class ApiClient {
  String? _token;
  set token(String? value) {
    _token = value;
    _dio.options.headers['Authorization'] = 'Bearer $value';
  }
}
```

### 4.2 Refresh on 401 — single-flight, replay exactly once

**Rule: one `QueuedInterceptor` owns refresh. It replays the failed request exactly once,
guarded by `options.extra`, and signs out on a second failure.**

`QueuedInterceptor` serialises its handlers, so ten requests failing 401 at once produce one
refresh, not ten. A plain `InterceptorsWrapper` produces a refresh stampede: the first refresh
rotates the token, the other nine present a now-invalid refresh token, and the backend revokes
the family — the user is signed out for being online with a fast connection.

```dart
// lib/core/network/auth_interceptor.dart
final class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStore tokens,
    required Dio refreshDio,
    required Future<void> Function() onSignOut,
  })  : _tokens = tokens,
        _refreshDio = refreshDio,
        _onSignOut = onSignOut;

  final TokenStore _tokens;

  /// A bare Dio with the same baseUrl and no interceptors — replaying through
  /// the main Dio would re-enter this queue and deadlock.
  final Dio _refreshDio;
  final Future<void> Function() _onSignOut;

  static const String _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokens.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final alreadyRetried = options.extra[_retriedKey] == true;
    if (err.response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      await _onSignOut();
      handler.next(err);
      return;
    }

    options.extra[_retriedKey] = true;
    final accessToken = await _tokens.readAccessToken();
    options.headers['Authorization'] = 'Bearer $accessToken';
    try {
      handler.resolve(await _refreshDio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refresh_token': refreshToken},
      );
      await _tokens.save(
        accessToken: response.data!['access_token'] as String,
        refreshToken: response.data!['refresh_token'] as String,
      );
      return true;
    } on DioException catch (_) {
      await _tokens.clear();
      return false;
    }
  }
}
```

### 4.3 Retry — idempotent verbs, backoff with jitter

**Rule: retry `GET`/`HEAD`/`OPTIONS`/`PUT`/`DELETE` on transport failures, 429 and 5xx.
Retry `POST` only when it carries an `Idempotency-Key`.**

A retried non-idempotent POST is a duplicate order, a duplicate message, a double charge. And
retries without jitter synchronise every client that failed in the same outage into the same
millisecond, so the backend comes back up and is immediately knocked down again by its own
users.

```dart
// lib/core/network/retry_interceptor.dart
import 'dart:math';

final class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxAttempts = 3, Random? random})
      : _random = random ?? Random();

  final Dio _dio;
  final int maxAttempts;
  final Random _random;

  static const Set<String> _idempotentMethods = {
    'GET',
    'HEAD',
    'OPTIONS',
    'PUT',
    'DELETE',
  };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isRetryable(err) || !_isIdempotent(options)) {
      handler.next(err);
      return;
    }

    final attempt = (options.extra['retry_attempt'] as int? ?? 0) + 1;
    if (attempt >= maxAttempts) {
      handler.next(err);
      return;
    }
    options.extra['retry_attempt'] = attempt;

    final backoff = Duration(milliseconds: 300 * (1 << (attempt - 1)));
    final jitter = Duration(milliseconds: _random.nextInt(backoff.inMilliseconds));
    await Future<void>.delayed(backoff + jitter);

    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isIdempotent(RequestOptions options) =>
      _idempotentMethods.contains(options.method.toUpperCase()) ||
      options.headers.containsKey('Idempotency-Key');

  bool _isRetryable(DioException err) => switch (err.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        DioExceptionType.badResponse => _isRetryableStatus(err.response?.statusCode),
        _ => false,
      };

  bool _isRetryableStatus(int? status) =>
      status == 429 || (status != null && status >= 500);
}
```

`DioExceptionType.cancel` is never retryable — a cancelled request is a deliberate act.

---

## 5. The sealed `AppError` hierarchy

**Rule: one sealed hierarchy. Foreign exceptions are converted at the boundary exactly once,
and classified by type — never by a `toString()` substring.**

Sealed gives exhaustive `switch` in the UI: add an error case and every unhandled `switch`
becomes a compile error rather than a runtime fallthrough. Substring matching on
`e.toString()` breaks on a Dio upgrade, an OS locale change, or a platform difference — and
it fails *open*, classifying a real server error as "unknown" and showing the wrong message.

```dart
// lib/core/error/app_error.dart
sealed class AppError implements Exception {
  const AppError({required this.message});

  final String message;

  /// See §6.
  bool get isReportable;
}

final class NetworkError extends AppError {
  const NetworkError() : super(message: 'No internet connection.');
  @override
  bool get isReportable => false;
}

final class TimeoutError extends AppError {
  const TimeoutError() : super(message: 'The request took too long.');
  @override
  bool get isReportable => false;
}

final class CancelledError extends AppError {
  const CancelledError() : super(message: 'Request cancelled.');
  @override
  bool get isReportable => false;
}

final class UnauthorizedError extends AppError {
  const UnauthorizedError() : super(message: 'Please sign in again.');
  @override
  bool get isReportable => false;
}

final class ForbiddenError extends AppError {
  const ForbiddenError() : super(message: 'You do not have access to this.');
  @override
  bool get isReportable => false;
}

final class NotFoundError extends AppError {
  const NotFoundError() : super(message: 'Not found.');
  @override
  bool get isReportable => false;
}

final class ConflictError extends AppError {
  const ConflictError() : super(message: 'This changed while you were editing.');
  @override
  bool get isReportable => false;
}

final class ValidationError extends AppError {
  const ValidationError({required this.fieldErrors})
      : super(message: 'Please check the highlighted fields.');

  final Map<String, List<String>> fieldErrors;

  @override
  bool get isReportable => false;
}

final class RateLimitedError extends AppError {
  const RateLimitedError({this.retryAfter})
      : super(message: 'Too many requests. Try again shortly.');

  final Duration? retryAfter;

  @override
  bool get isReportable => false;
}

final class ServerError extends AppError {
  const ServerError({required this.statusCode})
      : super(message: 'Something went wrong on our side.');

  final int statusCode;

  @override
  bool get isReportable => true;
}

final class ParseError extends AppError {
  const ParseError({required this.detail})
      : super(message: 'Something went wrong on our side.');

  final String detail;

  @override
  bool get isReportable => true;
}

final class UnknownError extends AppError {
  const UnknownError({this.cause}) : super(message: 'Something went wrong.');

  final Object? cause;

  @override
  bool get isReportable => true;
}
```

The single conversion point:

```dart
// lib/core/error/map_dio_exception.dart
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

AppError mapDioException(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      const TimeoutError(),
    DioExceptionType.connectionError => const NetworkError(),
    DioExceptionType.badCertificate => const NetworkError(),
    DioExceptionType.cancel => const CancelledError(),
    DioExceptionType.badResponse => _mapStatus(e.response),
    DioExceptionType.unknown =>
      e.error is SocketException ? const NetworkError() : UnknownError(cause: e.error),
  };
}

AppError _mapStatus(Response<dynamic>? response) {
  final status = response?.statusCode ?? 0;
  return switch (status) {
    401 => const UnauthorizedError(),
    403 => const ForbiddenError(),
    404 => const NotFoundError(),
    409 => const ConflictError(),
    422 => ValidationError(fieldErrors: _fieldErrors(response?.data)),
    429 => RateLimitedError(retryAfter: _retryAfter(response)),
    _ => ServerError(statusCode: status),
  };
}
```

**Rule: convert once, at the `ApiClient` boundary.** Once past `_request`, nothing in the app
sees `DioException` again. A service, repository or provider that catches `DioException` has
duplicated the classification table, and the two copies will disagree.

The UI switches exhaustively:

```dart
Widget buildError(AppError error) => switch (error) {
      NetworkError() || TimeoutError() => const OfflineBanner(),
      UnauthorizedError() => const SignInPrompt(),
      ValidationError(:final fieldErrors) => FieldErrorList(errors: fieldErrors),
      RateLimitedError(:final retryAfter) => RateLimitNotice(retryAfter: retryAfter),
      CancelledError() => const SizedBox.shrink(),
      _ => const GenericErrorView(),
    };
```

---

## 6. `isReportable`

**Rule: whether an error reaches the crash reporter is a property of the error type, not a
decision made at each catch site.**

An expected 4xx is the API working correctly. Reporting it turns Crashlytics into a log of
users mistyping passwords, and the one real regression is buried under ten thousand
`UnauthorizedError`s. Anything the backend or the client got *wrong* — 5xx, a parse failure,
an unclassified exception — is reportable.

| Error | Reportable | Because |
|---|---|---|
| `NetworkError`, `TimeoutError` | ✗ | The user is on a train |
| `CancelledError` | ✗ | Deliberate |
| `UnauthorizedError`, `ForbiddenError`, `NotFoundError`, `ConflictError`, `ValidationError`, `RateLimitedError` | ✗ | Expected outcomes; they are UI state |
| `ServerError`, `ParseError`, `UnknownError` | ✓ | A contract was broken |

```dart
// One place asks; nothing else decides. logging/flutter-observability owns the sink.
void reportIfNeeded(AppError error, StackTrace stackTrace) {
  if (!error.isReportable) return;
  crashReporter.recordError(error, stackTrace);
}
```

---

## 7. Offline cache policy

**Rule: every cacheable resource declares one policy, in a decorator over the service.**

The policy is a property of the resource, decided once and visible in one place — a list the
user needs on a plane is not the same as a payment confirmation that must never be served
from disk. Ad-hoc caching inside call sites gives an app where nobody can say which screens
work offline.

| Policy | Reads | Use for |
|---|---|---|
| `networkOnly` | Network; error propagates | Payments, auth, anything where stale is wrong |
| `networkFirst` | Network, falling back to cache on connectivity failure | Lists and detail views the user re-opens |
| `cacheFirst` | Fresh cache if within TTL, else network | Reference data: categories, config, static copy |
| `cacheThenNetwork` | Emits cache immediately, then the network result | Screens that must paint instantly |

```dart
// lib/core/network/cache_policy.dart
enum CachePolicy { networkOnly, networkFirst, cacheFirst, cacheThenNetwork }

/// Staleness travels with the data all the way to the UI.
final class Cached<T> {
  const Cached({
    required this.value,
    required this.fetchedAt,
    required this.isStale,
  });

  final T value;
  final DateTime fetchedAt;
  final bool isStale;

  Cached<T> asStale() =>
      Cached<T>(value: value, fetchedAt: fetchedAt, isStale: true);
}
```

**Rule: fall back to cache on connectivity and network errors only. Never on a 4xx, never on a
parse failure — so never a bare `catch`.**

A 404 means the resource is gone; serving the cached copy shows the user a program that was
deleted. A parse failure means the contract changed; serving cache hides a broken client until
it is a production incident. `on NetworkError catch (_)` is the whole allowance.

```dart
// lib/features/programs/data/services/caching_program_service.dart
final class CachingProgramService implements ProgramService {
  const CachingProgramService(
    this._inner,
    this._store, {
    this.policy = CachePolicy.networkFirst,
    this.ttl = const Duration(minutes: 15),
  });

  final ProgramService _inner;
  final ProgramCacheStore _store;

  /// Declared once, here — this resource's offline contract.
  final CachePolicy policy;
  final Duration ttl;

  @override
  Future<Cached<List<Program>>> fetchPrograms({
    required int page,
    CancelToken? cancelToken,
  }) async {
    final cached = await _store.readPage(page);

    if (policy == CachePolicy.cacheFirst && cached != null && !_isExpired(cached)) {
      return cached;
    }

    try {
      final fresh = await _inner.fetchPrograms(page: page, cancelToken: cancelToken);
      await _store.writePage(page, fresh);
      return fresh;
    } on NetworkError catch (_) {
      if (cached != null) return cached.asStale();
      rethrow;
    } on TimeoutError catch (_) {
      if (cached != null) return cached.asStale();
      rethrow;
    }
  }

  @override
  Future<Program> fetchProgram(String id, {CancelToken? cancelToken}) =>
      _inner.fetchProgram(id, cancelToken: cancelToken);

  bool _isExpired(Cached<List<Program>> cached) =>
      DateTime.now().difference(cached.fetchedAt) > ttl;
}
```

**Rule: staleness reaches the UI.** A user looking at data from yesterday must be able to tell.
`isStale` is rendered — a banner, a timestamp, a dimmed refresh affordance — never dropped
between the decorator and the widget.

```dart
if (page.isStale) StaleDataBanner(fetchedAt: page.fetchedAt),
```

The composition root wraps, so nothing else changes:

```dart
programServiceProvider.overrideWithValue(
  CachingProgramService(RestProgramService(apiClient), programCacheStore),
),
```

---

## 8. Media upload

**Rule: never upload the file the picker handed you. Compress, bake EXIF orientation, and
re-encode first.**

A modern phone camera produces an 8–12 MB JPEG. Uploading it burns the user's data, takes
tens of seconds on mobile, and often fails on the server's body limit. Worse, iOS stores
portrait photos as landscape pixels plus an EXIF orientation tag — Flutter's `Image.file`
honours it, most backends and web clients do not, so the photo that looked upright in the
picker appears rotated 90° everywhere else. `bakeOrientation` rewrites the pixels so the tag
is no longer load-bearing.

```dart
// lib/core/network/media_upload.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

const int _maxDimension = 1600;
const int _jpegQuality = 82;

Future<File> prepareImageForUpload(File picked) async {
  final decoded = img.decodeImage(await picked.readAsBytes());
  if (decoded == null) {
    throw const ParseError(detail: 'unsupported image format');
  }

  // 1. Bake EXIF orientation into the pixels.
  final oriented = img.bakeOrientation(decoded);

  // 2. Downscale on the longest edge.
  final resized = (oriented.width > _maxDimension || oriented.height > _maxDimension)
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? _maxDimension : null,
          height: oriented.height > oriented.width ? _maxDimension : null,
        )
      : oriented;

  // 3. Re-encode — this is what strips the remaining EXIF, GPS included.
  final jpeg = img.encodeJpg(resized, quality: _jpegQuality);

  // 4. Generated filename. Never the picker's — it leaks the device path and
  //    can carry a traversal sequence or a user's name into the bucket key.
  final out = File('${Directory.systemTemp.path}/${Uuid().v4()}.jpg');
  await out.writeAsBytes(jpeg, flush: true);
  return out;
}
```

**Rule: every upload has progress, cancel, and an idempotency key.** An upload is the longest
operation in the app; without progress the user force-quits, and without an idempotency key
the retry in §4.3 (or the user's own second attempt) creates a duplicate attachment.

```dart
Future<PhotoRef> uploadProgramPhoto({
  required ApiClient client,
  required String programId,
  required File prepared,
  required String idempotencyKey,
  void Function(double fraction)? onProgress,
  CancelToken? cancelToken,
}) async {
  final form = FormData.fromMap(<String, dynamic>{
    'file': MultipartFile.fromBytes(
      await prepared.readAsBytes(),
      filename: '$idempotencyKey.jpg',
      contentType: MediaType('image', 'jpeg'),
    ),
  });

  final json = await client.post<Map<String, dynamic>>(
    '/programs/$programId/photos',
    body: form,
    headers: <String, String>{'Idempotency-Key': idempotencyKey},
    cancelToken: cancelToken,
    onSendProgress: (sent, total) {
      if (total > 0) onProgress?.call(sent / total);
    },
    overallTimeout: const Duration(minutes: 5),
  );
  return PhotoRef.fromJson(json);
}
```

**Rule: files over ~10 MB upload in resumable chunks, not one request.** A 40 MB video on a
mobile connection will lose the socket at least once; a single request restarts from zero
every time and may never complete.

| Size | Strategy |
|---|---|
| < 10 MB | Single multipart request, as above |
| ≥ 10 MB | Chunked: `POST /uploads` to open a session, `PUT` each chunk with `Content-Range`, `POST /uploads/{id}/complete`. Persist the session id so a resume survives app restart. |

---

## 9. Common mistakes

| Mistake | Why it hurts | Instead |
|---|---|---|
| Feature depends on `RestProgramService` | No fake, no offline decorator, no mock server | Depend on the contract (§1) |
| `Dio` injected into a service | Cross-cutting rules land at call sites | Inject `ApiClient` (§2) |
| Five verb methods each with their own try/catch | Rules drift within a sprint | One `_request` (§2) |
| Only `connectTimeout` set | A dribbling server hangs forever | All four (§3) |
| `dio.options.headers['Authorization'] = …` at sign-in | Stale after refresh; leaks across sign-out | Read in `onRequest` (§4.1) |
| `InterceptorsWrapper` for refresh | Refresh stampede revokes the token family | `QueuedInterceptor` (§4.2) |
| Replay without an `extra` guard | Infinite 401 loop | `options.extra[_retriedKey]` (§4.2) |
| Retrying every failed request | Duplicate orders and charges | Idempotent verbs, or an `Idempotency-Key` (§4.3) |
| Fixed retry delay | Synchronised thundering herd on recovery | Backoff + jitter (§4.3) |
| `if (e.toString().contains('Socket'))` | Breaks on upgrade or locale, fails open | `switch` on `DioExceptionType` (§5) |
| Catching `DioException` in a repository | Two disagreeing classification tables | Convert once in `_request` (§5) |
| `recordError` at every catch site | Crash reporting drowned in expected 4xx | `isReportable` on the type (§6) |
| `} catch (_) { return cache; }` | Serves deleted resources; hides a broken contract | `on NetworkError catch (_)` only (§7) |
| Cache returned without staleness | User acts on yesterday's data believing it is live | `Cached<T>` with `isStale` (§7) |
| `MultipartFile.fromFile(picked.path)` | 12 MB upload, rotated photo, leaked EXIF GPS | `bakeOrientation` → resize → `encodeJpg` → `fromBytes` (§8) |
| Upload with no `Idempotency-Key` | Retry creates a duplicate attachment | Key per user-initiated upload (§8) |
