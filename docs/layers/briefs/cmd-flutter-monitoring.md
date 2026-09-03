# Brief — `/flutter-monitoring`

**Kind:** slash command (`skills/flutter-monitoring/`) · **Issue:** #2 · **Cookbook:** `#monitoring`, `#feedback`

`user-invocable: true`. Sub-commands: `setup`, `triage`, `feedback`.

## Content to encode
1. **The metrics, and what each one hides:**

   | Metric | Watch for | Blind spot |
   |---|---|---|
   | Crash-free **users** | The headline health number | Hides a crash hitting one user repeatedly |
   | Crash-free **sessions** | Repeat crashes, crash loops | A launch crash looks minor here |
   | ANR rate (Android) | Main-thread blocking | Not a crash — absent from crash reporting entirely |
   | Cold start p90 | Startup regressions | Averages hide the tail users feel |
   | Adoption by version | Rollout progress | Rates are noise below a few percent adoption |

   The two crash numbers disagree in exactly the informative case: a crash on launch barely
   moves the session number and destroys the user number. Never judge a new version's rate
   until adoption is meaningful — the first hours mislead in both directions.
2. **Triage practice:** a named owner each week, not "the team" — issues without an owner
   survive indefinitely. Rank by *users affected*, then by new-in-this-version. Every triaged
   crash gets a decision: fix now, fix next release, accept with a reason, or cannot-reproduce
   with a note on what data is missing. "Cannot reproduce" is a logging gap — add breadcrumbs
   and ship, rather than closing it.
3. Alert on **rate changes and new signatures**, never absolute counts. Counts scale with
   traffic and train people to ignore alerts. Every alert has a documented first response.
4. Only actionable errors reach crash reporting — 5xx, timeouts, parse failures, unexpected
   states. Expected 4xx and handled states are UI. Noise is what kills a dashboard.
5. Every report carries flavor, version, route and breadcrumbs, so it is triageable without
   reproducing it.
6. Keep symbol files for every shipped build; upload is part of the release job, never manual.
   An unsymbolicated trace is unreadable and cannot be recovered later.
7. A fix ships with a test that fails without it, so the crash cannot return unnoticed.
8. **Feedback:** reachable from settings and from an error state, attaching diagnostics
   automatically — version, flavor, platform, device, locale, current route, connectivity, a
   redacted log buffer, and a **pseudonymous session reference** that joins the report to your
   own logs without collecting anything identifying. The user sees exactly what is sent and
   can remove it. Offer screenshot or recording attachment — it removes a round trip.
9. The in-app review prompt is a limited resource capped by the OS: after a success, never
   after an error, never on launch, never twice to someone who dismissed it.

## Acceptance
- [ ] `setup` wires context keys, breadcrumbs and symbol upload, and does not report 4xx
- [ ] `triage` ranks by users affected and forces a decision per issue
- [ ] The diagnostics payload contains no email, name, or raw token
- [ ] Alert thresholds are expressed as deltas, never as counts
