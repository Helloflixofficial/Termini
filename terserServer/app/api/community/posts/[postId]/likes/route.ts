import { NextResponse } from 'next/server';
import { getAuthenticatedUserId } from '@/lib/auth';
import { db } from '@/lib/db';
import { getCommunityOwnerId } from '@/lib/community';
import { isTeacher } from '@/lib/teacher';

type Context = { params: { postId: string } };
export const runtime = 'nodejs';

export async function POST(request: Request, { params }: Context) {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) return NextResponse.json({ error: 'Authentication required' }, { status: 401 });
  const ownerId = isTeacher(userId) ? userId : getCommunityOwnerId();
  if (!ownerId) return NextResponse.json({ error: 'Community owner is not configured' }, { status: 503 });

  try {
    const post = await db.communityPost.findFirst({
      where: { id: params.postId, ownerId, ...(isTeacher(userId) ? {} : { isApproved: true }) },
      select: { id: true },
    });
    if (!post) return NextResponse.json({ error: 'Post not found' }, { status: 404 });

    const existing = await db.communityLike.findUnique({ where: { userId_postId: { userId, postId: post.id } } });
    if (existing) {
      await db.communityLike.delete({ where: { id: existing.id } });
    } else {
      await db.communityLike.create({ data: { userId, ownerId, postId: post.id } });
    }
    const [likesCount, isLikedByMe] = await Promise.all([
      db.communityLike.count({ where: { postId: post.id } }),
      db.communityLike.findUnique({ where: { userId_postId: { userId, postId: post.id } }, select: { id: true } }),
    ]);
    return NextResponse.json({ likesCount, isLikedByMe: Boolean(isLikedByMe) });
  } catch (error) {
    if (error && typeof error === 'object' && 'code' in error && error.code === 'P2002') {
      const likesCount = await db.communityLike.count({ where: { postId: params.postId } });
      return NextResponse.json({ likesCount, isLikedByMe: true });
    }
    console.error('[COMMUNITY_LIKE_POST]', error instanceof Error ? error.name : 'unknown');
    return NextResponse.json({ error: 'Unable to update like' }, { status: 500 });
  }
}
