# Brief — `i18n/flutter-l10n`

**Kind:** layer · **Issue:** #12 (parent #2) · **Cookbook:** `#strings`

## Globs
```yaml
paths:
  - "**/l10n/**"
  - "**/*.arb"
  - "**/l10n.yaml"
```

## Rules to encode
1. No user-facing literal in a widget. Enable the hardcoded-string check so a literal fails
   the build — otherwise you accumulate hundreds of keys beside hundreds of literals with no
   way to tell which screens are done.
2. Keys named by meaning (`programEnrollButton`, not `label12`); every key has a
   `description` — that is all a translator sees. Placeholders typed and named.
3. ICU plurals and select. Never sentence concatenation — word order differs by language.
4. Dates, numbers and currency through `intl` with the active locale, never a hardcoded
   pattern or interpolation.
5. Device locale is the default; an in-app override is a persisted preference that drives
   formats and text direction as well as strings.
6. Directional insets and alignment from the first screen; directional icons flip with
   `Directionality.of(context)`.
7. An RTL golden proves the layout before a locale ships; a pseudo-locale in CI surfaces
   overflow from longer translations.
8. Server-supplied text carries a locale or is translated server-side.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Show a count of enrolled students | `plural`, `count` | `'$count students'` |
| 02 | An ARB entry for a screen title | `"@`, `description` | key with no `@` metadata |
| 03 | Pad a row leading and trailing | `EdgeInsetsDirectional`, `start:` | `EdgeInsets.only(left:` |

## Boundaries
Widget structure is `frontend/flutter-ui`. Theme text styles are `mobile/flutter`.
