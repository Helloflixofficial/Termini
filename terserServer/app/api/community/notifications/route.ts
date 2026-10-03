import { NextResponse } from 'next/server';
import { getAuthenticatedUserId } from '@/lib/auth';
import { db } from '@/lib/db';
import { getCommunityOwnerId, serializeCommunityPost } from '@/lib/community';
import { isTeacher } from '@/lib/teacher';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) return NextResponse.json({ error: 'Authentication required' }, { status: 401 });
  const ownerId = isTeacher(userId) ? userId : getCommunityOwnerId();
  if (!ownerId) return NextResponse.json({ error: 'Community owner is not configured' }, { status: 503 });

  try {
    const posts = await db.communityPost.findMany({
      where: { ownerId, isApproved: true, authorId: { not: userId } },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        space: { select: { id: true, name: true, color: true } },
        comments: { orderBy: { createdAt: 'asc' }, take: 10 },
        _count: { select: { likes: true, comments: true } },
        likes: { where: { userId }, select: { id: true }, take: 1 },
      },
    });
    return NextResponse.json(posts.map(serializeCommunityPost));
  } catch (error) {
    console.error('[COMMUNITY_NOTIFICATIONS_GET]', error instanceof Error ? error.name : 'unknown');
    return NextResponse.json({ error: 'Unable to load community notifications' }, { status: 500 });
  }
}
