'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { BadgeCheck, Eye, HeartHandshake, MapPin, MessageCircle, RefreshCw, UserCheck } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import LiveNowStrip from '@/components/LiveNowStrip';
import BoostedMembersStrip from '@/components/BoostedMembersStrip';
import StoriesStrip from '@/components/StoriesStrip';
import { cachedFetch, TTL } from '@/lib/cachedFetch';

function getLocalMap(key) {
    if (typeof window === 'undefined') return {};
    try { return JSON.parse(localStorage.getItem(key) || '{}'); } catch { return {}; }
}

function relationshipFit(member, user, interactions) {
    let score = 45;
    const label = String(member.profileLabel || member.memberCategory || '').toLowerCase();
    if (targetLabelsForUser(user).has(label)) score += 22;
    const userLocation = String(user?.location || '').toLowerCase();
    const memberLocation = String(member.location || member.country || '').toLowerCase();
    if (userLocation && memberLocation && (memberLocation.includes(userLocation) || userLocation.includes(memberLocation))) score += 16;
    if (member.verified) score += 7;
    if (member.isBoosted) score += 18;
    if (member.intentSummary || member.wants) score += 8;
    if (member.ageRangePreference && user?.age) {
        const ages = member.ageRangePreference.match(/\d+/g)?.map(Number) || [];
        if (ages.length >= 2 && Number(user.age) >= ages[0] && Number(user.age) <= ages[1]) score += 10;
    }
    if (interactions.followed[member.id]) score += 10;
    if (interactions.likedIds.has(member.id)) score += 9;
    if ((member.totalProfileViews || 0) > 1000) score += 3;
    const seed = `${member.id}-${user?.email || ''}-fit`;
    let hash = 0;
    for (let i = 0; i < seed.length; i++) hash = ((hash << 5) - hash + seed.charCodeAt(i)) | 0;
    score += Math.abs(hash) % 8;
    return Math.max(50, Math.min(98, score));
}

function userProfileLabel(user) {
    const label = String(user?.profile_label || user?.member_category || '').toLowerCase();
    if (['sugar_mummy', 'sugar_daddy', 'mistress', 'toyboy'].includes(label)) return label;
    const pref = String(user?.preference || '').toLowerCase();
    if (pref.includes('toyboy')) return 'toyboy';
    if (pref.includes('sugar_daddy')) return 'sugar_daddy';
    if (pref.includes('mistress')) return 'mistress';
    if (pref.includes('sugar_mummy')) return 'sugar_mummy';
    return 'sugar_mummy';
}

function targetLabelsForUser(user) {
    const label = userProfileLabel(user);
    if (label === 'toyboy') return new Set(['sugar_mummy']);
    if (label === 'mistress') return new Set(['sugar_daddy']);
    if (label === 'sugar_daddy') return new Set(['mistress']);
    return new Set(['sugar_mummy', 'sugar_daddy', 'mistress', 'toyboy']);
}

function reasonFor(member, user, interactions) {
    if (interactions.followed[member.id]) return 'You follow this profile';
    if (String(member.location || '').toLowerCase().includes(String(user?.location || '').toLowerCase()) && user?.location) return 'Strong location fit';
    if (member.intentSummary || member.wants) return 'Intent and profile details match your preference';
    if (member.verified) return 'Verified member with a complete profile';
    return 'Suggested from your dating preference';
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

export default function MatchesPage() {
    const { user, likes, matches, messages } = useAuth();
    const [members, setMembers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [followed, setFollowed] = useState({});

    useEffect(() => {
        setFollowed(getLocalMap('gscom_followed_members'));
        async function load() {
            try {
                const data = await cachedFetch('/api/members?per_page=240', { ttl: TTL.MEMBERS });
                setMembers(data?.members || []);
            } finally {
                setLoading(false);
            }
        }
        load();
    }, []);

    const interactions = useMemo(() => ({
        followed,
        likedIds: new Set((likes || []).map((item) => item.id || item.wpId)),
        messagedIds: new Set((messages || []).map((item) => item.memberId).filter(Boolean)),
    }), [followed, likes, messages]);

    const recommendations = useMemo(() => {
        return (members || [])
            .filter((member) => member.id !== user?.id)
            .filter((member) => targetLabelsForUser(user).has(String(member.profileLabel || member.memberCategory || '').toLowerCase()))
            .map((member) => ({ ...member, score: relationshipFit(member, user, interactions), reason: reasonFor(member, user, interactions) }))
            .sort((a, b) => b.score - a.score)
            .slice(0, 40);
    }, [members, user, interactions]);

    return (
        <div className="px-4 py-4 pb-28 space-y-5">
            <div className="flex items-center justify-between gap-3">
                <div>
                    <h1 className="text-xl font-black text-text-primary">Smart Matches</h1>
                    <p className="text-xs text-text-muted">Ranked by location, preference, interactions, verification, and profile intent.</p>
                </div>
                <button onClick={() => window.location.reload()} className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center" aria-label="Refresh"><RefreshCw size={18} /></button>
            </div>

            <StoriesStrip title="Match Stories" />
            <LiveNowStrip title="Matches Live Now" />
            <BoostedMembersStrip title="Boosted Matches" />

            <section className="grid grid-cols-3 gap-2">
                <Metric label="Suggested" value={recommendations.length} />
                <Metric label="Liked" value={likes.length} />
                <Metric label="Mutual" value={matches.length} />
            </section>

            {loading ? <div className="py-12 text-center text-primary font-black">Finding compatible users...</div> : recommendations.length === 0 ? (
                <div className="text-center py-16 space-y-3"><div className="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center"><HeartHandshake size={30} className="text-primary" /></div><h2 className="text-lg font-black text-text-primary">No matches yet</h2><p className="text-sm text-text-muted">Complete your profile and interact with members to improve recommendations.</p></div>
            ) : (
                <section className="space-y-3">
                    {recommendations.map((member, index) => (
                        <motion.article key={member.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: index * 0.02 }} className="rounded-2xl overflow-hidden" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                            <div className="p-3 flex gap-3">
                                <Link href={memberPath(member)} className="w-20 h-24 rounded-2xl overflow-hidden shrink-0 bg-primary/10 flex items-center justify-center">
                                    {member.avatarUrl ? <img src={member.avatarUrl} alt={member.name} className="w-full h-full object-cover" onError={(event) => useFallbackAvatar(event, member.name)} /> : <UserAvatar name={member.name} size={54} />}
                                </Link>
                                <div className="min-w-0 flex-1 space-y-1.5">
                                    <div className="flex items-center gap-1.5"><h2 className="font-black text-text-primary truncate">{member.name}</h2><VerifiedBadge verified={member.verified} size={16} /></div>
                                    <p className="text-xs text-text-muted truncate">{member.age ? `${member.age} - ` : ''}{member.location || 'Location hidden'}</p>
                                    <p className="text-xs text-text-secondary line-clamp-2">{member.intentSummary || member.wants || member.bio || 'Compatible member suggestion.'}</p>
                                    <div className="flex flex-wrap gap-1"><span className="px-2 py-0.5 rounded-full text-[10px] font-black text-primary bg-primary/10">{member.score}% fit</span>{member.isBoosted && <span className="px-2 py-0.5 rounded-full text-[10px] font-black text-white bg-secondary">Boosted</span>}<span className="px-2 py-0.5 rounded-full text-[10px] font-black text-secondary bg-secondary/10">{member.reason}</span></div>
                                </div>
                            </div>
                            <div className="grid grid-cols-3 border-t" style={{ borderColor: 'rgba(15,118,110,0.08)' }}>
                                <Link href={memberPath(member)} className="py-2 text-xs font-black text-primary flex items-center justify-center gap-1"><Eye size={14} /> View</Link>
                                <Link href={memberPath(member, '#message')} className="py-2 text-xs font-black text-sky-700 flex items-center justify-center gap-1"><MessageCircle size={14} /> Message</Link>
                                <Link href="/packages" className="py-2 text-xs font-black text-gold flex items-center justify-center gap-1"><BadgeCheck size={14} /> Pro</Link>
                            </div>
                        </motion.article>
                    ))}
                </section>
            )}
        </div>
    );
}

function memberPath(member, suffix = '') {
    return member?.id ? '/members/' + member.id + suffix : '/members';
}

function Metric({ label, value }) {
    return <div className="rounded-2xl p-3 text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><p className="text-lg font-black text-primary">{value}</p><p className="text-[10px] font-bold text-text-muted">{label}</p></div>;
}
