---
name: adr
description: Create a numbered Architecture Decision Record in docs/adr/ using the Nygard format. Links the ADR back to the dev-brainstorm doc if one exists. Usage — /adr <title> [issue-number]
argument-hint: "<decision-title> [issue-number]"
arguments:
  - name: title
    description: "Short title for the decision (e.g. 'use-dynamodb-for-sessions')"
  - name: issue
    description: "Optional GitHub issue number this decision relates to"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(find *)
  - Bash(ls *)
  - Bash(git *)
  - Bash(gh *)
---

# ADR — Architecture Decision Record

Parse `$ARGUMENTS[0]` as the decision title (convert to kebab-case for filename).
Parse `$ARGUMENTS[1]` as an optional GitHub issue number.

---

## Step 1 — Determine the next ADR number

```bash
# Count existing ADRs to get the next sequential number
find docs/adr/ -name '[0-9]*.md' 2>/dev/null | wc -l
```

If `docs/adr/` does not exist, create it.

Next number = count + 1, zero-padded to 4 digits: `0001`, `0002`, etc.

Filename: `docs/adr/<NNNN>-<kebab-slug>.md`

---

## Step 2 — Load context

If an issue number was provided:
```bash
gh issue view <number> --json title,body | head -50
find docs/dev-brainstorm/ -name "<number>.md" | head -1
```

Read both the issue and the dev-brainstorm doc (if exists) to pre-fill the ADR with the actual context and decision from the exploration.

---

## Step 3 — Ask clarifying questions

Before writing, confirm the core decision with the user:

> **ADR #<NNNN>: <title>**
>
> I'll need a few things to write this accurately:
>
> 1. **What was the decision?** (one sentence — what did you choose?)
> 2. **What were the alternatives you rejected?**
> 3. **What is the key consequence to be aware of?** (positive or negative)
>
> (If a dev-brainstorm doc exists for this issue, I'll pre-fill from there — just confirm or correct.)

Wait for answers. If a brainstorm doc exists, pre-populate the answers from it and ask for confirmation instead.

---

## Step 4 — Write the ADR

Write to `docs/adr/<NNNN>-<slug>.md`:

```markdown
# ADR <NNNN>: <Title>

**Date:** <YYYY-MM-DD>
**Status:** Accepted
**Author:** <git config user.name>
**Related:** <GitHub issue link if provided> · <dev-brainstorm doc link if exists>

---

## Context

<What is the issue or problem that motivates this decision? What forces are at play — technical, team, timeline, cost? What constraints exist? Write 2–5 sentences. This section should stand alone — a new team member reading this 2 years from now should understand why a decision was needed.>

## Decision

<What is the change or approach being adopted? State it clearly and specifically. "We will use X" not "We considered X." 1–3 sentences.>

## Alternatives Considered

### Option A: <Name> _(chosen)_
<Brief description. Why this was chosen.>

### Option B: <Name> _(rejected)_
<Brief description. Why this was rejected.>

### Option C: <Name> _(rejected)_
<Brief description. Why this was rejected.>

## Consequences

### Positive
- <What becomes easier or better?>
- <What new capability does this enable?>

### Negative / Trade-offs
- <What becomes harder? What cost is accepted?>
- <What technical debt is being incurred knowingly?>

### Risks
- <What could go wrong? What would trigger revisiting this decision?>

## Revisit Triggers

This ADR should be revisited if:
- <specific condition — e.g., "DynamoDB costs exceed $X/month">
- <specific condition — e.g., "query patterns require joins that DynamoDB cannot support">
```

---

## Step 5 — Update the ADR index

Update (or create) `docs/adr/README.md` with the new entry:

```markdown
# Architecture Decision Records

| # | Title | Date | Status |
|---|---|---|---|
| [0001](0001-use-dynamodb-for-sessions.md) | Use DynamoDB for sessions | 2025-01-15 | Accepted |
| [<NNNN>](<filename>.md) | <title> | <today> | Accepted |
```

---

## Step 6 — Link back from source

If a dev-brainstorm doc exists for the related issue, append a line to it:

```markdown
**ADR:** [ADR <NNNN>: <title>](../adr/<filename>.md)
```

---

## Step 7 — Commit

```bash
git add docs/adr/
git commit -m "docs(adr): ADR <NNNN> — <title>"
```

---

## Step 8 — Done

> ✅ ADR <NNNN> saved to `docs/adr/<NNNN>-<slug>.md`
> Index updated: `docs/adr/README.md`
>
> Status: **Accepted** — change to `Superseded` or `Deprecated` if this decision is later reversed by running `/adr` again and referencing this one.

**Related skills — apply together:**
- `dev-brainstorm` — the recommended approach from a brainstorm becomes an ADR
- `dev-design` — the design doc links to the ADR for architectural context
- `conventional-commit` — ADR commits use `docs(adr):` prefix
