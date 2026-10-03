import { db } from "@/lib/db";

export const DEFAULT_COMMUNITY_SPACES = [
  { name: "Announcements", slug: "announcements", description: "Important updates and news for your community.", color: "#bd8956" },
  { name: "General", slug: "general", description: "A welcoming place for everyday conversation.", color: "#6b8f71" },
  { name: "Questions & Help", slug: "questions-help", description: "Ask questions, share wins, and help each other move forward.", color: "#6a82a8" },
] as const;

export function getCommunityOwnerId() {
  return (process.env.TEACHER_IDS || "").split(",")[0]?.trim() || null;
}

export async function ensureCommunitySpaces(ownerId: string) {
  const existing = await db.communitySpace.findMany({
    where: { ownerId },
    orderBy: { createdAt: "asc" },
    include: { _count: { select: { posts: true } } },
  });

  const existingSlugs = new Set(existing.map((space) => space.slug));
  const missingSpaces = DEFAULT_COMMUNITY_SPACES.filter((space) => !existingSlugs.has(space.slug));
  if (missingSpaces.length === 0) return existing;

  await db.communitySpace.createMany({
    data: missingSpaces.map((space) => ({ ...space, ownerId })),
    skipDuplicates: true,
  });

  return db.communitySpace.findMany({
    where: { ownerId },
    orderBy: { createdAt: "asc" },
    include: { _count: { select: { posts: true } } },
  });
}

export async function ensureCommunitySettings(ownerId: string) {
  const existing = await db.communitySettings.findUnique({ where: { ownerId } });
  if (existing) return existing;

  try {
    return await db.communitySettings.create({ data: { ownerId } });
  } catch (error: any) {
    if (error?.code === "P2002") {
      const createdByAnotherRequest = await db.communitySettings.findUnique({ where: { ownerId } });
      if (createdByAnotherRequest) return createdByAnotherRequest;
    }
    throw error;
  }
}

export function slugify(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 50);
}

export function serializeCommunityPost(post: any) {
  return {
    id: post.id,
    title: post.title,
    content: post.content,
    authorId: post.authorId,
    ownerId: post.ownerId,
    spaceId: post.spaceId,
    isPinned: post.isPinned,
    isAnnouncement: post.isAnnouncement,
    isApproved: post.isApproved,
    createdAt: post.createdAt.toISOString(),
    updatedAt: post.updatedAt.toISOString(),
    mediaUrl: post.mediaUrl ?? null,
    mediaType: post.mediaType ?? null,
    linkUrl: post.linkUrl ?? null,
    linkTitle: post.linkTitle ?? null,
    authorName: post.authorName ?? null,
    authorImageUrl: post.authorImageUrl ?? null,
    likesCount: post._count?.likes ?? post.likes?.length ?? 0,
    isLikedByMe: Boolean(post.isLikedByMe ?? post.likes?.length),
    commentsCount: post._count?.comments ?? post.comments?.length ?? 0,
    space: post.space ? {
      id: post.space.id,
      name: post.space.name,
      color: post.space.color,
    } : null,
    comments: (post.comments || []).map((comment: any) => ({
      id: comment.id,
      content: comment.content,
      authorId: comment.authorId,
      authorName: comment.authorName ?? null,
      authorImageUrl: comment.authorImageUrl ?? null,
      createdAt: comment.createdAt.toISOString(),
    })),
  };
}
