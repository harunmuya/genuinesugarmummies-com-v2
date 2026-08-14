/**
 * Can somebody guess their way into an account?
 *
 * Nothing limited authentication attempts. Login accepted unlimited password
 * guesses against any address, and reset was worse: createResetCode returns a
 * six digit number, 900,000 possibilities, and the check ran as many times as
 * anybody cared to send. Request a reset for an address, walk the code space,
 * and the account is yours in about an hour.
 *
 * There is a second class of bug here too, and this file exists partly because
 * one was shipped. Removing password_hash from FULL_MEMBER_FIELDS, so the
 * member directory would stop pulling 240 password hashes per browse, broke
 * login_account: it selects that constant and then reads
 * result.data.password_hash. Every sign-in would have failed with "This account
 * has no password yet", and it went unnoticed only because the database was
 * refusing every request for quota at the time.
 *
 * A handler that reads a column it did not select is invisible in review and
 * total in effect, so it is checked directly.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
const api = strip(readFileSync(join('src', 'app', 'api', 'members', 'route.js'), 'utf8'));

/** The body of one action handler. */
function handler(action) {
    const start = api.indexOf(`if (action === '${action}')`);
    if (start === -1) return '';
    const next = api.indexOf('\n    if (action ===', start + 10);
    return api.slice(start, next === -1 ? start + 4000 : next);
}

console.log('\nEvery handler selects the columns it reads');
{
    /*
      The specific regression. password_hash is not in FULL_MEMBER_FIELDS any
      more, on purpose, so anything reading it has to ask for it by name.
    */
    for (const action of ['login_account', 'upsert_account']) {
        const block = handler(action);
        if (!block.includes('.password_hash')) continue;
        const selects = [...block.matchAll(/\.select\(([^)]*)\)/g)].map((m) => m[1]);
        check(`${action} selects password_hash before reading it`,
            selects.some((s) => s.includes('password_hash')),
            'FULL_MEMBER_FIELDS no longer contains it');
    }

    const full = (readFileSync(join('src', 'app', 'api', 'members', 'route.js'), 'utf8')
        .match(/const FULL_MEMBER_FIELDS = `([^`]*)`/) || [])[1] || '';
    check('the shared field list still excludes password_hash',
        !full.split(',').map((c) => c.trim()).includes('password_hash'),
        'three screens request 240 rows of this list');
}

console.log('\nGuessing is throttled');
{
    const throttle = strip(readFileSync(join('src', 'lib', 'authThrottle.js'), 'utf8'));

    for (const [action, protects] of [
        ['login_account', 'verifyPassword('],
        ['reset_password', 'hashResetCode('],
        ['request_password_reset', 'createResetCode('],
    ]) {
        const block = handler(action);
        const guard = block.indexOf('checkThrottle(');
        const target = block.indexOf(protects);
        /*
          Order is the whole point. A throttle recorded after the check still
          lets every guess through; it has to refuse before the comparison
          happens.
        */
        check(`${action} is throttled before ${protects.replace('(', '')}`,
            guard !== -1 && target !== -1 && guard < target);
    }

    check('failures are recorded', /recordAttempt\(supabase, 'login', email, false\)/.test(api));
    check('and success clears the run', /recordAttempt\(supabase, 'login', email, true\)/.test(api),
        'otherwise a few mistypes lock somebody out after they get it right');

    /*
      The reset window has to be tighter than login. The search space is small
      and known, so five wrong codes is already abnormal, while ten wrong
      passwords is a person who has forgotten which one they used.
    */
    const limit = (kind) => {
        const m = throttle.match(new RegExp(`${kind}: \\{ max: (\\d+)`));
        return m ? Number(m[1]) : null;
    };
    check('reset is tighter than login', limit('reset') < limit('login'),
        `reset ${limit('reset')}, login ${limit('login')}`);
    check('reset requests are limited too', limit('resetRequest') !== null,
        'otherwise fresh codes can be issued to widen the pool of valid ones');

    /*
      A throttle that cannot be read must not lock everybody out. Failing
      closed here would turn a missing table into a total outage.
    */
    check('it fails open', /return \{ blocked: false \};[\s\S]*catch/.test(throttle));

    check('attempts are stored per address, not per IP',
        /scopeFor\(kind, identifier\)/.test(throttle),
        'blocking an IP takes out everyone behind a shared mobile connection');
}

console.log('\nThe attempts table is not readable by members');
{
    const migration = readFileSync(
        join('supabase', 'migrations', '20260813_040_auth_attempt_throttle.sql'), 'utf8');
    check('row level security is on', /enable row level security/.test(migration));
    check('and anon is revoked', /revoke all on public\.auth_attempts from anon/.test(migration),
        'it would otherwise reveal which addresses have accounts');
    check('old rows are pruned', /prune_auth_attempts/.test(migration),
        'it grows on every sign-in');
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;
