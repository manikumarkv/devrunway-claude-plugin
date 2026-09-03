# Brief — `/flutter-verify`

**Kind:** slash command (`skills/flutter-verify/`) · **Issue:** #16 (parent #2) · **Cookbook:** `#emulators`

`user-invocable: true`. No `paths:` — there is no file that triggers "what should I test".
Takes an optional argument describing what changed.

## What it does
Given a description of a change (or a diff), produce the verification checklist scoped to
what that change touches, and say which items need a physical device.

## Content to encode
1. **What an emulator can and cannot tell you.** Trustworthy: layout across sizes, dark mode,
   text scale, RTL, the four states, deep links, process death, migrations, permission denial
   paths, semantics tree. Needs hardware: **any performance number** (an Android emulator runs
   on the desktop CPU and is often faster than a real mid-range phone), real biometrics and
   keystore policy (the emulator keystore is software-backed, so hardware-bound key policies
   appear to work and then differ on device), real push tokens, purchases, camera/NFC/BLE,
   Doze and OEM killers, cellular transitions, link domain verification, real
   TalkBack/VoiceOver gestures.
2. **Five virtual devices, not fifteen:** smallest supported screen, largest/tablet, oldest
   supported OS, newest OS, one in "hostile mode" (dark + 200% text + RTL + slow network).
3. **Terminal drivers** — `simctl openurl` / `push` / `ui appearance` / `content_size` /
   `recordVideo`; `adb am start -d`, `settings put global always_finish_activities 1`,
   `svc wifi disable`, `pm clear`, `logcat --pid`, `input keyevent KEYCODE_BACK`.
   `always_finish_activities` is the highest-value setting: it reproduces what a real device
   does under memory pressure, turning "works until you background it" into a local failure.
4. **Test the upgrade, not the fresh install** — install the old build, create data, install
   the new one over it. A fresh install skips every migration you wrote, so the bug ships to
   everyone except the person who tested it.
5. **Checklist keyed by what changed** — UI / list / form / navigation / model / auth /
   networked / permissions, plus "both platforms, always".
6. **The physical-device gate before release** — profile-mode performance, biometrics, real
   push in all three states, links from outside the app, ten-minute background, screen-reader
   walk, install over the previous released version.
7. Anything verified by hand more than twice becomes a widget test.

## Output shape
A checklist the user can work through, each item marked emulator-ok or device-required, with
the exact command where one exists.

## Acceptance
- [ ] Given "changed the program list to paginate", returns list/scroll/error-state items and
      does **not** return biometric or purchase items
- [ ] Always includes the upgrade-install item when a model or local schema changed
- [ ] Never claims an emulator can validate performance
