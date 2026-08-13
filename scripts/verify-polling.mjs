/**
 * Does this app still poll a server when nobody is looking at it?
 *
 * Supabase restricted this project for exceeding its egress allowance: 6.03 GB
 * against a 5 GB quota, returning 402 to every request. The database is 57 MB
 * and storage is 5 MB, so the data cannot account for it. The polling could.
 *
 * Every screen ran its own setInterval straight into an API route, none of them
 * checked whether the page was visible, and two of them polled tables that
 * already had a realtime subscription delivering the same rows. One open tab
 * cost roughly 4000 Supabase requests an hour:
 *
 *   AuthContext.refreshAccount   10s, fanning out into six requests
 *   IncomingCallManager           3s, mounted on every signed-in page
 *   LiveNowStrip                 15s
 *   StoriesStrip                 20s
 *   BoostedMembersStrip          30s
 *
 * The app is a Capacitor shell, so it spends most of its life backgrounded with
 * the WebView alive and every one of those timers still firing.
 *
 * This checks the shape of the fix rather than the numbers: network polling goes
 * through startPolling, which owns the visibility handling, and the intervals
 * live in one table instead of being scattered as literals.
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

function walk(dir) {
    const out = [];
    for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        if (statSync(full).isDirectory()) out.push(...walk(full));
        else if (entry.endsWith('.js')) out.push(full);
    }
    return out;
}

const files = walk('src').filter((f) => !f.endsWith(join('lib', 'poll.js')));

console.log('\nNetwork polling is gated on visibility');
{
    /*
      A setInterval is only a problem here if its callback reaches the network.
      Elapsed-second counters, the alerts re-render tick and the WebRTC
      signalling retry are all legitimate and are left alone, so this looks at
      what the callback does rather than at the timer itself.
    */
    const offenders = [];
    for (const file of files) {
        const src = readFileSync(file, 'utf8');
        // The callback body, up to the interval argument.
        const re = /setInterval\(([\s\S]*?),\s*[^,)]*\)/g;
        let match;
        while ((match = re.exec(src)) !== null) {
            const body = match[1];
            if (/\bfetch\(|supabase|\bload[A-Z]\w*\(|\brefresh[A-Z]\w*\(/.test(body)) {
                const line = src.slice(0, match.index).split('\n').length;
                offenders.push(`${file}:${line}`);
            }
        }
    }
    check('no raw setInterval reaches the network', offenders.length === 0,
        offenders.length ? offenders.join(', ') : 'all network polling goes through startPolling');
}

console.log('\nThe helper actually stops when hidden');
{
    const poll = readFileSync(join('src', 'lib', 'poll.js'), 'utf8');
    check('it listens for visibilitychange', /addEventListener\('visibilitychange'/.test(poll));
    check('it clears the interval when hidden rather than firing into nothing',
        /clearInterval/.test(poll) && /visibilityState !== 'visible'/.test(poll));
    check('it refreshes on return, so slower intervals are not felt',
        /if \(runNow\) tick\(\);\s*\n\s*start\(\);/.test(poll));
    check('it removes its listener on stop', /removeEventListener\('visibilitychange'/.test(poll),
        'otherwise every navigation leaks one');
}

console.log('\nIntervals are named, not scattered as literals');
{
    const poll = readFileSync(join('src', 'lib', 'poll.js'), 'utf8');
    const named = [...poll.matchAll(/^\s{4}([A-Z_]+):\s*([\d_]+),/gm)]
        .map(([, key, value]) => [key, Number(value.replace(/_/g, ''))]);
    check('POLL table is populated', named.length >= 6, `${named.length} entries`);

    /*
      The incoming-call poll has to stay in a narrow band, and this check has
      been wrong in both directions already.

      At 3 seconds it cost 1200 requests an hour on every signed-in page. It
      was then set to 30 on the reading that the call_sessions realtime
      subscription delivered the ring and the poll was only a safety net.

      That reading was wrong. The subscription worked only because
      call_sessions carried FOR ALL USING (true) with no TO clause — a policy
      named for the service role that in fact applied to anon, leaving every
      member's call rows readable and writable with the public key. Closing
      that closes the subscription, so the poll rings the phone.

      Hence a floor and a ceiling: fast enough that a caller is not left
      waiting, slow enough that it is not the old 3 second bill.
    */
    const incoming = named.find(([k]) => k === 'INCOMING_CALLS');
    check('the incoming-call poll rings the phone without billing like the old one',
        incoming && incoming[1] >= 5_000 && incoming[1] <= 12_000,
        incoming ? `${incoming[1] / 1000}s` : 'INCOMING_CALLS missing');

    /*
      The chat thread is in the same position: its `messages` subscription is
      filtered by auth.uid(), and this app has no Supabase Auth session, so it
      has never delivered a row. The poll is the delivery path there too.
    */
    const thread = named.find(([k]) => k === 'THREAD');
    check('the chat thread poll is quick, since its subscription cannot deliver',
        thread && thread[1] <= 12_000,
        thread ? `${thread[1] / 1000}s` : 'THREAD missing');

    const account = named.find(([k]) => k === 'ACCOUNT');
    check('the account refresh is no longer every 10 seconds',
        account && account[1] >= 45_000,
        account ? `${account[1] / 1000}s, and it fans out into six requests` : 'ACCOUNT missing');
}

console.log('\nNo subscription to a table the public key can no longer read');
{
    /*
      call_sessions is closed to anon by
      supabase/migrations/20260813_020_lock_down_public_table_access.sql, so a
      subscription to it would sit there reporting SUBSCRIBED and never fire.
      A dead listener beside a working poll is worse than no listener: it is
      the thing that made the poll look redundant in the first place.
    */
    const manager = readFileSync(join('src', 'components', 'IncomingCallManager.js'), 'utf8');
    check('IncomingCallManager does not subscribe to call_sessions',
        !/postgres_changes/.test(manager),
        'the table is private now, so the socket cannot deliver');

    const migration = readFileSync(
        join('supabase', 'migrations', '20260813_020_lock_down_public_table_access.sql'), 'utf8');
    check('and the migration that closed it is present',
        /password_reset_codes/.test(migration) && /revoke all on public/.test(migration));
    check('live stream content stays readable, since it is public by nature',
        /live_comments/.test(migration) && /grant select on public/.test(migration));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;
