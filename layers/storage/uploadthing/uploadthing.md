# UploadThing Standards

---

## Setup

```bash
npm install uploadthing @uploadthing/react
```

---

## Upload router (server)

```typescript
// src/app/api/uploadthing/core.ts
import { createUploadthing, type FileRouter } from 'uploadthing/next'
import { getCurrentUser } from '@/lib/auth'
import { db } from '@/lib/db'

const f = createUploadthing()

export const ourFileRouter = {
  // Profile photo upload
  profilePhoto: f({
    image: {
      maxFileSize: '4MB',
      maxFileCount: 1,
    },
  })
    .middleware(async ({ req }) => {
      // Auth check — always required
      const user = await getCurrentUser()
      if (!user) throw new Error('Unauthorised')

      // Return metadata — passed to onUploadComplete, trusted server-side
      return { userId: user.id }
    })
    .onUploadComplete(async ({ metadata, file }) => {
      // Save to DB after successful upload
      await db.users.update({
        where: { id: metadata.userId },
        data:  { avatarUrl: file.url },
      })

      // Return value is sent back to the client onClientUploadComplete
      return { avatarUrl: file.url }
    }),

  // Document upload — multiple files
  orderDocuments: f({
    pdf:   { maxFileSize: '16MB', maxFileCount: 5 },
    image: { maxFileSize: '8MB',  maxFileCount: 10 },
  })
    .middleware(async ({ req }) => {
      const user = await getCurrentUser()
      if (!user) throw new Error('Unauthorised')

      // Pass orderId from request headers
      const orderId = req.headers.get('x-order-id')
      if (!orderId) throw new Error('Order ID required')

      // Validate the order belongs to the user
      const order = await db.orders.findUnique({ where: { id: orderId, userId: user.id } })
      if (!order) throw new Error('Order not found')

      return { userId: user.id, orderId }
    })
    .onUploadComplete(async ({ metadata, file }) => {
      await db.orderDocuments.create({
        data: {
          orderId:  metadata.orderId,
          userId:   metadata.userId,
          url:      file.url,
          fileKey:  file.key,
          fileName: file.name,
          fileSize: file.size,
          fileType: file.type,
        },
      })

      return { documentId: file.key }
    }),
} satisfies FileRouter

export type OurFileRouter = typeof ourFileRouter
```

---

## Route handler

```typescript
// src/app/api/uploadthing/route.ts
import { createRouteHandler } from 'uploadthing/next'
import { ourFileRouter } from './core'

export const { GET, POST } = createRouteHandler({
  router: ourFileRouter,
  config: {
    // Optional: callback URL for webhooks
    callbackUrl: `${process.env.NEXT_PUBLIC_APP_URL}/api/uploadthing`,
  },
})
```

---

## React client — built-in components

```tsx
// src/components/ProfilePhotoUpload.tsx
'use client'
import { UploadButton, UploadDropzone } from '@uploadthing/react'
import type { OurFileRouter } from '@/app/api/uploadthing/core'

interface Props {
  onUploadComplete: (url: string) => void
}

export function ProfilePhotoUpload({ onUploadComplete }: Props) {
  return (
    <UploadDropzone<OurFileRouter, 'profilePhoto'>
      endpoint="profilePhoto"
      onClientUploadComplete={(res) => {
        // res is the return value of onUploadComplete on the server
        const avatarUrl = res[0]?.serverData?.avatarUrl
        if (avatarUrl) onUploadComplete(avatarUrl)
      }}
      onUploadError={(error) => {
        // Show user-friendly error — not the raw error message
        const message = error.code === 'TOO_LARGE'
          ? 'File is too large. Maximum size is 4 MB.'
          : 'Upload failed. Please try again.'
        alert(message)
      }}
      appearance={{
        container: 'border-2 border-dashed border-gray-300 rounded-lg p-8',
        label:     'text-sm text-gray-600',
        button:    'bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700',
      }}
    />
  )
}
```

---

## React client — custom hook

```tsx
// src/components/DocumentUploader.tsx
'use client'
import { useState } from 'react'
import { useUploadThing } from '@uploadthing/react'
import type { OurFileRouter } from '@/app/api/uploadthing/core'

interface Props {
  orderId: string
  onComplete: (urls: string[]) => void
}

export function DocumentUploader({ orderId, onComplete }: Props) {
  const [progress, setProgress] = useState(0)

  const { startUpload, isUploading } = useUploadThing<OurFileRouter>('orderDocuments', {
    headers: {
      'x-order-id': orderId,   // passed to middleware via req.headers
    },
    onUploadProgress: (p) => setProgress(p),
    onClientUploadComplete: (res) => {
      const urls = res.map((r) => r.url)
      onComplete(urls)
      setProgress(0)
    },
    onUploadError: (error) => {
      console.error('Upload error:', error)
      alert('Failed to upload document. Please try again.')
    },
  })

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? [])
    if (files.length) startUpload(files)
  }

  return (
    <div>
      <input
        type="file"
        accept=".pdf,image/*"
        multiple
        onChange={handleFileChange}
        disabled={isUploading}
      />
      {isUploading && (
        <div>
          <progress value={progress} max={100} />
          <span>{progress}%</span>
        </div>
      )}
    </div>
  )
}
```

---

## UTApi — server-side file management

```typescript
// src/lib/uploadthing.ts
import { UTApi } from 'uploadthing/server'

export const utapi = new UTApi()

// Delete files when a record is deleted
export async function deleteUploadedFile(fileKey: string) {
  await utapi.deleteFiles(fileKey)
}

// Get file URLs (useful for signed/private files)
export async function getFileUrl(fileKey: string) {
  const response = await utapi.getFileUrls([fileKey])
  return response.data[0]?.url
}

// List all files (for admin)
export async function listFiles() {
  return utapi.listFiles()
}
```

---

## Delete on record removal

```typescript
// src/features/users/user.service.ts
import { utapi } from '@/lib/uploadthing'

export async function deleteUser(userId: string) {
  const user = await db.users.findUnique({ where: { id: userId } })

  // Delete uploaded files first
  if (user?.avatarFileKey) {
    await utapi.deleteFiles(user.avatarFileKey)
  }

  // Then delete the record
  await db.users.delete({ where: { id: userId } })
}
```

---

## Environment variables

```bash
UPLOADTHING_SECRET=sk_live_...   # from uploadthing.com dashboard
UPLOADTHING_APP_ID=...           # your app ID
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| No `middleware` auth check | Anyone can upload — always validate the session in middleware |
| Getting file URL from client `file.url` and trusting it | Get the URL from `onUploadComplete` on the server — it's verified |
| No `onUploadError` handler | Silent failures — users don't know what went wrong |
| Storing `fileKey` as the public document ID | Use your DB record ID; `fileKey` is internal to UploadThing |
| Not deleting files when records are deleted | Orphaned files accumulate costs — always `utapi.deleteFiles()` on record deletion |
| Accepting any file type without restriction | Always set `maxFileSize` and explicit `acceptedFileTypes` in the route config |
