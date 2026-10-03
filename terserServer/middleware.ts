import { NextRequest, NextResponse } from 'next/server';

// X-User-Id is accepted for legacy client preflight compatibility only; the API never trusts it.
const allowedHeaders = 'Authorization, Content-Type, Range, X-Requested-With, X-User-Id';
const allowedMethods = 'GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS';

export function middleware(request: NextRequest) {
  const origin = request.headers.get('origin');
  const allowList = (process.env.CORS_ORIGINS ?? '')
    .split(',').map((value) => value.trim()).filter(Boolean);

  if (origin && allowList.length > 0 && !allowList.includes(origin)) {
    return NextResponse.json({ error: 'Origin is not allowed' }, { status: 403 });
  }

  const response = request.method === 'OPTIONS'
    ? new NextResponse(null, { status: 204 })
    : NextResponse.next();
  if (origin && allowList.includes(origin)) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Vary', 'Origin');
  }
  response.headers.set('Access-Control-Allow-Methods', allowedMethods);
  response.headers.set('Access-Control-Allow-Headers', allowedHeaders);
  response.headers.set('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length');
  response.headers.set('Access-Control-Max-Age', '600');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'no-referrer');
  response.headers.set('Cache-Control', 'no-store');
  return response;
}

export const config = { matcher: ['/api/:path*', '/healthz'] };
