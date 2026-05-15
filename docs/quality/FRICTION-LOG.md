# Friction Log

Append-only log of every time devrunway should have caught something and didn't, or did something it shouldn't have, while building real projects.

The point is volume and honesty, not polish. 30 seconds per entry. If you're thinking about formatting, you're overthinking it.

---

## Entry format

```markdown
## YYYY-MM-DD — short title
**Trigger:** what command or hook fired (or should have)
**What happened:** one sentence
**What I expected:** one sentence
**Skill/agent involved:** path or name (e.g. layers/backend/nodejs-standards)
**Friction type:** skill-gap | false-positive-hook | false-negative-hook | pipeline-skip | UX | other
**Severity:** low | medium | high
**Eval candidate:** yes/no — one-line assertion idea
```

---

## Friction types — definitions

- **skill-gap** — the rule isn't encoded in any layer's `SKILL.md` or detail file
- **false-positive-hook** — a hook fired on code that's actually fine
- **false-negative-hook** — a hook should have fired but didn't
- **pipeline-skip** — a `skills/<name>/SKILL.md` step was skipped or ran out of order
- **UX** — the plugin behaved correctly but the experience was bad (confusing output, too much noise, wrong default, etc.)
- **other** — anything else

---

## Weekly review checklist

End of each week, 30 minutes:

- [ ] Read every entry from this week
- [ ] Cluster by skill/agent (which file path appears most?)
- [ ] Cluster by friction type (which type dominates?)
- [ ] Pick top 3 patterns
- [ ] For each: write the action (eval case + `/forge fix`, OR hook regex tune, OR skill step edit)
- [ ] Commit fixes: `chore(plugin): friction fixes — week N`
- [ ] Append `**Resolved:** commit-sha` to each addressed entry

---

## Example entry (delete once you have real ones)

## 2026-05-15 — Express signup route missing rate-limit
**Trigger:** `/dev-code` on signup ticket #42
**What happened:** generated `router.post('/signup', signupHandler)` with no rate-limit middleware
**What I expected:** the `nodejs-standards` layer should have produced `router.post('/signup', rateLimit({windowMs: 60_000, max: 5}), signupHandler)` because auth endpoints are abuse magnets
**Skill/agent involved:** `layers/backend/nodejs-standards`
**Friction type:** skill-gap
**Severity:** high
**Eval candidate:** yes — assert `rateLimit(` appears in any generated `/signup`, `/login`, `/reset-password` route handler

---

## Entries

<!-- append new entries below this line, newest at the bottom -->
