# AWS S3 Storage Standards

## Presigned URL Upload Flow

Never route file data through your server — use presigned URLs so the client uploads directly to S3:

```ts
// src/lib/s3.ts
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'

export const s3 = new S3Client({ region: process.env.AWS_REGION })

export const BUCKET = process.env.S3_BUCKET_NAME!

// Generate a presigned PUT URL for upload
export async function getUploadUrl(
  key: string,
  contentType: string,
  expiresIn = 900  // 15 minutes
): Promise<string> {
  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    ContentType: contentType,
  })
  return getSignedUrl(s3, command, { expiresIn })
}

// Generate a presigned GET URL for private download
export async function getDownloadUrl(key: string, expiresIn = 3600): Promise<string> {
  const command = new GetObjectCommand({ Bucket: BUCKET, Key: key })
  return getSignedUrl(s3, command, { expiresIn })
}
```

```ts
// src/api/upload/presign.ts — server endpoint
export async function POST(req: Request) {
  const { filename, contentType, size } = await req.json()

  // Validate before generating URL
  const allowed = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
  if (!allowed.includes(contentType)) {
    return Response.json({ error: 'File type not allowed' }, { status: 400 })
  }
  if (size > 10 * 1024 * 1024) {  // 10 MB limit
    return Response.json({ error: 'File too large' }, { status: 400 })
  }

  const userId = getUserId(req)
  const key = `uploads/${userId}/${Date.now()}-${sanitizeFilename(filename)}`
  const uploadUrl = await getUploadUrl(key, contentType)

  return Response.json({ uploadUrl, key })
}
```

```ts
// Client — uploads directly to S3, never through your server
async function uploadFile(file: File): Promise<string> {
  // 1. Get presigned URL from your API
  const { uploadUrl, key } = await api.post('/upload/presign', {
    filename: file.name,
    contentType: file.type,
    size: file.size,
  })

  // 2. Upload directly to S3
  await fetch(uploadUrl, {
    method: 'PUT',
    body: file,
    headers: { 'Content-Type': file.type },
  })

  // 3. Return the S3 key (not the presigned URL — that expires)
  return key
}
```

## CDK Bucket Configuration

```ts
// infra/stacks/storage.ts
import * as cdk from 'aws-cdk-lib'
import * as s3 from 'aws-cdk-lib/aws-s3'
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront'

const uploadsBucket = new s3.Bucket(this, 'UploadsBucket', {
  bucketName: `acme-uploads-${props.env}`,
  versioned: true,                                 // enable versioning for user data
  encryption: s3.BucketEncryption.S3_MANAGED,     // AES256; use KMS for regulated data
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  removalPolicy: cdk.RemovalPolicy.RETAIN,         // never auto-delete prod data
  lifecycleRules: [
    {
      transitions: [
        { storageClass: s3.StorageClass.INFREQUENT_ACCESS, transitionAfter: cdk.Duration.days(30) },
        { storageClass: s3.StorageClass.GLACIER, transitionAfter: cdk.Duration.days(90) },
      ],
      expiration: cdk.Duration.days(365),          // adjust per retention policy
    },
  ],
  cors: [
    {
      allowedOrigins: ['https://app.acme.com'],    // never '*' in production
      allowedMethods: [s3.HttpMethods.PUT],        // upload only
      allowedHeaders: ['Content-Type'],
      maxAge: 3600,
    },
  ],
})
```

## CloudFront for Public Assets

Public assets (avatars, marketing images) go through CloudFront — never direct S3 URLs:

```ts
const assetsBucket = new s3.Bucket(this, 'AssetsBucket', {
  bucketName: `acme-assets-${props.env}`,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,  // still private — CF has access
})

const distribution = new cloudfront.Distribution(this, 'AssetsDistribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(assetsBucket),
    viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
  },
})

// Public URL: https://<distro>.cloudfront.net/<key>
// Never: https://<bucket>.s3.amazonaws.com/<key>
```

## File Key Structure

```
uploads/<userId>/<timestamp>-<sanitized-filename>   # user uploads (private)
assets/avatars/<userId>/<timestamp>.webp            # profile photos (CloudFront)
assets/products/<productId>/<timestamp>.webp        # product images (CloudFront)
exports/<userId>/<job-id>/report.pdf                # generated exports (presigned GET)
```

## MIME Type Validation

Always validate server-side — file extensions are user-supplied and untrustworthy:

```ts
import { fileTypeFromBuffer } from 'file-type'

async function validateMimeType(buffer: Buffer, declaredType: string): Promise<void> {
  const detected = await fileTypeFromBuffer(buffer)
  if (!detected || detected.mime !== declaredType) {
    throw new AppError('File type mismatch', 400)
  }
}
```

For presigned URLs (where you don't see the body), validate on a Lambda S3 trigger or restrict `ContentType` in the presigned URL command and set a bucket policy to enforce it.

## Multipart Upload (large files)

For files > 100 MB, use multipart upload:

```ts
import { createMultipartUpload, uploadPart, completeMultipartUpload } from '@aws-sdk/client-s3'

// Each part: 5 MB minimum (except last)
const PART_SIZE = 5 * 1024 * 1024

async function uploadLargeFile(key: string, file: File): Promise<void> {
  const { UploadId } = await s3.send(new CreateMultipartUploadCommand({ Bucket: BUCKET, Key: key }))
  const parts: CompletedPart[] = []

  for (let i = 0; i < Math.ceil(file.size / PART_SIZE); i++) {
    const slice = file.slice(i * PART_SIZE, (i + 1) * PART_SIZE)
    const { ETag } = await s3.send(new UploadPartCommand({
      Bucket: BUCKET, Key: key, UploadId, PartNumber: i + 1, Body: slice,
    }))
    parts.push({ ETag, PartNumber: i + 1 })
  }

  await s3.send(new CompleteMultipartUploadCommand({
    Bucket: BUCKET, Key: key, UploadId,
    MultipartUpload: { Parts: parts },
  }))
}
```

## Anti-Patterns

| Anti-pattern | Risk | Fix |
|---|---|---|
| Routing file data through server | Memory exhaustion, slow uploads | Use presigned PUT URLs |
| Presigned URL TTL > 1 hour | URL leakage window | 15 min for uploads, 1 hour max for downloads |
| `s3:GetObject *` ACL | Anyone can read files | Block public access + use CloudFront |
| Trust file extension only | MIME type spoofing | Validate with `file-type` library |
| No versioning on production | Data loss | Enable on all user-data buckets |
| `*` in CORS AllowedOrigins | CSRF on upload endpoint | Restrict to your domain |
