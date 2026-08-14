/**
 * Does the account area go anywhere?
 *
 * It was a four-column grid of thirteen icon tiles above every section of the
 * account stacked onto one page: profile fields, photos, verification, stories,
 * activity, package, settings, support and sign-out, rendered together. Seven
 * of the tiles were anchors — href: '#profile-info', href: '#photos' — so
 * tapping one scrolled further down the same screen. Nothing was ever a
 * destination, so there was no sense of place and nothing to go back to.
 *
 * A tile also has room for one word, so thirteen of them read as a wall of
 * nouns: Edit Photos Messages Alerts Saved Pro Verify Privacy Status Prefs
 * Phone Support Wallet.
 *
 * The checks that matter are that rows lead somewhere real, and that every
 * destination offers a way back. A menu with a dead link is worse than the grid
 * it replaced.
 */
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\{\/\*[\s\S]*?\*\/\}/g, '')
    .replace(/^\s*\/\/.*$/gm, '');

const MAIN = join('src', 'app', '(main)');
const menu = strip(readFileSync(join(MAIN, 'profile', 'page.js'), 'utf8'));

/** Every route under the (main) group. */
function routes(dir = MAIN, prefix = '') {
    const found = [];
    for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        if (statSync(full).isDirectory()) {
            found.push(...routes(full, `${prefix}/${entry}`));
        } else if (entry === 'page.js') {
            found.push(prefix || '/');
        }
    }
    return found;
}
const known = new Set(routes());

console.log('\nThe account screen is a menu, not a wall of tiles');
{
    check('it uses menu rows', /MenuRow/.test(menu));
    /*
      The specific regression: a tile whose href is an anchor. It looks like
      navigation and only scrolls, which is what made one page hold everything.
    */
    const anchors = [...menu.matchAll(/href="(#[^"]*)"/g)].map((m) => m[1]);
    check('no row is an anchor into the same page', anchors.length === 0,
        anchors.length ? anchors.join(', ') : 'every row is a destination');

    check('rows are grouped under headings', /MenuGroup/.test(menu),
        'thirteen ungrouped entries is the wall of nouns again');
}

console.log('\nEvery destination exists');
{
    /*
      A dead row is worse than the grid this replaced: the grid at least
      scrolled somewhere. Deep links keep their fragment, so only the path is
      compared.
    */
    const hrefs = [...menu.matchAll(/href="(\/[^"]*)"/g)]
        .map((m) => m[1].split('#')[0])
        .filter((href) => !href.startsWith('/api'));
    const dead = [...new Set(hrefs)].filter((href) => !known.has(href));
    check('no dead links in the menu', dead.length === 0,
        dead.length ? dead.join(', ') : `${new Set(hrefs).size} destinations, all real`);
}

console.log('\nEvery sub-page can be left again');
{
    /*
      Splitting one page into several only helps if each says what it is and
      offers a way out. In the Android shell there is no browser back button,
      so a screen without one is a dead end.
    */
    for (const route of ['/profile/details', '/profile/activity', '/profile/saved']) {
        const file = join(MAIN, ...route.split('/').filter(Boolean), 'page.js');
        if (!existsSync(file)) { check(`${route} exists`, false); continue; }
        check(`${route} has a back header`, /PageHeader/.test(readFileSync(file, 'utf8')),
            'the app shell has no browser back button');
    }

    const header = readFileSync(join('src', 'components', 'PageHeader.js'), 'utf8');
    check('back falls through when there is no history', /history\.length > 1/.test(header),
        'a notification opened cold would leave the arrow doing nothing');
}

console.log('\nThe old page was kept, not deleted');
{
    /*
      Every section still works while they move across one at a time. Deleting
      726 lines to replace them with a menu would have removed working features
      in the same change that added navigation to them.
    */
    check('the full detail page still exists',
        existsSync(join(MAIN, 'profile', 'details', 'page.js')));
    check('and the menu links to it', /\/profile\/details/.test(menu));
}

console.log('\nStanding reminders do not repost every day');
{
    /*
      "Complete your profile", "Manual verification is available" and "Unlock
      premium GS features" are conditions, not events. Posting a fresh copy of
      each every 24 hours for as long as the condition holds is how an inbox
      reaches 58 items showing the same two notices, and it buries the messages
      that are genuinely events under nags nobody asked to see again.
    */
    const api = strip(readFileSync(join('src', 'app', 'api', 'members', 'route.js'), 'utf8'));
    check('a reminder is not reposted while unread', /if \(!data\.read\) return false;/.test(api),
        'repeating something unread cannot inform anybody');
    check('and waits a while after one is read', /REMINDER_COOLDOWN_MS/.test(api));
    check('the 24 hour rule is gone', !/alreadyNotifiedToday/.test(api));

    const auth = strip(readFileSync(join('src', 'contexts', 'AuthContext.js'), 'utf8'));
    check('copies already delivered are collapsed for display',
        /collapseStandingReminders/.test(auth),
        'they are in members inboxes and localStorage right now');
    check('only reminders collapse, not real messages',
        /STANDING_REMINDER_TYPES/.test(auth),
        'two likes are two things');

    check('and a migration clears the backlog',
        existsSync(join('supabase', 'migrations', '20260813_030_collapse_repeated_reminders.sql')));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;
