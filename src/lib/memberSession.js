import { createHmac, timingSafeEqual, randomBytes } from 'node:crypto';

export const MEMBER_SESSION_COOKIE = 'gs_member_session';
export const MEMBER_SESSION_MAX_AGE = 7 * 24 * 60 * 60;

function sessionSecret() {
    return process.env.MEMBER_SESSION_SECRET || process.env.SUPABASE_SERVICE_ROLE_KEY || '';
}

function signature(value) {
    const secret = sessionSecret();
    return secret ? createHmac('sha256', secret).update(value).digest('base64url') : '';
}

export function createMemberSessionToken(userId, now = Date.now()) {
    if (!sessionSecret() || !userId) return null;
    const payload = Buffer.from(JSON.stringify({
        sub: String(userId),
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + MEMBER_SESSION_MAX_AGE,
        nonce: randomBytes(12).toString('base64url'),
    })).toString('base64url');
    return `${payload}.${signature(payload)}`;
}

export function getMemberSessionUserId(request, now = Date.now()) {
    const cookieHeader = request?.headers?.get?.('cookie') || '';
    const token = cookieHeader.split(';').map((part) => part.trim())
        .find((part) => part.startsWith(`${MEMBER_SESSION_COOKIE}=`))
        ?.slice(MEMBER_SESSION_COOKIE.length + 1);
    if (!token || !sessionSecret()) return null;

    const [payload, providedSignature, extra] = token.split('.');
    if (!payload || !providedSignature || extra !== undefined) return null;
    const expectedSignature = signature(payload);
    const provided = Buffer.from(providedSignature);
    const expected = Buffer.from(expectedSignature);
    if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) return null;

    try {
        const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
        const current = Math.floor(now / 1000);
        if (!claims.sub || !Number.isInteger(claims.exp) || claims.exp <= current || claims.iat > current + 60) return null;
        return String(claims.sub);
    } catch {
        return null;
    }
}

export function setMemberSession(response, userId) {
    const value = createMemberSessionToken(userId);
    if (!value) return false;
    response.cookies.set(MEMBER_SESSION_COOKIE, value, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: MEMBER_SESSION_MAX_AGE,
    });
    return true;
}

export function clearMemberSession(response) {
    response.cookies.set(MEMBER_SESSION_COOKIE, '', {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 0,
    });
}
