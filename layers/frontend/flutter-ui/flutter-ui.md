# Flutter UI Standards

The widget tree is where a Flutter app is judged and where it rots. Almost every rule below
exists because the wrong version is what a competent developer writes by default under time
pressure, and because the cost only shows up later — on a slow network, at 200% text scale,
in Arabic, or on the third screen that needed the same card.

**Scope boundaries.** This layer covers pages, components, the shared design system, motion,
forms, wizards, search UI and embedded WebViews — the widgets themselves and how they consume
state. It does **not** cover colors, typography, spacing scales, `ThemeData`, or dark mode:
those are `mobile/flutter`, and a widget here reads `Theme.of(context)`, never a hex literal.
It does not cover routes, deep links, `GoRoute` declarations or redirect guards: that is
`frontend/go-router`, and a page here calls `context.go`/`context.push` but never declares a
route. It does not cover provider shape, `AsyncNotifier`, pagination state or cancellation
wiring: that is `state/riverpod`, and a page here *reads* a provider and never owns one.
Strings and plurals are `i18n/flutter-l10n`. Widget, golden and integration tests are
`testing/flutter-test`. HTTP and error mapping are `api-style/dio`.

**Version.** Targets Flutter 3.2x+ with Material 3 and `flutter_riverpod` 3.x. Where an API is
known to have been deprecated it is called out in [§17](#17-deprecated-apis). If a detail below
disagrees with the version in `pubspec.yaml`, the pubspec wins.

---

## 1. What a page is

A page is a `ConsumerWidget` (or `ConsumerStatefulWidget` if it owns controllers) that turns
provider state into widgets. That is all it does.

**Rule: a page takes ids and primitives, never a model.**

```dart
// ✅ constructible from a URL, so the route is deep-linkable and the page is testable
class ProgramDetailPage extends ConsumerWidget {
  const ProgramDetailPage({required this.programId, super.key});
  final String programId;
}

// ❌ requires a fully-loaded Program before the page can exist — so a deep link,
//    a push notification and a cold start all have nowhere to get one
class ProgramDetailPage extends StatelessWidget {
  const ProgramDetailPage({required this.program, super.key});
  final Program program;
}
```

The reason is not purity. `go_router` builds a page from path and query parameters only; a
page whose constructor demands a `Program` cannot be reached from a link, cannot be restored
after a process death, and forces the previous screen to have already fetched the data.

**Rule: no business logic on a page.** No pricing, no eligibility, no permission arithmetic.
If a page needs to know whether a button is enabled, a provider exposes `canEnrol`. The test
for that logic should never need `pumpWidget`.

| Belongs on the page | Belongs in a provider |
|---|---|
| Which of the four states to render | Which items to show |
| Layout, spacing, responsive breakpoints | Sorting and filtering |
| Wiring a callback to `ref.read(...).method()` | The method itself |
| Reading `Theme.of(context)` | Formatting a date or currency |
| `ref.listen` → snackbar, navigation | Deciding that a snackbar is warranted |

---

## 2. Four real states, and the retry actually re-fetches

**Rule: every screen backed by async data renders four states, and each one is real.**

| State | What "real" means |
|---|---|
| Loading | A skeleton shaped like the content, not a centered spinner on a blank page |
| Error | The message *plus* a retry button that re-runs the request |
| Empty | Distinct from loaded-with-items — its own illustration and its own call to action |
| Data | The content |

```dart
class ProgramListPage extends ConsumerWidget {
  const ProgramListPage({required this.schoolId, super.key});
  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final programs = ref.watch(programsProvider(schoolId: schoolId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.programsTitle)),
      body: programs.when(
        loading: () => const ProgramListSkeleton(),
        error: (error, _) => ErrorStateView(
          message: describeError(context, error),
          onRetry: () => ref.invalidate(programsProvider(schoolId: schoolId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateView(
              title: l10n.programsEmptyTitle,
              actionLabel: l10n.programsEmptyAction,
              onAction: () => context.push('/programs/browse'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(programsProvider(schoolId: schoolId)),
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) => ProgramCard(
                program: items[index],
                onTap: () => context.push('/programs/${items[index].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

**Rule: the retry re-fetches.** `ref.invalidate(theProvider)` — the same provider, with the
same family arguments. Three retries that are not retries:

```dart
onRetry: () => Navigator.of(context).pop(),        // ❌ closes the screen
onRetry: () => setState(() {}),                    // ❌ rebuilds the same AsyncError
onRetry: () => ref.invalidate(otherProvider),      // ❌ refreshes the wrong thing
```

Use `ref.invalidate` when the result is not needed at the call site and `ref.refresh` only
when you use its return value; a `ref.refresh` whose value is discarded is a lint.

**Empty is not a small data state.** An empty list rendered as an empty `ListView` is a blank
screen the user reads as a bug. It also silently hides the difference between "you have no
programs yet" and "your filter matched nothing", which need different copy and different
actions.

---

## 3. Lists: lazy by default, slivers when composed

**Rule: any list that can exceed one screen uses a lazy builder.**
`ListView.builder`, `ListView.separated`, `GridView.builder`, `SliverList.builder`.

`ListView(children: [...])` builds and lays out every child immediately. With 400 rows that
is 400 subtrees constructed before the first frame — a visible jank spike on a mid-range
Android device, and it re-runs on every rebuild.

**Rule: `shrinkWrap: true` with `NeverScrollableScrollPhysics()` means a sliver was the
answer.** That pair is what you write when you need a list inside another scrollable; it
defeats laziness entirely (`shrinkWrap` measures every child to size itself) and nests two
scroll contexts.

```dart
// ❌ a header, a list, and a footer in a Column inside a SingleChildScrollView
SingleChildScrollView(
  child: Column(children: [
    const ProgramHeader(),
    ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: ...,
    ),
    const ProgramFooter(),
  ]),
)

// ✅ one scrollable, one lazy list
CustomScrollView(
  slivers: [
    const SliverToBoxAdapter(child: ProgramHeader()),
    SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => ProgramCard(program: items[index]),
    ),
    const SliverToBoxAdapter(child: ProgramFooter()),
  ],
)
```

| Shape | Use |
|---|---|
| A screen that is only a list | `ListView.builder` |
| List with a header/footer/app bar that scrolls with it | `CustomScrollView` + slivers |
| Fixed row height | `ListView.builder` with `itemExtent` — skips per-child measurement |
| A handful of items, known to be short (≤ ~10, no growth) | `Column` is fine; say so in a comment |
| Infinite scroll | `ListView.builder` + a scroll threshold calling `loadMore()` — state shape is `state/riverpod` |

**Rule: stable keys on reorderable or filterable lists.** `ValueKey(item.id)`, never the
index. An index key makes Flutter reuse the wrong element when the list is filtered, which
shows up as a checkbox ticking the wrong row.

---

## 4. Nothing is computed in `build`

**Rule: `build` may read, choose and lay out. It may not sort, filter, parse, format or
allocate a client.**

`build` runs on every animation frame of every ancestor rebuild. A `.sort()` in `build` is a
sort per frame; a `DateFormat` constructed in `build` is a locale-data parse per frame.

```dart
// ❌
Widget build(BuildContext context, WidgetRef ref) {
  final programs = ref.watch(programsProvider).valueOrNull ?? [];
  final visible = programs.where((p) => p.isActive).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final formatter = DateFormat.yMMMd(Localizations.localeOf(context).toString());
  ...
}

// ✅ the provider derives it once, and the derivation is unit-testable
@riverpod
List<Program> visiblePrograms(Ref ref, {required String schoolId}) {
  final all = ref.watch(programsProvider(schoolId: schoolId)).valueOrNull ?? const [];
  return [...all.where((p) => p.isActive)]
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}
```

| In `build` | Move to |
|---|---|
| `.sort()`, `.where().toList()`, `.fold()` | A derived provider (§4) |
| `DateFormat(...)`, `NumberFormat(...)` | A provider, or a `static final` on a formatter class |
| `jsonDecode`, `int.parse` on a payload | The model layer (`language/dart-models`) |
| `Dio()`, `SharedPreferences.getInstance()` | A `keepAlive` provider (`state/riverpod`) |
| A `Random()` or `DateTime.now()` used for display | A provider, so a golden test can pin it |
| `MediaQuery.of(context)` for one property | `MediaQuery.sizeOf(context)` — rebuilds only on that property |

**Use the `…Of` accessors.** `MediaQuery.of(context)` subscribes the widget to *every*
MediaQuery change, so opening the keyboard rebuilds a widget that only wanted the width.
`MediaQuery.sizeOf`, `.paddingOf`, `.viewInsetsOf`, `.textScalerOf`,
`.disableAnimationsOf` each subscribe to one aspect.

---

## 5. Side effects use `ref.listen`, never `ref.watch`

**Rule: snackbars, dialogs, navigation and haptics are triggered from `ref.listen`.**

A `ref.watch` fires again on every rebuild that reproduces the same state — a keyboard
opening, a theme change, a parent rebuild. Watched navigation pushes the screen twice;
watched snackbars stack.

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen(enrolmentControllerProvider, (previous, next) {
    if (next case AsyncError(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(context, error))));
    }
    if (previous is AsyncLoading && next is AsyncData) {
      context.go('/enrolments/success');
    }
  });

  final state = ref.watch(enrolmentControllerProvider);
  return ElevatedButton(
    onPressed: state.isLoading
        ? null
        : () => ref.read(enrolmentControllerProvider.notifier).enrol(),
    child: state.isLoading ? const ButtonSpinner() : Text(l10n.enrol),
  );
}
```

`ref.listen` must be called in `build`, unconditionally — not inside an `if`, not in a
callback. Riverpod registers the listener on first build and reuses it; a conditional
`ref.listen` throws.

| Concern | Mechanism |
|---|---|
| Rendering state | `ref.watch` |
| Reacting to a state *transition* | `ref.listen` |
| Firing an action from a callback | `ref.read(...).notifier` |
| One-shot work when the page opens | A provider's `build`, or `initState` + `ref.read` |

---

## 6. `context` after `await`

**Rule: every `await` inside a widget callback is followed by
`if (!context.mounted) return;` before `context` is touched again.**

```dart
Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const ConfirmDeleteDialog(),
  );
  if (!context.mounted) return;          // dialog await
  if (confirmed != true) return;

  await ref.read(programControllerProvider.notifier).delete(programId);
  if (!context.mounted) return;          // network await

  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l10n.programDeleted)));
  context.pop();
}
```

Without the guard, a user who taps back while the request is in flight gets
`Looking up a deactivated widget's ancestor is unsafe` — a crash, not a warning, and one that
only reproduces on a slow network so it ships. The `use_build_context_synchronously` lint
catches it; it must be an error, not a warning (`mobile/flutter` owns `analysis_options.yaml`).

Inside a provider, the equivalent is `ref.mounted` — see `state/riverpod`.

---

## 7. Components take data in and send callbacks out

**Rule: a widget under `presentation/widgets/` or `core/widgets/` never receives a
`WidgetRef`, never extends `ConsumerWidget`, and never fetches anything.**

```dart
// ✅ pure: renders what it is given, reports what happened
class ProgramCard extends StatelessWidget {
  const ProgramCard({
    required this.program,
    required this.onTap,
    this.onFavouriteToggled,
    super.key,
  });

  final Program program;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFavouriteToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.title, style: theme.textTheme.titleMedium),
                Text(program.subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Three concrete costs of the alternative:

| A component that… | Costs |
|---|---|
| Takes a `WidgetRef` and watches | Cannot be golden-tested without a `ProviderScope` and fakes for everything it transitively reaches |
| Fetches its own data | N cards on screen means N requests, all of which fire again on scroll-back |
| Reads `ref` for one flag | Couples a shared component to one feature's provider graph, so the second feature cannot reuse it |

A component may hold **its own ephemeral state** — expansion, hover, an animation controller —
in a `StatefulWidget`. That is state about the widget, not about the app.

**The exception, named explicitly:** a container widget directly under
`presentation/pages/` that exists only to wire a provider to a dumb child may be a
`ConsumerWidget`. Keep it in the page file. It has no logic beyond `ref.watch` and passing
callbacks.

---

## 8. `const`, `super.key`, and why

**Rule: every widget class gets a `const` constructor and `super.key`.**

```dart
class ProgramCard extends StatelessWidget {
  const ProgramCard({required this.program, required this.onTap, super.key});
```

`const` lets Flutter skip rebuilding the subtree entirely: a `const` widget is canonicalised,
so the element sees an identical instance and short-circuits. Dropping `const` on a leaf
inside a `ListView.builder` is the difference between rebuilding one row and rebuilding its
whole subtree on every frame of a scroll.

`super.key` is not ceremony — without it, callers cannot pass `ValueKey(item.id)`, and the
list reuse in §3 silently misbehaves. `prefer_const_constructors` and `use_key_in_widget_constructors` should both be on.

**Rule: `const` on the call site too**, wherever every argument is const:
`const SizedBox(height: 16)`, `const Divider()`, `const CircularProgressIndicator()`.

---

## 9. Accessibility

**Rule: every interactive element has an accessible name.** A screen reader announcing
"button" tells the user nothing.

| Element | How the name arrives |
|---|---|
| Text button | The `Text` child |
| Icon-only button | `tooltip:` — sets the semantic label *and* gives sighted users a long-press hint |
| A tappable card | `MergeSemantics` so children announce as one node |
| A custom `GestureDetector` | `Semantics(button: true, label: …)` — a bare `GestureDetector` is invisible to the reader |
| A decorative image or illustration | `ExcludeSemantics` — it has no name because it has no meaning |
| An image that *is* content | `Image.asset(..., semanticLabel: l10n.…)` |
| A form field | `decoration: InputDecoration(labelText: …)` |

```dart
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.filter_list),
      tooltip: l10n.filterPrograms,          // ✅ required on every icon-only button
      onPressed: onFilterPressed,
    ),
  ],
)

ExcludeSemantics(                            // ✅ decorative header art
  child: Image.asset('assets/img/programs_header.png'),
)
```

**Rule: `MergeSemantics` around a composite tappable.** Without it, a card with a title, a
subtitle, a date and a chip is four stops in the reader for one tap target — the user swipes
four times per row.

**Rule: announce state changes that have no visual anchor.** A filter applied, a row deleted:
`SemanticsService.announce(l10n.filtersApplied, Directionality.of(context))`.

---

## 10. Touch targets, text scale, overflow

**Rule: 48×48dp minimum for anything tappable.** Material's `IconButton` already meets it;
a bare `GestureDetector` around a 16dp icon does not.

```dart
// ✅ pad the target, not the icon
InkWell(
  onTap: onTap,
  child: ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    child: const Center(child: Icon(Icons.close, size: 20)),
  ),
)
```

`MaterialTapTargetSize.shrinkWrap` on a button is opting out of the minimum. Do it only in a
dense table, never on a primary action.

**Rule: no fixed-height box around text.** `SizedBox(height: 44, child: Text(...))` clips at
150% text scale and is the single most common accessibility bug in a Flutter app. Constrain
with padding and `minHeight`, never `height`.

**Rule: every screen is checked at 200% text scale.** The three things that break:

| Symptom | Fix |
|---|---|
| `RenderFlex overflowed by N pixels` in a `Row` | `Expanded`/`Flexible` around the text child |
| Text clipped in a fixed-height container | `BoxConstraints(minHeight:)` instead of `height:` |
| A `Row` of label + value that no longer fits | `Wrap`, or a `LayoutBuilder` that stacks below a threshold |

Read the scale with `MediaQuery.textScalerOf(context)`. Clamp only where you must, and clamp
a range rather than pinning to 1.0:

```dart
MediaQuery.withClampedTextScaling(
  maxScaleFactor: 1.6,
  child: child,
)
```

**Rule: `Text` that can overflow declares what it does** — `maxLines` plus
`overflow: TextOverflow.ellipsis`. An undeclared overflow is a yellow-and-black stripe in
someone's locale.

---

## 11. Directionality from the first screen

**Rule: use the directional variants everywhere, before the app is ever localised.**

| Instead of | Use |
|---|---|
| `EdgeInsets.only(left: 16)` | `EdgeInsetsDirectional.only(start: 16)` |
| `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| `Positioned(left: 8)` | `PositionedDirectional(start: 8)` |
| `BorderRadius.only(topLeft: …)` | `BorderRadiusDirectional.only(topStart: …)` |
| `Icons.arrow_back` on a back affordance | `Icons.arrow_back` is auto-mirrored; a custom chevron needs `Transform.flip` gated on `Directionality.of(context)` |
| `TextAlign.left` | `TextAlign.start` |

`EdgeInsets.symmetric(horizontal:)` and `EdgeInsets.all()` are direction-neutral and fine.

Retrofitting this is the expensive part: it is a hundred one-line edits across every file,
with no test that catches a missed one. Writing it correctly from the first screen costs
nothing. Verify with `Directionality(textDirection: TextDirection.rtl, child: …)` in a
widget test, or by switching the device locale to Arabic.

---

## 12. The design system: promote on the third use

**Rule: a widget moves to `core/widgets/` on its third use, not its first.**

The first use is a widget. The second is a coincidence. The third is a pattern — and by then
you know which parts actually vary, so the API you extract is the right one. Extracting at
the first use produces a component with the wrong seams, which the second caller then
parameterises with a boolean, and the third with two more.

| Location | Contents |
|---|---|
| `presentation/widgets/` (per feature) | Widgets used by one feature only. May know `Program`, `Enrolment`. |
| `core/widgets/` | Shared. Knows `String`, `Widget`, `VoidCallback`, `IconData` — **no domain type** |

**Rule: a shared component knows no domain type.** `AppCard` takes a title, a subtitle and a
trailing widget. The moment it takes a `Program`, it is not shared — it is a program card in
the wrong folder, and the next feature copies it rather than importing it.

**Rule: variants are an enum, not boolean flags.**

```dart
// ❌ 2^3 = 8 combinations, 3 of them meaningless, and the widget must decide precedence
const AppButton({this.isPrimary = false, this.isDanger = false, this.isGhost = false});

// ✅ exactly the states that exist, exhaustively switchable
enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    super.key,
  });
```

Boolean flags also make the illegal states unrepresentable-in-review only: `isPrimary: true,
isDanger: true` compiles, and whichever branch the `if` chain checks first silently wins.

**Rule: shared components take styling from the theme.** No hex literal, no
`TextStyle(fontSize: 14)`, no magic spacing number — `Theme.of(context).colorScheme.primary`,
`theme.textTheme.labelLarge`, and the spacing tokens defined by `mobile/flutter`. A shared
component with a hard-coded color is a shared component that cannot survive dark mode.

**Every shared component gets a golden test** (`testing/flutter-test`). That is what stops the
third caller's change from silently altering the first two.

---

## 13. Motion

**Rule: honour the platform's reduce-motion setting.**

```dart
final reduceMotion = MediaQuery.disableAnimationsOf(context);
final duration = reduceMotion ? Duration.zero : AppMotion.medium;
```

This is an accessibility requirement, not a nicety: unrequested motion triggers nausea and
migraine for vestibular-sensitive users, and both iOS and Android expose the switch.

**Rule: implicit animations by default.** `AnimatedOpacity`, `AnimatedSlide`,
`AnimatedContainer`, `AnimatedSwitcher`, `TweenAnimationBuilder`. Reach for an
`AnimationController` only for something the implicit widgets cannot express — a repeating
animation, a gesture-driven one, or several properties that must stay in lockstep. Every
`AnimationController` you do create is a `TickerProviderStateMixin` plus a `dispose()`.

**Rule: animate transform and opacity, not layout.** Animating `width`, `height`, `padding`
or a `Flex` factor re-runs layout for the subtree on every frame. Animating `Transform.scale`,
`Transform.translate`, `FractionalTranslation` or `Opacity` (via `AnimatedOpacity`/
`FadeTransition`) is a compositing change.

| Want | Use | Not |
|---|---|---|
| Slide in | `AnimatedSlide` / `SlideTransition` | Animated `Positioned` / margin |
| Grow | `AnimatedScale` / `ScaleTransition` | Animated `width` + `height` |
| Fade | `AnimatedOpacity` / `FadeTransition` | Animated `Color` alpha on a container |
| Swap content | `AnimatedSwitcher` with a keyed child | Two `Visibility` widgets and a bool |
| Expand a section | `AnimatedSize` (measure once) | A hand-rolled height tween |

**Rule: durations and curves are tokens, not literals.** Define them once beside the theme and
reference them, so motion is consistent and so reduce-motion can be applied in one place.

```dart
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 400);
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
}
```

Anything over ~400ms on a mobile interaction reads as lag. Page transitions belong to
`frontend/go-router`.

---

## 14. Forms

**Rule: every controller and focus node created is disposed.** This is the most common leak
in a Flutter codebase, and it leaks a listener list, not just memory.

```dart
class ContactForm extends ConsumerStatefulWidget {
  const ContactForm({super.key});
  @override
  ConsumerState<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }
  ...
}
```

**Rule: the submit button is disabled while the request is in flight.** Not "shows a spinner
over an enabled button" — `onPressed: null`. A double-tap on a live submit creates two
records, and the second one is the support ticket.

```dart
final submitState = ref.watch(contactControllerProvider);

AppButton(
  label: l10n.send,
  isLoading: submitState.isLoading,
  onPressed: submitState.isLoading ? null : _submit,
)

Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  await ref.read(contactControllerProvider.notifier).send(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );
  if (!context.mounted) return;
  context.pop();
}
```

**Rule: validators come from a shared, localized `Validators`.** Never an inline `RegExp`,
never `value.contains('@')`.

```dart
TextFormField(
  controller: _emailController,
  focusNode: _emailFocus,
  validator: (value) => Validators.email(context, value),
  keyboardType: TextInputType.emailAddress,
  textInputAction: TextInputAction.next,
  autofillHints: const [AutofillHints.email],
  autovalidateMode: AutovalidateMode.onUserInteraction,
  decoration: InputDecoration(labelText: l10n.emailLabel),
  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
)
```

An inline validator is untranslatable (the message is a literal), untestable without a
widget, and inconsistent — the third form's email rule will differ from the first's.

| Field property | Why |
|---|---|
| `keyboardType` | The wrong keyboard is a per-character tax |
| `textInputAction` | `next` / `done` — without it the return key does nothing and the user hunts for the next field |
| `autofillHints` | Password managers and iOS/Android autofill do not work without it. Set it on every field that maps to a known category; omit it on free text |
| `autovalidateMode: onUserInteraction` | `always` shows "required" errors on a form the user has not touched |
| `obscureText` + `AutofillHints.newPassword` | Signals the OS to offer a generated password |

**Rule: `autovalidateMode` is `onUserInteraction`, and server-side errors map back onto the
field** that caused them, not into a snackbar. A 422 naming `email` should turn the email
field red.

**Rule: wrap the form in a scrollable and respect the keyboard.** A `Form` inside a `Column`
overflows the moment the keyboard opens. `SingleChildScrollView` plus
`MediaQuery.viewInsetsOf(context).bottom` padding, or `resizeToAvoidBottomInset` on the
`Scaffold`.

---

## 15. Wizards and multi-step flows

**Rule: one immutable draft object holds the whole flow. Steps are derived from it.**

```dart
@freezed
class EnrolmentDraft with _$EnrolmentDraft {
  const factory EnrolmentDraft({
    String? programId,
    DateTime? startDate,
    @Default([]) List<String> selectedOptions,
    ContactDetails? contact,
  }) = _EnrolmentDraft;
  const EnrolmentDraft._();

  bool get canSubmit =>
      programId != null && startDate != null && contact != null;
}
```

The alternative — a controller per step, each holding its own fields — means step 4 cannot see
step 1's answer without a lift, back-navigation loses answers, and there is no single object
to submit or to persist.

| Rule | Reason |
|---|---|
| One draft, held by one provider, for the whole flow | Every step reads and writes the same object |
| Step *validity* is a getter on the draft (`step2Complete`) | The "Next" button's enabled state is not duplicated per step |
| Persist the draft on **every** change | A phone call mid-flow kills the process; the user should return to step 3 |
| Steps are pages with routes (`/enrol/step-2`) | Back button, deep link and restoration all work — see `frontend/go-router` |
| Submit once, at the end, from the draft | Partial writes leave half-created records |
| Clear the draft on success **and** on explicit abandon | A stale draft resurfacing weeks later confuses more than it helps |

Persist to local storage (`storage/flutter-local`), keyed by flow, with the schema version.
Restoring a draft written by an older app version into a changed model is a crash on launch.

---

## 16. Search

**Rule: debounce with a cancellable timer, and cancel the superseded request.**

```dart
class ProgramSearchField extends ConsumerStatefulWidget {
  const ProgramSearchField({super.key});
  @override
  ConsumerState<ProgramSearchField> createState() => _ProgramSearchFieldState();
}

class _ProgramSearchFieldState extends ConsumerState<ProgramSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  CancelToken? _inFlight;

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _inFlight?.cancel('superseded');
      final token = CancelToken();
      _inFlight = token;
      ref.read(programSearchControllerProvider.notifier)
          .search(value.trim(), cancelToken: token);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inFlight?.cancel('disposed');
    _controller.dispose();
    super.dispose();
  }
  ...
}
```

Two failures this prevents:

- **No debounce**: "programming" is ten requests, nine of them wasted, on a connection that
  now queues them.
- **No cancellation**: request 3 ("pro") is slow, request 8 ("programming") is fast. Without
  cancelling, request 3 lands last and the user sees results for a query they finished typing
  a second ago. A `mounted` check does not fix this — the widget *is* mounted.

`await Future.delayed(...)` is not a debounce. It leaves one pending future per keystroke,
each of which still wakes up, and there is nothing to cancel on dispose.

**Rule: search happens server-side unless the whole set is already local.** A
`.toLowerCase().contains()` over a fetched list in `build` is §4's violation with a network
call's worth of data behind it, and it will not match the backend's results.

| Concern | Where |
|---|---|
| Debounce and cancel token lifetime | The search widget (here) |
| The request, results state, pagination | A provider (`state/riverpod`) |
| The `CancelToken` parameter on the service method | `api-style/dio` |
| Query in the URL so a search is shareable | `frontend/go-router` |

Show a distinct **"no results for X"** empty state — separate from "search something", and
naming the query so the user can see the typo.

---

## 17. Embedded WebViews

A WebView is a browser inside your app with your app's trust. Treat every rule here as
security, not UX.

**Rule: allowlist navigation by host.** Everything not on the list opens in the external
browser, or is blocked.

```dart
const _allowedHosts = {'help.example.com', 'docs.example.com'};

WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setNavigationDelegate(
    NavigationDelegate(
      onNavigationRequest: (request) {
        final uri = Uri.parse(request.url);
        if (uri.scheme != 'https' || !_allowedHosts.contains(uri.host)) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
      onWebResourceError: (error) => _showErrorState(error),
    ),
  )
  ..loadRequest(Uri.parse(startUrl));
```

Without the gate, one redirect on a page you do not control moves the user to an attacker's
page inside your chrome, with your padlock-free URL bar and your session.

**Rule: never a login form in an embedded WebView.** The user cannot see the URL, cannot check
the certificate, and their password manager will not fill it — so they type the password
manually into a view your app can read. Use `flutter_web_auth_2` / ASWebAuthenticationSession
/ Custom Tabs, which run in the system browser with a visible URL.

**Rule: never inject a token.** Not as an `Authorization` header on `loadRequest`, not as a
cookie you set, and never via `runJavaScript`.

```dart
// ❌ every one of these hands a bearer token to a page you do not control
loadRequest(uri, headers: {'Authorization': 'Bearer $accessToken'});
controller.runJavaScript("localStorage.setItem('token', '$accessToken')");
```

The header travels on redirects; `runJavaScript` string interpolation is an injection sink;
and both put a long-lived credential somewhere the page's own scripts and any third-party
script it loads can read.

**Instead: a short-lived, single-use exchange code.** The app asks its backend for a code
(`POST /auth/webview-code`, TTL ~60s, one use), appends it to the URL, and the web property
exchanges it for its own session server-side.

```dart
final code = await ref.read(authServiceProvider).createWebViewCode();
final uri = Uri.https('help.example.com', '/sso', {'code': code});
controller.loadRequest(uri);
```

| Also | Why |
|---|---|
| `JavaScriptMode.disabled` when the content does not need JS | Removes the whole injection surface |
| Register a JS channel only if required, and validate its payload | A channel is an RPC endpoint into your app |
| Clear cookies on sign-out (`WebViewCookieManager().clearCookies()`) | Otherwise the next user inherits the session |
| Show your own loading and error states | A blank white WebView reads as a broken app |

---

## 18. Deprecated APIs

| Deprecated | Use |
|---|---|
| `MediaQuery.of(context).textScaleFactor` | `MediaQuery.textScalerOf(context)` (`TextScaler`) |
| `textScaleFactor:` on `Text` / `RichText` | `textScaler:` |
| `WillPopScope` | `PopScope` (`canPop` + `onPopInvokedWithResult`) |
| `RaisedButton`, `FlatButton`, `OutlineButton` | `ElevatedButton`, `TextButton`, `OutlinedButton` |
| `Color.withOpacity(x)` | `Color.withValues(alpha: x)` |
| `theme.accentColor`, `theme.backgroundColor` | `theme.colorScheme.*` |
| `MaterialStateProperty` | `WidgetStateProperty` |
| `describeEnum(x)` | `x.name` |

Where unsure, check the installed SDK rather than recalling a signature —
`flutter analyze` reports the replacement for every deprecation in the pinned version.

---

## 19. Common mistakes

| Mistake | Why it hurts | Instead |
|---|---|---|
| Page constructor takes a model | Not deep-linkable, not restorable | Take an id (§1) |
| Business logic in `build` | Untestable without `pumpWidget` | Derived provider (§1, §4) |
| A spinner where the empty state should be | Blank screen reads as a bug | Four real states (§2) |
| Retry that pops the screen | The request is never re-run | `ref.invalidate(sameProvider)` (§2) |
| `ListView(children: [...])` for a real list | Builds every row before the first frame | `ListView.builder` (§3) |
| `shrinkWrap` + `NeverScrollableScrollPhysics` | Kills laziness, nests scrollables | Slivers (§3) |
| `.sort()` / `DateFormat(...)` in `build` | Runs per frame | Provider (§4) |
| `ref.watch` driving a snackbar or `context.go` | Double-fires on rebuild | `ref.listen` (§5) |
| `context` used after `await` with no guard | Crash on a slow network only | `if (!context.mounted) return;` (§6) |
| A component that takes `WidgetRef` | N cards = N requests; ungoldenable | Data in, callbacks out (§7) |
| Missing `const` / `super.key` | Whole subtree rebuilds; no list keys | Both, on every widget (§8) |
| `IconButton` with no `tooltip` | Screen reader announces "button" | `tooltip:` (§9) |
| `SizedBox(height: 44, child: Text(...))` | Clips at 150% text scale | `minHeight` constraint (§10) |
| `EdgeInsets.only(left:)` | Breaks in Arabic and Hebrew | `EdgeInsetsDirectional` (§11) |
| Extracting a shared component on first use | Wrong seams, then boolean creep | Promote on the third (§12) |
| `isPrimary` + `isDanger` + `isGhost` | 8 combinations, 3 illegal | An enum variant (§12) |
| Animating `width`/`padding` | Layout pass per frame | Transform / opacity (§13) |
| Ignoring `disableAnimationsOf` | Nausea for vestibular-sensitive users | Gate duration on it (§13) |
| Controller created, never disposed | Leaks a listener list per open | `dispose()` (§14) |
| Submit stays enabled during the request | Duplicate records | `onPressed: null` while loading (§14) |
| Inline `RegExp` email validator | Untranslatable, inconsistent, untestable | Shared `Validators` (§14) |
| One controller per wizard step | Back loses answers; nothing to submit | One draft object (§15) |
| Request fired on every keystroke | 10 requests per word, out-of-order results | Timer debounce + `CancelToken` (§16) |
| `await Future.delayed` as a debounce | Nothing to cancel; one future per keystroke | `Timer` you hold and cancel (§16) |
| Login form in a WebView | Invisible URL, no autofill, app can read the password | System browser auth (§17) |
| `Authorization` header or `runJavaScript` token | Leaks a bearer token to a page you do not control | Short-lived exchange code (§17) |

---

## 20. Never

- Give a page constructor a domain model instead of an id.
- Ship a screen with fewer than four states, or with a retry that does not re-fetch.
- Build a growable list with `ListView(children:)`.
- Pair `shrinkWrap: true` with `NeverScrollableScrollPhysics()`.
- Sort, filter, parse or format inside `build`.
- Drive navigation or a snackbar from `ref.watch`.
- Touch `context` after an `await` without `context.mounted`.
- Pass a `WidgetRef` into a component, or let a component fetch.
- Omit `const` or `super.key` on a widget class.
- Ship an icon-only button without a `tooltip`.
- Put text inside a fixed-height box.
- Write `EdgeInsets.only(left:)` or `Alignment.centerLeft`.
- Add a boolean variant flag to a shared component.
- Animate a layout property when a transform would do.
- Create a `TextEditingController`, `FocusNode` or `AnimationController` without a `dispose()`.
- Write an inline email or phone `RegExp` in a validator.
- Fire a search request from `onChanged` without a debounce and a cancel.
- Put a login form in an embedded WebView, or inject a token into one.
