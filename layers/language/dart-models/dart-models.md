# Dart model standards

**Scope boundaries.** This layer covers the *shape* of data and how it crosses the JSON boundary: model definition, code generation, key mapping, enums, nullability, dates, and derived values. It does **not** cover how data is fetched — HTTP clients, `Dio` interceptors, retries, error mapping and offline caching are `api-style/dio`. It does **not** cover how a model reaches a widget — providers, invalidation, pagination and loading state are `state/riverpod`. Field, file and env var naming is `naming-conventions`. Everything below assumes a `domain/` (pure Dart) and `data/` (wire-facing) split.

---

## 1. Every model is generated — `freezed` + `json_serializable`

**Rule: define the model as a `@freezed` class with a `fromJson` factory delegating to the generated `_$<Model>FromJson`. Never hand-write `fromJson` or `toJson`.**

Hand-written parsing drifts from the class the moment a field is added, and the drift is silent — a missing field parses as `null` and surfaces three screens later.

```dart
// lib/domain/models/program.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../converters/utc_date_time_converter.dart';

part 'program.freezed.dart';
part 'program.g.dart';

@freezed
class Program with _$Program {
  const Program._(); // required to add getters/methods below

  const factory Program({
    required String id,
    required String name,
    @JsonKey(unknownEnumValue: ProgramStatus.unknown)
    required ProgramStatus status,
    @NullableUtcDateTimeConverter() DateTime? startsAt,
    @Default(<String>[]) List<String> tags,
  }) = _Program;

  factory Program.fromJson(Map<String, dynamic> json) =>
      _$ProgramFromJson(json);

  bool get isUpcoming =>
      startsAt != null && startsAt!.isAfter(DateTime.now().toUtc());
}
```

```dart
// ❌ what a competent developer writes by default — and why it fails
factory Program.fromJson(Map<String, dynamic> json) => Program(
      id: json['id'] as String,            // throws on a schema change
      name: json['name'] as String,        // throws on a null the server now sends
      status: ProgramStatus.values
          .byName(json['status'] as String), // throws on a new server value
    );
```

**Regenerate with:**

```bash
dart run build_runner build --delete-conflicting-outputs
# during development
dart run build_runner watch --delete-conflicting-outputs
```

**Freezed 3.x:** the class must carry an explicit modifier — `@freezed abstract class Program with _$Program` for a plain model, `sealed class` for a union. Freezed 2.x uses a bare `class`. Match whatever the rest of the project already uses; do not mix.

Generated files (`*.freezed.dart`, `*.g.dart`) are committed or gitignored consistently across the repo, never per-file. Exclude them from the analyzer either way.

---

## 2. No unchecked casts on server JSON

**Rule: `strict-casts: true` in `analysis_options.yaml`. `as String` and `as Map<String, dynamic>` applied to a JSON value are the symptom this setting exists to eliminate.**

A cast on a `dynamic` from the network is an assertion about a system you do not control. Without `strict-casts` the analyzer accepts the implicit version too, so the rule is unenforceable by review alone.

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
    strict-inference: true
  errors:
    # freezed places @JsonKey / converters on factory parameters
    invalid_annotation_target: ignore
  exclude:
    - "**/*.freezed.dart"
    - "**/*.g.dart"
```

- `Map<String, dynamic>` in the `fromJson` **signature** is required and correct — that is the codegen contract, not a cast.
- `dynamic` as a *model field type* is never correct. If the wire field is genuinely polymorphic, model it as a freezed union (`sealed`) with a discriminator, not as `dynamic`.
- No `json[...]` subscripting anywhere outside generated code.

---

## 3. Closed sets are enums with `@JsonValue` and an `unknown` fallback

**Rule: a field with a fixed set of server values is an `enum`, every member carries `@JsonValue`, the enum has an `unknown` member, and the field carries `@JsonKey(unknownEnumValue: ...)`.**

Two failures this prevents. A server that adds a value must not crash the parse — without the fallback, `json_serializable` throws and the whole response is lost, not just the one field. And a bare `String` field pushes the comparison to every call site, where a typo is a silent `false` rather than a compile error.

```dart
@JsonEnum()
enum ProgramStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('active')
  active,
  @JsonValue('archived')
  archived,
  @JsonValue('unknown')
  unknown;

  bool get isOpenForEnrolment => this == ProgramStatus.active;
}
```

```dart
// ✅ field declaration — a new server value degrades to `unknown`
@JsonKey(unknownEnumValue: ProgramStatus.unknown)
required ProgramStatus status,
```

```dart
// ❌ the default wrong answer
required String status,          // in the model
if (program.status == 'active')  // at every call site
```

- The `@JsonValue` strings are the wire contract. Rename the Dart member freely; changing a `@JsonValue` is a breaking change.
- Put the predicate on the enum (`isOpenForEnrolment`), not in the widget. One place to change when the product adds a fourth status.
- `switch` over the enum in a Dart 3 switch expression gets exhaustiveness checking — the compiler tells you where to handle the new member.

---

## 4. Value equality on every model

**Rule: models compare by value. Freezed generates `==`/`hashCode`; do not write a model class without it.**

Riverpod, `select`, `AnimatedSwitcher` and every `didUpdateWidget` compare old to new. With identity equality, a refetch that returns byte-identical JSON produces a new object, which compares unequal, which rebuilds the subtree. The list flickers and the scroll position jumps, and nothing in the widget code looks wrong.

- Freezed uses `DeepCollectionEquality` for `List`/`Map`/`Set` fields, so collection-valued models compare correctly.
- Collections in a model are treated as immutable. Never mutate a list in place; `copyWith(tags: [...tags, tag])`.
- Do not add a hand-written `==` on top of freezed. It will disagree with the generated `hashCode`.

---

## 5. Domain models are not API models

**Rule: the domain model is the shape the app wants. Add a DTO in `data/dto/` when the wire shape is awkward, and map at the boundary.**

| Wire situation | Response |
|---|---|
| Field named `_id`, `programName`, `starts_at` | `@JsonKey(name: '...')` on the domain model — no DTO needed |
| Whole payload is snake_case | `@JsonSerializable(fieldRename: FieldRename.snake)` — no DTO needed |
| Nullable on the wire, required in the domain | **DTO**, with the default applied in `toDomain()` |
| Envelope (`{ data: {...}, meta: {...} }`) | **DTO** for the envelope, domain model for `data` |
| One wire object splits into two domain concepts | **DTO** |
| Field the app never reads | Omit it. A model is not a mirror of the payload. |

A DTO for a payload that is already the right shape is pure ceremony. Reach for `@JsonKey` first.

```dart
// lib/data/dto/enrolment_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/models/enrolment.dart';
import '../../domain/converters/utc_date_time_converter.dart';

part 'enrolment_dto.freezed.dart';
part 'enrolment_dto.g.dart';

@freezed
class EnrolmentDto with _$EnrolmentDto {
  const EnrolmentDto._();

  const factory EnrolmentDto({
    @JsonKey(name: '_id') required String id,
    @JsonKey(name: 'program_id') required String programId,
    @JsonKey(name: 'seats_remaining') int? seatsRemaining,
    @JsonKey(name: 'enrolled_at')
    @UtcDateTimeConverter()
    required DateTime enrolledAt,
  }) = _EnrolmentDto;

  factory EnrolmentDto.fromJson(Map<String, dynamic> json) =>
      _$EnrolmentDtoFromJson(json);

  Enrolment toDomain() => Enrolment(
        id: id,
        programId: programId,
        seatsRemaining: seatsRemaining ?? 0,
        enrolledAt: enrolledAt,
      );
}
```

```dart
// lib/domain/models/enrolment.dart — no .g.dart, it is never parsed directly
import 'package:freezed_annotation/freezed_annotation.dart';

part 'enrolment.freezed.dart';

@freezed
class Enrolment with _$Enrolment {
  const factory Enrolment({
    required String id,
    required String programId,
    required int seatsRemaining,
    required DateTime enrolledAt,
  }) = _Enrolment;
}
```

`toDomain()` lives on the DTO, not on the domain model — `domain/` must not know `data/` exists. The repository in `data/` calls it; see `api-style/dio`.

---

## 6. Nullable means the UI has a state for it

**Rule: a field is nullable only when "absent" is a real product state the UI renders differently. Never make a field nullable to stop a parse from failing.**

`String? name` because the parse crashed once is how a screen ends up rendering an empty title with no explanation and no error. The null propagates to a place that has no context to handle it.

| Situation | Model as |
|---|---|
| Optional by product design (no avatar, no end date) | `T?` — the UI has an empty state |
| Server sometimes omits it, but the app requires it | Required in the domain, defaulted in the DTO's `toDomain()` |
| Server contract says required and it arrives null | Non-nullable. Let the parse throw and surface it as a contract error |
| Empty list | `@Default(<T>[]) List<T>` — never `List<T>?` |
| Empty string that means "none" | Map to `null` in the DTO, or model the absence explicitly |

Never `List<T>?`. The call site then handles null *and* empty, and the two mean the same thing.

---

## 7. Dates are UTC in the model, local only at the display edge

**Rule: parse to UTC through a `JsonConverter`, store UTC, call `.toLocal()` only where the value is rendered, and format with `intl`'s `DateFormat`.**

`DateTime.parse` returns a *local* `DateTime` unless the string ends in `Z`. Two devices in different zones then compute different values for "is this in the past", and comparing a local `DateTime` with a UTC one silently compares wall-clock numbers.

```dart
// lib/domain/converters/utc_date_time_converter.dart
import 'package:freezed_annotation/freezed_annotation.dart';

class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toUtc();

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}

class NullableUtcDateTimeConverter implements JsonConverter<DateTime?, String?> {
  const NullableUtcDateTimeConverter();

  @override
  DateTime? fromJson(String? json) =>
      json == null ? null : DateTime.parse(json).toUtc();

  @override
  String? toJson(DateTime? object) => object?.toUtc().toIso8601String();
}
```

```dart
// ✅ presentation layer — the only place .toLocal() appears
Text(DateFormat.yMMMd().add_jm().format(program.startsAt!.toLocal()))
```

- Never build a date string with `substring`, `split('T')`, or string interpolation of `.day`/`.month`. `intl` handles locale, ordering and the 12/24-hour setting; ad-hoc formatting handles none of them. See `i18n/flutter-l10n`.
- Compare with `DateTime.now().toUtc()`, never bare `DateTime.now()`.
- A calendar date with no time (a birthday, a due date) is not a `DateTime` in a timezone. Model it as `String` in `yyyy-MM-dd` or a dedicated value type; converting it to UTC shifts it a day for half the world.

---

## 8. Derived values are getters, never stored fields

**Rule: anything computable from other fields is a getter on the model. Add `const Model._();` to the freezed class to allow it.**

A stored `isUpcoming` is correct at the moment it is constructed and wrong from then on. `copyWith(startsAt: ...)` updates the input and leaves the derived field stale, and nothing warns you.

```dart
// ✅
bool get isUpcoming =>
    startsAt != null && startsAt!.isAfter(DateTime.now().toUtc());
int get remainingSeats => capacity - enrolledCount;

// ❌ two fields that can disagree, and copyWith will make them disagree
const factory Program({
  required DateTime startsAt,
  required bool isUpcoming,
}) = _Program;
```

A derived value is also not serialized. If a getter must appear in `toJson`, that is a signal the value belongs on the DTO, not the domain model.

---

## 9. No Flutter imports in `domain/`

**Rule: `domain/` imports `dart:*`, `package:freezed_annotation`, and other `domain/` files. Nothing else — in particular no `package:flutter/...`.**

This is why converters live in `domain/converters/` and not `data/converters/`: a domain
model that carries `@UtcDateTimeConverter()` has to import it, and an import reaching into
`data/` would point the dependency outward. `data/` may import `domain/`; never the reverse.

A `Color` or `IconData` on a model binds the data layer to the widget layer: the model can no longer be unit-tested without a Flutter binding, cannot be reused by a CLI or a background isolate, and the theme decision ends up somewhere the designer cannot find it.

```dart
// ❌ domain/models/program.dart
import 'package:flutter/material.dart';
Color get statusColor => status == ProgramStatus.active ? Colors.green : Colors.grey;
```

```dart
// ✅ presentation/programs/program_status_x.dart
import 'package:flutter/material.dart';

import '../../domain/models/program.dart';

extension ProgramStatusColor on ProgramStatus {
  Color color(ColorScheme scheme) => switch (this) {
        ProgramStatus.draft => scheme.outline,
        ProgramStatus.active => scheme.primary,
        ProgramStatus.archived => scheme.surfaceContainerHighest,
        ProgramStatus.unknown => scheme.error,
      };
}
```

The switch expression is exhaustive over the enum, so adding a status becomes a compile error here rather than a wrong colour in production.

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Hand-written `fromJson` with `json['x'] as String` | `@freezed` + `_$ModelFromJson`. Casts on network `dynamic` are assertions about a system you do not control. |
| `strict-casts` left off | Set it in `analysis_options.yaml`. Without it the implicit cast is accepted and the rule is unenforceable. |
| `dynamic` as a model field type | Model the polymorphism as a `sealed` freezed union with a discriminator. |
| `String status` compared as `status == 'active'` | Enum with `@JsonValue` and a predicate getter. A typo is then a compile error. |
| Enum with no `unknown` member | Add one plus `@JsonKey(unknownEnumValue: ...)`. A new server value must not lose the whole response. |
| Plain Dart class as a model | `@freezed`. Identity equality makes Riverpod rebuild on every identical refetch. |
| Hand-written `==` alongside freezed | Delete it. It will disagree with the generated `hashCode`. |
| DTO created for a payload that is already the right shape | `@JsonKey(name:)` or `FieldRename.snake` first. A DTO is for a shape mismatch, not a name mismatch. |
| `toDomain()` placed on the domain model | Put it on the DTO. `domain/` must not import `data/`. |
| Field made nullable to stop a parse error | Fix the contract or default it in the DTO. Nullable is a UI state, not an error handler. |
| `List<T>?` | `@Default(<T>[]) List<T>`. Null and empty mean the same thing to the caller. |
| `DateTime.parse` with no `.toUtc()` | Use a `JsonConverter`. `DateTime.parse` yields local time unless the string ends in `Z`. |
| `.toLocal()` inside the model or repository | Only at the render site. UTC everywhere else. |
| Date formatted with `substring` or interpolation | `intl` `DateFormat`. It handles locale, ordering and 12/24-hour; string surgery does not. |
| Derived value stored as a field | Getter, with `const Model._();` on the class. `copyWith` cannot keep a stored derivative honest. |
| `package:flutter/material.dart` imported in `domain/` | Move the presentation concern to an extension in the UI layer. |
