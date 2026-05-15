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

```typescript
// server/upload.ts
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

export async function uploadImage(
  source: string | Buffer,
  options: {
    folder?: string;
    publicId?: string;
    tags?: string[];
    overwrite?: boolean;
  } = {}
): Promise<UploadResult> {
  const result: UploadApiResponse = await cloudinary.uploader.upload(
    source as string,
    {
      resource_type: "auto",
      folder: options.folder ?? "uploads",
      public_id: options.publicId,
      tags: options.tags,
      overwrite: options.overwrite ?? false,
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

export async function deleteAsset(publicId: string): Promise<void> {
  await cloudinary.uploader.destroy(publicId, { resource_type: "image" });
}
```

## Upload from multipart form (Next.js API route)

```typescript
// app/api/upload/route.ts
import { NextRequest, NextResponse } from "next/server";
import { cloudinary } from "@/lib/cloudinary";
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

  try {
    const result = await cloudinary.uploader.upload(base64, {
      folder: `users/${session.userId}/avatars`,
      resource_type: "image",
      transformation: [{ width: 400, height: 400, crop: "fill", gravity: "face" }],
    });

    return NextResponse.json({ publicId: result.public_id, url: result.secure_url });
  } catch (err) {
    console.error("Cloudinary upload failed", err);
    return NextResponse.json({ error: "Upload failed" }, { status: 500 });
  }
}
```

## Signed upload — signature endpoint

```typescript
// app/api/cloudinary-signature/route.ts
// Browser requests a signature; server signs it without exposing api_secret
import { NextRequest, NextResponse } from "next/server";
import { cloudinary } from "@/lib/cloudinary";
import { auth } from "@/lib/auth";

export async function POST(req: NextRequest) {
  const session = await auth(req);
  if (!session) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { folder, publicId } = await req.json();

  const timestamp = Math.round(Date.now() / 1000);
  const params = {
    timestamp,
    folder: folder ?? `users/${session.userId}`,
    ...(publicId ? { public_id: publicId } : {}),
  };

  const signature = cloudinary.utils.api_sign_request(
    params,
    process.env.CLOUDINARY_API_SECRET!
  );

  return NextResponse.json({
    signature,
    timestamp,
    apiKey: process.env.CLOUDINARY_API_KEY,
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
    folder: params.folder,
  });
}
```

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
  folder?: string;
}

export function ImageUploader({ onUpload, folder = "uploads" }: ImageUploaderProps) {
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
    // Get a server-generated signature — never use unsigned uploads for auth'd users
    const res = await fetch("/api/cloudinary-signature", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ folder }),
    });
    const { signature, timestamp, apiKey, cloudName } = await res.json();

    widgetRef.current = window.cloudinary.createUploadWidget(
      {
        cloudName,
        apiKey,
        uploadSignature: signature,
        uploadSignatureTimestamp: timestamp,
        folder,
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
| Missing webhook signature verification | Verify `X-Cld-Signature` before processing events |
| Storing full URL instead of public_id | Store `public_id` in DB; derive URL from SDK to allow future transforms |
