/**
 * Do packages actually gate what they claim to?
 *
 * The capability flags and canUseFeature have been right all along, and the
 * routes do call them: calls, live, gifts, images and voice notes are each
 * refused server-side, not merely hidden. Messages go through a daily limit,
 * which is the correct mechanism for them, and phone reveal has its own check.
 *
 * The hole was elsewhere and quieter. activeTierId decides the tier every one
 * of those checks runs against, and it considered admin_approved and
 * package_locked and never the expiry date. The admin screen writes
 * package_expires_at when granting a package and nothing had ever read it, so
 * an expired Gold stayed Gold indefinitely — calls, live, gifts, voice notes,
 * phone reveal, all of it, from a package that lapsed months ago.
 *
 * Worse, the two routes that decide entitlements did not even select the column,
 * so the value was undefined at the point of the decision.
 *
 * This runs the real function rather than reading the source, because the
 * failure is about what a date comparison does, not about which lines exist.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { activeTierId, canUseFeature } from '../src/lib/packageAccess.js';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

const DAY = 86_400_000;
const gold = (extra) => ({ subscription_tier: 'gold', admin_approved: true, ...extra });

console.log('\nAn expired package is a free account');
{
    check('a package with no expiry keeps working',
        activeTierId(gold({})) === 'gold');
    check('a package expiring tomorrow still works',
        activeTierId(gold({ package_expires_at: new Date(Date.now() + DAY).toISOString() })) === 'gold');
    check('a package that expired yesterday does not',
        activeTierId(gold({ package_expires_at: new Date(Date.now() - DAY).toISOString() })) === 'free',
        'this was the leak: admin sets an expiry and nothing read it');

    /*
      activeTierId is called both with rows straight from the database and with
      the camelCase objects normalizeMember produces. Handling one spelling
      grants the paid tier wherever the other is passed.
    */
    check('the camelCase spelling is handled too',
        activeTierId(gold({ packageExpiresAt: new Date(Date.now() - DAY).toISOString() })) === 'free',
        'rows and normalised members use different keys');

    // Bad data must not lock a paying member out of what they bought.
    check('an unparseable expiry is treated as no expiry',
        activeTierId(gold({ package_expires_at: 'not-a-date' })) === 'gold');

    check('approval is still required',
        activeTierId({ subscription_tier: 'gold', admin_approved: false }) === 'free');
    check('and a locked package is still refused',
        activeTierId(gold({ package_locked: true })) === 'free');
}

console.log('\nThe tier decides what is allowed');
{
    const free = { voice_video_access: false, can_go_live: false, can_send_gifts: false };
    const paid = { voice_video_access: true, can_go_live: true, can_send_gifts: true };
    check('a free tier cannot call', !canUseFeature(free, 'calls'));
    check('a paid tier can', canUseFeature(paid, 'calls'));
    check('a free tier cannot go live', !canUseFeature(free, 'live'));
    check('an absent tier allows nothing', !canUseFeature(null, 'calls'),
        'a lookup failure must not become free access');
}

console.log('\nEvery gated feature is refused by the server, not just hidden');
{
    /*
      A button hidden in the UI is not a gate. The endpoint has to refuse, or
      anyone can post to it directly and any bug that reveals the button gives
      the feature away.
    */
    const routes = {
        calls: join('src', 'app', 'api', 'calls', 'route.js'),
        live: join('src', 'app', 'api', 'live', 'route.js'),
        images: join('src', 'app', 'api', 'chat', 'route.js'),
        voiceNotes: join('src', 'app', 'api', 'chat', 'route.js'),
        gifts: join('src', 'app', 'api', 'wallet', 'route.js'),
    };
    for (const [feature, path] of Object.entries(routes)) {
        const src = readFileSync(path, 'utf8');
        check(`${feature} is checked in its route`,
            new RegExp(`canUseFeature\\([^,]+,\\s*'${feature}'\\)`).test(src));
    }
}

console.log('\nThe expiry column is loaded where entitlements are decided');
{
    /*
      The check above cannot pass if the value is never fetched. Both of these
      selected subscription_tier, admin_approved and package_locked and stopped
      there, so the expiry was undefined at the moment it mattered.
    */
    for (const name of ['calls', 'live']) {
        const src = readFileSync(join('src', 'app', 'api', name, 'route.js'), 'utf8');
        const getUser = src.slice(src.indexOf('async function getUser'), src.indexOf('async function getUser') + 400);
        check(`${name} loads package_expires_at`, /package_expires_at/.test(getUser),
            'an unloaded column reads as undefined, which never expires');
    }
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;
