/**
 * Are repeat reads still going all the way to Supabase?
 *
 * The usage page that triggered this work showed 6.03 GB of egress against
 * 0.002 GB of cached egress. Almost nothing was served twice from anywhere.
 *
 * Slowing the polls fixed the frequency but not the duplication. Discover,
 * matches and members each request /api/members with per_page=240, which is 240
 * rows of a 52 column select, so moving between those three tabs fetched the
 * same payload three times over. Several components also mount together and ask
 * for the same URL in the same tick, which a TTL cache alone cannot help with
 * because none of the requests has returned yet to populate it.
 *
 * cachedFetch handles both. This checks it is actually wired in, and that the
 * two things that make a shared cache dangerous are handled: failures must not
 * be cached, and the cache must not survive a change of account.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

const cache = readFileSync(join('src', 'lib', 'cachedFetch.js'), 'utf8');

console.log('\nThe cache does what a shared cache has to do');
{
    check('identical concurrent requests share one fetch', /inflight/.test(cache),
        'a TTL cache alone cannot dedupe requests that have not returned yet');

    /*
      A cached failure is how one dropped connection turns into a screen that
      stays empty for the whole TTL. Only successful bodies are stored.
    */
    check('failures are not cached',
        /if \(value !== null\) entries\.set/.test(cache),
        'otherwise a transient error sticks for the full TTL');

    check('in-flight entries are released whether or not the request succeeds',
        /\.finally\(\(\) => \{ inflight\.delete/.test(cache),
        'a rejected request left in the map would wedge that URL permanently');
}

console.log('\nAnd cannot serve one account another account data');
{
    check('there is a way to clear it', /export function clearCache/.test(cache));

    const auth = readFileSync(join('src', 'contexts', 'AuthContext.js'), 'utf8');
    check('AuthContext clears it', /clearCache\(\)/.test(auth));
    /*
      Responses differ by viewer: phone numbers are masked or revealed depending
      on the viewer's package, and cachedFetch keys on URL alone. Clearing on
      sign out is not sufficient because the account can change without one, so
      the identity itself is watched.
    */
    check('and does so whenever the account identity changes',
        /cachedForRef/.test(auth) && /\}, \[user\?\.id\]\);/.test(auth),
        'sign out alone would miss an account switch');
}

console.log('\nThe screens that shared a payload now share a cache entry');
{
    const screens = [
        ['members', join('src', 'app', '(main)', 'members', 'page.js')],
        ['matches', join('src', 'app', '(main)', 'matches', 'page.js')],
        ['boosted strip', join('src', 'components', 'BoostedMembersStrip.js')],
        ['live strip', join('src', 'components', 'LiveNowStrip.js')],
    ];
    for (const [label, path] of screens) {
        const src = readFileSync(path, 'utf8');
        check(`${label} reads through cachedFetch`, /cachedFetch\(/.test(src));
    }

    /*
      startPolling already runs its callback immediately, so a manual call
      beside it was a second identical request on every mount. Deduped now
      either way, but it should not be written that way.
    */
    const strip = readFileSync(join('src', 'components', 'BoostedMembersStrip.js'), 'utf8');
    check('no duplicate manual call beside startPolling',
        !/loadBoosted\(\);\s*\n\s*const stop = startPolling/.test(strip));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;
