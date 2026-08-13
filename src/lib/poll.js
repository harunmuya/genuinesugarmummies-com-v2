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
    /**
     * Incoming calls. This is the delivery path, not a safety net.
     *
     * It was briefly set to 30s on the understanding that the call_sessions
     * realtime subscription delivered the ring and the poll only covered for a
     * dropped socket. Reading the RLS policies showed that was the wrong way
     * round, twice over:
     *
     * The subscription did work, but only because call_sessions carried a
     * policy of FOR ALL USING (true) with no TO clause, which despite being
     * named "Service role manages call sessions" applied to anon as well. Every
     * member's call metadata was readable, and writable, with the public key
     * out of the JavaScript bundle. That is closed now, which also closes the
     * subscription.
     *
     * So the poll rings the phone. Eight seconds is the compromise: a caller
     * waits at most that long, against 3s before, and the visibility gate means
     * a backgrounded app costs nothing either way.
     */
    INCOMING_CALLS: 8_000,
    /** Inside an active call, where latency is actually felt. */
    ACTIVE_CALL: 10_000,
    /** Conversation list. */
    MESSAGES: 20_000,
    /**
     * Open chat thread.
     *
     * There is a realtime subscription on `messages` beside this poll, and it
     * has never delivered anything. Its policy reads
     * `auth.uid() IN (sender_id, receiver_id)`, and this app does not use
     * Supabase Auth — it verifies passwords against its own users table — so
     * auth.uid() is null for every visitor and the filter matches no rows.
     *
     * The poll has always been what actually moved messages, which is why it
     * was set to 5 seconds. It stays the delivery path, at 8.
     */
    THREAD: 8_000,
    /** Live streams, on the discover and live screens. */
    LIVE: 45_000,
    /** Decorative strips. Nothing breaks if these are a minute stale. */
    STRIP: 120_000,
};
