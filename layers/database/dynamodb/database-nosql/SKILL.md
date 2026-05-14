---
name: database-nosql
description: NoSQL database standards using DynamoDB + AWS SDK v3 — single-table design, access patterns, GSIs, keys, TTL, what to avoid. Load when writing or reviewing any DynamoDB schema, queries, or repository code.
user-invocable: false
stack: database/dynamodb---

Full standards in [nosql.md](nosql.md). Always-on summary:

**Stack:** AWS DynamoDB + AWS SDK v3 (`@aws-sdk/client-dynamodb` + `@aws-sdk/lib-dynamodb`)

**Design rules:**
- Design access patterns FIRST, schema second
- Single-table design for related entities — one table per service/bounded context
- PK + SK always strings, use prefixes: `USER#<id>`, `POST#<id>`
- GSIs for every access pattern the primary key cannot serve
- TTL for session data, tokens, temp records — never manually delete them

**Query rules:**
- Always `Query` over `Scan` — Scan reads every item in the table
- Always project only needed attributes — `ProjectionExpression`
- Use `BatchGetItem` for multi-key reads, not N individual `GetItem` calls
- Condition expressions on writes to prevent race conditions

**Never:**
- Scan the table in production code
- Use sequential numeric IDs as partition keys (hot partition)
- Store unbounded lists in a single item (DynamoDB 400 KB item limit)
- Mix unrelated domains in one table


**Related skills — apply together:**
- `error-handling` — DynamoDB ConditionalCheckFailed maps to ConflictError
- `typescript-patterns` — type entity interfaces and key builder functions
- `cdk` — DynamoDB table construct, IAM grants, and GSI definitions live in DatabaseStack