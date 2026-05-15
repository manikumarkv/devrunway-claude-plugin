---
name: confluence
description: Confluence — spaces, page hierarchy, templates, labels, page properties, Jira linking, MCP tool usage. Load when reading or writing Confluence docs.
user-invocable: false
stack: documents/confluence
paths:
  - ".mcp.json"
  - "confluence*"
  - ".confluence*"
  - "docs/**/*.confluence.md"
---

Full standards in [confluence.md](confluence.md). Always-on summary:

**Spaces and hierarchy:**
- One space per product or team — not per project
- Top-level pages mirror documentation type: `Engineering`, `Product`, `Runbooks`, `Decisions (ADRs)`
- Max 3 levels of nesting — beyond that, content is lost

**Page conventions:**
- Title: noun phrase, specific — "Checkout v2 — promo code validation" (not "Promo codes")
- Every page declares an owner (page property: `owner`)
- Every page declares a last-reviewed date — pages older than 6 months without review get a stale label

**Templates (mandatory for):**
- ADR (Architecture Decision Record) — context, decision, alternatives, consequences
- Runbook — symptoms, diagnosis, recovery steps, escalation
- RFC — problem, proposal, alternatives, open questions, deadline
- Postmortem — timeline, impact, root cause, action items (blameless)

**Labels:**
- Type: `adr`, `runbook`, `rfc`, `postmortem`, `how-to`, `reference`
- Status: `draft`, `accepted`, `superseded`, `deprecated`
- Domain: `frontend`, `backend`, `infra`, `data`

**Jira/ticket linking:**
- Embed Jira issue macros for inline ticket references
- ADRs link to the originating RFC and to the issues they unblock
- Every Postmortem links to the incident ticket and any follow-up issues

**MCP usage:**
- Prefer `mcp__confluence__*` tools (search_pages, create_page, update_page, get_page) over manual REST API calls
- Cache page IDs locally when traversing a tree; never refetch in a loop

**Never:**
- Free-form pages without a template where a template exists
- Orphan pages (no parent in the space tree)
- Duplicate content — link instead of copy
- Plain `<dates>` in prose — use the Confluence date macro so they render consistently

**Related skills:**
- `project-management/jira` for issue linking conventions
