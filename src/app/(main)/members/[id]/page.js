'use client';

import { use, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Calendar, Eye, Gift, Heart, Lock, MapPin, MessageCircle, Phone, PhoneCall, Send, Shield, Sparkles, UserPlus, Video } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';

const GIFTS = [
    { name: 'Rose', emoji: '\u{1F339}', label: 'Rose' },
    { name: 'Bouquet', emoji: '\u{1F490}', label: 'Bouquet' },
    { name: 'Diamond', emoji: '\u{1F48E}', label: 'Diamond' },
    { name: 'Crown', emoji: '\u{1F451}', label: 'Crown' },
];

function packageAccess(user) {
    const tier = String(user?.subscription_tier || user?.subscriptionTier || '').toLowerCase();
    const active = Boolean(user?.admin_approved && !user?.package_locked);
    return {
        tier,
        canBrowse: active && ['basic', 'silver', 'gold', 'diamond'].includes(tier),
        canMessage: active && ['basic', 'silver', 'gold', 'diamond'].includes(tier),
        canRevealPhone: active && ['silver', 'gold', 'diamond'].includes(tier),
        canCall: active && ['silver', 'gold', 'diamond'].includes(tier),
    };
}

function formatLabel(value) {
    return String(value || 'Member').split('_').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
}

function memberSince(date) {
    if (!date) return 'Recently';
    return new Intl.DateTimeFormat('en', { month: 'short', year: 'numeric' }).format(new Date(date));
}

function getActorKey() {
    if (typeof window === 'undefined') return 'guest';
    const key = 'gscom_actor_key';
    let value = localStorage.getItem(key);
    if (!value) {
        value = `member-${crypto.randomUUID?.() || Date.now()}`;
        localStorage.setItem(key, value);
    }
    return value;
}

export default function MemberProfilePage({ params }) {
    const { id } = use(params);
    const router = useRouter();
    const { user, addMessage } = useAuth();
    const access = packageAccess(user);
    const [member, setMember] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [message, setMessage] = useState('');
    const [status, setStatus] = useState('');
    const [following, setFollowing] = useState(false);

    useEffect(() => {
        const followed = JSON.parse(localStorage.getItem('gscom_followed_members') || '{}');
        setFollowing(Boolean(followed[id]));
    }, [id]);

    useEffect(() => {
        let alive = true;
        async function loadMember() {
            setLoading(true);
            setError('');
            try {
                const query = new URLSearchParams({ id });
                if (access.canRevealPhone && user?.id) query.set('viewer_id', user.id);
                const res = await fetch(`/api/members?${query.toString()}`);
                const data = await res.json();
                if (!alive) return;
                if (!res.ok) setError(data.error || 'Unable to load member.');
                setMember(data.members?.[0] || null);
            } catch {
                if (alive) setError('Unable to load member.');
            } finally {
                if (alive) setLoading(false);
            }
        }
        loadMember();
        return () => { alive = false; };
    }, [id, access.canRevealPhone, user?.id]);

    useEffect(() => {
        if (!id) return;
        const key = `gscom_viewed_${id}`;
        if (sessionStorage.getItem(key)) return;
        sessionStorage.setItem(key, '1');
        fetch('/api/members', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'view', memberId: id, actorKey: getActorKey() }) }).catch(() => {});
    }, [id]);

    async function postAction(payload, successText) {
        setStatus('');
        const res = await fetch('/api/members', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ memberId: id, actorKey: getActorKey(), ...payload }) });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            setStatus(data.error || 'Action failed.');
            return data;
        }
        setStatus(successText);
        return data;
    }

    async function toggleFollow() {
        if (!access.canBrowse) { router.push('/packages'); return; }
        const data = await postAction({ action: 'follow' }, following ? 'Unfollowed.' : 'Following.');
        if (typeof data.following === 'boolean') {
            setFollowing(data.following);
            setMember((current) => current ? { ...current, followersCount: data.followersCount ?? current.followersCount } : current);
            const followed = JSON.parse(localStorage.getItem('gscom_followed_members') || '{}');
            if (data.following) followed[id] = true;
            else delete followed[id];
            localStorage.setItem('gscom_followed_members', JSON.stringify(followed));
        }
    }

    async function sendMessage(event) {
        event.preventDefault();
        if (!access.canMessage) { router.push('/packages'); return; }
        const text = message.trim();
        if (!text) return;
        await postAction({ action: 'message', message: text, senderName: user?.display_name || user?.email || 'Member' }, 'Message sent and saved.');
        addMessage?.({ type: 'member_message', sender: 'You', senderImage: user?.avatar_url || '', title: `Message sent to ${member.name}`, body: text, memberId: member.id });
        setMessage('');
    }

    async function sendGift(gift) {
        if (!access.canMessage) { router.push('/packages'); return; }
        const data = await postAction({ action: 'gift', giftName: gift.name, emoji: gift.emoji }, `${gift.label} sent and recorded.`);
        setMember((current) => current ? { ...current, giftsReceivedCount: data.giftsReceivedCount ?? current.giftsReceivedCount } : current);
        addMessage?.({ type: 'gift', sender: 'You', title: `${gift.label} sent to ${member.name}`, body: gift.emoji, memberId: member.id });
    }

    async function requestCall(type) {
        if (!access.canCall) { router.push('/packages'); return; }
        const label = type === 'video' ? 'Video call' : 'Voice call';
        await postAction({ action: 'call_request', callType: type, senderName: user?.display_name || user?.email || 'Member' }, `${label} request recorded. Admin can review and connect approved members.`);
        addMessage?.({ type: 'call_request', sender: 'You', title: `${label} requested`, body: `${label} request for ${member.name}`, memberId: member.id });
    }

    if (loading) return <div className="min-h-[70vh] flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary/25 border-t-primary rounded-full animate-spin" /></div>;
    if (!member) return <div className="min-h-[70vh] flex flex-col items-center justify-center gap-4 px-6 text-center"><h1 className="text-xl font-black text-text-primary">Member Not Found</h1>{error && <p className="text-sm text-text-muted">{error}</p>}<button onClick={() => router.back()} className="px-5 py-3 rounded-2xl font-bold text-white gradient-primary">Go Back</button></div>;

    return (
        <div className="pb-28">
            <section className="relative min-h-[330px] bg-primary/5 overflow-hidden">
                {member.avatarUrl ? <img src={member.avatarUrl} alt={member.name} className={`absolute inset-0 w-full h-full object-cover ${access.canBrowse ? '' : 'blur-xl scale-110'}`} /> : <div className="absolute inset-0 flex items-center justify-center"><UserAvatar name={member.name} size={120} /></div>}
                <div className="absolute inset-0 bg-gradient-to-t from-black/88 via-black/25 to-black/35" />
                {!access.canBrowse && <div className="absolute inset-0 flex items-center justify-center"><Link href="/packages" className="rounded-2xl px-4 py-3 bg-white text-text-primary text-xs font-black shadow-lg text-center"><Lock size={19} className="mx-auto mb-1 text-primary" /> Basic unlocks photos and profile details</Link></div>}
                <button onClick={() => router.back()} className="absolute top-4 left-4 w-10 h-10 rounded-full flex items-center justify-center bg-black/55 text-white" aria-label="Back"><ArrowLeft size={21} /></button>
                <div className="absolute bottom-0 left-0 right-0 p-5 text-white space-y-2">
                    <div className="flex items-center gap-2"><h1 className="text-3xl font-black truncate">{member.name}</h1><VerifiedBadge verified={member.verified} size={22} /></div>
                    <div className="flex flex-wrap items-center gap-2 text-sm opacity-90">{member.age && <span>{member.age}</span>}{member.location && <span className="inline-flex items-center gap-1"><MapPin size={14} /> {member.location}</span>}</div>
                    <div className="flex flex-wrap gap-2"><span className="px-3 py-1 rounded-full text-xs font-bold bg-white/18 backdrop-blur-sm">{formatLabel(member.profileLabel)}</span>{member.lookingFor && <span className="px-3 py-1 rounded-full text-xs font-bold bg-white/18 backdrop-blur-sm">Seeking {member.lookingFor}</span>}</div>
                </div>
            </section>

            <div className="px-4 -mt-4 relative z-10 space-y-4">
                <section className="grid grid-cols-6 gap-2">
                    <button onClick={toggleFollow} className={`h-12 rounded-2xl flex items-center justify-center text-white shadow-lg ${following ? 'bg-success' : 'gradient-primary'}`} aria-label="Follow"><UserPlus size={18} /></button>
                    <a href="#message" className="h-12 rounded-2xl flex items-center justify-center bg-secondary text-white shadow-lg" aria-label="Message"><MessageCircle size={18} /></a>
                    <button onClick={() => sendGift(GIFTS[0])} className="h-12 rounded-2xl flex items-center justify-center bg-amber-500 text-white shadow-lg" aria-label="Send gift"><Gift size={18} /></button>
                    <button onClick={() => requestCall('voice')} className="h-12 rounded-2xl flex items-center justify-center bg-sky-600 text-white shadow-lg" aria-label="Voice call"><PhoneCall size={18} /></button>
                    <button onClick={() => requestCall('video')} className="h-12 rounded-2xl flex items-center justify-center bg-teal-600 text-white shadow-lg" aria-label="Video call"><Video size={18} /></button>
                    <Link href="/packages" className="h-12 rounded-2xl flex items-center justify-center bg-gray-900 text-white shadow-lg" aria-label="Packages"><Lock size={18} /></Link>
                </section>

                {status && <div className="rounded-2xl p-3 text-sm font-bold text-primary bg-primary/10">{status}</div>}
                {!access.canBrowse && <section className="rounded-2xl p-4 space-y-2" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="text-sm font-black text-text-primary">Profile Locked</h2><p className="text-xs text-text-muted">Basic unlocks profile photos/details and messaging limits. Silver unlocks lifetime phone reveal plus voice/video requests.</p><Link href="/packages" className="inline-flex rounded-xl px-4 py-2 text-xs font-black text-white gradient-primary">View Packages</Link></section>}

                {access.canBrowse && <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="text-sm font-black text-text-primary flex items-center gap-2"><Sparkles size={16} className="text-primary" /> Match Intent</h2><p className="text-sm font-bold text-text-primary">{member.intentSummary || `I am a ${formatLabel(member.profileLabel)} looking for ${member.lookingFor || 'a genuine match'}.`}</p><div className="grid gap-2 text-sm text-text-secondary">{member.wants && <p><span className="font-black text-text-primary">What they want:</span> {member.wants}</p>}{member.neededQualities && <p><span className="font-black text-text-primary">Needed qualities:</span> {member.neededQualities}</p>}{member.ageRangePreference && <p><span className="font-black text-text-primary">Preferred age:</span> {member.ageRangePreference}</p>}</div></section>}

                {access.canBrowse && <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="text-sm font-black text-text-primary">About</h2><p className="text-sm text-text-secondary leading-relaxed line-clamp-4">{member.bio || 'This member has not added a bio yet.'}</p><div className="flex flex-wrap gap-2">{[...(member.interests || []), ...(member.hobbies || [])].slice(0, 8).map((item) => <span key={item} className="px-2.5 py-1 rounded-full text-[11px] font-bold text-primary bg-primary/10">{item}</span>)}</div></section>}

                <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><div className="flex items-center justify-between gap-3"><div className="flex items-center gap-2 min-w-0"><Phone size={17} className="text-primary shrink-0" /><div className="min-w-0"><p className="text-xs font-bold text-text-muted">Phone</p><p className={`text-sm font-black text-text-primary truncate ${!access.canRevealPhone ? 'blur-[2px] select-none' : ''}`}>{access.canRevealPhone ? (member.phone || member.phoneMasked || 'Hidden') : (member.phoneMasked || 'Hidden')}</p></div></div><span className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-[11px] font-bold text-primary bg-primary/10">{access.canRevealPhone ? <Shield size={12} /> : <Lock size={12} />} {access.canRevealPhone ? 'Unlocked' : 'Silver+'}</span></div>{!access.canRevealPhone && <div className="space-y-2"><p className="text-xs text-text-muted">Silver or Gold admin-approved packages reveal phone numbers for lifetime access.</p><Link href="/packages" className="inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2 text-xs font-black text-white gradient-primary"><Lock size={13} /> View Packages</Link></div>}</section>

                {access.canBrowse && <section className="grid grid-cols-3 gap-2"><Stat icon={Heart} label="Followers" value={member.followersCount || 0} /><Stat icon={Eye} label="Views" value={member.totalProfileViews || 0} /><Stat icon={Calendar} label="Joined" value={memberSince(member.createdAt)} /></section>}

                <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="text-sm font-black text-text-primary">Send a Gift</h2><div className="grid grid-cols-4 gap-2">{GIFTS.map((gift) => <button key={gift.name} onClick={() => sendGift(gift)} className="rounded-2xl p-3 text-center bg-primary/10 text-primary font-black text-xs"><span className="block text-lg">{gift.emoji}</span>{gift.label}</button>)}</div></section>

                <section id="message" className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="text-sm font-black text-text-primary">Message</h2><form onSubmit={sendMessage} className="flex gap-2"><input value={message} onChange={(event) => setMessage(event.target.value)} placeholder={access.canMessage ? `Message ${member.name}` : 'Basic package unlocks messaging'} className="min-w-0 flex-1 rounded-2xl px-3 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/40" style={{ background: 'var(--color-surface)' }} /><button className="w-12 rounded-2xl gradient-primary text-white flex items-center justify-center" aria-label="Send message"><Send size={18} /></button></form></section>

                {member.verified && <section className="rounded-2xl p-4 flex items-center gap-3" style={{ background: 'rgba(14,165,233,0.08)', border: '1px solid rgba(14,165,233,0.18)' }}><Shield size={20} className="text-sky-500" /><p className="text-sm font-bold text-text-primary">Verified adult member</p></section>}
            </div>
        </div>
    );
}

function Stat({ icon: Icon, label, value }) {
    return <div className="rounded-2xl p-3 text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><Icon size={16} className="mx-auto text-primary mb-1" /><p className="text-[10px] text-text-muted">{label}</p><p className="text-sm font-black text-text-primary">{value}</p></div>;
}

