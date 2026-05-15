---
name: gcs
description: Google Cloud Storage standards for service account auth, signed URLs, upload/download, bucket IAM, and lifecycle rules
user-invocable: false
stack: storage/gcs
paths:
  - "**/*gcs*"
  - "**/*storage*"
  - "**/*.py"
  - "**/*.ts"
  - "**/*.js"
  - "**/cdk/**"
  - "**/*google*"
---

Full standards in [gcs.md](gcs.md). Always-on summary:

**Authentication:**
- Use ADC (Application Default Credentials) in GCP-hosted environments — never hardcode service account keys
- Store service account JSON key in a secret manager (Secret Manager or Doppler); never commit it
- Grant the least-privileged role: `roles/storage.objectViewer` for read, `roles/storage.objectCreator` for write, `roles/storage.admin` only for bucket management

**Signed URLs:**
- Generate server-side with `file.getSignedUrl({ action: 'write', expires: Date.now() + 15 * 60 * 1000 })` for uploads
- Use `v4` signing — `v2` is deprecated
- Pass `action: 'write'` for upload signed URLs; set `contentType` to restrict MIME type
- Validate `mimetype` against an `allowedMimeTypes` list before generating the URL — clients can lie about content type

**Uploads and downloads:**
- Use `upload_from_filename` for file paths, `upload_from_string` / `upload_from_file` for in-memory data
- Always set `content_type` on blobs — never rely on auto-detection
- Use resumable uploads for files > 5 MB

**Bucket config:**
- Enable `uniformBucketLevelAccess` on every bucket — never use per-object ACLs (they conflict with IAM)
- Set lifecycle rules to delete temporary/processed objects older than N days
- Enable versioning on buckets that store user-critical data

**Never:**
- Never make buckets publicly readable unless serving static assets; use signed URLs instead
- Never log signed URLs — they grant time-limited access
- Never use the default compute service account for storage operations — use a dedicated SA

**Related skills:** security-principles, logging-standards, cdk
