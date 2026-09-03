# Brief — `logging/flutter-observability`

**Kind:** layer · **Issue:** #2 · **Cookbook:** `#logging`, `#analytics`, `#flags`

## Globs
```yaml
paths:
  - "**/core/observability/*.dart"
  - "**/core/logging/*.dart"
  - "**/*_logger.dart"
  - "**/*analytics*.dart"
  - "**/*remote_config*.dart"
  - "**/*feature_flag*.dart"
```

## Rules to encode
1. One logging facade, injected via provider, level-configurable, silent in release below
   warning. Two logging systems means no way to raise a level or guarantee silence.
2. Ban `print` **and** `debugPrint` — `avoid_print` does not catch the latter, and it writes
   to the system log in release too.
3. Never log a credential, token or full URI. Redaction lives in the facade so a call site
   cannot skip it. Log method and path; redact the query string.
4. Crash-report context set once: flavor, version, pseudonymous user id, current route, plus
   navigation breadcrumbs.
5. All three global error channels installed — `FlutterError.onError`,
   `PlatformDispatcher.onError`, a zone guard around `runApp`.
6. **Analytics:** events are a sealed set of types, not strings. One naming convention
   (`object_verb`, snake_case, past tense). No personal data as a property. Screen views from
   a nav observer. Consent checked **before collection**, not before reporting — a queued
   event awaiting consent is data collected without permission. Debug builds never write to
   production analytics.
7. **Flags:** typed, with a compiled-in default that is the safe behaviour, so the app works
   with no network. Version gate **fails open** on unreachable config — a blocking screen
   from a backend blip is a self-inflicted outage. Every risky feature ships with a verified
   kill switch. Every flag has an owner and a removal date. Flags never gate security.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Log a push registration including the token | `redact` | `token` interpolated into the message |
| 02 | Install global error capture at startup | `FlutterError.onError`, `PlatformDispatcher`, `runZonedGuarded` | only one channel |
| 03 | Define and log an analytics event | `sealed`/`final class`, `snake_case` name | `log('...', {` free-form |
| 04 | A minimum-supported-version gate | `hasFetched`, early return | block on unfetched config |

## Boundaries
Error *types* are `api-style/dio`. Crash triage practice is the `/flutter-monitoring` command.
