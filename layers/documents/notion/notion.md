# Notion — Full Standards

## Workspace and teamspace structure

```
<Workspace>
├── Engineering (teamspace)
│   ├── 📊 ADRs (database)
│   ├── 📊 Runbooks (database)
│   ├── 📊 RFCs (database)
│   ├── 📊 Postmortems (database)
│   └── 📊 Meeting Notes (database)
├── Product (teamspace)
│   ├── 📊 Specs (database)
│   ├── 📊 Roadmap (database)
│   └── Free-form pages
└── Operations (teamspace)
    └── 📊 Runbooks (database)
```

Databases over loose pages. Loose pages get lost; database entries get filtered, sorted, and tagged.

## Standard database properties

Every documentation database has at minimum:

| Property | Type | Notes |
|---|---|---|
| Title | Title | Page title (built-in) |
| Owner | Person | Required |
| Status | Select | Per-database vocabulary |
| Last reviewed | Date | Set when content is verified |
| Tags | Multi-select | Domain tags |
| Related | Relation | To other databases (issues, ADRs) |

## ADR template

```
# ADR-<n>: <decision>

**Status:** Proposed | Accepted | Superseded | Deprecated
**Date:** <yyyy-mm-dd>
**Owner:** @<person>

## Context

What problem are we solving?

## Decision

What we're doing.

## Alternatives

| Option | Pros | Cons |

## Consequences

- Positive:
- Negative:
- Follow-ups: (Relation → Issues)
```

## Runbook template

```
# Runbook — <symptom>

**Severity:** P1 / P2 / P3
**Owner:** @<team>

## Symptoms

## Quick check

```bash
```

## Recovery

1.
2.

## Escalation
```

## RFC template

```
# RFC: <title>

**Author:** @<person>
**Reviewers:** @<list>
**Deadline:** <yyyy-mm-dd>
**Status:** Draft | Review | Accepted | Implemented

## Problem

## Proposal

## Alternatives

## Open questions
```

## Postmortem template (blameless)

```
# Postmortem — <incident>

**Incident:** (Relation → Incident page)
**Date:** <yyyy-mm-dd>
**Duration:** <start–end>
**Impact:**

## Timeline (UTC)

| Time | Event |

## Root cause

## Action items (Relation → Issues database)
```

## Relations — use them

Relations are Notion's superpower. Use them:

- ADR.Supersedes → ADR
- Postmortem.Action items → Issues
- Spec.Issue → Linear/Jira (via mirrored database)
- Meeting notes.Decisions → ADRs

Never duplicate content — link via relation instead.

## Status workflows

```
ADR:         Proposed → Accepted → Superseded → Deprecated
RFC:         Draft → Review → Accepted → Implemented
Doc:         Draft → Published → Stale
Spec:        Backlog → In design → Approved → In dev → Shipped
Runbook:     Draft → Active → Deprecated
Postmortem:  Draft → Published
```

## MCP tools

Prefer:
- `mcp__notion__search`
- `mcp__notion__get_page`
- `mcp__notion__create_page`
- `mcp__notion__update_page`
- `mcp__notion__query_database`

Pass page IDs (UUIDs), not titles — titles can change without warning.

## Never

- Loose pages in the sidebar where a database fits
- Pages without an `Owner` property
- Inline links where a relation property is appropriate
- Pasting screenshots without alt text
- Copying content across pages — relate, don't duplicate
