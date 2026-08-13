'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Rocket } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import { startPolling, POLL } from '@/lib/poll';

function memberPath(member) {
    return member?.id ? '/members/' + member.id : '/members';
}

function fallbackAvatarSrc(name = 'Member') {
    const initials = String(name || 'Member').trim().split(/\s+/).slice(0, 2).map((part) => part[0] || '').join('').toUpperCase() || 'GS';
    const svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="520" viewBox="0 0 400 520">',
        '<defs><linearGradient id="g" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#f97316"/><stop offset="1" stop-color="#14b8a6"/></linearGradient></defs>',
        '<rect width="400" height="520" fill="url(#g)"/>',
        '<circle cx="200" cy="190" r="86" fill="rgba(255,255,255,.28)"/>',
        '<text x="200" y="210" text-anchor="middle" font-family="Arial,sans-serif" font-size="78" font-weight="900" fill="white">' + initials + '</text>',
        '<text x="200" y="330" text-anchor="middle" font-family="Arial,sans-serif" font-size="24" font-weight="700" fill="rgba(255,255,255,.86)">Genuine profile</text>',
        '</svg>',
    ].join('');
    return 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg);
}

function useFallbackAvatar(event, name) {
    event.currentTarget.onerror = null;
    event.currentTarget.src = fallbackAvatarSrc(name);
}

export default function BoostedMembersStrip({ title = 'Boosted Members', limit = 8 }) {
    const [members, setMembers] = useState([]);

    useEffect(() => {
        let alive = true;
        async function loadBoosted() {
            try {
                const res = await fetch(`/api/members?boosted=1&per_page=${limit}`);
                const data = await res.json().catch(() => ({}));
                if (alive && res.ok) setMembers(data.members || []);
            } catch {}
        }
        loadBoosted();
        const stop = startPolling(loadBoosted, POLL.STRIP);
        return () => { alive = false; stop(); };
    }, [limit]);

    if (!members.length) return null;

    return (
        <section className="rounded-2xl p-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
            <div className="mb-2 flex items-center justify-between gap-2">
                <h2 className="flex items-center gap-1 text-sm font-black text-text-primary"><Rocket size={15} className="text-secondary" /> {title}</h2>
                <Link href="/members" className="text-[11px] font-black text-primary">See all</Link>
            </div>
            <div className="flex gap-2 overflow-x-auto pb-1">
                {members.slice(0, limit).map((member) => (
                    <Link key={member.id} href={memberPath(member)} className="min-w-32 space-y-1 rounded-2xl p-2" style={{ background: 'var(--color-surface)' }}>
                        <div className="relative h-28 overflow-hidden rounded-xl bg-primary/10">
                            {member.avatarUrl ? <img src={member.avatarUrl} alt="" className="h-full w-full object-cover" onError={(event) => useFallbackAvatar(event, member.name)} /> : <UserAvatar name={member.name} size={58} />}
                            <span className="absolute left-2 top-2 rounded-full bg-secondary px-2 py-0.5 text-[9px] font-black text-white">BOOST</span>
                        </div>
                        <div className="flex min-w-0 items-center gap-1">
                            <p className="truncate text-xs font-black text-text-primary">{member.name}</p>
                            <VerifiedBadge verified={member.verified} size={12} />
                        </div>
                        <p className="truncate text-[10px] text-text-muted">{member.location || member.lookingFor || 'Featured now'}</p>
                    </Link>
                ))}
            </div>
        </section>
    );
}
