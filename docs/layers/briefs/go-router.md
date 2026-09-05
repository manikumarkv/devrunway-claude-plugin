# Brief — `frontend/go-router`

**Kind:** layer · **Issue:** #7 (parent #2) · **Cookbook:** `#route`, `#deeplinksetup`

## Globs
```yaml
paths:
  - "**/core/router/*.dart"
  - "**/routes.dart"
  - "**/app_router.dart"
  - "**/.well-known/**"
```

## Rules to encode
1. Every screen reachable from a cold start with only a URL. That single constraint buys
   deep links, push targets, state restoration and testability together.
2. IDs in the path (`/programs/:id`); the screen fetches by id. `extra` is an optional
   render-ahead hint, never the only copy — a non-nullable `state.extra as X` throws on
   every entry that is not an in-app push.
3. Authorization in the route table: one top-level `redirect` reading auth and role, one
   `refreshListenable`. Never a guard inside a screen.
4. A guarded redirect preserves the intended destination and returns to it after sign-in.
5. Typed routes generated with `go_router_builder`; no string paths at call sites.
6. `errorBuilder` renders a real not-found screen — links are attacker-controlled input.
7. Push payloads carry a route location resolved through the same table.
8. **App Links / Universal Links:** `assetlinks.json` carries the **Play app signing**
   fingerprint, not the upload key. Both files served over HTTPS, no redirect, no auth,
   `application/json`. Every deep-linkable path has a real web page behind it.

## Eval cases
*Assertions below are sketches of intent, not literal strings. Replace any prose
with a discriminating code token — see AUTHORING.md section 6.*

| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Add a program detail route | `:id`, `pathParameters` | `state.extra as Program` |
| 02 | Guard the authenticated surface | `redirect:`, `refreshListenable` | guard inside a widget `build` |
| 03 | Write `assetlinks.json` for a flavor | `sha256_cert_fingerprints`, `delegate_permission` | upload-key wording |

## Boundaries
Screens are `frontend/flutter-ui`. Session state is `auth/flutter-session`.
