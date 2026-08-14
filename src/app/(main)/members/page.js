'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { Bell, Filter, Loader2, MapPin, MessageSquareText, Phone, Search, UserPlus, UserRoundCheck, Users } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import LiveNowStrip from '@/components/LiveNowStrip';
import BoostedMembersStrip from '@/components/BoostedMembersStrip';
import StoriesStrip from '@/components/StoriesStrip';
import { useAuth } from '@/contexts/AuthContext';
import { usePagedMembers, useInfiniteScroll } from '@/lib/usePagedMembers';

const MODES = [
    { id: 'all', label: 'Show All' },
    { id: 'following', label: 'Following' },
    { id: 'online', label: 'Online Now' },
    { id: 'nearby', label: 'Near Me' },
];

const PROFILE_LABELS = [
    { id: 'all', label: 'All Types' },
    { id: 'sugar_mummy', label: 'Sugar Mummy' },
    { id: 'sugar_daddy', label: 'Sugar Daddy' },
    { id: 'mistress', label: 'Mistress' },
    { id: 'toyboy', label: 'Sugar Guy / Toyboy' },
];

function labelText(label) {
    return PROFILE_LABELS.find((item) => item.id === label)?.label || 'Member';
}

function planText(plan) {
    const value = String(plan || 'free').toLowerCase();
    if (value === 'diamond') return 'Diamond';
    if (value === 'gold') return 'Gold';
    if (value === 'silver') return 'Silver';
    return 'Free';
}

function timeSince(date) {
    if (!date) return '';
    const seconds = Math.max(0, Math.floor((Date.now() - new Date(date).getTime()) / 1000));
    if (seconds < 60) return 'online now';
    if (seconds < 3600) return `active ${Math.floor(seconds / 60)} min ago`;
    if (seconds < 86400) return `active ${Math.floor(seconds / 3600)} hr ago`;
    if (seconds < 172800) return 'active yesterday';
    return 'Recently active';
}

function presenceTone(member) {
    if (member.isOnline) return 'bg-success ring-success/30';
    const seen = member.lastSeenAt ? Date.now() - new Date(member.lastSeenAt).getTime() : Infinity;
    if (seen < 24 * 60 * 60 * 1000) return 'bg-amber-400 ring-amber-200';
    return 'bg-gray-300 ring-gray-200';
}

function lookingTone(member) {
    const text = `${member.lookingFor || ''} ${member.profileLabel || ''}`.toLowerCase();
    if (text.includes('sugar mummy')) return 'from-rose-500 to-pink-500';
    if (text.includes('sugar daddy')) return 'from-sky-500 to-indigo-500';
    if (text.includes('mistress')) return 'from-teal-500 to-emerald-500';
    if (text.includes('toyboy') || text.includes('sugar guy')) return 'from-amber-500 to-orange-500';
    return 'from-primary to-secondary';
}

function lookingLabel(member) {
    return member.lookingFor || labelText(member.profileLabel);
}

function memberPath(member, suffix = '') {
    return member?.id ? '/members/' + member.id + suffix : '/members';
}

function getActorKey() {
    if (typeof window === 'undefined') return 'guest';
    const key = 'gscom_actor_key';
    let value = localStorage.getItem(key);
    if (!value) {
        value = `guest-${crypto.randomUUID?.() || Date.now()}`;
        localStorage.setItem(key, value);
    }
    return value;
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

export default function MembersPage() {
    const router = useRouter();
    const { user, guest } = useAuth();
    const [mode, setMode] = useState('all');
    const [label, setLabel] = useState('all');
    const [search, setSearch] = useState('');
    const [followed, setFollowed] = useState({});
    const [notice, setNotice] = useState('');

    /*
      per_page was 240: most of a megabyte of a 52 column select before
      anything appeared, for a list nobody scrolls to the end of. The hook
      requests 24 at a time and appends as the user reaches the bottom.

      per_page is deliberately not set here — usePagedMembers owns paging.
    */
    const query = useMemo(() => {
        const params = new URLSearchParams({ mode, label });
        if (search.trim()) params.set('search', search.trim());
        return params.toString();
    }, [mode, label, search]);

    useEffect(() => {
        if (typeof window !== 'undefined') {
            setFollowed(JSON.parse(localStorage.getItem('gscom_followed_members') || '{}'));
        }
    }, []);

    const {
        members, loading, loadingMore, hasMore, error, schemaReady, loadMore, setMembers,
    } = usePagedMembers(query);

    // Fires a screen before the bottom, so the next page is usually already
    // there by the time the user gets there.
    const sentinelRef = useInfiniteScroll(loadMore, { enabled: hasMore && !loading });

    const visibleMembers = mode === 'following' ? members.filter((member) => followed[member.id]) : members;

    async function toggleFollow(memberId) {
        if (!user?.id) { router.push('/auth/login'); return; }
        const res = await fetch('/api/profiles/follows', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userId: user.id, targetId: memberId }),
        });
        const data = await res.json();
        if (!res.ok) return;
        setMembers((items) => items.map((item) => item.id === memberId ? { ...item, followersCount: data.followersCount ?? item.followersCount } : item));
        setFollowed((current) => {
            const next = { ...current, [memberId]: data.following };
            if (!data.following) delete next[memberId];
            localStorage.setItem('gscom_followed_members', JSON.stringify(next));
            return next;
        });
    }

    async function openMember(member, section = '') {
        if (guest || !user?.id) { router.push('/auth/login'); return; }
        const res = await fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'view', memberId: member.id, actorUserId: user.id }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            setNotice(data.error || 'Your daily quota has exhausted. Pay for a package to unlock unlimited access.');
            window.setTimeout(() => router.push(data.redirectTo || '/packages'), 900);
            return;
        }
        router.push(memberPath(member, section));
    }

    function canMessage() {
        return Boolean(user?.id);
    }

    function openMessage(member) {
        if (!canMessage()) {
            setNotice('Create an account or sign in to message members.');
            window.setTimeout(() => router.push('/auth/login'), 900);
            return;
        }
        openMember(member, '#message');
    }


    function canCall() {
        const tier = String(user?.subscription_tier || 'free').toLowerCase();
        return Boolean(user?.admin_approved && !user?.package_locked && ['silver', 'gold', 'diamond'].includes(tier));
    }



    return (
        <div className="px-4 py-4 pb-28 space-y-5">
            <section className="space-y-3">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-xl font-black text-text-primary">Members</h1>
                        <p className="text-xs text-text-muted mt-0.5">{visibleMembers.length} visible profiles</p>
                    </div>
                    <Link href="/profile" className="w-10 h-10 rounded-full flex items-center justify-center text-white gradient-primary shadow-lg" aria-label="Create profile">
                        <UserPlus size={18} />
                    </Link>
                </div>
                {notice && <div className="rounded-2xl p-3 text-xs font-bold text-primary bg-primary/10">{notice}</div>}
                <StoriesStrip title="Member Stories" />
                <LiveNowStrip title="Members Live Now" />
                <BoostedMembersStrip title="Boosted Members" />

                <div className="flex gap-3 overflow-x-auto pb-1 -mx-4 px-4">
                    <Link href="/profile" className="shrink-0 text-center space-y-1">
                        <div className="relative">
                            <UserAvatar name="You" size={58} />
                            <span className="absolute -right-0.5 -bottom-0.5 w-5 h-5 rounded-full gradient-primary text-white text-sm leading-5 font-bold">+</span>
                        </div>
                        <p className="text-[11px] font-semibold text-text-secondary">Your Profile</p>
                    </Link>
                    {visibleMembers.slice(0, 12).map((member) => (
                        <button key={member.id} type="button" onClick={() => openMember(member)} className="shrink-0 text-center space-y-1">
                            <div className="p-0.5 rounded-full" style={{ background: member.isOnline ? 'var(--gradient-primary)' : 'rgba(148,163,184,0.35)' }}>
                                <UserAvatar name={member.name} src={member.avatarUrl} size={54} />
                            </div>
                            <p className="w-16 truncate text-[11px] font-semibold text-text-secondary">{member.name}</p>
                        </button>
                    ))}
                </div>
            </section>

            <section className="space-y-3">
                <div className="relative">
                    <Search size={17} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted" />
                    <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search members, countries, interests" className="w-full rounded-2xl py-3 pl-10 pr-4 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/40" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }} />
                </div>

                <div className="flex gap-2 overflow-x-auto pb-1 -mx-4 px-4">
                    {MODES.map((item) => (
                        <button key={item.id} onClick={() => setMode(item.id)} className={`shrink-0 px-3 py-2 rounded-full text-xs font-bold transition-all ${mode === item.id ? 'text-white gradient-primary' : 'text-text-secondary'}`} style={mode === item.id ? {} : { background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                            {item.label}
                        </button>
                    ))}
                </div>

                <div className="flex items-center gap-2">
                    <Filter size={15} className="text-text-muted" />
                    <select value={label} onChange={(event) => setLabel(event.target.value)} className="flex-1 rounded-xl px-3 py-2 text-xs font-semibold text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/40" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                        {PROFILE_LABELS.map((item) => <option key={item.id} value={item.id}>{item.label}</option>)}
                    </select>
                </div>
            </section>

            {!schemaReady && !loading && (
                <div className="rounded-2xl p-4 space-y-2" style={{ background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.22)' }}>
                    <div className="flex items-center gap-2 text-amber-700 font-bold text-sm"><Bell size={16} /> Supabase setup needed</div>
                    <p className="text-xs text-text-secondary leading-relaxed">Run the member seed migration and set the Supabase environment variables to populate this page.</p>
                </div>
            )}

            {error && !loading && <div className="rounded-2xl p-4 text-sm text-danger" style={{ background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.18)' }}>{error}</div>}

            {loading ? (
                <div className="flex items-center justify-center py-14 text-primary"><Loader2 size={28} className="animate-spin" /></div>
            ) : visibleMembers.length === 0 ? (
                <div className="text-center py-16 space-y-3">
                    <div className="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center"><Users size={30} className="text-primary" /></div>
                    <h2 className="text-lg font-black text-text-primary">No members found</h2>
                    <p className="text-sm text-text-muted max-w-xs mx-auto">Try a different search or filter.</p>
                </div>
            ) : (
                <section className="grid grid-cols-2 gap-3">
                    {visibleMembers.map((member, index) => (
                        <motion.article key={member.id} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: index * 0.015 }} className="overflow-hidden rounded-2xl" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                            <button type="button" onClick={() => openMember(member)} className="block w-full text-left">
                                <div className="relative aspect-[3/4] bg-primary/5">
                                    {member.avatarUrl ? <img src={member.avatarUrl} alt={member.name} className="w-full h-full object-cover" loading="lazy" onError={(event) => useFallbackAvatar(event, member.name)} /> : <div className="w-full h-full flex items-center justify-center"><UserAvatar name={member.name} size={76} /></div>}
                                    <div className="absolute inset-x-0 bottom-0 p-2 bg-gradient-to-t from-black/75 to-transparent text-white">
                                        <div className="flex items-center gap-1 min-w-0"><h2 className="text-sm font-black truncate">{member.name}</h2><VerifiedBadge verified={member.verified} size={15} /></div>
                                        <p className="text-[11px] opacity-85 truncate">{member.age ? `${member.age} - ` : ''}{member.lookingFor || labelText(member.profileLabel)}</p>
                                    </div>
                                    <span className="absolute top-2 left-2 px-2 py-1 rounded-full text-[11px] font-bold text-white bg-black/55 backdrop-blur-sm">{labelText(member.profileLabel)}</span>
                                    {member.isBoosted && <span className="absolute left-2 top-9 rounded-full bg-secondary px-2 py-1 text-[11px] font-black text-white shadow-sm">BOOSTED</span>}
                                    <span className={`absolute top-2 right-2 w-3.5 h-3.5 rounded-full ring-4 ring-white/80 ${presenceTone(member)}`} title={timeSince(member.lastSeenAt) || 'offline'} aria-label={timeSince(member.lastSeenAt) || 'offline'} />
                                </div>
                            </button>
                            <div className="p-2.5 space-y-2">
                                <div className="min-h-[46px] space-y-1">
                                    {member.location && <p className="flex items-center gap-1 text-[11px] text-text-muted truncate"><MapPin size={11} /> {member.location}</p>}
                                    <div className="flex items-center justify-between gap-1"><span className="px-2 py-0.5 rounded-full text-[11px] font-bold text-primary bg-primary/10">{planText(member.subscriptionTier)}</span><span className="text-[11px] text-text-muted">{member.followersCount || 0} follows</span></div>
                                    <div className="flex items-center gap-1.5 text-[11px] text-text-muted">
                                        <span className={`inline-block w-2.5 h-2.5 rounded-full ${presenceTone(member)}`} title={timeSince(member.lastSeenAt)} aria-label={timeSince(member.lastSeenAt)} />
                                        <span className="truncate">{timeSince(member.lastSeenAt) || 'offline'}</span>
                                    </div>
                                    <div className={`inline-flex max-w-full rounded-full bg-gradient-to-r ${lookingTone(member)} px-2 py-1 text-[11px] font-black text-white shadow-sm`}>
                                        <span className="truncate">Looking for {lookingLabel(member)}</span>
                                    </div>
                                </div>
                                <div className="rounded-xl px-2 py-1.5 flex items-center justify-between gap-1.5" style={{ background: 'var(--color-surface)' }}>
                                    <span className="min-w-0 flex items-center gap-1.5"><Phone size={12} className="text-text-muted shrink-0" /><span className="text-[11px] font-black tracking-wide text-text-secondary truncate select-none">{member.phoneMasked || 'Hidden'}</span></span>
                                    <span className="text-[11px] font-black text-primary bg-primary/10 rounded-full px-1.5 py-0.5">Silver+</span>
                                </div>
                                {/*
                                  Two actions, not five.

                                  This was a grid-cols-5 of Follow, Message,
                                  Gift, Call and View Profile, inside a card that
                                  is itself one of two columns. On a 360px phone
                                  that is roughly 26px per button, which is why
                                  the labels were set at 8.5px and truncated, and
                                  why they were impossible to hit accurately.

                                  Bigger text alone would only have made them
                                  overflow. The card already opens the profile
                                  when tapped, so View Profile was duplicating
                                  it, and Gift and Call belong on the profile
                                  where there is room to explain what they cost.
                                */}
                                <div className="grid grid-cols-2 gap-2">
                                    <button
                                        onClick={() => toggleFollow(member.id)}
                                        className={`inline-flex min-h-11 items-center justify-center gap-1.5 rounded-xl px-2 text-[12px] font-bold ${followed[member.id] ? 'bg-primary/15 text-primary' : 'bg-surface text-text-secondary'}`}
                                    >
                                        <UserRoundCheck size={16} strokeWidth={2.5} />
                                        <span className="truncate">{followed[member.id] ? 'Following' : 'Follow'}</span>
                                    </button>
                                    <button
                                        onClick={() => openMessage(member)}
                                        className="inline-flex min-h-11 items-center justify-center gap-1.5 rounded-xl bg-primary px-2 text-[12px] font-bold text-bg-dark"
                                    >
                                        <MessageSquareText size={16} strokeWidth={2.5} />
                                        <span className="truncate">Message</span>
                                    </button>
                                </div>
                            </div>
                        </motion.article>
                    ))}
                </section>
            )}

            {/*
              The sentinel sits outside the empty check so it still exists while
              a filter is showing nothing, and outside the grid so it is not a
              grid item.
            */}
            {!loading && hasMore && <div ref={sentinelRef} aria-hidden className="h-px w-full" />}

            {loadingMore && (
                <div className="flex items-center justify-center py-8 text-primary">
                    <Loader2 size={22} className="animate-spin" />
                </div>
            )}

            {!loading && !hasMore && visibleMembers.length > 0 && (
                <p className="py-8 text-center text-xs text-text-muted">
                    That is everyone matching this filter.
                </p>
            )}
        </div>
    );
}
