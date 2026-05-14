---
name: dev-design
description: Create a detailed phased implementation plan for a GitHub issue. Each phase has explicit numbered steps that /dev-code will execute sequentially. Outputs docs/dev-tech-designs/<ticket>-design.md. Usage — /dev-design <issue-number> [or brainstorm doc path]
argument-hint: "<issue-number> [or docs/dev-brainstorm/<ticket>.md]"
arguments:
  - name: input
    description: "GitHub issue number, or path to a dev-brainstorm doc"
user-invocable: true
effort: high
allowed-tools:
  - Read
  - Write
  - Bash(find *)
  - Bash(ls *)
  - Bash(grep *)
  - Bash(gh *)
  - mcp__git__get_issue
---

# Dev Design

Parse `$ARGUMENTS[0]` as either a GitHub issue number or a brainstorm doc path.

---

## Step 1 — Load all context

> **MCP preferred:** When the `github` MCP is active, use `mcp__git__get_issue` instead of `gh issue view`. Fall back to `gh` CLI if MCP unavailable.

```bash
# If issue number given (gh CLI fallback)
gh issue view <number> --json title,body,milestone,labels,comments

# Brainstorm doc
find docs/dev-brainstorm/ -name "<number>.md" | head -1

# Refined requirements doc
find docs/product-tasks/ -name "<number>-refined.md" | head -1

# Understand existing code structure
find src/ -type f | grep -v node_modules | head -40
```

Read every relevant doc before writing a single line of the plan. The design must reflect the **recommended approach** from the brainstorm doc if one exists.

---

## Step 2 — Confirm scope

ultrathink

Summarise what will be built and ask for confirmation before writing the plan:

> **Scope for #<number>: <title>**
>
> What I'm planning to design:
> - Backend: <list key pieces>
> - Frontend: <list key pieces>
> - DB: <schema changes>
> - Tests: <what will be tested>
>
> Approach: <from brainstorm or fresh analysis>
>
> Confirm scope before I write the plan?

Wait for confirmation. If the scope is wrong, discuss until aligned.

---

## Step 3 — Write the design document

ultrathink

Write to `docs/dev-tech-designs/<issue-number>-design.md`.

**Critical:** Each step in the plan must be concrete enough that `/dev-code` can execute it without ambiguity. Include actual field names, type signatures, route paths, and component names — not placeholders.

```markdown
# Tech Design: #<number> <title>
_Date: <today>_
_Source: docs/dev-brainstorm/<number>.md_

## Scope
<What is being built in this design. What is NOT in scope.>

## Architecture Overview
<How the pieces fit together — data flow from FE to BE to DB>

## API Design

### Endpoints
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | /api/v1/<resource> | Required | List with cursor pagination |
| POST | /api/v1/<resource> | Required | Create |
| PATCH | /api/v1/<resource>/:id | Required | Update (owner only) |
| DELETE | /api/v1/<resource>/:id | Required | Soft delete (owner only) |

### Request / Response shapes

```
POST /api/v1/<resource>
Request fields: <field>: <type>, <field>: <type>
Validation: <field> required and non-empty, <field> must be positive integer, ...
Response: { success: true, data: <Resource> }
```

### Error cases
| Condition | Status | Code |
|---|---|---|
| Not found | 404 | NOT_FOUND |
| Not owner | 403 | FORBIDDEN |
| Invalid input | 400 | VALIDATION_ERROR |

## Data Model

```
Entity: <Resource>
Fields:
  id          — unique identifier (auto-generated)
  ownerId     — reference to the User who owns this
  <field>     — <type>, required
  <field>     — <type>, optional
  deletedAt   — soft-delete timestamp, nullable
  createdAt   — auto-set on insert
  updatedAt   — auto-updated on write

Relations:
  belongs to User (via ownerId)
```

_(Use your database layer's schema syntax to implement this model)_

## UI Components Needed

| Component | Purpose |
|---|---|
| `<Resource>List` | Displays paginated list — handles loading, empty, error, and data states |
| `<Resource>Form` | Create / edit form — handles validation and server error display |

## Implementation Plan

> ⚠️ /dev-code executes these steps one at a time with user confirmation between each.

### Phase 1: Data model
**Step 1.1** — Define the schema for `<Resource>` using your database layer's conventions
_Fields: id, ownerId, <fields>, deletedAt, createdAt, updatedAt_

**Step 1.2** — Run migration / schema sync using your database layer's tooling
_Confirm required environment variables (connection string, etc.) are set first_

### Phase 2: Validation schemas / types
**Step 2.1** — Define input schemas for Create<Resource> and Update<Resource>
_Use your validation layer (Zod, Pydantic, etc.) — schemas are the source of truth for types_

### Phase 3: Data access layer
**Step 3.1** — Create the repository / data access module for `<Resource>`
_Methods: findById, findByOwner (with pagination), create, update, softDelete_

### Phase 4: Service layer
**Step 4.1** — Create the service for `<Resource>` business logic
_Ownership check on every mutating method — throw a permission error if ownerId ≠ caller's ID_

### Phase 5: Entry point (controller / handler / route)
**Step 5.1** — Create the controller/handler for `<Resource>`
_Validate all inputs using Step 2 schemas; call service; return standard response envelope_

**Step 5.2** — Register routes / endpoints
_All routes require authentication; mutation routes require ownership (enforced in service)_

### Phase 6: Unit tests
**Step 6.1** — Repository tests
_Test: returns null for unknown id, returns correct page, creates record, soft-deletes correctly_

**Step 6.2** — Service tests
_Test: throws permission error when owner mismatch, happy path for each method_

**Step 6.3** — Controller/handler tests
_Test: 401 when unauthenticated, 400 on invalid input, 201 on create, 200 on list_

### Phase 7: Frontend data layer (if applicable)
**Step 7.1** — Define frontend types for `<Resource>`
_Mirror the API response shape; use your validation layer to infer types if available_

**Step 7.2** — Create data-fetching hooks / queries for `<Resource>`
_List (with pagination), create mutation, update mutation, delete mutation_

### Phase 8: Frontend components (if applicable)
**Step 8.1** — Create `<Resource>List` component
_4 states: loading skeleton, empty state, error state, populated list_

**Step 8.2** — Create `<Resource>Form` component
_Validation on submit; display server-side field errors alongside client-side errors_

**Step 8.3** — Export barrel

### Phase 9: Screen / page
**Step 9.1** — Create or update the route/page/view that hosts these components

### Phase 10: Playwright E2E tests
**Step 10.1** — Create `e2e/<resource>.spec.ts`
_Happy path: create, view list, update, delete. Auth required: unauthenticated redirect._

### Phase 11: Logging
**Step 11.1** — Verify Pino logger is called at service layer for create, update, delete
_Log: userId, resourceId, action. Never log PII or full request bodies._

## Open Questions
| Question | Answer |
|---|---|

## Next Step
→ Run `/dev-code <issue-number>` to execute this plan step by step.
```

---

## Step 4 — Hand off

> Design saved to `docs/dev-tech-designs/<issue-number>-design.md`.
>
> The plan has <N> phases and <M> steps. Ready to start building?
> ```
> /dev-code <issue-number>
> ```
