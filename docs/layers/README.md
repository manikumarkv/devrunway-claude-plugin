# Flutter mobile layers — build plan

Tracking [#2](https://github.com/manikumarkv/devrunway-claude-plugin/issues/2).

**One unit per session.** Each row below is a self-contained piece of work. A session needs
only two files to start cold — [`AUTHORING.md`](AUTHORING.md) for the format and the unit's
brief for the spec — plus the cookbook section it references.

Full standards: [Flutter Feature Cookbook](https://claude.ai/code/artifact/53812caa-49e4-488e-b221-f8ab5d03d323) (50 sections).

## Layers — routed by `paths:` globs

| Brief | Issue | Target | Covers | Status |
|---|---|---|---|---|
| [mobile-flutter](briefs/mobile-flutter.md) | [#15](https://github.com/manikumarkv/devrunway-claude-plugin/issues/15) | `layers/mobile/flutter/` | structure, bootstrap, theme, platform, app size, monorepo | 📋 |
| [dart-models](briefs/dart-models.md) | [#3](https://github.com/manikumarkv/devrunway-claude-plugin/issues/3) | `layers/language/dart-models/` | models, serialization | ✅ |
| [dio-services](briefs/dio-services.md) | [#4](https://github.com/manikumarkv/devrunway-claude-plugin/issues/4) | `layers/api-style/dio/` | services, errors, offline, media, contract | 📋 |
| [riverpod](briefs/riverpod.md) | [#5](https://github.com/manikumarkv/devrunway-claude-plugin/issues/5) | `layers/state/riverpod/` | providers, pagination, realtime | 📋 |
| [flutter-ui](briefs/flutter-ui.md) | [#6](https://github.com/manikumarkv/devrunway-claude-plugin/issues/6) | `layers/frontend/flutter-ui/` | pages, components, design system, motion, forms, wizard, search, webview | 📋 |
| [go-router](briefs/go-router.md) | [#7](https://github.com/manikumarkv/devrunway-claude-plugin/issues/7) | `layers/frontend/go-router/` | routing, deep links | 📋 |
| [flutter-session](briefs/flutter-session.md) | [#8](https://github.com/manikumarkv/devrunway-claude-plugin/issues/8) | `layers/auth/flutter-session/` | session, biometrics, payments | 📋 |
| [flutter-local](briefs/flutter-local.md) | [#9](https://github.com/manikumarkv/devrunway-claude-plugin/issues/9) | `layers/storage/flutter-local/` | local storage | 📋 |
| [fcm](briefs/fcm.md) | [#11](https://github.com/manikumarkv/devrunway-claude-plugin/issues/11) | `layers/notifications/fcm/` | push, background work | 📋 |
| [observability](briefs/observability.md) | [#10](https://github.com/manikumarkv/devrunway-claude-plugin/issues/10) | `layers/logging/flutter-observability/` | logging, analytics, flags | 📋 |
| [flutter-l10n](briefs/flutter-l10n.md) | [#12](https://github.com/manikumarkv/devrunway-claude-plugin/issues/12) | `layers/i18n/flutter-l10n/` | localization | 📋 |
| [flutter-test](briefs/flutter-test.md) | [#13](https://github.com/manikumarkv/devrunway-claude-plugin/issues/13) | `layers/testing/flutter-test/` | tests, goldens, e2e, contract, perf budgets | 📋 |
| [flutter-release-ci](briefs/flutter-release-ci.md) | [#14](https://github.com/manikumarkv/devrunway-claude-plugin/issues/14) | `layers/ci/flutter-release/` | flavors, CI/CD, analyzer config | 📋 |

## Commands — invoked by the user

| Brief | Issue | Target | Status |
|---|---|---|---|
| [cmd-flutter-verify](briefs/cmd-flutter-verify.md) | [#16](https://github.com/manikumarkv/devrunway-claude-plugin/issues/16) | `skills/flutter-verify/` | 📋 |
| [cmd-flutter-signing](briefs/cmd-flutter-signing.md) | [#17](https://github.com/manikumarkv/devrunway-claude-plugin/issues/17) | `skills/flutter-signing/` | 📋 |
| [cmd-flutter-release](briefs/cmd-flutter-release.md) | [#18](https://github.com/manikumarkv/devrunway-claude-plugin/issues/18) | `skills/flutter-release/` | 📋 |
| [cmd-flutter-submit](briefs/cmd-flutter-submit.md) | [#19](https://github.com/manikumarkv/devrunway-claude-plugin/issues/19) | `skills/flutter-submit/` | 📋 |
| [cmd-flutter-monitoring](briefs/cmd-flutter-monitoring.md) | [#20](https://github.com/manikumarkv/devrunway-claude-plugin/issues/20) | `skills/flutter-monitoring/` | 📋 |
| [cmd-flutter-build-doctor](briefs/cmd-flutter-build-doctor.md) | [#21](https://github.com/manikumarkv/devrunway-claude-plugin/issues/21) | `skills/flutter-build-doctor/` | 📋 |

📋 planned · 🚧 in progress · ✅ done and eval passing

## Suggested order

Globs must not overlap, so build the specific layers before the fallback — that way
`mobile/flutter`'s catch-all glob is written knowing what the others already claim.

1. `dart-models`, `dio-services`, `riverpod` — the spine everything else references
2. `flutter-ui`, `go-router` — the largest surface
3. `flutter-session`, `flutter-local`, `observability`
4. `fcm`, `flutter-l10n`, `flutter-test`, `flutter-release-ci`
5. `mobile-flutter` — last, so its fallback glob is written against known claims
6. The six commands, in any order — they are independent

## Prompt for a fresh session

> Read `docs/layers/AUTHORING.md` and `docs/layers/briefs/<brief>.md`. Create the layer it
> describes: `SKILL.md`, the detail `.md`, and the `.eval.yaml`. Run `/eval <tech>` and fix
> the layer until it passes. Update the status in `docs/layers/README.md`. Commit with
> `feat(layer): ...`.

After each unit, verify routing: `stack-dispatcher` should return the new layer for a
representative target file and *not* return it for an unrelated one.
