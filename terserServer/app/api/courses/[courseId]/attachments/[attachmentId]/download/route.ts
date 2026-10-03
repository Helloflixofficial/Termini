import { getAuthenticatedUserId } from "@/lib/auth";
import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(
  req: Request,
  { params }: { params: { courseId: string; attachmentId: string } },
) {
  try {
    const userId = await getAuthenticatedUserId(req);
    if (!userId) return new NextResponse('Unauthorized', { status: 401 })

    const attachment = await db.attachment.findUnique({
      where: { id: params.attachmentId, courseId: params.courseId },
      include: { course: { select: { userId: true } } },
    })
    if (!attachment) return new NextResponse('File not found', { status: 404 })

    const purchase = await db.purchase.findUnique({
      where: { userId_courseId: { userId, courseId: params.courseId } },
      select: { id: true },
    })
    const isOwner = attachment.course.userId === userId
    if (!purchase && !isOwner) return new NextResponse('Forbidden', { status: 403 })

    const fileUrl = new URL(attachment.url)
    const storageHosts = ['utfs.io', 'ufs.sh', 'uploadthing.com']
    if (fileUrl.protocol !== 'https:' || !storageHosts.some((host) => fileUrl.hostname === host || fileUrl.hostname.endsWith(`.${host}`))) {
      return new NextResponse('File host is not allowed', { status: 502 })
    }
    const fileResponse = await fetch(fileUrl, { redirect: 'error', signal: AbortSignal.timeout(15000) })
    if (!fileResponse.ok || !fileResponse.body) {
      return new NextResponse('Unable to download file', { status: 502 })
    }

    const filename = (attachment.name || 'course-file').replace(/[^a-zA-Z0-9._() -]/g, '_')
    const headers = new Headers()
    headers.set('Content-Type', fileResponse.headers.get('content-type') || 'application/octet-stream')
    headers.set('Content-Disposition', `attachment; filename="${filename}"`)
    const length = fileResponse.headers.get('content-length')
    if (length) headers.set('Content-Length', length)

    return new NextResponse(fileResponse.body, { headers })
  } catch (error) {
    console.error('[ATTACHMENT_DOWNLOAD]', error)
    return new NextResponse('Unable to download file', { status: 500 })
  }
}
