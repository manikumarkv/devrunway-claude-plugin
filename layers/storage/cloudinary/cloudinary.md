# Cloudinary Standards

## Install

```bash
# Node.js (server + React)
npm install cloudinary @cloudinary/react @cloudinary/url-gen

# Python
pip install cloudinary
```

## Configuration

```typescript
// lib/cloudinary.ts — server-side only
import { v2 as cloudinary } from "cloudinary";

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME!,
  api_key: process.env.CLOUDINARY_API_KEY!,
  api_secret: process.env.CLOUDINARY_API_SECRET!,
  secure: true,
});

export { cloudinary };
```

```typescript
// lib/cloudinary-client.ts — safe to expose in browser bundles
import { Cloudinary } from "@cloudinary/url-gen";

export const cld = new Cloudinary({
  cloud: { cloudName: process.env.NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME! },
  url: { secure: true },
});
```

## Server-side upload

The destination path is **derived**, never accepted. A caller who can name the
`folder` or the `public_id` can write into any other user's folder — and, with
`overwrite`, replace their asset. So the upload helper takes an owner identity and
a bucket name from a closed set, and computes the path itself.

```typescript
// server/upload.ts
import { randomUUID } from "crypto";
import { cloudinary } from "@/lib/cloudinary";
import type { UploadApiResponse } from "cloudinary";

export interface UploadResult {
  publicId: string;
  secureUrl: string;
  width: number;
  height: number;
  format: string;
  bytes: number;
}

/** The closed set of buckets a caller may ask for. Anything else is rejected. */
export const ASSET_KINDS = ["avatars", "posts", "documents"] as const;
export type AssetKind = (typeof ASSET_KINDS)[number];

export interface UploadTarget {
  /** Taken from the verified session — never from a request body, query or header. */
  ownerId: string;
  kind: AssetKind;
}

/** Single place that turns an identity into a path. Callers never build one. */
export function assetPath(target: UploadTarget): { folder: string; publicId: string } {
  return {
    folder: `users/${target.ownerId}/${target.kind}`,
    publicId: randomUUID(),
  };
}

export async function uploadImage(
  source: string | Buffer,
  target: UploadTarget,
  options: { tags?: string[] } = {}
): Promise<UploadResult> {
  const { folder: assetFolder, publicId: assetPublicId } = assetPath(target);

  const result: UploadApiResponse = await cloudinary.uploader.upload(
    source as string,
    {
      resource_type: "auto",
      folder: assetFolder,
      public_id: assetPublicId,
      tags: options.tags,
      // A fresh public_id every time, so an upload can never land on an existing
      // asset. Replacing an avatar is: upload new, update the row, delete the old.
      overwrite: false,
      // Always optimize delivery
      quality: "auto",
      fetch_format: "auto",
    }
  );

  return {
    publicId: result.public_id,
    secureUrl: result.secure_url,
    width: result.width,
    height: result.height,
    format: result.format,
    bytes: result.bytes,
  };
}

export async function deleteAsset(target: UploadTarget, publicId: string): Promise<void> {
  // Ownership is checked against the derived prefix. `destroy` takes whatever id it
  // is given, so a route that forwards a caller-supplied id deletes other people's
  // assets — the same bypass as signing a caller-supplied path.
  const { folder } = assetPath(target);
  if (!publicId.startsWith(`${folder}/`)) {
    throw new Error("Asset does not belong to this user");
  }
  await cloudinary.uploader.destroy(publicId, { resource_type: "image" });
}
```

## Upload from multipart form (Next.js API route)

```typescript
// app/api/upload/route.ts
import { NextRequest, NextResponse } from "next/server";
import { cloudinary } from "@/lib/cloudinary";
import { assetPath } from "@/server/upload";
import { replaceUserAvatar } from "@/server/users";
import { auth } from "@/lib/auth"; // your auth helper

export async function POST(req: NextRequest) {
  const session = await auth(req);
  if (!session) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const formData = await req.formData();
  const file = formData.get("file") as File | null;
  if (!file) return NextResponse.json({ error: "No file provided" }, { status: 400 });

  const bytes = await file.arrayBuffer();
  const buffer = Buffer.from(bytes);
  const base64 = `data:${file.type};base64,${buffer.toString("base64")}`;

  // The path comes from the session, not from the form. `formData.get("folder")`
  // would be a caller-chosen destination — see the signature endpoint below.
  const { folder, publicId } = assetPath({ ownerId: session.userId, kind: "avatars" });

  try {
    const result = await cloudinary.uploader.upload(base64, {
      folder,
      public_id: publicId,
      resource_type: "image",
      overwrite: false,
      transformation: [{ width: 400, height: 400, crop: "fill", gravity: "face" }],
    });

    // Point the user row at the new asset, then delete the old one — never
    // overwrite in place, so a failed upload cannot destroy the current avatar.
    await replaceUserAvatar(session.userId, result.public_id);

    return NextResponse.json({ publicId: result.public_id, url: result.secure_url });
  } catch (err) {
    console.error("Cloudinary upload failed", err);
    return NextResponse.json({ error: "Upload failed" }, { status: 500 });
  }
}
```

## Signed upload — signature endpoint

A signature **is** the authorisation. Cloudinary verifies the upload against exactly
the parameters that were signed, so whoever chooses those parameters chooses where
the file lands. Sign values the caller supplied and you have authorised that caller
to write anywhere in the account, under any name, including over somebody else's
asset. Being signed in says *who* they are; it does not say the path they asked for
is theirs.

**The rule: the signed `folder` and `public_id` are derived from the verified session.
This endpoint reads no request body.** The one choice the caller has is which of a
fixed set of buckets, and it arrives on the route.

```typescript
// app/api/cloudinary-signature/[kind]/route.ts
import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { cloudinary } from "@/lib/cloudinary";
import { ASSET_KINDS, type AssetKind } from "@/server/upload";
import { auth } from "@/lib/auth";

export async function POST(
  req: NextRequest,
  { params }: { params: { kind: string } }
) {
  const session = await auth(req);
  if (!session) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  if (!ASSET_KINDS.includes(params.kind as AssetKind)) {
    return NextResponse.json({ error: "Unknown upload kind" }, { status: 400 });
  }

  const timestamp = Math.round(Date.now() / 1000);
  const paramsToSign = {
    timestamp,
    folder: `users/${session.userId}/${params.kind}`,
    public_id: randomUUID(),
  };

  const signature = cloudinary.utils.api_sign_request(
    paramsToSign,
    process.env.CLOUDINARY_API_SECRET!
  );

  // Hand the signed values back. The browser must upload with exactly these —
  // change one character and Cloudinary rejects the upload, which is what makes
  // a server-derived path an enforced boundary rather than a suggestion.
  return NextResponse.json({
    signature,
    timestamp,
    folder: paramsToSign.folder,
    publicId: paramsToSign.public_id,
    apiKey: process.env.CLOUDINARY_API_KEY,
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
  });
}
```

`CLOUDINARY_API_SECRET` is the required second argument of `api_sign_request` and
belongs in this file — server-side, read from the environment. What must never
happen is the secret reaching a browser bundle: no browser-visible copy of it under
any name, and no "sign it on the client" shortcut. The browser receives the signature and
the timestamp, and nothing else it could sign with.

## Browser upload widget (React)

```tsx
// components/ImageUploader.tsx
"use client";
import { useEffect, useRef } from "react";

declare global {
  interface Window {
    cloudinary: {
      createUploadWidget: (options: object, callback: (error: unknown, result: UploadWidgetResult) => void) => UploadWidget;
    };
  }
}

interface UploadWidgetResult {
  event: string;
  info: { public_id: string; secure_url: string; width: number; height: number };
}

interface UploadWidget {
  open: () => void;
  destroy: () => void;
}

interface ImageUploaderProps {
  onUpload: (publicId: string, url: string) => void;
  /** Which bucket, not which path — the server decides the path. */
  kind: "avatars" | "posts" | "documents";
}

export function ImageUploader({ onUpload, kind }: ImageUploaderProps) {
  const widgetRef = useRef<UploadWidget | null>(null);

  useEffect(() => {
    const script = document.createElement("script");
    script.src = "https://upload-widget.cloudinary.com/global/all.js";
    script.async = true;
    script.onload = () => initWidget();
    document.head.appendChild(script);
    return () => { widgetRef.current?.destroy(); document.head.removeChild(script); };
  }, []);

  async function initWidget() {
    // Get a server-generated signature — never use unsigned uploads for auth'd users.
    // No destination is sent: the server derives it from the session and returns it.
    const res = await fetch(`/api/cloudinary-signature/${kind}`, { method: "POST" });
    const { signature, timestamp, apiKey, cloudName, folder, publicId } = await res.json();

    widgetRef.current = window.cloudinary.createUploadWidget(
      {
        cloudName,
        apiKey,
        uploadSignature: signature,
        uploadSignatureTimestamp: timestamp,
        // Echo back exactly what was signed — anything else fails verification.
        folder,
        publicId,
        maxFileSize: 10_000_000, // 10 MB
        clientAllowedFormats: ["jpg", "jpeg", "png", "webp", "gif"],
        cropping: true,
        croppingAspectRatio: 1,
        showSkipCropButton: false,
      },
      (error, result) => {
        if (error) { console.error("Upload widget error", error); return; }
        if (result.event === "success") {
          onUpload(result.info.public_id, result.info.secure_url);
        }
      }
    );
  }

  return (
    <button type="button" onClick={() => widgetRef.current?.open()}>
      Upload Image
    </button>
  );
}
```

## React display with transforms

```tsx
// components/CloudinaryImage.tsx
import { AdvancedImage, lazyload, responsive, placeholder } from "@cloudinary/react";
import { cld } from "@/lib/cloudinary-client";
import { fill, thumbnail } from "@cloudinary/url-gen/actions/resize";
import { byRadius } from "@cloudinary/url-gen/actions/roundCorners";
import { quality, format } from "@cloudinary/url-gen/actions/delivery";
import { auto as autoQuality } from "@cloudinary/url-gen/qualifiers/quality";
import { auto as autoFormat } from "@cloudinary/url-gen/qualifiers/format";
import { focusOn } from "@cloudinary/url-gen/qualifiers/gravity";
import { FocusOn } from "@cloudinary/url-gen/qualifiers/focusOn";

interface CloudinaryImageProps {
  publicId: string;
  width: number;
  height: number;
  alt: string;
  variant?: "fill" | "thumb";
}

export function CloudinaryImage({ publicId, width, height, alt, variant = "fill" }: CloudinaryImageProps) {
  const image = cld
    .image(publicId)
    .resize(
      variant === "thumb"
        ? thumbnail().width(width).height(height).gravity(focusOn(FocusOn.face()))
        : fill().width(width).height(height)
    )
    .delivery(quality(autoQuality()))
    .delivery(format(autoFormat()));

  return (
    <AdvancedImage
      cldImg={image}
      alt={alt}
      plugins={[lazyload(), responsive({ steps: 200 }), placeholder({ mode: "blur" })]}
    />
  );
}
```

## Signed delivery URL (private assets)

```typescript
// Generate a time-limited signed URL for restricted assets
export function getSignedUrl(publicId: string, expiresInSeconds = 3600): string {
  const expiresAt = Math.round(Date.now() / 1000) + expiresInSeconds;
  return cloudinary.url(publicId, {
    sign_url: true,
    type: "authenticated",
    expires_at: expiresAt,
    resource_type: "image",
    secure: true,
  });
}
```

## Webhook verification

```typescript
// app/api/cloudinary-webhook/route.ts
import { NextRequest, NextResponse } from "next/server";
import { cloudinary } from "@/lib/cloudinary";

export async function POST(req: NextRequest) {
  const body = await req.text();
  const signature = req.headers.get("X-Cld-Signature");
  const timestamp = req.headers.get("X-Cld-Timestamp");

  if (!signature || !timestamp) {
    return NextResponse.json({ error: "Missing signature" }, { status: 400 });
  }

  const isValid = cloudinary.utils.verifyNotificationSignature(
    body,
    parseInt(timestamp, 10),
    signature,
    process.env.CLOUDINARY_API_SECRET!
  );

  if (!isValid) {
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  const event = JSON.parse(body);
  // Handle notification_type: "upload", "delete", "moderation", etc.
  console.log("Cloudinary event", event.notification_type, event.public_id);

  return NextResponse.json({ received: true });
}
```

## Upload presets (Cloudinary dashboard config)

```
# Unsigned preset — use only for truly public uploads (no auth)
Name: public_avatars
Signing mode: Unsigned
Allowed formats: jpg, png, webp
Max file size: 5 MB
Folder: public/avatars
Transformations: w_400,h_400,c_fill,g_face,q_auto,f_auto

# Signed preset — for server-side or signed client uploads
Name: user_uploads
Signing mode: Signed
Allowed formats: jpg, png, webp, pdf
Max file size: 20 MB
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Exposing `api_secret` in client code | Only server-side; use signed uploads with signature endpoint |
| Constructing transform URLs by string | Use SDK `@cloudinary/url-gen` builder methods |
| No `quality: "auto"` on delivery URLs | Always add `q_auto,f_auto` for 30-70% size savings |
| Width/height without crop mode | Always pair with `c_fill`, `c_thumb`, or `c_limit` |
| Unsigned preset used for auth'd uploads | Use signed uploads for any user-specific content |
| Signing a destination the caller supplied | Derive `folder` and `public_id` from the verified session; a signature over a caller-chosen path authorises writing into anyone's folder |
| Session identity used only as a fallback for a caller-supplied path | The session is the source of the path, not a default for when the caller omits one |
| Passing a caller-supplied `public_id` to `destroy` | Check the id sits under that user's derived prefix before deleting |
| Overwriting an asset in place on re-upload | Upload under a fresh `public_id`, repoint the row, then delete the old asset |
| Missing webhook signature verification | Verify `X-Cld-Signature` before processing events |
| Storing full URL instead of public_id | Store `public_id` in DB; derive URL from SDK to allow future transforms |
