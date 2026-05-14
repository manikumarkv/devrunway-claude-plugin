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
find src/ -type f -name "*.ts" -not -path "*/node_modules/*" | head -40
ls prisma/ 2>/dev/null
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
```ts
// POST /api/v1/<resource>
// Request body (Zod schema)
const Create<Resource>Schema = z.object({
  field: z.string().min(1),
})

// Response
{ success: true, data: <Resource> }
```

### Error cases
| Condition | Status | Code |
|---|---|---|
| Not found | 404 | NOT_FOUND |
| Not owner | 403 | FORBIDDEN |
| Invalid input | 400 | VALIDATION_ERROR |

## Database

### Prisma model
```prisma
model <Resource> {
  id        String   @id @default(cuid())
  userId    String
  field     String
  deletedAt DateTime?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  user User @relation(fields: [userId], references: [id])
}
```

## Frontend Components

| Component | Path | Purpose |
|---|---|---|
| <Resource>List | src/features/<resource>/components/<Resource>List/ | Displays paginated list |
| <Resource>Form | src/features/<resource>/components/<Resource>Form/ | Create / edit form |

## Implementation Plan

> ⚠️ /dev-code executes these steps one at a time with user confirmation between each.

### Phase 1: Database
**Step 1.1** — Add Prisma model to `prisma/schema.prisma`
_Fields: id, userId, <fields>, deletedAt, createdAt, updatedAt_

**Step 1.2** — Run migration
```bash
npx prisma migrate dev --name add-<resource>
npx prisma generate
```

### Phase 2: Backend types
**Step 2.1** — Create `src/types/<resource>.types.ts`
_Zod schemas: Create<Resource>Schema, Update<Resource>Schema, <Resource>Response_

### Phase 3: Repository
**Step 3.1** — Create `src/repositories/<resource>.repository.ts`
_Methods: findById, findByUserId (cursor pagination), create, update, softDelete_

### Phase 4: Service
**Step 4.1** — Create `src/services/<resource>.service.ts`
_Ownership check on every mutating method. Throw ForbiddenError if userId !== user.sub_

### Phase 5: Controller & routes
**Step 5.1** — Create `src/controllers/<resource>.controller.ts`
_asyncHandler on all handlers. Use ok(), created(), paginated() helpers._

**Step 5.2** — Register routes in `src/app.ts`
_All routes behind requireAuth(). PATCH/DELETE behind ownership (done in service)._

### Phase 6: Unit tests
**Step 6.1** — `src/repositories/<resource>.repository.test.ts`
_Test: findById returns null for unknown id, findByUserId returns correct page, create inserts row, softDelete sets deletedAt_

**Step 6.2** — `src/services/<resource>.service.test.ts`
_Test: throws ForbiddenError when userId mismatch, happy path for each method_

**Step 6.3** — `src/controllers/<resource>.controller.test.ts`
_Test: 401 when unauthenticated, 400 on invalid body, 201 on create, 200 on list_

### Phase 7: Frontend types & API hooks
**Step 7.1** — Create `src/features/<resource>/types.ts`
_Types: <Resource>, Create<Resource>Input, Update<Resource>Input_

**Step 7.2** — Create `src/features/<resource>/api/<resource>.api.ts`
_Hooks: useInfiniteQuery for list, useMutation for create/update/delete_

### Phase 8: Frontend components
**Step 8.1** — Create `src/features/<resource>/components/<Resource>List/`
_4 states: loading skeleton, empty state, error state, populated list with infinite scroll_

**Step 8.2** — Create `src/features/<resource>/components/<Resource>Form/`
_react-hook-form + zodResolver. setError for server-side field errors._

**Step 8.3** — Create `src/features/<resource>/index.ts`
_Barrel export_

### Phase 9: Screen / page
**Step 9.1** — Create or update the route/page component that hosts these components

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
