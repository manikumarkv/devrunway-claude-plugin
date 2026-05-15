---
name: graphql
description: GraphQL standards — schema-first design, resolvers, DataLoader, auth, subscriptions, and codegen. Load when working with GraphQL APIs.
user-invocable: false
stack: api-style/graphql
paths:
  - "**/*.graphql"
  - "**/*.gql"
  - "**/resolvers/**"
  - "**/schema/**"
  - "**/graphql/**"
---

Full standards in [graphql.md](graphql.md). Always-on summary:

**Schema design:**
- Schema-first: define the SDL (`.graphql` file) before writing resolvers
- Use `type`, `input`, `enum`, and `interface` — never return raw JSON scalars for structured data
- Nullable by default; use `!` (non-null) only when the server guarantees the field will always be present
- Pagination: connections pattern (`edges`, `node`, `pageInfo`) for lists; never return plain arrays for paginated data

**Minimal SDL example:**
```graphql
type Query {
  user(id: ID!): User
  users: UserConnection!
}
type User {
  id: ID!
  name: String!
}
```

**Resolvers:**
- Keep resolvers thin — delegate to service/repository layer functions
- Never query the DB directly in a resolver — use service functions that can be tested independently
- Use DataLoader for all parent-to-child relationships to prevent N+1 queries — define a `batchLoadFn` that accepts an array of keys and returns a parallel array of values

**Auth:**
- Authentication: validate the token in the context function — attach `user` to context or throw
- Authorisation: check permissions in the resolver (or a directive) — not in the schema
- Never expose internal IDs directly — use opaque global IDs (Relay spec: `base64("Type:id")`)

**Error handling:**
- Business errors: return them as typed union types in the schema, not as GraphQL errors
- System errors: throw `GraphQLError` with an `extensions.code` — `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`
- Never expose raw stack traces or internal error messages to clients

**Performance:**
- Always use DataLoader — a resolver that fetches per-parent causes N+1 unless batched
- Set `depthLimit` and `complexityLimit` to prevent expensive queries
- Enable `persistedQueries` in production — reduces bandwidth and blocks ad-hoc queries

**Never:**
- Resolve relationships (user → orders) without DataLoader
- Put business logic in the SDL (comments, descriptions are fine)
- Use `__typename` hacks to work around poor schema design

**Related skills:** `api-style/rest` (REST alternative), `state/redux-toolkit` (Apollo/URQL client state)
