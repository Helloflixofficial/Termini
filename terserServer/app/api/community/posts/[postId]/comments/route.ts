import { getAuthenticatedUserId } from "@/lib/auth";
import { NextResponse } from "next/server";

import { db } from "@/lib/db";
import { ensureCommunitySettings, getCommunityOwnerId } from "@/lib/community";
import { isTeacher } from "@/lib/teacher";
import { clerkApi } from "@/lib/auth";

type Context = { params: { postId: string } };

export const runtime = "nodejs";

export async function GET(req: Request, { params }: Context) {
  const userId = await getAuthenticatedUserId(req);
  if (!userId) return NextResponse.json({ error: "Authentication required" }, { status: 401 });
  const ownerId = isTeacher(userId) ? userId : getCommunityOwnerId();
  if (!ownerId) return NextResponse.json({ error: "Community owner is not configured" }, { status: 503 });
  try {
    const post = await db.communityPost.findFirst({
      where: { id: params.postId, ownerId, ...(isTeacher(userId) ? {} : { isApproved: true }) },
      select: { id: true },
    });
    if (!post) return NextResponse.json({ error: "Post not found" }, { status: 404 });
    const comments = await db.communityComment.findMany({ where: { postId: post.id }, orderBy: { createdAt: "asc" }, take: 200 });
    return NextResponse.json(comments);
  } catch (error) {
    console.error("[COMMUNITY_COMMENTS_GET]", error instanceof Error ? error.name : "unknown");
    return NextResponse.json({ error: "Unable to load comments" }, { status: 500 });
  }
}

export async function POST(req: Request, { params }: Context) {
  const userId = await getAuthenticatedUserId(req);
  const isAdmin = !!userId && isTeacher(userId);
  const ownerId = isAdmin ? userId : getCommunityOwnerId();
  if (!userId || !ownerId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  try {
    const settings = await ensureCommunitySettings(ownerId);
    if (!isAdmin && !settings.allowStudentComments) return NextResponse.json({ error: "Student comments are currently disabled" }, { status: 403 });
    const body = await req.json();
    const content = typeof body.content === "string" ? body.content.trim() : "";
    if (!content || content.length > 2000) return NextResponse.json({ error: "Comment must be between 1 and 2,000 characters" }, { status: 400 });

    const post = await db.communityPost.findFirst({ where: { id: params.postId, ownerId, ...(isAdmin ? {} : { isApproved: true }) } });
    if (!post) return NextResponse.json({ error: "Post not found" }, { status: 404 });

    const profile = await clerkApi().users.getUser(userId);
    const authorName = [profile.firstName, profile.lastName].filter(Boolean).join(" ").slice(0, 80) || "Learner";
    const comment = await db.communityComment.create({
      data: {
        content,
        postId: post.id,
        ownerId,
        authorId: userId,
        authorName,
        authorImageUrl: profile.imageUrl,
      },
    });
    return NextResponse.json({ ...comment, createdAt: comment.createdAt.toISOString() }, { status: 201 });
  } catch (error) {
    console.error("[COMMUNITY_COMMENT_POST]", error);
    return NextResponse.json({ error: "Unable to add comment" }, { status: 500 });
  }
}
