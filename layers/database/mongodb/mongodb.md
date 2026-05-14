# MongoDB Standards

---

## Connection — one client per app

```typescript
// src/lib/mongodb.ts — module-level singleton
import { MongoClient, Db } from 'mongodb'

const uri = process.env.MONGODB_URI!
const options = {
  maxPoolSize: 20,           // concurrent connections per server
  minPoolSize: 5,
  connectTimeoutMS: 10_000,
  socketTimeoutMS: 45_000,
  serverSelectionTimeoutMS: 10_000,
}

let client: MongoClient
let clientPromise: Promise<MongoClient>

if (process.env.NODE_ENV === 'development') {
  // In dev, reuse the connection across hot reloads
  const globalWithMongo = global as typeof globalThis & { _mongoClientPromise?: Promise<MongoClient> }
  if (!globalWithMongo._mongoClientPromise) {
    client = new MongoClient(uri, options)
    globalWithMongo._mongoClientPromise = client.connect()
  }
  clientPromise = globalWithMongo._mongoClientPromise
} else {
  client = new MongoClient(uri, options)
  clientPromise = client.connect()
}

export async function getDb(dbName?: string): Promise<Db> {
  const c = await clientPromise
  return c.db(dbName)
}
```

---

## Schema design — embed vs reference

### Embed when:
- Sub-documents are always accessed with the parent
- The array has a bounded, small size (< 100 items)
- Sub-documents are not shared between parents

```javascript
// ✅ Embed — order items always fetched with the order
{
  _id: ObjectId("..."),
  userId: ObjectId("..."),
  status: "pending",
  items: [                      // embedded — bounded array
    { productId: ObjectId("..."), name: "Widget", quantity: 2, price: 1000 },
    { productId: ObjectId("..."), name: "Gadget", quantity: 1, price: 2000 },
  ],
  total: 4000,
  createdAt: ISODate("...")
}
```

### Reference when:
- Documents are large or independently updated
- Data is shared across many parent documents
- The array is unbounded (user's entire order history)

```javascript
// ✅ Reference — user document stays small; orders grow independently
// users collection
{ _id: ObjectId("u1"), email: "user@example.com", name: "Alice" }

// orders collection — references user
{ _id: ObjectId("o1"), userId: ObjectId("u1"), total: 4000, createdAt: ISODate("...") }
```

---

## Indexes

```typescript
// Create indexes at startup or in a migration script — NOT on every request
const db = await getDb('myapp')

// Single field
await db.collection('users').createIndex({ email: 1 }, { unique: true })

// Compound — order matters: equality fields first, range/sort fields last
await db.collection('orders').createIndex({ userId: 1, createdAt: -1 })

// Text search
await db.collection('products').createIndex({ name: 'text', description: 'text' })

// TTL — auto-expire documents (e.g. sessions, tokens)
await db.collection('sessions').createIndex(
  { expiresAt: 1 },
  { expireAfterSeconds: 0 }   // delete when expiresAt is in the past
)

// Partial index — only index documents matching a condition
await db.collection('orders').createIndex(
  { userId: 1 },
  { partialFilterExpression: { status: 'pending' } }
)
```

**Verify index usage:**
```javascript
// In MongoDB shell or Compass
db.orders.find({ userId: ObjectId("...") }).explain('executionStats')
// Check: winningPlan.stage should be "IXSCAN", not "COLLSCAN"
```

---

## CRUD operations

```typescript
const db = await getDb('myapp')
const orders = db.collection<Order>('orders')

// Find one
const order = await orders.findOne(
  { _id: new ObjectId(id) },
  { projection: { items: 1, status: 1, total: 1 } }  // project only needed fields
)

// Find many with pagination (cursor-based)
const cursor = orders.find(
  { userId: new ObjectId(userId) },
  {
    sort: { createdAt: -1 },
    limit: 20,
    projection: { items: 0 },   // exclude heavy nested arrays in list views
  }
)
const results = await cursor.toArray()

// Insert one
const result = await orders.insertOne({
  userId: new ObjectId(userId),
  status: 'pending',
  items: [...],
  total: 4000,
  createdAt: new Date(),
  updatedAt: new Date(),
})
const newId = result.insertedId

// Update
await orders.updateOne(
  { _id: new ObjectId(id), userId: new ObjectId(userId) },  // include userId for ownership check
  {
    $set: { status: 'shipped', updatedAt: new Date() },
  }
)

// Soft delete
await orders.updateOne(
  { _id: new ObjectId(id) },
  { $set: { deletedAt: new Date() } }
)

// Hard delete (only for ephemeral data)
await orders.deleteOne({ _id: new ObjectId(id) })
```

---

## Aggregation pipeline

```typescript
// Common pipeline for paginated list with total count
const [result] = await orders.aggregate([
  { $match: { userId: new ObjectId(userId), deletedAt: { $exists: false } } },
  { $sort: { createdAt: -1 } },
  {
    $facet: {
      data: [
        { $skip: (page - 1) * limit },
        { $limit: limit },
        { $project: { items: 0 } },   // exclude heavy fields
      ],
      total: [{ $count: 'count' }],
    },
  },
]).toArray()

const { data, total } = result
const totalCount = total[0]?.count ?? 0
```

```typescript
// Join with another collection ($lookup)
const orders = await db.collection('orders').aggregate([
  { $match: { userId: new ObjectId(userId) } },
  {
    $lookup: {
      from: 'products',
      localField: 'items.productId',
      foreignField: '_id',
      as: 'productDetails',
    },
  },
  {
    $project: {
      status: 1,
      total: 1,
      productDetails: { name: 1, imageUrl: 1 },
    },
  },
]).toArray()
```

---

## Transactions (multi-document)

```typescript
// Use a session for atomic multi-collection operations
const session = client.startSession()

try {
  await session.withTransaction(async () => {
    await orders.insertOne(
      { userId: new ObjectId(userId), status: 'pending', total: 4000 },
      { session }
    )
    await inventory.updateOne(
      { productId: new ObjectId(productId) },
      { $inc: { quantity: -2 } },
      { session }
    )
  })
} finally {
  await session.endSession()
}
```

**Transactions require a replica set** (even for local dev — use `docker-compose` with a replica set, or MongoDB Atlas free tier).

---

## Mongoose patterns

```typescript
// src/models/user.model.ts
import { Schema, model, Document } from 'mongoose'

interface IUser extends Document {
  email: string
  name: string
  role: 'user' | 'admin'
  deletedAt?: Date
  createdAt: Date
  updatedAt: Date
}

const userSchema = new Schema<IUser>(
  {
    email:     { type: String, required: true, unique: true, lowercase: true, trim: true },
    name:      { type: String, required: true, trim: true },
    role:      { type: String, enum: ['user', 'admin'], default: 'user' },
    deletedAt: { type: Date },
  },
  {
    timestamps: true,          // auto-manages createdAt and updatedAt
    toJSON:  { virtuals: true },
    toObject: { virtuals: true },
  }
)

// Indexes
userSchema.index({ email: 1 }, { unique: true })
userSchema.index({ deletedAt: 1 }, { sparse: true })  // null values not indexed

// Soft delete query helper
userSchema.query.active = function () {
  return this.where({ deletedAt: { $exists: false } })
}

export const User = model<IUser>('User', userSchema)
```

```typescript
// Always use .lean() when you don't need Mongoose document methods
const users = await User.find({ role: 'admin' }).lean()  // returns plain objects — faster
const user = await User.findById(id).lean()
```

---

## Cursor pagination

```typescript
// Cursor-based pagination with _id (stable under inserts)
async function listOrders(userId: string, cursor?: string, limit = 20) {
  const query: Filter<Order> = { userId: new ObjectId(userId) }

  if (cursor) {
    query._id = { $lt: new ObjectId(cursor) }  // fetch items older than the cursor
  }

  const items = await orders
    .find(query, { projection: { items: 0 } })
    .sort({ _id: -1 })
    .limit(limit + 1)  // fetch one extra to detect hasMore
    .toArray()

  const hasMore = items.length > limit
  if (hasMore) items.pop()

  return {
    data: items,
    nextCursor: hasMore ? items[items.length - 1]._id.toHexString() : null,
    hasMore,
  }
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Creating a `MongoClient` per request | Use a module-level singleton with connection pooling |
| Querying without an index | Add an index for every field in `find()` filters and sort |
| Unbounded arrays (`user.orders.push(...)` forever) | Reference orders in a separate collection |
| `find({})` in an API route | Always filter; no collection scans in production |
| Not projecting fields | Always specify which fields you need — don't return full documents in list views |
| Missing `.lean()` in Mongoose list queries | `.lean()` returns plain objects — 2-5× faster for read-only operations |
