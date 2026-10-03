import { utapi } from 'uploadthing/server'
import { createUploadthing, type FileRouter } from 'uploadthing/next'

import { getAuthenticatedUserId } from '@/lib/auth'
import { isTeacher } from '@/lib/teacher'

const f = createUploadthing()

const handleAuth = (userId: string | null) => {
  const isAuthorized = isTeacher(userId)

  if (!userId || !isAuthorized) throw new Error('Unauthorized')
  return { userId }
}

export const ourFileRouter = {
  courseImage: f({ image: { maxFileSize: '16MB', maxFileCount: 1 } })
    .middleware(async ({ req }) => handleAuth(await getAuthenticatedUserId(req)))
    .onUploadError(async error => {
      console.error('[UPLOADTHING]', error)
      await utapi.deleteFiles(error.fileKey)
    })
    .onUploadComplete(() => { }),
  courseAttachment: f(['text', 'image', 'video', 'audio', 'pdf'])
    .middleware(async ({ req }) => handleAuth(await getAuthenticatedUserId(req)))
    .onUploadError(async error => {
      console.error('[UPLOADTHING]', error)
      await utapi.deleteFiles(error.fileKey)
    })
    .onUploadComplete(() => { }),
  chapterVideo: f({ video: { maxFileCount: 1, maxFileSize: '512GB' } })
    .middleware(async ({ req }) => handleAuth(await getAuthenticatedUserId(req)))
    .onUploadError(async error => {
      console.error('[UPLOADTHING]', error)
      await utapi.deleteFiles(error.fileKey)
    })
    .onUploadComplete(() => { }),
} satisfies FileRouter

export type OurFileRouter = typeof ourFileRouter
