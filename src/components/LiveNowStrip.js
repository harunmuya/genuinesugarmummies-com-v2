'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Radio } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import { startPolling, POLL } from '@/lib/poll';
import { cachedFetch, TTL } from '@/lib/cachedFetch';

function liveDuration(startedAt) {
    const started = startedAt ? new Date(startedAt).getTime() : 0;
    if (!started || Number.isNaN(started)) return '0:00';
    const seconds = Math.max(0, Math.floor((Date.now() - started) / 1000));
    const mins = Math.floor(seconds / 60);
    return `${mins}:${String(seconds % 60).padStart(2, '0')}`;
}

export default function LiveNowStrip({ title = 'Featured Live Now', limit = 8, showWhenEmpty = false }) {
    const [streams, setStreams] = useState([]);

    useEffect(() => {
        let alive = true;
        async function loadLiveStreams() {
            try {
                const data = await cachedFetch('/api/live', { ttl: TTL.LIVE });
                if (alive && data) setStreams(data.streams || []);
            } catch {}
        }
        const stop = startPolling(loadLiveStreams, POLL.LIVE);
        return () => { alive = false; stop(); };
    }, []);

    if (!streams.length && !showWhenEmpty) return null;

    return (
        <section className="rounded-2xl p-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
            <div className="mb-2 flex items-center justify-between gap-2">
                <h2 className="text-sm font-black text-text-primary flex items-center gap-1"><Radio size={15} className="text-danger" /> {title}</h2>
                <Link href="/live" className="text-[11px] font-black text-primary">Open Live</Link>
            </div>
            {streams.length === 0 ? (
                <p className="text-xs text-text-muted">No one is live right now. Start a stream to be featured here.</p>
            ) : (
                <div className="flex gap-2 overflow-x-auto pb-1">
                    {streams.slice(0, limit).map((stream) => {
                        const host = stream.host || {};
                        const photo = host.avatar_url || host.photos?.[0] || '';
                        return (
                            <Link key={stream.id} href={`/live/${stream.id}`} className="min-w-40 rounded-2xl bg-gray-950 p-2 text-white shadow-sm">
                                <div className="relative h-24 overflow-hidden rounded-xl bg-primary/20">
                                    {photo ? <img src={photo} alt="" className="h-full w-full object-cover" /> : <UserAvatar name={host.display_name || 'Live'} size={52} />}
                                    <span className="absolute left-2 top-2 rounded-full bg-danger px-2 py-0.5 text-[11px] font-black">LIVE</span>
                                </div>
                                <p className="mt-2 truncate text-[11px] font-black">{stream.title || 'GS Live'}</p>
                                <p className="text-[11px] text-white/70">{host.display_name || 'Member'} - {liveDuration(stream.started_at)}</p>
                                <p className="text-[11px] text-white/70">{stream.viewer_count || 0} watching - {stream.total_likes || 0} likes - {stream.total_gifts || 0} gifts</p>
                                <span className="mt-2 block rounded-xl bg-white/10 py-1.5 text-center text-[11px] font-black">Join Live</span>
                            </Link>
                        );
                    })}
                </div>
            )}
        </section>
    );
}
