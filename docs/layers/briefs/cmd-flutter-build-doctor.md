# Brief — `/flutter-build-doctor`

**Kind:** slash command (`skills/flutter-build-doctor/`) · **Issue:** #21 (parent #2) · **Cookbook:** `#build`, `#debug`

`user-invocable: true`. Takes pasted build output, or runs the build and reads it.

## Content to encode
1. **Read the first error, not the last.** Gradle and Xcode both bury the cause above a long
   summary, and the last forty lines are noise. This single rule saves the most time.
2. **Three questions that classify almost everything:**

   | Fails… | Assume until disproven | First check |
   |---|---|---|
   | Only for you | A stale cache or local toolchain drift | Fresh clone into a temp directory |
   | Only in CI | Toolchain version or a missing secret | Diff CI's Flutter / JDK / Xcode against yours |
   | Only in release | R8 / obfuscation / a missing keep rule | Rebuild release with shrinking off |

3. **Classify before cleaning.** A Dart compile error does not improve with `flutter clean`,
   and reaching for it first hides which cache was stale. `.dart` + line number → your code;
   `build_runner` / `.g.dart` → codegen; "version solving failed" → resolution;
   `:app:` / `AAPT` / `D8` / `R8` → Android native; `xcodebuild` / `CocoaPods` / `ld:` → iOS
   native; "provisioning profile" / "code signing" → credentials, not code.
4. **The cleaning ladder, one rung at a time, rebuilding between:** `flutter clean` +
   `pub get` → `build_runner --delete-conflicting-outputs` → pods removed and
   `pod install --repo-update` → DerivedData → `gradlew clean` + `--refresh-dependencies` →
   `pub cache repair` → **fresh clone into a temp directory**. Rung 7 is the one that answers
   the question: if the fresh clone builds, the repo is fine and the workspace is dirty.
5. **Android catalogue:** `Unsupported class file major version` (JDK too new for this
   Gradle); `Could not find method` (AGP ↔ Gradle mismatch); `Duplicate class` (inspect the
   dependency tree, then constrain or exclude); `minSdkVersion cannot be smaller` (a plugin
   raised the floor — raise it deliberately, never with an override); manifest merger
   conflict; `mergeDexRelease` (multidex or fewer dependencies); builds debug but fails or
   crashes in release (R8 keep rule); missing per-flavor `google-services.json`; NDK mismatch.
6. **iOS catalogue:** `Module 'X' not found`; incompatible pod versions or a stale repo;
   deployment-target disagreement across Podfile, project and plugin; Apple-Silicon
   `EXCLUDED_ARCHS`; four distinct signing failures (bundle ID mismatch, missing entitlement
   in the profile, unlocked keychain in CI, expired certificate); archive succeeds but upload
   is rejected; Swift ↔ Xcode version mismatch.
7. **CI-only is always a *difference*** — enumerate rather than debug: unpinned toolchain, a
   missing or empty secret (assert the env file before the build step, so the error names the
   secret), a case-sensitive filesystem catching an import macOS forgave, gitignored generated
   files not regenerated in every job, cold caches resolving differently, a moved `-latest`
   runner image.
8. **Close the loop:** clean, codegen, build both platforms in debug, then confirm CI is
   green. A local green is half the answer.

## Rules the command must not break
- Never commit a fix it cannot explain. A pin, an exclusion or a `tools:replace` without a
  comment naming the conflict it resolves becomes permanent mystery config.
- Version overrides and dependency exclusions are last resorts and carry an expiry note —
  they mask a conflict that resurfaces at the next upgrade.
- Change one thing per rebuild and record it. "I ran several things and it worked" means the
  cause is still there.
- A recurring failure becomes a CI check, not a wiki note.

## Acceptance
- [ ] Given pasted Gradle output, names the failure class before suggesting any command
- [ ] Never opens with `flutter clean`
- [ ] Suggests the fresh-clone check before deep workspace debugging
- [ ] Refuses to propose an unexplained version override
