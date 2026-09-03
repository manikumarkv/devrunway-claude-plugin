---
name: flutter-release
description: Run a Flutter mobile release as a process — agree halt criteria with numbers and an owner before the rollout starts, cut a tag and promote the tested artifact, watch the staged rollout against those numbers, and hotfix from the released tag. Encodes the one fact that shapes mobile releases — you cannot roll back; you halt, kill-switch, and roll forward. Usage — /flutter-release <plan|cut|watch|hotfix> [args]
argument-hint: <plan|cut|watch|hotfix> [version|tag]
arguments:
  - name: subcommand
    description: "Sub-command: plan, cut, watch, hotfix"
  - name: args
    description: "For plan/cut/watch: the version name (e.g. 3.4.0). For hotfix: the released tag and a one-line description of the bug."
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(git *)
  - Bash(gh *)
  - Bash(cat *)
  - Bash(grep *)
  - Bash(sed *)
  - Bash(ls *)
  - Bash(mkdir *)
---

# Flutter Release

**You cannot roll back a mobile release.** A user who has updated stays updated. There is no
switch that returns them to the previous binary, and re-uploading the old build is a *new*
release that has to win the same rollout race. Everything below follows from that one fact,
and it is the thing teams from a web background get wrong on their first bad release.

So the leverage all sits *before* and *around* the release, not after it:

- The rollout is staged, so a bad build reaches a cohort instead of everyone.
- The numbers that mean "stop" are agreed in writing before the rollout starts, because
  deciding whether a number is bad while watching it climb produces the wrong answer every
  time.
- A kill switch is infrastructure, not a nice-to-have. It is the only control that reaches
  users who already updated, and it works in minutes.

Sub-command is `$ARGUMENTS[0]`: `plan` · `cut` · `watch` · `hotfix`. If it is missing or
unrecognised, print the four sub-commands with one line each and stop.

---

## The incident order

Used by `watch` and `hotfix`. Run it top to bottom; do not skip to 3 because it feels more
like fixing.

| Order | Action | Time to effect | Who it reaches |
|---|---|---|---|
| 1 | **Halt the staged rollout** | Minutes | *New* users only — nobody who already updated |
| 2 | **Kill switch the feature, or fix it server-side** | Minutes | Users who already updated — the only step that does |
| 3 | **Ship a fix and roll forward** | Hours to days, plus store review | Users who update again |
| 4 | **Force update** | A release cycle, then immediate | Everyone — every user pays for one cohort's bug |

Steps 1 and 2 are why a kill switch is infrastructure. A team without one has only step 3, and
step 3 takes a day at best — longer on iOS, where a review sits between you and the fix.

**"Roll back the release" is not on this list and is never offered.** If someone asks for it,
the answer is step 1 plus step 2, and then step 3 — say that, rather than agreeing to look
into a rollback that does not exist.

---

## Scope boundaries

This command owns the **release process**: cadence, halt criteria, rollout stages, the watch,
and the hotfix branch. It does not restate build configuration.

| Concern | Owner |
|---|---|
| Flavors, pinned toolchain, the PR gate, CI-generated monotonic build numbers, `--obfuscate` + symbol upload, runner and secret rules | `layers/ci/flutter-release` — load it via `stack-dispatcher` when a workflow or Gradle file needs to change |
| Keystores, provisioning profiles, App Store Connect API keys | `/flutter-signing` |
| Store requirements, review, rejection triage | `/flutter-submit` |
| Kill switches, the minimum-version gate, flag ownership and removal dates | `layers/logging/flutter-observability` §10 |
| Crash triage as a practice, alert thresholds, dashboards | `/flutter-monitoring` |
| "Gradle says duplicate class", "the archive hangs" | `/flutter-build-doctor` |

When one of those needs to change during a release, say which file and which owner — do not
re-derive the rule here.

---

# `/flutter-release plan [version]`

Produces the written agreement the rest of the release is run against. Nothing is built here.

## 1. Confirm the train

```bash
git tag --sort=-creatordate | head -5
git log -1 --format="%H %ci %s"
```

Establish and record:

- **Cadence** — a fixed date ("every second Tuesday"), not "when it's ready". Predictability is
  what lets you *skip* a release calmly when quality is not there. A ship-when-ready team
  cannot skip, because there is no next train to put the work on.
- **Code freeze** — when trunk stops feeding this release.
- **Cut date** and **rollout start** — they are not the same day if the store review sits
  between them.

If the previous release slipped, ask whether to skip this train rather than compress it. That
is a normal outcome and should be recorded as one.

## 2. Scope the release and find the risky changes

```bash
LAST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
git log "${LAST_TAG}..HEAD" --pretty=format:"%h %s" --no-merges
```

Classify each change, and mark as **risky** anything that touches payments, writes user data
irreversibly, calls a brand-new backend, changes a migration, or rewrites something that
already works.

For every risky change, the plan records a kill switch:

| Change | Risk | Kill switch key | Verified off? | Owner |
|---|---|---|---|---|
| `feat(checkout): new payments provider` | Payments | `checkout_new_provider` | ☐ flipped off on a real device | @name |

A kill switch nobody has flipped is a hope, not a control. Verification is a real build, flag
off, foregrounded, behaviour observed — the mechanics are `flutter-observability` §10.3. If a
risky change has no switch, that is a finding to raise now, not on the night of the rollout.

## 3. Halt criteria — numbers, adoption floor, and a named owner

This is the part that must not be soft. Emit a table with **actual numbers** filled in, ask the
team to confirm or override each one, and write the confirmed values into the release doc.

Defaults to propose (they are defaults, not law — but the plan ships with numbers either way):

| # | Criterion | Halt at | Evaluated |
|---|---|---|---|
| 1 | **Crash-free users** delta vs the previous version at the same adoption | drop **> 0.3 pp** | Each checkpoint after the adoption floor |
| 2 | **Crash-free users** absolute | below **99.0%** | Same |
| 3 | **Crash-free sessions** delta | drop **> 0.2 pp** | Same |
| 4 | **New crash signature** entering the **top 5 by users affected** | any occurrence | From T+2h, on counts, floor does not apply |
| 5 | **Android user-perceived ANR rate** | above **0.47%**, or **+0.1 pp** over the previous version | T+24h onward |
| 6 | **Primary funnel completion** (name the funnel, e.g. cart → purchase) | down **> 5% relative** vs the same weekday-and-hour cohort on the previous version | T+24h onward |
| 7 | **1–2★ reviews naming this version** | more than **5/day**, or any mentioning data loss | Daily |

Two things make this table work, and both are easy to leave out:

**An adoption floor.** No *rate* is evaluated until the new version has **≥ 5% adoption AND
≥ 1,000 sessions AND ≥ 24 hours elapsed** (scale the session count down for a small app, but
keep all three conditions — pick numbers, do not delete the condition). Below the floor, rates
are noise: the earliest adopters are unrepresentative, a handful of crashes moves a percentage
by a point, and the first hours mislead in *both* directions — they invent problems and they
hide them. Criterion 4 is the deliberate exception: a genuinely new signature is a count, not a
rate, and counts are readable immediately.

**A named owner.** A person, not "the team" — an unowned criterion is watched by nobody.
Record:

- The owner per checkpoint window, including an out-of-hours backup with a way to reach them.
- That the owner **can halt alone**, without a meeting. A halt is cheap and reversible: the
  rollout resumes. Reaching 100% is neither.

State the reason in the doc, because it is the whole point of writing it down beforehand: at
T+6h with a number moving and a launch date behind you, the pressure runs one way. The number
was agreed when nobody was under it.

## 4. Rollout stages and dwell time

Propose, and record, the stage schedule:

| Platform | Stages | Dwell | Halt mechanism |
|---|---|---|---|
| Android (Play staged rollout) | 5% → 20% → 50% → 100% | ≥ 24h per stage, and ≥ 1 full business day at 20% before going past it | Halt rollout — stops new users, keeps existing ones |
| iOS (phased release) | The 7-day 1/2/5/10/20/50/100 schedule | Fixed by the store | Pause phased release — same semantics |

The dwell time exists so the adoption floor can actually be reached before the next increase.
A 5% → 100% jump the same afternoon means every criterion above is evaluated for the first
time when the release is already everywhere.

Both halt mechanisms stop *new* users only. Write that sentence into the plan; it is the thing
people assume otherwise.

## 5. Release notes source

Record where the notes come from — the `CHANGELOG.md` section for this version, or the commits
since the last tag — and that store metadata lives in the repo and is generated at cut time.
Nobody hand-types release text into two consoles; that is how store text and code end up
disagreeing about what shipped.

## 6. Write the plan

Confirm with the user, then write `docs/releases/<version>.md`:

```markdown
# Release <version>

**Cut:** <date> · **Rollout starts:** <date> · **Release manager:** @name

## Scope
<changes since last tag, risky ones marked>

## Kill switches
<table from §2 — key, verified-off, owner>

## Halt criteria
<table from §3, with the confirmed numbers>
**Adoption floor:** ≥5% adoption AND ≥1,000 sessions AND ≥24h before any rate is judged.
**Owners:** <window → person, plus out-of-hours backup>. Any owner may halt without a meeting.

## Rollout stages
<table from §4>

## If something goes wrong
There is no rollback. The order is: halt the rollout (minutes, new users only) → kill switch
or server-side fix (minutes, reaches users who already updated) → ship a fix and roll forward
(hours to days) → force update only for genuine incompatibility.

## Post-release check — <date, T+72h>
Crash-free users / crash-free sessions / funnel / store reviews / open issues. Written down
whether or not anything felt wrong.
```

---

# `/flutter-release cut [version]`

Turns an agreed plan into a tag and starts the rollout.

## 1. Preconditions

```bash
git branch --show-current      # must be trunk
git status --short             # must be clean
gh run list --branch main --limit 3
```

- On trunk, clean, and the PR gate green on the commit being cut. The gate's four checks are
  defined by `ci/flutter-release` §7 — this command only requires that they passed, it does not
  redefine them.
- The plan doc exists and its halt criteria have numbers and an owner. If not, run
  `/flutter-release plan` first. Cutting without agreed criteria is how a rollout ends up
  judged by whoever is looking at the dashboard.

## 2. Version name in a reviewed commit; build number from CI

Bump the version *name* in `pubspec.yaml` in a normal reviewed commit. Do **not** touch the
build number — it is generated by CI and monotonic across every flavor and both platforms
(`ci/flutter-release` §10). A hand-edited build number collides the first time two branches
merge in the same afternoon, and both stores reject it at the end of a twenty-minute pipeline.

## 3. Tag

```bash
git tag -a "v<version>" -m "Release v<version>"
git push origin "v<version>"
```

The release build runs from the tag. Every release is tagged, and the tag must map to an
artifact and a symbol file that still exist — see §5.

## 4. Promotion, not a rebuild

**Production is a promotion of the exact artifact the testers used. It is never a rebuild.**

A rebuild from the same commit is a different binary: a different toolchain patch on the
runner, a different transitive dependency resolution, a different obfuscation mapping. Nobody
tested it. The tested artifact and the shipped artifact must be the same build number.

```
Tested on the internal/TestFlight track:  <name>+<number>
Promoting to production:                  <name>+<number>   ← must be identical
```

Verify the number on the track before promoting, and record it. If the tested artifact has
expired, been deleted, or cannot be identified, you do not have a tested release candidate —
you have a new one. Build it, put it back through testing, and start this step again. Shipping
an untested rebuild because the tested one is gone is the failure this rule exists to prevent.

## 5. Verify tag → artifact → symbols

Confirm all three exist and carry the same `<name>+<number>`:

- The tag.
- The uploaded artifact on the store track.
- The Dart symbols (`--split-debug-info` output) and the native symbols/dSYMs.

The upload itself belongs to the release job (`ci/flutter-release` §11); what this command
checks is that the mapping is intact *before* the rollout, because a crash report you cannot
symbolicate is a crash report you cannot triage — and criteria 1–4 all depend on reading crash
signatures.

## 6. Generate the release notes

```bash
LAST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | head -2 | tail -1)
git log "${LAST_TAG}..v<version>" --pretty=format:"%s" --no-merges
```

Generate the user-facing notes from the `CHANGELOG.md` section or from these commits, write
them to the versioned store-metadata files in the repo, and use those files for both stores.
Store text and code cannot disagree if only one of them is written by hand.

## 7. Start the rollout at stage one

Start at the first percentage from the plan — never at 100%. Then announce, in the team
channel, all four of:

1. Version and build number.
2. The halt criteria with their numbers.
3. The owner for the current window and the out-of-hours backup.
4. A link to the plan doc.

Then print the release record and tell the user the next step is `/flutter-release watch
<version>` at the first checkpoint.

---

# `/flutter-release watch [version]`

Runs a checkpoint against the agreed criteria. Read the plan doc first and use *its* numbers;
if it has none, say so and stop — improvising thresholds mid-rollout is exactly the failure
mode `plan` exists to prevent.

## 1. Adoption floor first

Before reporting any rate, check the floor: **≥ 5% adoption, ≥ 1,000 sessions, ≥ 24h elapsed**
(or the plan's values). Below the floor, report the numbers with an explicit "below floor — not
actionable" label and evaluate only criterion 4, the new-signature count. Do not let a
crash-free-users figure computed from 40 sessions start a conversation about halting.

## 2. Crash-free **users** and crash-free **sessions** are different questions

They disagree in exactly the informative cases, and each direction has a different response.

| What happened | Crash-free sessions | Crash-free users | Response |
|---|---|---|---|
| Crash on launch, hits 2% of users | ~99.7% — looks fine | ~98.0% — very bad | **Halt.** Judge on the user number |
| One device in a crash loop, 500 crashed sessions | Badly dented | Barely moves | Not a release halt. One device, one signature — triage it |

A launch crash barely moves the session number, because the session count is dominated by the
healthy sessions of unaffected heavy users, and an affected user contributes only their one or
two failed attempts before giving up. It destroys the user number, because every affected user
is counted once whether they crash once or twenty times. That asymmetry is the entire reason
both metrics exist:

- **Crash-free users** answers *how many people is this hurting* → the halt decision.
- **Crash-free sessions** answers *how badly, and how repeatedly* → the triage priority.

Report both, always labelled, always with the previous version's value at the *same adoption*
next to them. Comparing a 6%-adopted new version against the previous version's settled
lifetime figure compares two different populations and produces a scary number every time.

## 3. Checkpoints

| When | What is readable | Action |
|---|---|---|
| T+2h | New signatures, absolute crash counts | Criterion 4 only |
| T+24h | First real rates, if the floor is met | Full criteria evaluation |
| T+72h | Funnel, store reviews, ANR | Full evaluation, and the post-release check |
| Before **every** stage increase | Everything | Explicit go/no-go by the named owner |

The pre-increase check is not a formality. Going from 20% to 50% is the last cheap decision in
the release; after 100% the only remaining controls are the kill switch and a new build.

## 4. The decision

For each criterion, print: metric, current value, threshold, previous version's value at
comparable adoption, and **tripped / not tripped**. Then the named owner decides — the command
does not decide for them, but it does say plainly when a criterion is tripped rather than
softening it.

If nothing is tripped: hold or advance per the plan, and record the checkpoint in the release
doc.

If something is tripped: **run the incident order from the top of this file.** Halt first — it
costs nothing and buys the time to think. Then reach for the kill switch, which is the only
step that helps the users who already updated. Only then talk about a fix.

Never offer, and never accept as an instruction, "roll back the release". Say what is actually
available: halt, kill switch, roll forward.

## 5. The post-release check happens either way

At the time set in the plan (default T+72h), append to the release doc — even when the release
felt uneventful:

- Crash-free users and sessions, versus the previous version.
- Primary funnel completion.
- Store reviews mentioning the version.
- Any criterion that came close without tripping, and whether the threshold was right.
- Anything to change in the next plan.

A check that only happens when something feels wrong tells you nothing about the releases that
went fine, which is where the drift shows up first.

---

# `/flutter-release hotfix <tag> <description>`

`$ARGUMENTS[1]` is the released tag; the rest is a one-line description of the bug.

## 1. Confirm this is actually step 3

Before writing any code, confirm steps 1 and 2 have been done:

- Is the rollout **halted**? If not, halt it now. It takes a minute and stops the bleeding for
  everyone who has not yet updated.
- Can a **kill switch or a server-side change** fix this? If yes, do that first and measure
  before committing to a hotfix. It reaches the users who already updated — which the hotfix
  does not, until they update again.

A hotfix that a flag flip would have covered costs a build, a review and a second rollout, and
it arrives a day late for the people already affected.

## 2. Branch from the released tag

```bash
git fetch --tags
git checkout -b "hotfix/<version>" "<tag>"
```

**From the tag, not from trunk.** Trunk has everything merged since the cut — unreleased work
that has not been through a release gate and was never in the tested artifact. Branching from
trunk turns a one-line fix into an untested release of everything merged this sprint.

The release branch exists *only* while the hotfix does. It is not a long-lived branch.

## 3. The minimum change

Only the fix. No refactor, no dependency bump, no drive-by cleanup, no "while we're in here".
Every extra line is a change that skipped the normal review-and-soak path, and the whole point
of a hotfix is that it is small enough to reason about under time pressure.

Include a test that fails without the fix, so the bug cannot return unnoticed.

Bump the version *name* patch segment; the build number still comes from CI.

## 4. Same gate, same promotion rule

The hotfix takes the same PR gate as any other change, and production is still a **promotion of
the tested artifact** — a hotfix is not an exemption from §4 of `cut`. Urgency is the reason
this rule gets broken and the reason it matters most here.

## 5. Roll out the hotfix staged too

Staged, with the same criteria as the plan, tightened around the area that broke. Go faster
only when the bug in production is demonstrably worse than the risk of the fix — and write down
which of the two you judged worse.

## 6. Merge back to trunk the same day

```bash
git checkout main
git merge --no-ff "hotfix/<version>"
# or: cherry-pick onto a branch and open a PR, if trunk requires review
git push origin main
git branch -d "hotfix/<version>"
```

**Same day. Not "when things calm down".** A fix that lives only on the release branch
regresses in the next release, which is the worst-shaped bug there is: found, fixed, shipped,
then silently unfixed by the release that was supposed to be an improvement. The next occurrence
is also harder to diagnose, because everyone remembers fixing it.

Do not close the incident until the merge-back is pushed. Then delete the branch.

## 7. Force update — only for genuine incompatibility

Forcing an update is step 4 and is reserved for:

- A security fix.
- A broken API contract, where the old client cannot function against the current backend.
- Data corruption caused by the old client.

It is **not** for encouraging adoption, tidying up version fragmentation, or making a metric
look better. It is blunt by construction: every user on every older version pays an interruption
for one cohort's bug, including users who were never affected and cannot update right now.

If it is genuinely warranted, the mechanism is the minimum-version gate in
`logging/flutter-observability` §10 — a fail-open gate that has been tested by raising it in
staging and confirming a real build both blocks and releases. A force-update gate first
exercised during an incident is as likely to lock out everyone as to fix anything.

---

## Never offered

| Someone asks for | The honest answer |
|---|---|
| "Roll back the release" | There is no rollback. Halt the rollout, kill-switch the feature, then roll forward |
| "Re-upload the previous build" | That is a *new* release with a higher build number, subject to review and its own rollout — slower than a fix, and it downgrades nobody who already updated |
| "Just push it to 100%, it looks fine" | Not before the adoption floor. It looks fine because almost nobody has it |
| "Rebuild from the same commit and ship that" | Different binary, untested. Promote the tested artifact or produce a new candidate and test it |
| "Fix it on the release branch, merge later" | Later is the next release, where it silently regresses. Merge back the same day |

## Common mistakes

| Mistake | What it costs |
|---|---|
| Halt criteria decided during the rollout | The number is judged by someone who wants it to be fine |
| Judging crash-free **sessions** for a launch crash | The metric that hides launch crashes is the one you watched |
| Evaluating rates at 1% adoption | Both false alarms and false calm, from the same tiny sample |
| Comparing against the previous version's *final* rate | Two different populations; the new version always looks worse |
| "The team" owns the criteria | Nobody watches, and nobody has the standing to halt |
| Rebuilding for production | The binary users get was tested by no one |
| Hotfix branched from trunk | An unplanned release of everything merged since the cut |
| Hotfix never merged back | Fixed, then unfixed, by the next release |
| Force update to drive adoption | Every user interrupted for one cohort's bug; the gate stops being credible |
