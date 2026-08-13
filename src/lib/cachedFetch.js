/**
 * A small read cache in front of the JSON API.
 *
 * Supabase reported 6.03 GB of egress against a 5 GB allowance and 0.002 GB of
 * cached egress. Essentially nothing was being served twice from anywhere, and
 * the same responses were being fetched over and over.
 *
 * Two things caused that, and slowing the polls only fixed one of them.
 *
 * The first is repetition across screens. Discover, matches and members each
 * request /api/members with per_page=240, which is 240 rows of a 52 column
 * select. Moving between those three tabs fetched the same payload three times,
 * and coming back fetched it again.
 *
 * The second is concurrency. Several components mount at once and ask for the
 * same URL in the same tick, so identical requests were in flight side by side.
 * A time based cache alone does not help there, because none of them has
 * returned yet to populate it.
 *
 * So this does both: a TTL cache for repeat reads, and an in-flight map so
 * simultaneous callers share one request rather than racing.
 *
 * Deliberately not a general purpose data layer. It caches GETs by URL and
 * nothing else, it holds results in memory only, and it is dropped whenever the
 * signed-in user changes so one account never reads another's cached response.
 */

const entries = new Map();   // url -> { at, value }
const inflight = new Map();  // url -> Promise

/** Default lifetime. Long enough to cover a tab switch, short enough to feel live. */
const DEFAULT_TTL = 60_000;

/**
 * Fetch JSON, reusing a recent result or an in-flight request for the same URL.
 *
 * @param {string} url
 * @param {{ ttl?: number, force?: boolean }} [options] `force` bypasses the
 *        cached value but still joins an in-flight request, so a refresh button
 *        cannot be used to stampede the API.
 * @returns {Promise<any|null>} parsed JSON, or null if the request failed. The
 *          null is not cached: caching a failure is how a transient error turns
 *          into an empty screen that stays empty.
 */
export function cachedFetch(url, { ttl = DEFAULT_TTL, force = false } = {}) {
    if (!force) {
        const hit = entries.get(url);
        if (hit && Date.now() - hit.at < ttl) return Promise.resolve(hit.value);
    }

    const pending = inflight.get(url);
    if (pending) return pending;

    const request = fetch(url)
        .then(async (res) => {
            if (!res.ok) return null;
            const value = await res.json().catch(() => null);
            if (value !== null) entries.set(url, { at: Date.now(), value });
            return value;
        })
        .catch(() => null)
        .finally(() => { inflight.delete(url); });

    inflight.set(url, request);
    return request;
}

/**
 * Drop cached responses.
 *
 * Call with a prefix after a write, so the screen that just changed something
 * sees it: posting a story should not leave a minute of stale strip behind.
 * Call with nothing on sign-in and sign-out, where keeping anything at all
 * risks showing one account the previous account's data.
 */
export function clearCache(prefix) {
    if (!prefix) { entries.clear(); return; }
    for (const key of entries.keys()) {
        if (key.startsWith(prefix)) entries.delete(key);
    }
}

/** How long each kind of read stays usable, in one place. */
export const TTL = {
    /** Member directory. The 240 row payload shared by three screens. */
    MEMBERS: 90_000,
    /** Decorative strips. Nothing breaks if these are a minute stale. */
    STRIP: 120_000,
    /** Live streams, where being a little behind is obvious to the user. */
    LIVE: 30_000,
};
