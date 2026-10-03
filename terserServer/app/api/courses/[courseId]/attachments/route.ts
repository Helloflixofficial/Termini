import { getAuthenticatedUserId } from "@/lib/auth";
import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { isTeacher } from "@/lib/teacher";
import { safeImageUrl } from "@/lib/validation";

export async function POST(
  req: Request,
  { params }: { params: { courseId: string } }
) {
  try {
    const userId = await getAuthenticatedUserId(req);
    const body = await req.json();
    const url = safeImageUrl(body?.url);

    if (!userId || !isTeacher(userId)) {
      return new NextResponse("Unauthorized", { status: 401 });
    }

    const courseOwner = await db.course.findUnique({
      where: {
        id: params.courseId,
        userId: userId,
      },
    });

    if (!courseOwner) {
      return new NextResponse("Unauthorized", { status: 401 });
    }
    if (!url) return NextResponse.json({ error: "Attachment must be a secure HTTPS upload URL" }, { status: 400 });

    const attachment = await db.attachment.create({
      data: {
        url,
        name: new URL(url).pathname.split("/").filter(Boolean).pop() || "course-file",
        courseId: params && params.courseId, // Add a check for params and courseId
      },
    });

    return NextResponse.json(attachment);
  } catch (error) {
    console.log("COURSE_ID_ATTACHMENTS", error);
    return new NextResponse("Internal Error", { status: 500 });
  }
}
