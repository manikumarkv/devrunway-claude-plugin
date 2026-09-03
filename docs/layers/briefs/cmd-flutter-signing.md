# Brief — `/flutter-signing`

**Kind:** slash command (`skills/flutter-signing/`) · **Issue:** #2 · **Cookbook:** `#accounts`

`user-invocable: true`. Sub-commands: `audit` (what exists, what is missing, what expires),
`setup ios|android`, `rotate <credential>`.

## Content to encode
1. **Decide first, because these are permanent:** bundle ID / package name (a change means a
   new listing and losing every install and review); organization vs individual Apple
   enrolment (individual cannot add team members); who is Account Holder; the flavor suffix
   scheme.
2. **Store accounts belong to company-controlled role addresses**, not a person's Apple ID.
   The most common irreversible mistake in small teams; it surfaces the week someone leaves.
3. **Apple identity chain:** certificate + App ID + devices = provisioning profile. Enabling
   a capability in Xcode changes the App ID but **does not regenerate the profile** — a top
   iOS build failure that appears only at signing time.
4. Use an **App Store Connect API key** for CI, never an Apple ID: no two-factor prompt,
   survives password changes, scoped and revocable. The `.p8` downloads **once** — into the
   secret manager in the same minute.
5. Distribution certificates are a shared, limited team resource. Revoking one invalidates
   every profile built on it, for everyone — never "clean up" certificates you did not create.
6. Prefer an **APNs auth key** (one per team, both environments, never expires) over per-app
   push certificates that expire annually on a date nobody has calendared.
7. **Play App Signing:** you hold a rotatable *upload* key; Google holds the permanent *app
   signing* key. Enrol — it turns unrecoverable key loss into a support ticket.
8. The CI service account is created in Google Cloud but its permissions are granted **in the
   Play Console** — a separate step that is easy to miss.
9. Play's **annual `targetSdk` deadline** blocks updates. Calendar it with an owner.
10. **Secret inventory** table: what, where it lives, expiry, recovery path. The failure mode
    is never theft — it is an expiry nobody owned.
11. In-repo vs never-in-repo: Firebase config files are **not** secrets and belong in the
    repo; keystores, `.p8` keys and service-account JSON never do. Verify against the index
    of tracked files, not by reading `.gitignore` — an ignore rule does not apply to a file
    that is already tracked.
12. Signing must be reproducible from secrets on any machine or runner. "It signs on my Mac"
    is not a release process — use `fastlane match` or explicitly imported credentials.

## Acceptance
- [ ] `audit` lists every credential with owner, location and expiry, flagging anything absent
- [ ] Detects env or keystore files tracked in the repo despite a `.gitignore` rule
- [ ] Never instructs the user to commit a keystore or a `.p8`
- [ ] Recommends an API key over an Apple ID for every CI path
