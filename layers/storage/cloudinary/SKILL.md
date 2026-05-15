---
name: cloudinary
description: Cloudinary standards for upload presets, transformations, signed uploads, React integration, and webhook handling
user-invocable: false
stack: storage/cloudinary
paths:
  - "**/*cloudinary*"
  - "**/upload*"
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.js"
---

Full standards in [cloudinary.md](cloudinary.md). Always-on summary:

**Uploads:**
- Always use signed uploads for server-side or authenticated client uploads — never expose `api_secret` to browsers
- Use unsigned uploads with a restricted upload preset only for public-facing widgets with no auth requirement
- Set `resource_type: "auto"` to handle image/video/raw in one call

**Transformations:**
- Build transformation chains server-side using the SDK; never construct URLs by string concatenation
- Use eager transformations for predictable variants (thumbnail, webp); use on-the-fly for dynamic resizing
- Apply `quality: "auto"`, `fetch_format: "auto"` on all delivery URLs for automatic optimization

**Security:**
- Sign upload params server-side using `cloudinary.utils.api_sign_request(paramsToSign, apiSecret)` — expose only the `signature`, never the secret
- Generate signed URLs on the server for private/restricted assets; set a short `expires_at`
- Validate Cloudinary webhooks using the `X-Cld-Signature` header before processing
- Store the Cloudinary API secret only server-side; never expose it in frontend bundles

**Transformations:**
- Use `cloudinary.url('public_id', { transformation: [{ width: 400, crop: 'fill' }] })` — never build transformation URLs by string concatenation
- Organize with `folder:` prefix and explicit `public_id:` on every upload

**React:**
- Use `@cloudinary/react` + `@cloudinary/url-gen` for declarative transforms in JSX
- Use the upload widget (`cloudinary.createUploadWidget`) for in-browser uploads; pass a server-generated signature

**Never:**
- Never include `api_secret` in client-side code or public upload presets
- Never store raw Cloudinary public IDs without a prefix/folder structure
- Never use width/height pixel values in URLs without a `crop` mode — use `fill`, `thumb`, or `limit`

**Related skills:** security-principles, api-conventions
