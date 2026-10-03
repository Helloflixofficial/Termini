import { NextResponse } from 'next/server';

export async function POST() {
  return NextResponse.json(
    { error: 'Sign-up is handled by Clerk. Demo accounts are disabled.' },
    { status: 410, headers: { 'Cache-Control': 'no-store' } },
  );
}
