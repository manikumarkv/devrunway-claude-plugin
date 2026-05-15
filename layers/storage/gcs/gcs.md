# Google Cloud Storage Standards

## Install

```bash
# Python
pip install google-cloud-storage

# Node.js
npm install @google-cloud/storage
```

## Authentication

```python
# Python — ADC (Application Default Credentials)
# On GCP (Cloud Run, GKE, Compute Engine): no config needed
# Locally: run `gcloud auth application-default login`
from google.cloud import storage

client = storage.Client()  # uses ADC automatically

# With explicit service account (e.g., loaded from Secret Manager)
import json
from google.oauth2 import service_account

def make_storage_client(service_account_json: str) -> storage.Client:
    info = json.loads(service_account_json)
    credentials = service_account.Credentials.from_service_account_info(info)
    return storage.Client(credentials=credentials)
```

```typescript
// TypeScript — ADC
import { Storage } from "@google-cloud/storage";

// ADC: set GOOGLE_APPLICATION_CREDENTIALS env var to SA key path
// or use Workload Identity on GKE
const storage = new Storage({ projectId: process.env.GCP_PROJECT_ID });
const bucket = storage.bucket(process.env.GCS_BUCKET_NAME!);
```

## Typed GCS service (Python)

```python
# storage/gcs_service.py
import io
import logging
from dataclasses import dataclass
from datetime import timedelta

from google.cloud import storage
from google.cloud.exceptions import NotFound

logger = logging.getLogger(__name__)


@dataclass
class UploadResult:
    blob_name: str
    public_url: str
    size: int
    content_type: str


class GCSService:
    def __init__(self, bucket_name: str, client: storage.Client | None = None):
        self._client = client or storage.Client()
        self._bucket = self._client.bucket(bucket_name)
        self._bucket_name = bucket_name

    def upload_file(
        self,
        source_path: str,
        destination_blob_name: str,
        content_type: str,
    ) -> UploadResult:
        blob = self._bucket.blob(destination_blob_name)
        blob.upload_from_filename(source_path, content_type=content_type)
        logger.info(
            "gcs_upload_complete",
            extra={"blob": destination_blob_name, "bucket": self._bucket_name},
        )
        return UploadResult(
            blob_name=blob.name,
            public_url=blob.public_url,
            size=blob.size or 0,
            content_type=content_type,
        )

    def upload_bytes(
        self,
        data: bytes,
        destination_blob_name: str,
        content_type: str,
    ) -> UploadResult:
        blob = self._bucket.blob(destination_blob_name)
        blob.upload_from_file(io.BytesIO(data), content_type=content_type)
        blob.reload()
        return UploadResult(
            blob_name=blob.name,
            public_url=blob.public_url,
            size=blob.size or 0,
            content_type=content_type,
        )

    def download_bytes(self, blob_name: str) -> bytes:
        blob = self._bucket.blob(blob_name)
        try:
            return blob.download_as_bytes()
        except NotFound:
            raise FileNotFoundError(f"GCS object not found: {blob_name}")

    def delete(self, blob_name: str) -> None:
        blob = self._bucket.blob(blob_name)
        try:
            blob.delete()
            logger.info("gcs_delete", extra={"blob": blob_name})
        except NotFound:
            pass  # idempotent delete

    def exists(self, blob_name: str) -> bool:
        return self._bucket.blob(blob_name).exists()

    def generate_signed_upload_url(
        self,
        blob_name: str,
        content_type: str,
        expiration_minutes: int = 15,
    ) -> str:
        blob = self._bucket.blob(blob_name)
        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=expiration_minutes),
            method="PUT",
            content_type=content_type,
        )
        return url

    def generate_signed_download_url(
        self,
        blob_name: str,
        expiration_minutes: int = 60,
    ) -> str:
        blob = self._bucket.blob(blob_name)
        return blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=expiration_minutes),
            method="GET",
        )
```

## Node.js service

```typescript
// storage/gcs.ts
import { Storage, Bucket } from "@google-cloud/storage";
import path from "path";

const storage = new Storage({ projectId: process.env.GCP_PROJECT_ID });

export function getBucket(bucketName = process.env.GCS_BUCKET_NAME!): Bucket {
  return storage.bucket(bucketName);
}

export async function uploadBuffer(
  buffer: Buffer,
  destinationPath: string,
  contentType: string,
  bucket = getBucket()
): Promise<string> {
  const file = bucket.file(destinationPath);
  await file.save(buffer, {
    metadata: { contentType },
    resumable: buffer.byteLength > 5 * 1024 * 1024, // resumable for >5 MB
  });
  return file.publicUrl();
}

export async function generateSignedUploadUrl(
  blobName: string,
  contentType: string,
  expiresInMs = 15 * 60 * 1000,
  bucket = getBucket()
): Promise<string> {
  const file = bucket.file(blobName);
  const [url] = await file.generateSignedPostPolicyV4({
    expires: Date.now() + expiresInMs,
    conditions: [
      ["content-length-range", 0, 20 * 1024 * 1024], // max 20 MB
      ["eq", "$Content-Type", contentType],
    ],
    fields: { "Content-Type": contentType },
  });
  return url.url;
}

export async function generateSignedDownloadUrl(
  blobName: string,
  expiresInMs = 60 * 60 * 1000,
  bucket = getBucket()
): Promise<string> {
  const file = bucket.file(blobName);
  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "read",
    expires: Date.now() + expiresInMs,
  });
  return url;
}

export async function deleteObject(blobName: string, bucket = getBucket()): Promise<void> {
  try {
    await bucket.file(blobName).delete();
  } catch (err: unknown) {
    if ((err as { code?: number }).code === 404) return; // idempotent
    throw err;
  }
}
```

## API route — presigned upload URL (Next.js)

```typescript
// app/api/storage/upload-url/route.ts
import { NextRequest, NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { generateSignedUploadUrl } from "@/lib/gcs";
import { randomUUID } from "crypto";

const ALLOWED_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "application/pdf"]);

export async function POST(req: NextRequest) {
  const session = await auth(req);
  if (!session) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { contentType, filename } = await req.json();
  if (!ALLOWED_TYPES.has(contentType)) {
    return NextResponse.json({ error: "Unsupported file type" }, { status: 422 });
  }

  const ext = filename?.split(".").pop() ?? "bin";
  const blobName = `users/${session.userId}/${randomUUID()}.${ext}`;
  const uploadUrl = await generateSignedUploadUrl(blobName, contentType);

  return NextResponse.json({ uploadUrl, blobName });
}
```

## Bucket IAM (Terraform)

```hcl
resource "google_storage_bucket" "app_uploads" {
  name          = "myapp-uploads-prod"
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true  # REQUIRED — disables per-object ACLs

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }  # delete objects older than 1 year
  }

  lifecycle_rule {
    action { type = "SetStorageClass"; storage_class = "NEARLINE" }
    condition { age = 30 }  # move to Nearline after 30 days
  }
}

resource "google_storage_bucket_iam_member" "app_sa_writer" {
  bucket = google_storage_bucket.app_uploads.name
  role   = "roles/storage.objectCreator"  # write but not read
  member = "serviceAccount:${google_service_account.app.email}"
}

resource "google_storage_bucket_iam_member" "app_sa_reader" {
  bucket = google_storage_bucket.app_uploads.name
  role   = "roles/storage.objectViewer"  # read only
  member = "serviceAccount:${google_service_account.app.email}"
}
```

## CORS configuration (for browser direct uploads)

```python
# Set CORS on bucket to allow browser PUT to signed URLs
bucket = client.get_bucket("myapp-uploads-prod")
bucket.cors = [
    {
        "origin": ["https://myapp.com", "http://localhost:3000"],
        "method": ["PUT", "GET"],
        "responseHeader": ["Content-Type", "x-goog-resumable"],
        "maxAgeSeconds": 3600,
    }
]
bucket.patch()
```

## Naming conventions

```
# Folder structure by entity type
users/{userId}/{uuid}.{ext}          ← user uploads
documents/{orgId}/{docId}/{version}  ← versioned documents
exports/{jobId}/output.csv           ← processing outputs
temp/{sessionId}/{uuid}              ← ephemeral; lifecycle rule deletes after 1 day
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Public bucket for private assets | Keep bucket private; use signed URLs for access |
| Hardcoded SA key in source code | Load from Secret Manager / Doppler at runtime |
| Per-object ACLs with IAM | Enable `uniform_bucket_level_access`; use IAM only |
| Missing `content_type` on upload | Always set it — wrong type breaks downloads |
| `v2` signed URLs | Use `version="v4"` — v2 is deprecated |
| Logging signed URLs | Signed URLs grant access — never log them |
| Storing GCS `public_url` for private blobs | Store `blob_name`; generate signed URL on demand |
| No lifecycle rules | Add rules to prevent unbounded storage growth |
