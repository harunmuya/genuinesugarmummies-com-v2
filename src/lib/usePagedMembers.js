'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { cachedFetch, TTL } from '@/lib/cachedFetch';

/**
 * Load members a page at a time instead of all of them at once.
 *
 * Discover, matches and members each asked for per_page=240 on mount. That is
 * 240 rows of a 52 column select, most of a megabyte, before anything appears
 * on screen — and nobody scrolls 240 profiles. It was a large part of what put
 * this project over its Supabase egress allowance, and it is why the first
 * paint was slow on a phone.
 *
 * A page is 24. Enough to fill a screen and a bit, small enough that the first
 * one arrives quickly.
 *
 * Two details that are easy to get wrong here:
 *
 * Rows are deduplicated by id. The API mixes boosted, real and seeded profiles
 * within each page, and filters out anyone without a photo, so a page can
 * return fewer rows than asked for and the boundaries are not as clean as a
 * plain offset. Appending blindly can repeat a profile, and React then warns
 * about duplicate keys while the same face appears twice.
 *
 * "No more" means a page came back empty, not a short page. Because of that
 * photo filter a page in the middle can legitimately return three rows while
 * more exist behind it, and treating short as final truncates the list.
 */
const PER_PAGE = 24;

export function usePagedMembers(baseQuery, { perPage = PER_PAGE, enabled = true } = {}) {
    const [members, setMembers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [loadingMore, setLoadingMore] = useState(false);
    const [hasMore, setHasMore] = useState(true);
    const [error, setError] = useState('');
    const [schemaReady, setSchemaReady] = useState(true);

    const pageRef = useRef(1);
    const seenRef = useRef(new Set());
    // Guards against a scroll sentinel firing repeatedly while a page is still
    // in flight, which would request page 2 several times over.
    const inFlightRef = useRef(false);

    const load = useCallback(async (page) => {
        if (inFlightRef.current) return;
        inFlightRef.current = true;
        if (page === 1) setLoading(true); else setLoadingMore(true);

        try {
            const params = new URLSearchParams(baseQuery);
            params.set('page', String(page));
            params.set('per_page', String(perPage));

            const data = await cachedFetch(`/api/members?${params.toString()}`, { ttl: TTL.MEMBERS });
            if (!data) {
                setError('Members are unavailable right now.');
                setHasMore(false);
                return;
            }

            setSchemaReady(data.schemaReady !== false && !data.setupRequired);
            if (data.error) setError(data.error); else setError('');

            const incoming = data.members || [];
            if (incoming.length === 0) {
                setHasMore(false);
                return;
            }

            const fresh = incoming.filter((m) => m?.id && !seenRef.current.has(m.id));
            fresh.forEach((m) => seenRef.current.add(m.id));
            setMembers((current) => (page === 1 ? fresh : [...current, ...fresh]));
            pageRef.current = page;
        } catch {
            setError('Members are unavailable right now.');
            setHasMore(false);
        } finally {
            inFlightRef.current = false;
            setLoading(false);
            setLoadingMore(false);
        }
    }, [baseQuery, perPage]);

    // A changed filter is a different list, so everything resets: the page
    // counter, the seen set, and the end-of-list flag. Forgetting the seen set
    // here means switching filter and back shows an empty screen, because every
    // row is already marked as seen.
    useEffect(() => {
        if (!enabled) return;
        pageRef.current = 1;
        seenRef.current = new Set();
        setMembers([]);
        setHasMore(true);
        load(1);
    }, [baseQuery, enabled, load]);

    const loadMore = useCallback(() => {
        if (loading || loadingMore || !hasMore || inFlightRef.current) return;
        load(pageRef.current + 1);
    }, [hasMore, load, loading, loadingMore]);

    return { members, loading, loadingMore, hasMore, error, schemaReady, loadMore, setMembers };
}

/**
 * A ref to attach to a sentinel element at the end of a list.
 *
 * Calls `onVisible` when that element scrolls into view, a screen ahead of the
 * bottom so the next page is usually there by the time the user arrives.
 */
export function useInfiniteScroll(onVisible, { enabled = true, rootMargin = '600px' } = {}) {
    const ref = useRef(null);
    const handler = useRef(onVisible);
    handler.current = onVisible;

    useEffect(() => {
        const node = ref.current;
        if (!node || !enabled || typeof IntersectionObserver === 'undefined') return undefined;

        const observer = new IntersectionObserver((entries) => {
            if (entries.some((entry) => entry.isIntersecting)) handler.current?.();
        }, { rootMargin });

        observer.observe(node);
        return () => observer.disconnect();
    }, [enabled, rootMargin]);

    return ref;
}
