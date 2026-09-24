import { auth } from '@clerk/nextjs'
import { NextRequest, NextResponse } from 'next/server'

import { db } from '@/lib/db'
import { isTeacher } from '@/lib/teacher'
import { getCourses } from '@/Actions/get-courses'

export async function GET(req: NextRequest) {
  try {
    const { userId } = auth()
    const { searchParams } = new URL(req.url)
    const title = searchParams.get('title') || undefined
    const categoryId = searchParams.get('categoryId') || undefined

    const courses = await getCourses({
      userId: userId || '',
      title,
      categoryId,
    })

    return NextResponse.json(courses)
  } catch (error) {
    console.error('[COURSES_GET]', error)
    return new NextResponse('Internal server error', { status: 500 })
  }
}

export async function POST(req: Request) {
  try {
    const { userId } = auth()
    const { title } = await req.json()

    if (!userId || !isTeacher(userId)) {
      return new NextResponse('Unauthorized', { status: 401 })
    }

    if (!title) {
      return new NextResponse('Title is required', { status: 400 })
    }

    const course = await db.course.create({
      data: {
        title,
        userId,
      },
    })

    return NextResponse.json(course)
  } catch (error) {
    console.error('[COURSES]', error)
    return new NextResponse('Internal server error', { status: 500 })
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200 })
}
