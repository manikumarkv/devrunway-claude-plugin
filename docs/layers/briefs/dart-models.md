# Brief — `language/dart-models`

**Kind:** layer · **Issue:** #2 · **Cookbook:** `#model`

## Globs
```yaml
paths:
  - "**/domain/models/*.dart"
  - "**/domain/**/*.dart"
  - "**/data/dto/*.dart"
```

## Rules to encode
1. Generate models with `freezed` + `json_serializable`. Never hand-write `fromJson`.
2. No unchecked casts on server JSON — `as String`, `as Map<String, dynamic>` are the
   symptom. `strict-casts: true` is what makes this enforceable.
3. Closed sets are enums with `@JsonValue` and an `unknown` fallback, never bare strings
   compared at call sites.
4. Value equality on every model — without it Riverpod rebuilds on every identical fetch.
5. Domain models ≠ API models. A DTO at the boundary when the wire shape is awkward
   (`_id`, snake_case, nullable-on-wire-but-required-in-domain).
6. Nullable means something the UI handles. Never nullable to dodge a parse error.
7. Dates parsed as UTC, converted only at the display edge, formatted through `intl`.
8. Derived values are getters, never stored fields that can disagree.
9. No Flutter imports in `domain/`.

## Eval cases
| id | Scenario | must_contain | must_not_contain |
|---|---|---|---|
| 01 | Model a `Program` with id, name, status, optional start date | `@freezed`, `_$ProgramFromJson` | `as String`, `json['name'] as` |
| 02 | Model a status field that the backend may extend | `enum`, `@JsonValue`, `unknown` | `== 'active'` |
| 03 | Model an API response whose field is `_id` and dates are ISO strings | `@JsonKey`, `DateTime` | `dynamic` |

## Boundaries
Serialization and shape only. Fetching is `api-style/dio`. Naming is `naming-conventions`.
