import Mux from "@mux/mux-node";
import { getAuthenticatedUserId } from "@/lib/auth";
import { NextResponse } from "next/server";

import { db } from "@/lib/db";
import { isTeacher } from "@/lib/teacher";
import { createMuxPlaybackToken } from "@/lib/mux";

function muxVideo() {
  const tokenId = process.env.MUX_TOKEN_ID;
  const tokenSecret = process.env.MUX_TOKEN_SECRET;
  if (!tokenId || !tokenSecret) throw new Error("Mux is not configured");
  return new Mux(tokenId, tokenSecret).Video;
}

export async function DELETE(
  req: Request,
  { params }: { params: { courseId: string; chapterId: string } }
) {
  try {
    const Video = muxVideo();
    const userId = await getAuthenticatedUserId(req);
    const { courseId, chapterId } = params;

    if (!userId || !isTeacher(userId)) {
      return new NextResponse("Unauthorized", { status: 401 });
    }

    const courseOwner = await db.course.findUnique({
      where: {
        userId,
        id: courseId,
        chapters: {
          some: {
            id: chapterId,
          },
        },
      },
    });

    if (!courseOwner) {
      return new NextResponse("Unauthorized", { status: 401 });
    }

    const chapter = await db.chapter.findUnique({
      where: {
        courseId,
        id: chapterId,
      },
    });

    if (!chapter) {
      return new NextResponse("Not found", { status: 404 });
    }

    if (chapter.videoUrl) {
      const existingMuxDate = await db.muxData.findFirst({
        where: {
          chapterId,
        },
      });

      if (existingMuxDate) {
        const video = await Video.Assets.get(existingMuxDate.assetId);

        if (video) {
          await Video.Assets.del(existingMuxDate.assetId);
        }

        await db.muxData.delete({
          where: {
            id: existingMuxDate.id,
          },
        });
      }
    }

    const deletedChapter = await db.chapter.delete({
      where: {
        courseId,
        id: chapterId,
      },
    });

    const publishedChapterInCourse = await db.chapter.findMany({
      where: {
        courseId,
        isPublished: true,
      },
    });

    if (!publishedChapterInCourse.length) {
      await db.course.update({
        where: {
          id: courseId,
        },
        data: {
          isPublished: false,
        },
      });
    }

    return NextResponse.json(deletedChapter);
  } catch (error) {
    console.error("[CHAPTER_ID_DELETE]", error);
    return new NextResponse("Internal server error", { status: 500 });
  }
}

export async function PATCH(
  req: Request,
  { params }: { params: { courseId: string; chapterId: string } }
) {
  try {
    const Video = muxVideo();
    const userId = await getAuthenticatedUserId(req);
    const { courseId, chapterId } = params;
    const { isPublished, ...values } = await req.json();

    if (!userId) {
      return new NextResponse("Unauthorized", { status: 401 });
    }

    const courseOwner = await db.course.findUnique({
      where: {
        userId,
        id: courseId,
        chapters: {
          some: {
            id: chapterId,
          },
        },
      },
    });

    if (!courseOwner) {
      return new NextResponse("Unauthorized", { status: 401 });
    }

    const chapter = await db.chapter.update({
      where: {
        courseId,
        id: chapterId,
      },
      data: {
        ...values,
      },
    });

    if (values.videoUrl) {
      const existingMuxDate = await db.muxData.findFirst({
        where: {
          chapterId,
        },
      });

      if (existingMuxDate) {
        await Video.Assets.del(existingMuxDate.assetId);
        await db.muxData.delete({
          where: {
            id: existingMuxDate.id,
          },
        });
      }

      const asset = await Video.Assets.create({
        test: false,
        input: values.videoUrl,
        playback_policy: "signed",
      });

      await db.muxData.create({
        data: {
          chapterId,
          assetId: asset.id,
          playbackId: asset.playback_ids?.[0]?.id,
        },
      });
    }

    return NextResponse.json(chapter);
  } catch (error) {
    console.error("[COURSE_CHAPTER_ID]", error);
    return new NextResponse("Internal server error", { status: 500 });
  }
}

export async function GET(
  req: Request,
  { params }: { params: { courseId: string; chapterId: string } }
) {
  try {
    const userId = await getAuthenticatedUserId(req);
    const { courseId, chapterId } = params;

    const data = await import("@/Actions/get-chapters").then((m) =>
      m.getChapter({
        userId: userId || "",
        courseId,
        chapterId,
      })
    );

    if (!data.chapter) {
      return new NextResponse("Not found", { status: 404 });
    }

    if (data.muxData?.playbackId) {
      data.muxData = { ...data.muxData, playbackToken: createMuxPlaybackToken(data.muxData.playbackId) };
      data.chapter.videoUrl = null;
    }
    return NextResponse.json(data);
  } catch (error) {
    console.error("[CHAPTER_ID_GET]", error);
    return new NextResponse("Internal server error", { status: 500 });
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200 });
}
