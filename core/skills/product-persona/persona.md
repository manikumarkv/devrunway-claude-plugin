# Product Persona & Requirements Standards

---

## Persona template

Create one persona per distinct user type. Personas are referenced by name in user stories.

```markdown
## Persona: [Name]

**Role:** [Job title or user type]
**Age range:** [Optional — only if relevant to UX decisions]

### Goals
- [Primary goal — what they're trying to accomplish]
- [Secondary goal]
- [Tertiary goal]

### Pain points
- [Frustration with the current situation]
- [Time sink or manual workaround they rely on]
- [Fear or risk they're trying to avoid]

### Context
- **Tech comfort:** [Low / Medium / High]
- **Device:** [Desktop / Mobile / Both]
- **Frequency:** [Daily / Weekly / Occasional]
- **Environment:** [Office / Field / Remote / On the go]

### Quote
> "[A sentence in their voice that captures their frustration or need]"
```

**Example:**

```markdown
## Persona: Marcus

**Role:** Operations Manager at a mid-size logistics company

### Goals
- Track all open orders without switching between three spreadsheets
- Catch delayed shipments before customers notice
- Give his team a single place to update order status

### Pain points
- Manually reconciles shipping data from email attachments every morning
- Gets blindsided by delays because drivers update status in a different system
- Spends 30 min/day on status calls that could be self-serve

### Context
- **Tech comfort:** Medium — comfortable with software, not with APIs or CLIs
- **Device:** Desktop in office, mobile in warehouse
- **Frequency:** Daily, multiple times
- **Environment:** Loud warehouse floor + office desk

### Quote
> "I shouldn't need three browser tabs and a spreadsheet to know where one order is."
```

---

## User story format

```
As a [persona name],
I want to [specific action],
so that [concrete outcome or value].
```

**Rules:**
- Use the persona's name, not a generic role ("As Marcus", not "As an operations manager")
- The action is specific — not "manage orders" but "see all open orders with their current status on one screen"
- The outcome is measurable — "so that I don't have to open a spreadsheet to answer a customer question"

**Examples:**

```
As Marcus,
I want to see all open orders filtered by status (pending/in-transit/delayed),
so that I can spot delays without opening each order individually.

As Marcus,
I want to receive a push notification when an order status changes to "delayed",
so that I can proactively contact the customer before they call me.
```

---

## Acceptance criteria (Gherkin)

Each story must have 2–5 acceptance criteria written in Gherkin format.

```
Given [precondition or system state]
When [user action]
Then [expected observable result]
```

**Example for the filter story:**

```
Given I am logged in as a user with the Operations role
When I open the Orders page
Then I see a list of all open orders sorted by created date descending

Given I am on the Orders page
When I click the "Delayed" filter chip
Then only orders with status "delayed" are shown
And the count badge updates to reflect the filtered total

Given there are no delayed orders
When I click the "Delayed" filter chip
Then I see the empty state message "No delayed orders — you're all caught up."
```

---

## Definition of done

Every story is done when ALL of the following are true:

**Functionality**
- [ ] All acceptance criteria pass
- [ ] Demo-able to the requester
- [ ] Works on mobile and desktop (if applicable)

**Quality**
- [ ] Unit tests written, coverage ≥ 80%
- [ ] No TypeScript errors (`tsc --noEmit`)
- [ ] No lint errors (`eslint .`)
- [ ] No `console.log` statements

**Accessibility**
- [ ] Keyboard navigable (tab order, focus visible)
- [ ] Screen reader tested (VoiceOver or NVDA)
- [ ] Color contrast passes WCAG AA (4.5:1 for text)

**Review**
- [ ] PR reviewed and approved
- [ ] No unresolved PR comments
- [ ] Merged to `develop`
- [ ] Deployed to staging and smoke-tested

---

## Story sizing

Use T-shirt sizes. If a story is larger than L, split it.

| Size | Effort | Criteria |
|---|---|---|
| XS | < 1 hour | Single field, copy change, config tweak |
| S | Half day | Single component, single endpoint |
| M | 1–2 days | Feature with UI + API + tests |
| L | 3–4 days | Multi-step flow, complex state, auth |
| XL | > 4 days | Split this story |

---

## Requirements document structure

For features larger than S, write a short requirements doc before implementation:

```markdown
# [Feature Name]

## Problem
One paragraph: who has this problem, what they can't do today, what it costs them.

## Personas affected
- [Persona name] — [how they're affected]

## User stories
1. As [persona]... (highest value first)
2. As [persona]...

## Out of scope
- [Explicitly list what this feature does NOT include]

## Open questions
- [ ] [Question that blocks implementation — owner, due date]

## Dependencies
- [API endpoint] — [team/person responsible]
- [Design mockup] — [link]
```
