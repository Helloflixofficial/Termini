import { auth } from "@clerk/nextjs";
import { NextResponse } from "next/server";
import { isTeacher } from "@/lib/teacher";
import { getAnalytics } from "@/Actions/get-analytics";

export async function GET() {
  try {
    const { userId } = auth();

    if (!userId || !isTeacher(userId)) {
      return new NextResponse("Unauthorized", { status: 401 });
    }

    const data = await getAnalytics(userId);

    return NextResponse.json(data);
  } catch (error) {
    console.error("[TEACHER_ANALYTICS_GET]", error);
    return new NextResponse("Internal server error", { status: 500 });
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200 });
}
