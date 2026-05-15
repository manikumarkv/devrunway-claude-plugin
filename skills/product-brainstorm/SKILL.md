---
name: product-brainstorm
description: Lead an interactive PM brainstorming session for a feature, requirement, or use case. Explores usability, simplicity, UX, edge cases, and user value from multiple perspectives. Outputs docs/product-brainstorm/<slug>.md. Usage — /product-brainstorm <feature-name> [short description]
argument-hint: "<feature-name> [short description]"
arguments:
  - name: feature
    description: "Feature name or short slug (used for the output filename)"
  - name: description
    description: "Optional one-line description of the idea to start from"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(find *)
  - Bash(ls *)
---

# Product Brainstorm

Parse `$ARGUMENTS[0]` as the feature slug (kebab-case). Parse `$ARGUMENTS[1..n]` as the starting description if provided.

---

## Step 1 — Set the stage

Greet the PM and confirm the topic:

> Starting brainstorm for **<feature>**.
>
> I'll guide you through a structured exploration — usability, user value, UX, scope, and edge cases. Answer as much or as little as you like at each prompt. Type `done` at any point to generate the doc.
>
> First: describe the problem this feature solves and who has it.

Wait for the PM's answer before continuing.

---

## Step 2 — Guided exploration (one theme at a time)

Work through each perspective below sequentially. Ask 1–2 focused questions per theme. Wait for the answer before moving to the next. Do not dump all questions at once.

### Theme 1 — User & problem
- Who specifically is affected? (role, frequency, context)
- What does the user currently do instead? What pain does that cause?

### Theme 2 — User value & success
- What does success look like for the user after this feature exists?
- How would you measure that?

### Theme 3 — Usability & simplicity
- What is the simplest possible version that solves the problem?
- Where might users get confused or make mistakes?

### Theme 4 — UX & interaction
- Is this primarily a flow (multi-step) or a single action?
- Any existing patterns in the product this should be consistent with?

### Theme 5 — Edge cases & constraints
- What are the error or failure states? What happens then?
- Any technical, legal, or business constraints you already know about?

### Theme 6 — Scope boundary
- What is definitely NOT in scope for the first version?
- Is there a phased rollout in mind?

---

## Step 3 — Open questions round

After all themes: ask if there is anything unresolved or uncertain the PM wants to flag explicitly. Record these as open questions.

---

## Step 4 — Synthesise and confirm

Summarise the brainstorm back in 3–5 bullet points:

> Here's what I captured:
> - Problem: …
> - Primary user: …
> - Core value: …
> - Key constraint: …
> - Likely out of scope: …
>
> Does this capture it correctly? Any corrections before I write the doc?

Wait for confirmation or corrections.

---

## Step 5 — Write the output document

Write to `docs/product-brainstorm/<slug>.md`:

```markdown
# Brainstorm: <Feature Name>
_Date: <today> · Status: Draft_

## Problem Statement
<what problem, for whom, in what context>

## User Perspectives

### Who is affected
<role, frequency, context>

### Current workaround and pain
<what they do today and why it is painful>

## User Value & Success
<what success looks like and how to measure it>

## UX & Usability Analysis

### Simplest possible version
<the MVP interaction>

### Where users may struggle
<confusion points, error states>

### Interaction model
<flow vs single action, consistency notes>

## Constraints
<technical, legal, business constraints already known>

## Scope

### In scope (initial version)
- <item>

### Out of scope (explicitly deferred)
- <item> — reason

## Open Questions
| Question | Owner | Status |
|---|---|---|
| <question> | PM | Open |

## Next Step
→ Run `/product-plan <slug>` to define personas, user flows, and stories.
```

---

## Step 6 — Hand off

After writing:

> Brainstorm saved to `docs/product-brainstorm/<slug>.md`.
>
> When you're ready to define personas, user flows, and stories:
> ```
> /product-plan <slug>
> ```
