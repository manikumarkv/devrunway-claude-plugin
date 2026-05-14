# NoSQL Database Standards (DynamoDB + AWS SDK v3)

---

## Design access patterns first

DynamoDB schema flows from access patterns — unlike SQL you cannot query arbitrary columns. Define every access pattern before designing keys.

```
Access patterns for a blog app:
1. Get user by ID
2. Get user by email
3. Get all posts by user (sorted by date)
4. Get single post by ID
5. Get all comments on a post (sorted by date)
6. Get all posts (global feed, sorted by date)
```

Then design PK/SK and GSIs to serve each pattern.

---

## Single-table design

Put all related entities in one table. Use prefixed composite keys to separate entity types.

```
Table: my-app-prod

PK              SK                  Entity
USER#u1         #METADATA           User item
USER#u1         POST#p1             User's post
USER#u1         POST#p2             User's post
POST#p1         #METADATA           Post item
POST#p1         COMMENT#c1          Comment on post
POST#p1         COMMENT#c2          Comment on post

GSI1PK          GSI1SK
EMAIL#a@b.com   USER#u1             → lookup user by email
FEED            2026-01-15T10:00Z   → global feed sorted by date
```

---

## AWS SDK v3 setup

```ts
// src/lib/dynamodb.ts
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb'

const client = new DynamoDBClient({
  region: process.env.AWS_REGION ?? 'us-east-1',
})

// DocumentClient handles marshalling/unmarshalling automatically
export const dynamo = DynamoDBDocumentClient.from(client, {
  marshallOptions: {
    removeUndefinedValues: true,  // don't store undefined as NULL
    convertEmptyValues: false,
  },
})

export const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME!
```

---

## Key design patterns

### Prefix every key — never use bare IDs

```ts
// ❌ — bare IDs collide across entity types
PK = 'abc123'   SK = 'metadata'

// ✅ — prefixed keys are self-describing and never collide
PK = 'USER#abc123'   SK = '#METADATA'
PK = 'POST#xyz789'   SK = '#METADATA'
PK = 'USER#abc123'   SK = 'POST#xyz789'  // user owns post (1:N)
```

### Helper functions for key construction

```ts
const keys = {
  user: (id: string) => ({ PK: `USER#${id}`, SK: '#METADATA' }),
  userPost: (userId: string, postId: string) => ({ PK: `USER#${userId}`, SK: `POST#${postId}` }),
  post: (id: string) => ({ PK: `POST#${id}`, SK: '#METADATA' }),
  postComment: (postId: string, commentId: string) => ({ PK: `POST#${postId}`, SK: `COMMENT#${commentId}` }),
  emailIndex: (email: string) => ({ GSI1PK: `EMAIL#${email.toLowerCase()}`, GSI1SK: `USER#` }),
}
```

---

## Reading

### GetItem — single item by full PK + SK

```ts
import { GetCommand } from '@aws-sdk/lib-dynamodb'

async function getUser(id: string): Promise<User | null> {
  const result = await dynamo.send(
    new GetCommand({
      TableName: TABLE_NAME,
      Key: keys.user(id),
      ProjectionExpression: 'id, #name, email, createdAt',
      ExpressionAttributeNames: { '#name': 'name' }, // 'name' is reserved
    })
  )
  return (result.Item as User) ?? null
}
```

### Query — items by PK (with optional SK filter)

```ts
import { QueryCommand } from '@aws-sdk/lib-dynamodb'

// ✅ — get all posts by a user, sorted by date descending
async function getPostsByUser(userId: string, limit = 20): Promise<Post[]> {
  const result = await dynamo.send(
    new QueryCommand({
      TableName: TABLE_NAME,
      KeyConditionExpression: 'PK = :pk AND begins_with(SK, :skPrefix)',
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}`,
        ':skPrefix': 'POST#',
      },
      ProjectionExpression: 'id, title, createdAt',
      ScanIndexForward: false,  // descending
      Limit: limit,
    })
  )
  return result.Items as Post[]
}
```

### Pagination with LastEvaluatedKey

```ts
async function getPostsFeed(limit = 20, lastKey?: Record<string, unknown>) {
  const result = await dynamo.send(
    new QueryCommand({
      TableName: TABLE_NAME,
      IndexName: 'GSI1',
      KeyConditionExpression: 'GSI1PK = :feed',
      ExpressionAttributeValues: { ':feed': 'FEED' },
      ScanIndexForward: false,
      Limit: limit,
      ExclusiveStartKey: lastKey,  // pass undefined for first page
    })
  )
  return {
    items: result.Items as Post[],
    nextKey: result.LastEvaluatedKey ?? null,  // null = no more pages
  }
}
```

### BatchGetItem — multiple items in one call

```ts
import { BatchGetCommand } from '@aws-sdk/lib-dynamodb'

// ✅ — single round-trip for multiple keys
async function getUsersByIds(ids: string[]): Promise<User[]> {
  const result = await dynamo.send(
    new BatchGetCommand({
      RequestItems: {
        [TABLE_NAME]: {
          Keys: ids.map(id => keys.user(id)),
          ProjectionExpression: 'id, #name, email',
          ExpressionAttributeNames: { '#name': 'name' },
        },
      },
    })
  )
  return (result.Responses?.[TABLE_NAME] ?? []) as User[]
}
```

---

## Writing

### PutItem — create or replace

```ts
import { PutCommand } from '@aws-sdk/lib-dynamodb'

async function createUser(input: CreateUserInput): Promise<User> {
  const now = new Date().toISOString()
  const id = randomUUID()

  const item = {
    ...keys.user(id),
    // GSI keys for email lookup
    GSI1PK: `EMAIL#${input.email.toLowerCase()}`,
    GSI1SK: `USER#${id}`,
    // Data fields
    id,
    email: input.email.toLowerCase(),
    name: input.name,
    createdAt: now,
    updatedAt: now,
    entityType: 'USER',
  }

  await dynamo.send(
    new PutCommand({
      TableName: TABLE_NAME,
      Item: item,
      // Prevent overwriting an existing user
      ConditionExpression: 'attribute_not_exists(PK)',
    })
  )

  return item as User
}
```

### UpdateItem — partial update

```ts
import { UpdateCommand } from '@aws-sdk/lib-dynamodb'

async function updateUser(id: string, input: UpdateUserInput): Promise<void> {
  await dynamo.send(
    new UpdateCommand({
      TableName: TABLE_NAME,
      Key: keys.user(id),
      UpdateExpression: 'SET #name = :name, updatedAt = :now',
      ConditionExpression: 'attribute_exists(PK)',  // fail if not exists
      ExpressionAttributeNames: { '#name': 'name' },
      ExpressionAttributeValues: {
        ':name': input.name,
        ':now': new Date().toISOString(),
      },
    })
  )
}
```

### Optimistic locking — prevent race conditions

```ts
// Use a version field to detect concurrent writes
async function updateWithOptimisticLock(id: string, input: UpdateInput, expectedVersion: number) {
  await dynamo.send(
    new UpdateCommand({
      TableName: TABLE_NAME,
      Key: keys.user(id),
      UpdateExpression: 'SET #name = :name, version = :newVersion, updatedAt = :now',
      ConditionExpression: 'version = :expectedVersion',
      ExpressionAttributeNames: { '#name': 'name' },
      ExpressionAttributeValues: {
        ':name': input.name,
        ':expectedVersion': expectedVersion,
        ':newVersion': expectedVersion + 1,
        ':now': new Date().toISOString(),
      },
    })
  )
}
```

### TTL — for sessions, tokens, temp data

```ts
// TTL field must be a Unix timestamp in seconds
const TTL_7_DAYS = Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60

await dynamo.send(
  new PutCommand({
    TableName: TABLE_NAME,
    Item: {
      PK: `SESSION#${sessionId}`,
      SK: '#METADATA',
      userId,
      token: hashedToken,
      createdAt: new Date().toISOString(),
      ttl: TTL_7_DAYS,  // DynamoDB auto-deletes after this time
    },
  })
)
```

---

## GSI design

```
# Access pattern → GSI

1. Get user by email
   GSI1PK = EMAIL#<email>    GSI1SK = USER#<id>

2. Get all posts (global feed by date)
   GSI1PK = FEED             GSI1SK = <ISO date>  (sort by date)

3. Get comments by author
   GSI2PK = USER#<userId>    GSI2SK = COMMENT#<commentId>
```

Rules:
- Max 20 GSIs per table — design carefully
- GSI keys must be on every item that needs that access pattern
- Items that don't use a GSI just omit those attributes (sparse index)

---

## What never to do

```ts
// ❌ — Scan reads EVERY item in the table — O(n), expensive, slow
await dynamo.send(new ScanCommand({ TableName: TABLE_NAME }))

// ❌ — sequential numeric ID is a hot partition
PK = '1', '2', '3' ... // all traffic hits the same shard

// ✅ — UUID/cuid distributes evenly across partitions
PK = `USER#${randomUUID()}`

// ❌ — storing an unbounded list in one item (400 KB limit)
item.comments = [...allComments]  // will eventually exceed limit

// ✅ — store each comment as its own item
PK = `POST#${postId}`   SK = `COMMENT#${commentId}`

// ❌ — N individual GetItem calls
for (const id of ids) {
  await dynamo.send(new GetCommand({ Key: keys.user(id) }))
}

// ✅ — BatchGetItem: up to 100 items in one call
await dynamo.send(new BatchGetCommand({ RequestItems: { [TABLE]: { Keys: [...] } } }))
```

---

## CDK table definition

```ts
import { Table, AttributeType, BillingMode, ProjectionType } from 'aws-cdk-lib/aws-dynamodb'

const table = new Table(stack, 'AppTable', {
  tableName: `${project}-${env}-main`,
  partitionKey: { name: 'PK', type: AttributeType.STRING },
  sortKey: { name: 'SK', type: AttributeType.STRING },
  billingMode: BillingMode.PAY_PER_REQUEST,  // on-demand — no capacity planning
  timeToLiveAttribute: 'ttl',
  pointInTimeRecovery: true,  // always on for production
})

// GSI for email lookups and feed
table.addGlobalSecondaryIndex({
  indexName: 'GSI1',
  partitionKey: { name: 'GSI1PK', type: AttributeType.STRING },
  sortKey: { name: 'GSI1SK', type: AttributeType.STRING },
  projectionType: ProjectionType.ALL,
})
```
