/**
 * Polling that stops when nobody is looking.
 *
 * This app was restricted by Supabase for exceeding its egress allowance:
 * 6.03 GB against a 5 GB quota, on a 57 MB database with 5 MB of storage and
 * zero monthly active users. Nothing about the data explains that number. The
 * polling did.
 *
 * Every screen ran its own `setInterval` straight into an API route, and none
 * of them checked whether the page was visible. A single open tab produced
 * roughly 4000 Supabase requests an hour:
 *
 *   AuthContext.refreshAccount   10s, and it fans out into six requests
 *   IncomingCallManager           3s, on every signed-in page
 *   LiveNowStrip                 15s
 *   StoriesStrip                 20s
 *   BoostedMembersStrip          30s
 *
 * The interval length was never the whole problem. The app is a Capacitor
 * shell, so it spends most of its life backgrounded with the WebView alive and
 * the timers still firing. Polling a server every three seconds for a user who
 * is not looking at the screen is the bulk of that 6 GB.
 *
 * So visibility is handled here, once, rather than being left to each caller to
 * remember. While the page is hidden the interval is cleared outright instead
 * of being allowed to fire into a discarded result, and coming back to the app
 * runs the callback immediately so the first thing the user sees is current.
 */

const canPoll = () => typeof document !== 'undefined';

/**
 * Run `fn` every `intervalMs`, but only while the page is visible.
 *
 * Returns a stop function. Safe to call during SSR, where it does nothing.
 *
 * @param {() => void | Promise<void>} fn
 * @param {number} intervalMs
 * @param {{ runNow?: boolean }} [options] `runNow` fires immediately on start
 *        and on every return to the foreground. Leave it on for anything the
 *        user reads on arrival; turn it off for background bookkeeping that
 *        should not stampede when several tabs wake at once.
 */
export function startPolling(fn, intervalMs, { runNow = true } = {}) {
    if (!canPoll()) return () => {};

    let timer = null;
    let stopped = false;

    const tick = () => {
        // Belt and braces: a timer can fire once after the tab is hidden,
        // between the visibilitychange event and the clearInterval below.
        if (stopped || document.visibilityState !== 'visible') return;
        try { fn(); } catch { /* a failing poll must not kill the loop */ }
    };

    const start = () => {
        if (stopped || timer !== null) return;
        timer = window.setInterval(tick, intervalMs);
    };

    const pause = () => {
        if (timer === null) return;
        window.clearInterval(timer);
        timer = null;
    };

    const onVisibility = () => {
        if (stopped) return;
        if (document.visibilityState === 'visible') {
            // Catch up on whatever was missed while hidden, then resume. Without
            // this the user returns to stale data and waits a full interval for
            // it to correct itself, which is what the short intervals were
            // really compensating for.
            if (runNow) tick();
            start();
        } else {
            pause();
        }
    };

    document.addEventListener('visibilitychange', onVisibility);

    if (document.visibilityState === 'visible') {
        if (runNow) tick();
        start();
    }

    return () => {
        stopped = true;
        pause();
        document.removeEventListener('visibilitychange', onVisibility);
    };
}

/**
 * How often the app polls, in one place.
 *
 * These were 3 to 30 seconds. The values below are what each screen actually
 * needs, given that returning to the app now refreshes immediately and that
 * several of these tables also carry a realtime subscription which delivers
 * changes the moment they happen.
 *
 * Where a realtime channel already exists the poll is only a safety net for a
 * dropped socket, so it can be slow. IncomingCallManager is the clearest case:
 * it subscribed to `call_sessions` and *also* polled every three seconds, so
 * 1200 requests an hour were paying for something the socket had already
 * delivered.
 */
export const POLL = {
    /** Account state: admin approvals and package unlocks reaching the device. */
    ACCOUNT: 60_000,
    /** Safety net behind the call_sessions realtime subscription. */
    INCOMING_CALLS: 30_000,
    /**
     * Used only when that subscription is not working — errored, timed out,
     * closed, or Supabase not configured at all. A missed incoming call is
     * worth more than the requests, so this stays short.
     */
    CALLS_FALLBACK: 5_000,
    /** Inside an active call, where latency is actually felt. */
    ACTIVE_CALL: 10_000,
    /** Conversation list. */
    MESSAGES: 20_000,
    /** Open thread, which also has a realtime subscription. */
    THREAD: 15_000,
    /** Live streams, on the discover and live screens. */
    LIVE: 45_000,
    /** Decorative strips. Nothing breaks if these are a minute stale. */
    STRIP: 120_000,
};
