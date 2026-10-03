import { NextResponse } from 'next/server';
import { getAuthenticatedUserId } from '@/lib/auth';
import { db } from '@/lib/db';
import { isTeacher } from '@/lib/teacher';
import { createMuxPlaybackToken } from '@/lib/mux';

type Context = { params: { id: string } };
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: Request, { params }: Context) {
  return streamRedirect(request, params.id);
}

export async function HEAD(request: Request, { params }: Context) {
  return streamRedirect(request, params.id, true);
}

async function streamRedirect(request: Request, chapterId: string, head = false) {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) return NextResponse.json({ error: 'Authentication required' }, { status: 401 });
  try {
    const chapter = await db.chapter.findUnique({
      where: { id: chapterId },
      include: { course: { include: { purchases: { where: { userId }, select: { id: true } } } }, muxData: true },
    });
    if (!chapter || !chapter.course.isPublished || (!chapter.isPublished && !isTeacher(userId))) {
      return NextResponse.json({ error: 'Video not found' }, { status: 404 });
    }
    const canAccess = isTeacher(userId) || chapter.isFree || chapter.course.purchases.length > 0;
    if (!canAccess) return NextResponse.json({ error: 'Enrollment is required' }, { status: 403 });

    let destination = chapter.videoUrl;
    if (chapter.muxData?.playbackId) {
      const token = createMuxPlaybackToken(chapter.muxData.playbackId);
      destination = `https://stream.mux.com/${encodeURIComponent(chapter.muxData.playbackId)}.m3u8?token=${encodeURIComponent(token)}`;
    }
    if (!destination) return NextResponse.json({ error: 'Video is not available' }, { status: 404 });
    const url = new URL(destination);
    const mediaHosts = ['utfs.io', 'ufs.sh', 'uploadthing.com'];
    const isAllowedMediaHost = mediaHosts.some((host) => url.hostname === host || url.hostname.endsWith(`.${host}`));
    if (url.protocol !== 'https:' || url.username || url.password || (!chapter.muxData?.playbackId && !isAllowedMediaHost)) {
      return NextResponse.json({ error: 'Video source is not valid' }, { status: 502 });
    }
    return NextResponse.redirect(url, { status: 307, headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('[VIDEO_REDIRECT]', error instanceof Error ? error.name : 'unknown');
    return NextResponse.json({ error: 'Unable to authorize video' }, { status: 500 });
  }
}
