import { getAuthenticatedUserId } from "@/lib/auth";
import { NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { isTeacher } from '@/lib/teacher'

export async function PUT(
    req: Request,
    { params }: { params: { courseId: string; chapterId: string } },
) {
    try {
        const userId = await getAuthenticatedUserId(req);
        const { isCompleted } = await req.json()

        if (!userId) {
            return new NextResponse('Unauthorized', { status: 401 })
        }

        if (typeof isCompleted !== 'boolean') {
            return NextResponse.json({ error: 'isCompleted must be a boolean' }, { status: 400 })
        }

        const chapter = await db.chapter.findFirst({
            where: { id: params.chapterId, courseId: params.courseId, isPublished: true },
            select: { id: true, isFree: true, course: { select: { userId: true, isPublished: true } } },
        })
        if (!chapter || !chapter.course.isPublished) return new NextResponse('Not found', { status: 404 })
        const purchase = await db.purchase.findUnique({
            where: { userId_courseId: { userId, courseId: params.courseId } },
            select: { id: true },
        })
        if (!chapter.isFree && !purchase && chapter.course.userId !== userId && !isTeacher(userId)) {
            return new NextResponse('Enrollment is required', { status: 403 })
        }

        const userProgress = await db.userProgress.upsert({
            where: {
                userId_chapterId: {
                    userId,
                    chapterId: params.chapterId,
                },
            },
            update: {
                isCompleted,
            },
            create: {
                userId,
                isCompleted,
                chapterId: params.chapterId,
            },
        })

        return NextResponse.json(userProgress)
    } catch (error) {
        console.error('[CHAPTER_ID_PROGRESS]', error)
        return new NextResponse('Internal server error', { status: 500 })
    }
}
