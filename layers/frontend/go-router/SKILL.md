---
name: go-router
description: go_router navigation standards for Flutter — URL-addressable routes, path parameters vs extra, typed routes with go_router_builder, one top-level redirect plus refreshListenable for authorization, intended-destination preservation, errorBuilder, push-notification route payloads, and the server-side deep-link files assetlinks.json and apple-app-site-association. Load when writing or reviewing the route table, deep links, or well-known files.
user-invocable: false
stack: frontend/go-router
paths:
  - "**/core/router/*.dart"
  - "**/routes.dart"
  - "**/app_router.dart"
  - "**/.well-known/**"
---

Full standards in [go-router.md](go-router.md). Always-on summary:

**Scope:** the route table and the deep-link contract. Screen and widget code is `frontend/flutter-ui`; who the user is and how the session refreshes is `auth/flutter-session`.

**The one rule everything else serves:**
- Every screen is reachable from a cold start with only a URL. A screen reachable only by an in-app tap cannot be deep-linked, notified into, restored after process death, or opened directly in a test.

**Routes:**
- Identity goes in the path — `/programs/:id` — and the screen fetches by that id. The screen constructor takes `required this.id`, never a model object.
- `extra` is an optional render-ahead hint, never the only copy. Read it as a nullable (`state.extra as Program?`); a non-nullable `state.extra as Program` throws on every entry that is not an in-app push — deep link, notification tap, process-death restore, `flutter run --route`.
- Typed routes via `go_router_builder`: `@TypedGoRoute<ProgramRoute>(path: '/programs/:id')` on `class ProgramRoute extends GoRouteData with _$ProgramRoute`. Call sites are `ProgramRoute(id: p.id).push(context)`, never an interpolated string.

**Authorization lives in the route table:**
- One top-level `redirect:` on `GoRouter` reads session and role and compares `state.matchedLocation` against a public allowlist, plus one `refreshListenable` so the redirect re-runs when auth changes. Never a guard in a screen's `build`/`initState`, never a `StreamBuilder` swapping the home widget.
- `redirect` is pure and synchronous — no `await`, no fetch, no writes — returns `null` for "carry on", and returns `null` while the session is still restoring, or it bounces a signed-in user to sign-in on every cold start.
- A guarded redirect preserves the destination: send to `/sign-in?from=${Uri.encodeComponent(state.uri.toString())}`, and after sign-in go to `state.uri.queryParameters['from']` — validated with `startsWith('/')`, since an absolute value is an open redirect — falling back to the home location, never unconditionally home.
- `errorBuilder` renders a real not-found screen. A link is attacker-controlled input.

**External entry points:** a push payload carries a route *location* (`data['route']`), checked with `startsWith('/')` and resolved through the same table with `router.go(...)`; never a `Navigator.push` of a screen built from payload fields.

**Android App Links — `.well-known/assetlinks.json`:**
- `relation: ["delegate_permission/common.handle_all_urls"]`, `namespace: "android_app"`, the **flavor's** `package_name`, and `sha256_cert_fingerprints`.
- The fingerprint is the **Play app signing** certificate (Play Console → App integrity → App signing key certificate), never the upload key — Play re-signs the app, so the upload key is never on the device, and this is the single most common cause of App Links failing to verify, silently. In a checked-in template the placeholder names its source: `PLAY_APP_SIGNING_SHA256`, substituted at deploy time.
- Pair it with `android:autoVerify="true"` on the flavor's `https` intent-filter.

**iOS Universal Links — `.well-known/apple-app-site-association`:** the filename has no extension; adding `.json` to it means iOS never fetches it and every link silently opens Safari instead. `applinks.details[].appIDs` = `<TeamID>.<bundleId>`; use `components` with `{"/": "/programs/*"}` and `exclude: true` for web-only paths, not the legacy flat `paths` array.

**Both files:** HTTPS, no redirect, no auth, `Content-Type: application/json`, one file per flavor domain, and a real web page behind every deep-linkable path.

**Related:** `frontend/flutter-ui`, `auth/flutter-session`, `state/riverpod`, `testing/flutter-test`.
