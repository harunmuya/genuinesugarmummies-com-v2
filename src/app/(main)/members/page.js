'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Bell, Check, Eye, Filter, Loader2, MapPin, MessageCircle, Phone, Search, UserPlus, Users } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';

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
    if (seconds < 60) return 'now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
    return `${Math.floor(seconds / 86400)}d`;
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

export default function MembersPage() {
    const [members, setMembers] = useState([]);
    const [mode, setMode] = useState('all');
    const [label, setLabel] = useState('all');
    const [search, setSearch] = useState('');
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [schemaReady, setSchemaReady] = useState(true);
    const [followed, setFollowed] = useState({});

    const query = useMemo(() => {
        const params = new URLSearchParams({ mode, label, per_page: '240' });
        if (search.trim()) params.set('search', search.trim());
        return params.toString();
    }, [mode, label, search]);

    useEffect(() => {
        if (typeof window !== 'undefined') {
            setFollowed(JSON.parse(localStorage.getItem('gscom_followed_members') || '{}'));
        }
    }, []);

    useEffect(() => {
        let alive = true;
        async function loadMembers() {
            setLoading(true);
            setError('');
            try {
                const res = await fetch(`/api/members?${query}`);
                const data = await res.json();
                if (!alive) return;
                setMembers(data.members || []);
                setSchemaReady(data.schemaReady !== false && !data.setupRequired);
                if (!res.ok) setError(data.error || 'Members are unavailable right now.');
            } catch {
                if (alive) setError('Members are unavailable right now.');
            } finally {
                if (alive) setLoading(false);
            }
        }
        loadMembers();
        return () => { alive = false; };
    }, [query]);

    const visibleMembers = mode === 'following' ? members.filter((member) => followed[member.id]) : members;

    async function toggleFollow(memberId) {
        const res = await fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'follow', memberId, actorKey: getActorKey() }),
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

                <div className="flex gap-3 overflow-x-auto pb-1 -mx-4 px-4">
                    <Link href="/profile" className="shrink-0 text-center space-y-1">
                        <div className="relative">
                            <UserAvatar name="You" size={58} />
                            <span className="absolute -right-0.5 -bottom-0.5 w-5 h-5 rounded-full gradient-primary text-white text-sm leading-5 font-bold">+</span>
                        </div>
                        <p className="text-[10px] font-semibold text-text-secondary">Your Profile</p>
                    </Link>
                    {visibleMembers.slice(0, 12).map((member) => (
                        <Link key={member.id} href={`/members/${member.id}`} className="shrink-0 text-center space-y-1">
                            <div className="p-0.5 rounded-full" style={{ background: member.isOnline ? 'var(--gradient-primary)' : 'rgba(148,163,184,0.35)' }}>
                                <UserAvatar name={member.name} src={member.avatarUrl} size={54} />
                            </div>
                            <p className="w-16 truncate text-[10px] font-semibold text-text-secondary">{member.name}</p>
                        </Link>
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
                            <Link href={`/members/${member.id}`} className="block">
                                <div className="relative aspect-[3/4] bg-primary/5">
                                    {member.avatarUrl ? <img src={member.avatarUrl} alt={member.name} className="w-full h-full object-cover" loading="lazy" /> : <div className="w-full h-full flex items-center justify-center"><UserAvatar name={member.name} size={76} /></div>}
                                    <div className="absolute inset-x-0 bottom-0 p-2 bg-gradient-to-t from-black/75 to-transparent text-white">
                                        <div className="flex items-center gap-1 min-w-0"><h2 className="text-sm font-black truncate">{member.name}</h2><VerifiedBadge verified={member.verified} size={15} /></div>
                                        <p className="text-[11px] opacity-85 truncate">{member.age ? `${member.age} - ` : ''}{member.lookingFor || labelText(member.profileLabel)}</p>
                                    </div>
                                    <span className="absolute top-2 left-2 px-2 py-1 rounded-full text-[10px] font-bold text-white bg-black/55 backdrop-blur-sm">{labelText(member.profileLabel)}</span>
                                    <span className={`absolute top-2 right-2 w-3 h-3 rounded-full ring-2 ring-white ${member.isOnline ? 'bg-success' : 'bg-gray-400'}`} />
                                </div>
                            </Link>
                            <div className="p-2.5 space-y-2">
                                <div className="min-h-[46px] space-y-1">
                                    {member.location && <p className="flex items-center gap-1 text-[11px] text-text-muted truncate"><MapPin size={11} /> {member.location}</p>}
                                    <div className="flex items-center justify-between gap-1"><span className="px-2 py-0.5 rounded-full text-[10px] font-bold text-primary bg-primary/10">{planText(member.subscriptionTier)}</span><span className="text-[10px] text-text-muted">{member.followersCount || 0} follows</span></div>
                                    {member.lastSeenAt && <span className="text-[10px] text-text-muted">Active {timeSince(member.lastSeenAt)} ago</span>}
                                </div>
                                <div className="rounded-xl px-2 py-1.5 flex items-center gap-1.5" style={{ background: 'var(--color-surface)' }}><Phone size={12} className="text-text-muted" /><span className="text-[10px] font-semibold text-text-secondary truncate blur-[1.5px] select-none">{member.phoneMasked || 'Hidden'}</span></div>
                                <div className="grid grid-cols-3 gap-1.5">
                                    <button onClick={() => toggleFollow(member.id)} className={`h-8 rounded-lg flex items-center justify-center ${followed[member.id] ? 'gradient-primary text-white' : 'bg-primary/10 text-primary'}`} aria-label="Follow"><Check size={14} /></button>
                                    <Link href={`/members/${member.id}#message`} className="h-8 rounded-lg flex items-center justify-center bg-secondary/10 text-secondary" aria-label="Message"><MessageCircle size={14} /></Link>
                                    <Link href={`/members/${member.id}`} className="h-8 rounded-lg flex items-center justify-center bg-gray-100 text-text-secondary" aria-label="View profile"><Eye size={14} /></Link>
                                </div>
                            </div>
                        </motion.article>
                    ))}
                </section>
            )}
        </div>
    );
}