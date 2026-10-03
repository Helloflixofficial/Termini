import { Attachment, Chapter } from '@prisma/client'

import { db } from '@/lib/db'
import { isTeacher } from '@/lib/teacher'
import { createMuxPlaybackToken } from '@/lib/mux'

interface GetChapterProps {
    userId: string
    courseId: string
    chapterId: string
}

export const getChapter = async ({
    userId,
    courseId,
    chapterId,
}: GetChapterProps) => {
    try {
        const [purchase, course, chapter] = await Promise.all([
            db.purchase.findUnique({
                where: { userId_courseId: { userId, courseId } },
            }),
            db.course.findUnique({
                where: { id: courseId, isPublished: true },
                select: { price: true, userId: true },
            }),
            db.chapter.findUnique({
                where: { courseId, id: chapterId, isPublished: true },
            }),
        ])

        if (!chapter || !course) {
            throw new Error('Chapter or course no found')
        }

        const hasAccess = chapter.isFree || !!purchase || course.userId === userId || isTeacher(userId)
        const [userProgress, attachments, muxData, nextChapter] = await Promise.all([
            db.userProgress.findUnique({
                where: { userId_chapterId: { userId, chapterId } },
            }),
            (purchase || course.userId === userId || isTeacher(userId))
                ? db.attachment.findMany({ where: { courseId } })
                : Promise.resolve([] as Attachment[]),
            hasAccess
                ? db.muxData.findUnique({ where: { chapterId } })
                : Promise.resolve(null),
            hasAccess
                ? db.chapter.findFirst({
                    where: { courseId, isPublished: true, position: { gt: chapter.position } },
                    orderBy: { position: 'asc' },
                })
                : Promise.resolve(null),
        ])

        const safeChapter = hasAccess && muxData
            ? { ...chapter, videoUrl: null }
            : !hasAccess ? { ...chapter, videoUrl: null } : chapter
        const playbackToken = hasAccess && muxData?.playbackId
            ? createMuxPlaybackToken(muxData.playbackId)
            : null

        return {
            course,
            chapter: safeChapter,
            muxData: muxData ? { ...muxData, playbackToken } : null,
            purchase,
            attachments,
            nextChapter: nextChapter ? { ...nextChapter, videoUrl: null } : null,
            userProgress,
        }
    } catch (error) {
        console.log('[GET_CHAPTER]', error)
        return {
            course: null,
            chapter: null,
            muxData: null,
            attachments: [],
            purchased: false,
            nextChapter: null,
            userProgress: null,
        }
    }
}
