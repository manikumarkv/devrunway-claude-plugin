---
name: mongodb
description: MongoDB conventions — schema design, indexes, connection pooling, aggregation pipeline, and Mongoose patterns. Load when working with MongoDB or Mongoose.
user-invocable: false
stack: database/mongodb
paths:
  - "**/models/**"
  - "**/*.model.ts"
  - "**/*.model.js"
  - "**/schemas/**"
  - "mongoose.config.*"
---

Full standards in [mongodb.md](mongodb.md). Always-on summary:

**Schema design:**
- Embed documents when they are always accessed together and the embedded array is bounded (< a few hundred items)
- Reference (store `_id`) when documents are large, frequently updated independently, or shared across collections
- Use `ObjectId` references for relationships — not string copies of data

**Indexes — required:**
- Every field you query on `find()`, `findOne()`, or in a `$match` stage must have an index — define with `createIndex({ email: 1 })`
- Compound indexes: field order matters — put equality fields before range fields
- `explain('executionStats')` to verify index usage before shipping a query

**Connection:**
- One `MongoClient` instance per application — never create per-request
- Set `maxPoolSize` to match your workload (default 5 — often too low for APIs)
- Always handle `'error'` and `'disconnected'` events

**Operations:**
- `findOne(` instead of chaining find + limit — it stops at the first match and uses the index correctly
- Always project only the fields you need: `find({}, { name: 1, email: 1 })`
- Use `session` for multi-document transactions — operations outside a session are not atomic

**Array updates:**
- Cap arrays on growth: `{ $push: { recentActivity: { $each: [event], $slice: -50 } } }` — prevents unbounded array growth

**Never:**
- Store arrays without a size limit (unbounded arrays grow documents and break indexes)
- Run `find({})` (full collection scan) in a production API route
- Skip `lean()` in Mongoose when you don't need Mongoose document methods (returns plain objects — faster)

**Related skills:** `data-governance` (PII tagging in schema), `api-conventions` (cursor pagination with `_id`)
