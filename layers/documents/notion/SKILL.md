---
name: notion
description: Notion — workspace/teamspace structure, databases, templates, properties, relations, MCP tool usage. Load when reading or writing Notion pages.
user-invocable: false
stack: documents/notion
paths:
  - ".mcp.json"
  - "notion*"
  - ".notion*"
---

Full standards in [notion.md](notion.md). Always-on summary:

**Workspace structure:**
- One teamspace per team — Engineering, Product, Design, Operations
- Top-level databases: `Docs`, `ADRs`, `Runbooks`, `Postmortems`, `RFCs`, `Meeting Notes`
- Free-form pages live under their parent database; not loose in the sidebar

**Databases over pages (always):**
- Anything that benefits from filtering, sorting, or status tracking goes in a database — not as a standalone page
- ADRs, Runbooks, RFCs, Postmortems, Specs, Meeting Notes — all databases
- Standardize properties: `Owner` (person), `Status` (select), `Last reviewed` (date), `Tags` (multi-select)

**Templates (per database):**
- ADR template — Status, Context, Decision, Alternatives, Consequences
- Runbook template — Symptoms, Quick check, Recovery, Escalation
- RFC template — Problem, Proposal, Alternatives, Open questions
- Postmortem template — Timeline, Impact, Root cause, Action items (blameless)
- Meeting Notes template — Attendees, Agenda, Decisions, Action items

**Relations:**
- ADRs relate to the RFC they came from (relation property)
- Postmortems relate to the incident page and the action item issues
- Specs relate to the Jira/Linear issue tracking them

**Status workflows (select property):**
- ADR: `Proposed → Accepted → Superseded → Deprecated`
- RFC: `Draft → Review → Accepted → Implemented`
- Doc: `Draft → Published → Stale` (auto-flag Stale after 6 months no edit)

**MCP usage:**
- Prefer `mcp__notion__*` tools (search, get_page, create_page, update_page, query_database) over manual API calls
- Use page IDs (UUIDs) for relations; not titles — titles change

**Never:**
- Free-form pages where a database exists for that doc type
- Pages without an owner property
- Loose pages in the sidebar (no parent database) — they get lost
- Inline-mention people without also setting the `Owner` property

**Related skills:**
- `project-management/linear` or `project-management/jira` for relation targets
