import { createHash, randomBytes, randomInt, scryptSync, timingSafeEqual } from 'node:crypto';

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

export function createResetCode() {
    return String(randomInt(100000, 1000000));
}

export function hashResetCode(email, code) {
    return createHash('sha256')
        .update(`${String(email || '').trim().toLowerCase()}:${String(code || '').trim()}`)
        .digest('hex');
}
