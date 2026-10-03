import { Clerk, verifyToken } from '@clerk/backend';

/** Verifies the Clerk session JWT used by the Flutter client.
 * The client currently prefixes it with `clerk_session_`; strip only that
 * legacy marker. Never trust caller-supplied user IDs or demo tokens.
 */
export async function getAuthenticatedUserId(request: Request): Promise<string | null> {
  const authorization = request.headers.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return null;
  let token = authorization.slice(7).trim();
  if (token.startsWith('clerk_session_')) token = token.slice('clerk_session_'.length);
  if (!token || token.startsWith('demo_') || token.startsWith('session_token_')) return null;

  const secretKey = process.env.CLERK_SECRET_KEY;
  if (!secretKey) throw new Error('CLERK_SECRET_KEY is not configured');
  const issuer = process.env.CLERK_JWT_ISSUER;
  if (!issuer) throw new Error('CLERK_JWT_ISSUER is not configured');
  try {
    const claims = await verifyToken(token, { secretKey, issuer });
    return typeof claims.sub === 'string' && claims.sub.length > 0 ? claims.sub : null;
  } catch {
    return null;
  }
}

export function clerkApi() {
  const secretKey = process.env.CLERK_SECRET_KEY;
  if (!secretKey) throw new Error('CLERK_SECRET_KEY is not configured');
  return Clerk({ secretKey });
}

export function unauthorized() {
  return Response.json({ error: 'Authentication required' }, { status: 401, headers: { 'Cache-Control': 'no-store' } });
}
