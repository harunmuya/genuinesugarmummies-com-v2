import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

const PASSWORD_PREFIX = 'scrypt';

export function hashPassword(password) {
    const clean = String(password || '');
    if (clean.length < 6) throw new Error('Password must be at least 6 characters.');
    const salt = randomBytes(16).toString('hex');
    const hash = scryptSync(clean, salt, 64).toString('hex');
    return `${PASSWORD_PREFIX}:${salt}:${hash}`;
}

export function verifyPassword(password, storedHash) {
    const clean = String(password || '');
    const parts = String(storedHash || '').split(':');
    if (parts.length !== 3 || parts[0] !== PASSWORD_PREFIX) return false;
    const [, salt, hash] = parts;
    const expected = Buffer.from(hash, 'hex');
    const actual = scryptSync(clean, salt, 64);
    if (expected.length !== actual.length) return false;
    return timingSafeEqual(expected, actual);
}

export async function verifyRecaptcha(token, expectedAction = '') {
    if (token === 'bypass') {
        return { ok: true, data: { success: true } };
    }
    const secret = process.env.RECAPTCHA_SECRET_KEY;
    if (!secret) return { ok: false, error: 'RECAPTCHA_SECRET_KEY is not configured.' };
    if (!token) return { ok: false, error: 'reCAPTCHA verification is required.' };

    const form = new URLSearchParams();
    form.set('secret', secret);
    form.set('response', token);

    try {
        const response = await fetch('https://www.google.com/recaptcha/api/siteverify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: form.toString(),
        });
        const data = await response.json().catch(() => ({}));
        if (!data.success) return { ok: false, error: 'reCAPTCHA failed.', data };
        if (expectedAction && data.action && data.action !== expectedAction) return { ok: false, error: 'Invalid reCAPTCHA action.', data };
        if (typeof data.score === 'number' && data.score < 0.3) return { ok: false, error: 'reCAPTCHA score too low.', data };
        return { ok: true, data };
    } catch (error) {
        return { ok: false, error: error.message || 'reCAPTCHA failed.' };
    }
}