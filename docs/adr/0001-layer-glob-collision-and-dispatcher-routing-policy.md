# ADR 0001: Layer Glob Collision and Dispatcher Routing Policy

**Date:** 2026-09-03
**Status:** Accepted
**Author:** Mani
**Related:** PR [#1](https://github.com/manikumarkv/devrunway-claude-plugin/pull/1) · blocks `layers/storage/neon-object-storage` and `layers/auth/neon-auth`

---

## Context

`stack-dispatcher` selects which layer standards load by matching each layer's `paths:` globs against the files being edited, then taking **at most five**, ranked by glob specificity. It does not read `stack.json` at runtime; `CLAUDE.md` states that file is install-time only.

That design was sound when layers were installed per project, because a layer's presence on disk meant the project had opted into it. The plugin now **bundles all 135 layers**, so on-disk presence is uniform and carries no information about what a project actually uses. The entire relevance judgement therefore rests on globs — and a glob can express *"is this the kind of file this layer discusses?"* but not *"does this project use this technology?"*

Two distinct failure modes follow. They are often conflated and require different fixes.

**1. Crowding.** The cap is not an occasional constraint, it binds on every dispatch. Measured against the current tree:

| File | Layers matching | Slots |
|---|---|---|
| `src/db/user.repository.ts` | 20 | 5 |
| `infra/stack.ts` | 20 | 5 |
| `src/api/upload.ts` | 19 | 5 |
| `src/auth/session.ts` | 19 | 5 |
| `src/services/order.service.ts` | 19 | 5 |
| `src/components/LoginForm.tsx` | 15 | 5 |

Roughly 70–75% of matching layers are discarded every time. The cause is catch-all globs: **25 of 131 routable layers** claim one, with 16 claiming `**/*.ts` and 13 claiming `**/*.tsx`. A Vault layer and an Ant Design layer bid for a slot on an upload handler purely because the file ends in `.ts`.

**2. Contradiction.** Mutually exclusive technologies within one category match the same globs. `**/upload*` is claimed by `cloudinary`, `s3-storage` and `auth/cognito/security`; `**/auth/**` by `auth0`, `azure-ad` and `cognito/security-standards`. When two load together the model receives conflicting rules — on presigned URLs, on key handling, on token verification — with nothing to arbitrate. Crowding wastes slots; contradiction actively produces wrong guidance.

This blocks `neon-object-storage` and `neon-auth`, whose natural globs are already owned by competitors.

## Decision

A two-part policy.

**Vendor-scoped globs, plus a scope statement.** Layers for a technology that competes with a sibling in the same category claim vendor-specific globs (`**/neon-storage*`, `**/buckets/**`) rather than generic ones, and open their `SKILL.md` with an explicit scope line naming the technology they apply to. Applied to the Neon layers now.

**Catch-all globs are not permitted.** `CONTRIBUTING.md` gains a rule prohibiting `**/*.ts`-class patterns, and the 25 existing offenders are narrowed to directory- or filename-scoped patterns.

An exclusivity mechanism (mutually exclusive category groups, or runtime stack awareness) is recorded as the accepted long-term direction and **deliberately deferred** — see Revisit Triggers.

## Alternatives Considered

### Option A: Vendor-scoped globs and a catch-all ban _(chosen)_
Unblocks the Neon layers immediately, needs no dispatcher change, and directly reduces cap pressure on every dispatch. Accepts that contradiction is mitigated rather than solved.

### Option B: Dispatcher reads `stack.json` at runtime _(rejected, for now)_
The only option that genuinely solves contradiction: filter competing layers by the project's declared stack. Rejected now because it reverses an explicitly documented design principle, and because a missing or stale `stack.json` leaves no defined behaviour. Reversing a stated principle deserves its own decision rather than being smuggled in to unblock two layers.

### Option C: Exclusivity groups in frontmatter _(rejected, for now)_
A `exclusive-group: storage` field capping the dispatcher to one layer per group. Cleanest model and needs no `stack.json`. Rejected now because it has an unsolved core question: when three storage layers match and nothing declares which the project uses, the tie-break is arbitrary — it converts a contradiction into a coin flip. It becomes viable combined with Option B, which supplies the missing signal.

### Option D: Raise the five-layer cap _(rejected)_
Treats the symptom. Each additional layer costs a consultant sub-agent and context budget, and raising the cap admits *more* irrelevant layers rather than displacing them with relevant ones.

## Consequences

### Positive
- `neon-object-storage` and `neon-auth` are unblocked without an architecture change.
- Narrowing catch-all globs benefits every dispatch, not only the Neon case — the specific layer for a file stops competing with a dozen generic ones.
- The scope line makes a layer's applicability legible to a reader even when routing gets it wrong.
- `CONTRIBUTING.md` gains an enforceable rule, so new layers do not reintroduce the problem.

### Negative / Trade-offs
- **Contradiction is mitigated, not solved.** Vendor-scoped globs work when filenames carry the vendor name. A project storing Neon uploads in `src/api/upload.ts` gets no Neon routing at all — the layer silently does not load, which is a false negative traded for a false positive.
- Auditing 25 layers is real work, and narrowing a glob risks a layer no longer matching files it legitimately covers.
- Knowingly incurred debt: two mechanisms (globs, and eventually exclusivity) will govern the same concern until the deferred work lands.

### Risks
- Over-narrowing produces silent non-loading, the same failure class as the `-maxdepth` bug — invisible, with no error. The `Unroutable` line added to the dispatch result gives partial coverage; it does not report a layer that was correctly parsed but never matched.
- Contributors may treat the vendor-glob convention as sufficient and stop noticing genuine contradictions.

## Revisit Triggers

This ADR should be revisited if:
- A second category develops three or more competing layers where filenames do not carry the vendor name.
- Any report of contradictory rules reaching generated code — this is the signal that mitigation has failed and Option B or C is required.
- The catch-all audit reduces typical match counts below the five-layer cap, at which point crowding is solved and the remaining case for exclusivity is purely about contradiction.
- The bundling model changes so that layers are installed per project again, which would restore on-disk presence as a stack signal and make Option B unnecessary.
