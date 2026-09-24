import { auth } from "@clerk/nextjs";
import { NextResponse } from "next/server";
import { getDashboardCourses } from "@/Actions/get-dashboard-courses";

export async function GET() {
  try {
    const { userId } = auth();

    if (!userId) {
      return new NextResponse("Unauthorized", { status: 401 });
    }

    const { completedCourses, coursesInProgress } = await getDashboardCourses(userId);

    return NextResponse.json({
      completedCourses,
      coursesInProgress,
    });
  } catch (error) {
    console.error("[DASHBOARD_GET]", error);
    return new NextResponse("Internal server error", { status: 500 });
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200 });
}
