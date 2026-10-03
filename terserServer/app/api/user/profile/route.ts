import { NextResponse } from 'next/server';
import { clerkApi, getAuthenticatedUserId } from '@/lib/auth';
import { db } from '@/lib/db';
import { isTeacher } from '@/lib/teacher';
import { readJsonObject } from '@/lib/validation';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) return NextResponse.json({ error: 'Authentication required' }, { status: 401 });

  try {
    const [profile, enrolledCoursesCount, completedChaptersCount] = await Promise.all([
      clerkApi().users.getUser(userId),
      db.purchase.count({ where: { userId } }),
      db.userProgress.count({ where: { userId, isCompleted: true } }),
    ]);
    const joinedDate = new Date(profile.createdAt).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    return NextResponse.json({
      id: userId,
      email: profile.emailAddresses.find((email) => email.id === profile.primaryEmailAddressId)?.emailAddress ?? profile.emailAddresses[0]?.emailAddress ?? '',
      firstName: profile.firstName ?? '',
      lastName: profile.lastName ?? '',
      bio: typeof profile.publicMetadata.bio === 'string' ? profile.publicMetadata.bio : '',
      imageUrl: profile.imageUrl,
      isTeacher: isTeacher(userId),
      joinedDate,
      stats: { enrolledCoursesCount, completedChaptersCount, certificatesCount: 0, hoursLearned: 0 },
    });
  } catch (error) {
    console.error('[USER_PROFILE_GET]', error instanceof Error ? error.name : 'unknown');
    return NextResponse.json({ error: 'Unable to load profile' }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) return NextResponse.json({ error: 'Authentication required' }, { status: 401 });
  const body = await readJsonObject(request, 8 * 1024);
  if (!body) return NextResponse.json({ error: 'Invalid or oversized JSON body' }, { status: 400 });

  const firstName = typeof body.firstName === 'string' ? body.firstName.trim() : undefined;
  const lastName = typeof body.lastName === 'string' ? body.lastName.trim() : undefined;
  const bio = typeof body.bio === 'string' ? body.bio.trim() : undefined;
  if ((firstName !== undefined && firstName.length > 80) || (lastName !== undefined && lastName.length > 80) || (bio !== undefined && bio.length > 500)) {
    return NextResponse.json({ error: 'Profile fields exceed their allowed length' }, { status: 400 });
  }
  if (body.imageUrl !== undefined) {
    return NextResponse.json({ error: 'Update profile photos through Clerk’s profile image upload.' }, { status: 400 });
  }

  try {
    const client = clerkApi();
    const profile = await client.users.updateUser(userId, {
      ...(firstName !== undefined ? { firstName } : {}),
      ...(lastName !== undefined ? { lastName } : {}),
    });
    if (bio !== undefined) await client.users.updateUserMetadata(userId, { publicMetadata: { bio } });
    const [enrolledCoursesCount, completedChaptersCount] = await Promise.all([
      db.purchase.count({ where: { userId } }),
      db.userProgress.count({ where: { userId, isCompleted: true } }),
    ]);
    return NextResponse.json({
      id: userId,
      email: profile.emailAddresses.find((email) => email.id === profile.primaryEmailAddressId)?.emailAddress ?? '',
      firstName: profile.firstName ?? '',
      lastName: profile.lastName ?? '',
      bio: bio ?? (typeof profile.publicMetadata.bio === 'string' ? profile.publicMetadata.bio : ''),
      imageUrl: profile.imageUrl,
      isTeacher: isTeacher(userId),
      joinedDate: new Date(profile.createdAt).toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
      stats: { enrolledCoursesCount, completedChaptersCount, certificatesCount: 0, hoursLearned: 0 },
    });
  } catch (error) {
    console.error('[USER_PROFILE_PUT]', error instanceof Error ? error.name : 'unknown');
    return NextResponse.json({ error: 'Unable to save profile' }, { status: 500 });
  }
}
