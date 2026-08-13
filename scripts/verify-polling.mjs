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
      The 3 second call poll is the one that must never come back. It ran on
      every signed-in page beside a realtime subscription on the same table,
      so it was paying 1200 requests an hour for news the socket had already
      delivered.
    */
    const incoming = named.find(([k]) => k === 'INCOMING_CALLS');
    check('the incoming-call poll is a safety net, not the delivery path',
        incoming && incoming[1] >= 20_000,
        incoming ? `${incoming[1] / 1000}s behind the realtime subscription` : 'INCOMING_CALLS missing');

    /*
      But it is allowed to be fast when realtime is genuinely unavailable. A
      call that never rings is worse than the requests, and collapsing this
      into one slow number would trade the egress problem for a broken feature.
    */
    const fallback = named.find(([k]) => k === 'CALLS_FALLBACK');
    check('and there is a fast fallback for when the socket is down',
        fallback && fallback[1] <= 10_000,
        fallback ? `${fallback[1] / 1000}s` : 'CALLS_FALLBACK missing');

    const account = named.find(([k]) => k === 'ACCOUNT');
    check('the account refresh is no longer every 10 seconds',
        account && account[1] >= 45_000,
        account ? `${account[1] / 1000}s, and it fans out into six requests` : 'ACCOUNT missing');
}

console.log('\nPolls that duplicate a realtime subscription stay slow');
{
    const manager = readFileSync(join('src', 'components', 'IncomingCallManager.js'), 'utf8');
    check('IncomingCallManager still subscribes to call_sessions',
        /postgres_changes[\s\S]*call_sessions/.test(manager),
        'the socket is the delivery path; the poll only covers for it');
    check('and reacts to the subscription failing',
        /CHANNEL_ERROR|TIMED_OUT/.test(manager),
        'otherwise a dead socket means a call that never rings');
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;
