# Flutter Localization Standards

Localization is the one concern that cannot be retrofitted cheaply. Every rule below exists
because the *deferred* version of it — "we'll add Arabic later" — turns into a migration
touching every screen, with no test that tells you when it is finished.

**Scope boundaries.** This layer covers the ARB catalogue, `l10n.yaml` and `gen-l10n`, ICU
message syntax, `intl` formatting, locale selection and override, the RTL/pseudo-locale
proofs, and how server-supplied text is handled. It does **not** cover widget structure,
state shape, or the shared localized `Validators` class — those are `frontend/flutter-ui`,
whose §11 holds the full directional-geometry substitution table this layer only points at.
Colors, typography and `ThemeData` are `mobile/flutter`. Interceptor plumbing and error
mapping are `api-style/dio`. The key-value store behind the persisted locale preference is
`storage/flutter-local`. Golden-test infrastructure is `testing/flutter-test`.

**Version.** Targets Flutter 3.2x+ with `flutter_localizations` and `intl` 0.19+. `gen-l10n`
options have moved between releases (`synthetic-package` is deprecated and then removed);
where a detail below disagrees with `flutter gen-l10n --help` on your channel, the tool wins.

---

## 1. The catalogue and the toolchain

One template ARB in the app's language, one ARB per shipped locale, one generated class.

```
lib/l10n/
  app_en.arb          template — the only file a developer edits by hand
  app_ar.arb          translations come back from the vendor into these
  app_fr.arb
  generated/          gen-l10n output, git-ignored
```

**Rule: `l10n.yaml` is checked in and carries the enforcement options, not just the paths.**

```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
nullable-getter: false
required-resource-attributes: true
untranslated-messages-file: build/untranslated_messages.json
use-escaping: true
format: true
```

| Option | Why it is not optional |
|---|---|
| `required-resource-attributes: true` | `gen-l10n` fails when a key has no `@key` block. This is the only mechanical guarantee that every string has a translator description |
| `untranslated-messages-file` | Writes `{"ar": ["programsTitle", …]}`. CI fails if the file is non-empty, so a new key cannot ship as an English string inside an Arabic build |
| `nullable-getter: false` | `AppLocalizations.of(context)` returns non-null, so no call site needs a `!`. A nullable getter invites `?.` chains that silently render nothing |
| `use-escaping: true` | Makes `'` the escape for a literal `{`. Without it a message containing a brace is a build error nobody can decipher |
| `output-dir` | Generated code lives in the repo tree where the IDE and the analyzer can see it. On Flutter versions that still have `synthetic-package`, set it to `false` alongside |

And in `pubspec.yaml`:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any          # pinned by flutter_localizations — do not fight it

flutter:
  generate: true
```

`flutter gen-l10n` runs as part of `flutter run`/`flutter build` once `generate: true` is set,
but run it explicitly in CI before `analyze` so a malformed ARB fails at the right step.

---

## 2. No user-facing literal in a widget — and the build says so

**Rule: no user-facing string literal reaches a widget constructor.**

```dart
// ✅
Text(l10n.programsTitle)
AppButton(label: l10n.programEnrollButton, onPressed: _enrol)

// ❌ the string is now invisible to the toolchain — it will not appear in an ARB,
//    will not appear in the untranslated report, and will not be found by grep
//    once someone wraps it in a helper
Text('Programs')
```

Not user-facing and therefore fine: `Key`/`ValueKey` strings, route names, analytics event
names, asset paths, `semanticsIdentifier`, log messages, and enum-ish wire values.

**Rule: turn the rule into a build failure on day one.** Enforcement is the whole point.
Without it, a codebase reaches "50% localized" and stays there: hundreds of keys sitting
beside hundreds of literals, and no way to answer "is the profile screen done?" short of
reading it. A half-migrated app has paid for the ARB pipeline, the vendor contract and the
review overhead, and cannot ship a second language.

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - avoid_hardcoded_strings:
        exclude:
          - "test/**"
          - "lib/l10n/**"
          - "**/*.g.dart"
          - "**/*.freezed.dart"
```

```yaml
# dev_dependencies
  custom_lint: ^0.7.0
  no_hardcoded_strings: ^1.0.0     # or hardcoded_strings_lint — either provides the rule
```

**`dart run custom_lint` is a separate CI step.** This is the detail teams get wrong:
`flutter analyze` does not execute analyzer plugins, so a pipeline that only runs
`flutter analyze` reports a clean tree while every literal sails through. The check must be
its own step with its own non-zero exit.

```yaml
# .github/workflows/ci.yaml — the localization job
- run: flutter gen-l10n
- run: flutter analyze --fatal-infos --fatal-warnings
- run: dart run custom_lint
- name: Every shipped locale is complete
  run: |
    if [ -f build/untranslated_messages.json ]; then
      jq -e 'length == 0' build/untranslated_messages.json \
        || { cat build/untranslated_messages.json; exit 1; }
    fi
```

`gen-l10n` writes the report as `{}` when nothing is missing, so test the parsed length —
`test -s` on the file is true for `{}` and fails every build.

Suppress a genuine exception at the line with `// ignore: avoid_hardcoded_strings` and a
reason. A file-wide ignore is a screen that is not localized; say so in the PR.

---

## 3. Keys, metadata and placeholders

**Rule: a key is named for what the string means, never for where it sits or what it looks
like.** `programEnrollButton`, `enrolmentClosedBanner`, `studentsEnrolled`. Not `label12`,
not `text_1`, not `homeScreenString3`.

The reason is churn. A key named for a position dies the first time the design moves; a key
named for its English wording (`clickHere`) is a lie in every language that does not click.
Names are `lowerCamelCase` — `gen-l10n` turns each into a Dart member, so anything else
either fails to compile or is silently mangled.

**Rule: every key has an `@key` block with a `description`.** The translator sees the key
name, the English value and the description. Nothing else — not the screen, not the widget,
not the adjacent strings. A `description` that restates the value is worthless; it must say
where the string appears and what constrains it.

```json
{
  "@@locale": "en",

  "programsTitle": "Programs",
  "@programsTitle": {
    "description": "App bar title of the screen listing a school's programs. Single word preferred; truncates past ~20 characters on small phones."
  },

  "studentsEnrolled": "{count, plural, =0{No students enrolled} =1{1 student enrolled} other{{count} students enrolled}}",
  "@studentsEnrolled": {
    "description": "Summary line under a program title showing how many students have enrolled.",
    "placeholders": {
      "count": {
        "type": "num",
        "format": "decimalPattern",
        "example": "42"
      }
    }
  },

  "enrolmentClosesOn": "Enrolment closes on {date}",
  "@enrolmentClosesOn": {
    "description": "Deadline shown on a program card. {date} is rendered by intl in the active locale.",
    "placeholders": {
      "date": {
        "type": "DateTime",
        "format": "yMMMd",
        "example": "17 May 2026"
      }
    }
  }
}
```

**Rule: placeholders are named and typed.** `{count}`, not `{0}`. `"type"` is required for
anything that is not a plain `String`, and it is what makes `intl` format the value instead
of calling `toString()` on it. Add `example` — it is often the only thing that tells a
translator whether `{name}` is a person or a program.

| Placeholder type | Use for |
|---|---|
| `String` | Names, free text, and `select` discriminators |
| `num` / `int` / `double` | Anything counted or measured; pair with `format` |
| `DateTime` | Always, for dates — never pre-format a date into a `String` placeholder |

**Rule: `@@locale` is the first entry of every ARB, and translated ARBs contain values only.**
The `@key` metadata lives in the template. Duplicating it into `app_ar.arb` means it drifts.

---

## 4. Plurals, select, and why you must never concatenate

**Rule: one key is one whole sentence.**

```dart
// ❌ untranslatable. In Arabic the number's position, the noun's form and the
//    dual/paucal/plural distinction all change; in German the noun case changes.
Text('$count students')
Text('${l10n.enrolled} $count')
Text(l10n.youHave + ' ' + count.toString() + ' ' + l10n.messages)
```

The failure is not aesthetic. A translator handed `enrolled` and `students` as two rows has
no way to express "٣ طلاب مسجلين" — the fragments cannot be reordered, and Arabic's six
plural categories cannot be reached from a `+`.

**Rule: counts use ICU `plural`.** English needs `=1` and `other`; Arabic needs `zero`,
`one`, `two`, `few`, `many`, `other`; Japanese needs only `other`. The ARB carries every
category the *source* language needs, and translators add the rest for theirs.

```json
"messagesWaiting": "{count, plural, =0{No new messages} =1{1 new message} other{{count} new messages}}"
```

```dart
Text(l10n.messagesWaiting(count))
```

`=0` is a distinct branch from `zero`: `=0` matches the literal number, `zero` matches the
CLDR plural category. Use `=0` for "no messages" copy, and leave `zero` to translators.

**Rule: variants use ICU `select`, never a Dart conditional over localized fragments.**

```json
"enrolmentStatus": "{status, select, enrolled{You are enrolled} waitlisted{You are on the waitlist} closed{Enrolment is closed} other{Enrolment status unknown}}",
"@enrolmentStatus": {
  "description": "Status banner on the program detail screen.",
  "placeholders": { "status": { "type": "String", "example": "enrolled" } }
}
```

`select` cases are case-sensitive and `other` is mandatory. Feed it `status.name` from an
enum so an added enum value shows up as `other` rather than a crash.

**Rule: nest, do not concatenate, when a sentence has two variables.** ICU nests:

```json
"seatsLeft": "{count, plural, =1{1 seat left in {program}} other{{count} seats left in {program}}}"
```

---

## 5. Dates, numbers and currency

**Rule: every locale-dependent value is formatted by `intl` at the active locale, through the
ARB `format:` option wherever the value is part of a message.**

```json
"@programPrice": {
  "description": "Price shown on a program card.",
  "placeholders": {
    "amount": { "type": "double", "format": "simpleCurrency", "optionalParameters": { "name": "AED" } }
  }
}
```

| Want | `format:` | Renders (en_US, 1200000) |
|---|---|---|
| Plain grouped number | `decimalPattern` | `1,200,000` |
| Abbreviated | `compact` | `1.2M` |
| Money | `simpleCurrency` | `$1,200,000` |
| Abbreviated money | `compactCurrency` | `$1.2M` |
| Percentage | `percentPattern` | pass the fraction, not `× 100` |
| Date | `yMd`, `yMMMd`, `yMMMMEEEEd` | `7/9/1959`, `Jul 9, 1959` |
| Time | `jm`, `Hm` | honours the locale's 12/24-hour convention |

**Rule: never a hardcoded pattern string.** `DateFormat('MM/dd/yyyy')` is American; it is
wrong in Britain, wrong in Germany, wrong in Japan, and unreadable in Arabic. Use the named
skeleton constructors, which resolve per locale.

```dart
// ✅ outside a message, when a bare value is rendered on its own
final label = DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);

// ❌
final label = DateFormat('dd/MM/yyyy').format(date);
final price = '\$${amount.toStringAsFixed(2)}';
```

`toStringAsFixed` on money is doubly wrong: the decimal separator is a comma in most of
Europe, and the number of minor units is zero in JPY and three in KWD.

**Rule: derive a formatted string in a provider, not in `build`** — that is
`frontend/flutter-ui` §4's rule, and it applies here because formatting is exactly the kind
of work that creeps into a widget. A provider that formats must depend on the locale, so
invalidate it when the locale changes (see §6).

**Rule: relative time is a message with a plural, not a hand-rolled ladder.** "2 days ago"
built from `if (diff.inDays < 7)` produces English grammar in every language. Use
`timeago`-style ARB keys with plural branches, or the platform's relative formatter.

---

## 6. Choosing the locale, and overriding it

**Rule: the device locale is the default; wire the generated delegates and nothing else.**

```dart
MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: ref.watch(localeControllerProvider),   // null → follow the device
  routerConfig: router,
);
```

`AppLocalizations.localizationsDelegates` already includes `GlobalMaterialLocalizations`,
`GlobalCupertinoLocalizations` and `GlobalWidgetsLocalizations`. Those three are what supply
Material's own strings ("Back", "Show menu"), the date picker's month names, and — critically
— the text direction for the locale. Hand-listing only `AppLocalizations.delegate` gives you
translated app strings inside an English, always-LTR frame.

**Rule: the in-app override is a persisted `Locale?`, where `null` means follow the device.**
Not a `String` language code, not a default of `Locale('en')`. A stored `en` is
indistinguishable from "the user has never chosen", so a user who moves to a French phone is
stuck in English forever.

```dart
@riverpod
class LocaleController extends _$LocaleController {
  static const _key = 'app.locale';

  @override
  Locale? build() {
    final tag = ref.watch(keyValueStoreProvider).getString(_key);
    final locale = tag == null ? null : _parse(tag);
    _applyOutsideWidgetTree(locale);
    return locale;
  }

  /// 'ar' → Locale('ar'); 'ar-AE' → Locale('ar', 'AE'). `Locale(tag)` on a full
  /// tag produces a language code of "ar-AE", which matches nothing.
  static Locale _parse(String tag) {
    final parts = tag.split('-');
    return parts.length == 1 ? Locale(parts.first) : Locale(parts.first, parts[1]);
  }

  Future<void> setLocale(Locale? locale) async {
    final store = ref.read(keyValueStoreProvider);
    locale == null ? await store.remove(_key) : await store.setString(_key, locale.toLanguageTag());
    _applyOutsideWidgetTree(locale);
    state = locale;
  }

  void _applyOutsideWidgetTree(Locale? locale) {
    // Formatting that has no BuildContext: background jobs, PDF/CSV export, notifications.
    // `toString()`, not `toLanguageTag()` — intl wants `ar_AE`, not `ar-AE`.
    Intl.defaultLocale =
        (locale ?? WidgetsBinding.instance.platformDispatcher.locale).toString();
  }
}
```

**Rule: the override drives four things, not one.** Strings are the easy one.

| The override must also change | Mechanism |
|---|---|
| Number and date formats | `Intl.defaultLocale` for context-free code; `Localizations.localeOf(context)` inside the tree |
| Text direction | Automatic via the Global delegates — never set it by hand, and never wrap the app in a fixed-direction widget |
| Server-rendered text | An `Accept-Language` header on every request (§9) |
| Anything cached per locale | Invalidate locale-dependent providers; a formatted-label cache keyed only by id serves French labels to an Arabic user |

**Rule: `supportedLocales` comes from the generated class, not a hand-written list.** A
hand-written list drifts from `arb-dir` the moment a locale is added, and the drift is
silent: the ARB is generated, the locale is simply never selectable.

---

## 7. Direction and mirroring

An RTL locale is a layout change, not a string change. Padding, alignment, positioning and
custom glyphs all have a direction-aware form, and the substitution table lives in
`frontend/flutter-ui` §11 — `EdgeInsetsDirectional`, `AlignmentDirectional`,
`PositionedDirectional`, `BorderRadiusDirectional`, `TextAlign.start`. Use them from the
first screen. In English they are identical to their absolute counterparts, so the cost is
zero; retrofitting them is a hundred one-line edits with no test that catches a missed one.

What belongs here rather than there:

**Rule: a custom directional glyph flips on `Directionality.of(context)`.** Material's own
`Icons.arrow_back`, `Icons.chevron_right` and friends are auto-mirrored by the framework. A
custom SVG arrow, a progress chevron, or a swipe affordance is not.

```dart
final isRtl = Directionality.of(context) == TextDirection.rtl;
Transform.flip(flipX: isRtl, child: const AppIcon.chevron());
```

Icons that are *not* mirrored, in any locale: media transport controls (play/next),
clock faces, checkmarks, and anything depicting a physical object with a fixed handedness.

**Rule: text that is not in the app's language gets its own `Directionality`.** An Arabic
comment inside an English UI, or a Latin-script program code inside an Arabic UI, needs
`Directionality` around that subtree or the punctuation lands on the wrong end. Use
`Bidi.detectRtlDirectionality` from `intl` on server text whose language you know but whose
direction you have not been told.

---

## 8. Proving it before the locale ships

**Rule: an RTL golden exists before the first RTL locale is announced.** Pump the widget
under the real locale with the real delegates — not under a bare `Directionality` wrapper. A
`Directionality` wrapper proves mirroring; it does not prove that Arabic strings fit, that
the font renders, or that a date is not still `07/09/1959`.

```dart
testWidgets('program card renders in Arabic', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ProgramCard(program: fakeProgram, onTap: () {})),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(ProgramCard),
    matchesGoldenFile('goldens/program_card_ar.png'),
  );
});
```

**Rule: CI runs a pseudo-locale so overflow fails a build, not a review.** German and
Finnish translations run 30–40% longer than English; Arabic runs shorter but taller. A
pseudo-locale surfaces both without a single real translation existing.

```dart
// tool/generate_pseudo_arb.dart — run in CI, output never committed
// app_en.arb → app_en_XA.arb, each value accented and padded:
//   "Programs"  →  "[!! Ƥřögřámš ··· !!]"
```

```yaml
- run: dart run tool/generate_pseudo_arb.dart      # writes lib/l10n/app_en_XA.arb
- run: flutter gen-l10n
- run: flutter test --dart-define=PSEUDO_LOCALE=en_XA test/widget
- run: git clean -f lib/l10n/app_en_XA.arb
```

The widget tests pump under `Locale('en', 'XA')`, and a `RenderFlex` overflow throws in a
test rather than painting a yellow-and-black stripe — so overflow that only a translation
would have caused fails the build. Generating the pseudo ARB in CI rather than committing it
keeps `en_XA` out of `supportedLocales` in release builds, where a user could otherwise
select it. The bracket delimiters make truncation visible in a golden: a snapshot missing its
closing `!!]` is a clipped string.

**Rule: "localized" means the untranslated report is empty and the RTL golden exists** — not
that a developer remembers doing the screen.

---

## 9. Server-supplied text

**Rule: text the API returns is translated on the server, or it carries a locale tag.**

A localized shell around untranslated content is not a localized app. The user sees Arabic
navigation wrapped around an English program description and concludes the app is broken.

```dart
// The effective locale — the override from §6, or the device's when there is none.
@riverpod
Locale effectiveLocale(Ref ref) =>
    ref.watch(localeControllerProvider) ??
    WidgetsBinding.instance.platformDispatcher.locale;

// Dio interceptor — it rides on every request, in BCP-47 form with hyphens.
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    options.headers['Accept-Language'] = ref.read(effectiveLocaleProvider).toLanguageTag();
    handler.next(options);
  },
));
```

| Content | Approach |
|---|---|
| Enum-like server values (status, category, role) | The API returns a stable code; the ARB holds the display name. Never render the code |
| Editorial copy (program descriptions, help articles) | Server-side translation keyed off `Accept-Language`; the response echoes the locale actually served |
| User-generated text (comments, names) | Untranslatable. Store and return its own `locale` tag, render it with its own `Directionality`, and offer a translate action rather than pretending |
| Validation and error messages | Server returns a **code** plus field; the app maps the code to an ARB key. A human-readable `message` field is a debug aid, never UI copy |

**Rule: never translate server text on the device.** A device-side lookup table means every
content change ships an app update, and it produces English on any string the table missed.

**Rule: the response says which locale it served.** When the server falls back — Arabic
requested, English available — the UI can label the block ("Available in English only")
rather than silently mixing languages.

---

## 10. Adding a locale — the checklist

1. Add the vendor's `app_<locale>.arb` to `arb-dir`. Values only; no `@key` blocks.
2. `flutter gen-l10n` — `supportedLocales` picks it up automatically.
3. `jq -e 'length == 0' build/untranslated_messages.json` — fill every gap before merging.
4. Check the font covers the script. Arabic, Thai and Devanagari are not in the default
   Roboto subset; a missing glyph renders as a box, and it renders that way only on the
   locale you did not test.
5. If the locale is RTL, add its goldens (§8) and walk the app once with the device set to it.
6. Check the number system: `ar` may render Eastern Arabic numerals (`٤٢`) depending on the
   locale tag. Decide deliberately — `ar` and `ar_EG` differ.
7. Add the store listing, the push-notification templates and the transactional emails. They
   are outside `arb-dir` and are the most common thing left in English.

---

## 11. Common mistakes

| Mistake | What happens |
|---|---|
| Key named `label12` or `homeText1` | The translator has no idea what it is and guesses; the guess ships |
| `description` restating the English value | Same as no description, but harder to audit |
| `{0}` positional placeholder | `gen-l10n` generates a meaningless parameter name; reordering is impossible |
| Sentence built with `+` or interpolation | Unfixable by translation — the fragments have no grammatical relationship |
| `String` placeholder holding a pre-formatted date | The date is formatted in whatever locale the caller happened to be in |
| Only `AppLocalizations.delegate` in `localizationsDelegates` | English Material widgets and LTR layout inside a translated app |
| Locale preference stored as `'en'` by default | The user can never return to "follow device" |
| Pseudo-locale ARB committed to `arb-dir` | `en_XA` becomes a selectable production language |
| `flutter analyze` as the only lint step | The hardcoded-string plugin never runs; the check is decorative |
| Server error `message` rendered directly | Untranslated English strings in the UI's most visible moment |

---

## 12. Never

- Put a user-facing string literal in a widget constructor.
- Ship the hardcoded-string rule without a CI step that actually executes it.
- Add a key without an `@key` block and a `description` written for a translator.
- Use a positional or untyped placeholder.
- Build a sentence by concatenating keys, or a key and a value.
- Express a count with anything other than ICU `plural`.
- Express a variant with a Dart conditional over localized fragments instead of ICU `select`.
- Write a date or number pattern string, or format money with `toStringAsFixed`.
- Hand-write `supportedLocales`.
- Default the stored locale preference to a concrete locale instead of null.
- Set text direction by hand, or wrap the app in a fixed direction.
- Announce an RTL locale without a golden pumped under that locale.
- Commit the pseudo-locale ARB.
- Translate server content on the device, or render a server `message` field as UI copy.
