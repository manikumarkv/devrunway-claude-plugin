---
name: uploadthing
description: UploadThing standards — router definition, file type and size limits, auth, React dropzone, and webhook handling. Load when working with UploadThing.
user-invocable: false
stack: storage/uploadthing
paths:
  - "**/uploadthing*"
  - "**/core.ts"
  - "**/upload/**"
---

Full standards in [uploadthing.md](uploadthing.md). Always-on summary:

**Router setup:**
- Define upload routes with `createUploadthing(` in `core.ts`
- Each route is defined with `f({` file type config (e.g., `f({ image: { maxFileSize: '4MB' } })`) followed by `.middleware()` and `.onUploadComplete(`
- The `middleware` function runs on the server — validate auth and return metadata here

**Auth:**
- Always validate the user session in `middleware` — throw if not authenticated
- Return metadata (userId, etc.) from `middleware` — it's passed to `onUploadComplete` and is trusted server-side
- Never trust user-supplied metadata from the client

**File validation:**
- Set explicit file type restrictions via the route config — don't rely on client-side validation alone
- Set `maxFileSize` conservatively — large uploads cost more and can time out
- Validate file content type on the server in `onUploadComplete`, not just the extension

**Client:**
- Use `useUploadThing()` hook for custom UI or `<UploadButton>` / `<UploadDropzone>` for quick setup
- Handle `onUploadComplete` on the client to update UI state after upload finishes
- Handle `onUploadError` — always show user-facing errors, not raw error messages

**Webhooks:**
- Configure the UploadThing webhook to call your endpoint when uploads complete
- Verify the webhook signature — use `UTApi.webhookSignature` helpers

**Never:**
- Store the file URL from the client — get it from the `onUploadComplete(` callback which provides the `fileUrl`
- Skip the `middleware` auth check — anyone could upload without it
- Use the UploadThing `fileKey` as a public identifier — it's internal; use your DB record ID

**Related skills:** `storage/cloudinary` (image transformation alternative), `storage/gcs` (GCS direct upload)
