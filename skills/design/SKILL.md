---
name: design
description: Generate a tech design document for a feature before implementation. Usage — /design <feature-name> [brief description]
argument-hint: <feature-name> [brief description of what it does]
arguments:
  - name: feature-name
    description: "kebab-case feature name, e.g. order-tracking, payment-methods"
  - name: description
    description: "One-line description of what this feature does (optional)"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(git *)
  - Bash(gh *)
  - Bash(find *)
  - Bash(ls *)
---

# Tech Design

Generate a structured tech design document for a feature before any code is written.
Design first prevents rework. The doc is the contract between planning and implementation.

Parse `$ARGUMENTS`:
- `featureName` = first arg (kebab-case)
- `description` = remaining args joined (optional context)

Before writing the doc:
1. Search the codebase for related existing patterns — check `src/features/`, `src/controllers/`, `prisma/schema.prisma`, `infra/` — fill in what already exists rather than leaving every field blank.
2. Read `prisma/schema.prisma` if it exists to understand the current data model.
3. Read `src/routes/index.ts` if it exists to understand existing API structure.

Write the design doc to `docs/design/<feature-name>.md`. Create the `docs/design/` directory if it doesn't exist.

---

## Document template

```markdown
# Tech Design: <Feature Name>

**Status:** Draft  
**Author:** [fill in]  
**Created:** <today's date>  
**Ticket:** [link or number]

---

## Problem

<!-- One paragraph: what user pain does this solve, who has it, what they do today without this feature -->

---

## Personas affected

<!-- Which personas from docs/personas.md (or product context) this touches -->
- **[Persona name]** — [how they benefit or are affected]

---

## User stories

<!-- Highest value first. Format: As [persona], I want to [action], so that [outcome] -->
1. As [persona], I want to [action], so that [outcome].
2. As [persona], I want to [action], so that [outcome].

---

## Out of scope

<!-- Explicitly list what this feature does NOT cover in this iteration -->
-
-

---

## API design

<!-- Follow api-conventions: /api/v1/ prefix, plural nouns, cursor pagination, consistent envelope -->

### Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/v1/<kebabNames>` | required | List with cursor pagination |
| `POST` | `/api/v1/<kebabNames>` | required | Create |
| `GET` | `/api/v1/<kebabNames>/:id` | required | Get by ID |
| `PATCH` | `/api/v1/<kebabNames>/:id` | required | Partial update |
| `DELETE` | `/api/v1/<kebabNames>/:id` | required | Soft delete |

### Request schemas (Zod)

```ts
// Create
const create<PascalName>Schema = z.object({
  // TODO: define fields
})

// Update (partial)
const update<PascalName>Schema = create<PascalName>Schema.partial()
```

### Response shapes

```ts
// Single resource
{ success: true, data: <PascalName> }

// List
{ success: true, data: <PascalName>[], meta: { nextCursor: string | null, total: number } }
```

### Error cases

| Scenario | Status | Code |
|---|---|---|
| Resource not found | 404 | `NOT_FOUND` |
| Not the owner | 403 | `FORBIDDEN` |
| Validation failure | 400 | `VALIDATION_ERROR` |
| [Business rule] | 422 | `UNPROCESSABLE` |

---

## Database design

### SQL (Prisma) — use if data is relational

```prisma
model <PascalName> {
  id        String    @id @default(uuid())
  userId    String
  // TODO: domain fields

  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  deletedAt DateTime?

  user      User      @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@map("<kebabNames>")
}
```

**Indexes needed:**
- `userId` — for "list by user" access pattern (auto-added above)
- [any other high-frequency query fields]

**Migration:**
```bash
npx prisma migrate dev --name add-<kebabName>
```

### NoSQL (DynamoDB) — use if data is document-oriented or access-pattern-driven

**Access patterns:**
1. Get [entity] by ID → `pk = <ENTITY>#<id>`, `sk = METADATA`
2. List [entities] by user → `gsi1pk = USER#<userId>`, `gsi1sk = <ENTITY>#<createdAt>`

```
pk              sk               gsi1pk              gsi1sk
<ENTITY>#<id>   METADATA         USER#<userId>        <ENTITY>#<createdAt>
```

---

## Frontend architecture

### Feature structure

```
src/features/<kebabName>/
  types.ts                  ← <PascalName>, Create<PascalName>Input
  api/<kebabName>.api.ts    ← use<PascalNames>, useCreate<PascalName>, ...
  components/
    <PascalName>List/       ← infinite scroll, 4 states
    <PascalName>Form/       ← create/edit, field-level server errors
  index.ts
```

### State management

<!-- Where does state live? React Query for server state, Zustand only for true global UI state -->
- Server state: React Query (`use<PascalNames>`, `useCreate<PascalName>`)
- Local form state: react-hook-form + Zod
- Global UI state: [none / describe if needed]

### Key components

| Component | Responsibility |
|---|---|
| `<PascalName>List` | Infinite scroll list with loading/empty/error states |
| `<PascalName>Form` | Create form with validation, field-level server errors |
| [Others as needed] | |

---

## Infra changes

<!-- Only fill this in if new infrastructure is needed -->

- [ ] New DynamoDB table → add construct to `DatabaseStack`
- [ ] New Lambda IAM grant → `table.grantReadWriteData(fn)`
- [ ] New API Gateway routes → add to `ApiStack`
- [ ] New S3 bucket or SSM parameter
- [ ] CloudWatch alarm for this feature's error rate

---

## Security considerations

<!-- Work through the security checklist for this feature -->

- **Auth:** all endpoints behind `requireAuth` ✓
- **Authorization:** `requireGroup` needed? [yes/no — which groups]
- **Ownership:** service layer checks `resource.userId === user.sub` on every read/write
- **Input validation:** Zod schemas on body, params, query
- **Sensitive data:** [any PII or secrets stored? how handled]
- **Rate limiting:** auth routes (5/15min), API routes (100/min) ✓

---

## Open questions

<!-- Decisions that must be made before implementation starts. Add owner and due date. -->

- [ ] [Question] — owner: [name], needed by: [date]
- [ ] [Question] — owner: [name], needed by: [date]

---

## Dependencies

<!-- External blockers: other features, API contracts from other teams, design mockups -->

- [ ] [Dependency] — [team/person responsible] — [status]

---

## Implementation plan

<!-- Ordered task list. Each task should be small enough to complete in one session. -->

### Phase 1 — Backend
- [ ] Add Prisma model + migration
- [ ] Zod schemas in `src/types/<kebabName>.types.ts`
- [ ] Repository: `findMany`, `findById`, `create`, `update`, `softDelete`
- [ ] Service: business logic, ownership checks, error throwing
- [ ] Controller: route handler with asyncHandler + response helpers
- [ ] Register router in `src/routes/index.ts`
- [ ] Bruno collection stubs

### Phase 2 — Frontend
- [ ] TypeScript interfaces in `src/features/<kebabName>/types.ts`
- [ ] React Query hooks in `api/<kebabName>.api.ts`
- [ ] `<PascalName>List` component + tests (4 states)
- [ ] `<PascalName>Form` component + tests
- [ ] Wire into page component with error boundary

### Phase 3 — Integration
- [ ] Fill in Bruno request bodies, verify all 5 requests pass
- [ ] E2E Playwright spec for critical user journey
- [ ] CDK infra changes (if any) + `cdk diff` review

---

## Acceptance criteria

<!-- Gherkin format — these become your test cases -->

```
Given [precondition]
When [action]
Then [expected result]
```
```

---

After writing the file, print:

```
✅ Design doc created: docs/design/<feature-name>.md

Fill in before starting implementation:
  □ Problem statement
  □ User stories
  □ API request/response schemas (Zod fields)
  □ Database model fields
  □ Open questions with owners
  □ Acceptance criteria

Then run: /scaffold <feature-name> fullstack
```
