import { NextResponse } from 'next/server';

export async function POST() {
  return NextResponse.json(
    { error: 'Sign-in is handled by Clerk. Demo credentials are disabled.' },
    { status: 410, headers: { 'Cache-Control': 'no-store' } },
  );
}
