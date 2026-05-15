# Confluence — Full Standards

## Space organization

One space per product or team. Inside each space, top-level pages by type:

```
<Space>
├── Engineering
│   ├── Architecture
│   ├── Decisions (ADRs)
│   ├── Runbooks
│   └── How-to guides
├── Product
│   ├── Roadmap
│   ├── RFCs
│   └── Specs
└── Operations
    ├── Postmortems
    └── On-call
```

## ADR template

```markdown
# ADR-<n>: <decision>

**Status:** Proposed | Accepted | Superseded by ADR-X | Deprecated
**Date:** <yyyy-mm-dd>
**Owner:** @<person>

## Context

What problem are we solving? What constraints apply?

## Decision

What we are doing, in one paragraph.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| A | ... | ... |
| B | ... | ... |

## Consequences

- Positive:
- Negative:
- Follow-up actions: <link to issues>
```

## Runbook template

```markdown
# Runbook — <symptom or system>

**Severity:** P1 / P2 / P3
**Owner:** @<team>
**Last-reviewed:** <yyyy-mm-dd>

## Symptoms

How an on-caller would recognise this.

## Quick check

```bash
# commands to confirm
```

## Recovery

1. Step 1
2. Step 2

## Escalation

If <X> fails, page @<team>.

## Related

- Postmortems: <links>
- Dashboards: <links>
```

## RFC template

```markdown
# RFC: <title>

**Author:** @<person>  **Reviewers:** @<list>  **Deadline:** <yyyy-mm-dd>

## Problem

## Proposal

## Alternatives

## Open questions

## Decision log

| Date | Decision | Author |
```

## Postmortem template (blameless)

```markdown
# Postmortem — <incident name>

**Incident:** <ticket link>
**Date:** <yyyy-mm-dd>
**Duration:** <start–end>
**Impact:** <users affected, $$$ if known>

## Timeline (UTC)

| Time | Event |

## Root cause

## What went well

## What went poorly

## Action items

| ID | Action | Owner | Due |
| AI-1 | ... | @x | yyyy-mm-dd |
```

## Labels — vocabulary

```
Type:   adr | runbook | rfc | postmortem | how-to | reference | spec
Status: draft | accepted | superseded | deprecated
Domain: frontend | backend | infra | data | security
```

## MCP tools

Prefer:
- `mcp__confluence__search_pages`
- `mcp__confluence__get_page`
- `mcp__confluence__create_page`
- `mcp__confluence__update_page`

## Never

- Plain pages where a template applies
- Pages older than 6 months without a review date update
- Embedded screenshots without alt text
- Duplicate content — link to the canonical page
