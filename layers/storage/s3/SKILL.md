---
name: s3-storage
description: AWS S3 storage patterns — presigned URLs, multipart upload, bucket policy, lifecycle rules, CloudFront CDN integration. Load when working with S3 file storage.
user-invocable: false
stack: storage/s3
paths:
  - "src/lib/s3*"
  - "src/api/upload*"
  - "infra/**"
  - "cdk/**"
---

Full standards in [s3-storage.md](s3-storage.md). Always-on summary:

**Never expose AWS credentials to the client** — always generate presigned URLs server-side

**Upload flow:** client requests URL → server generates `PutObjectCommand` presigned URL with `getSignedUrl(` (15 min TTL) → client uploads directly to S3 — server is never in the data path

**File validation:** validate `ContentType` against an `allowedTypes` list server-side before generating the presigned URL — clients can send any content type

**Bucket policy:** set `BlockPublicAccess.BLOCK_ALL` on all buckets; use CloudFront for public assets — never `s3:GetObject *` ACL

**Naming:** `<company>-<service>-<env>` (e.g. `acme-uploads-prod`) — lowercase, no dots

**Encryption:** `AES256` minimum; SSE-KMS for regulated data

**Versioning:** enable on production buckets storing user data

**Lifecycle:** STANDARD_IA after 30 days → GLACIER after 90 → delete after 365 (adjust per retention policy)

**CORS:** restrict `AllowedOrigins` to your domain — never `*` in production

**File validation:** check MIME type server-side before generating presigned URL (not just file extension)
