'use client';

import { use, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { ArrowLeft, Calendar, Eye, Gift, Heart, ImagePlus, Lock, MapPin, MessageCircle, Mic, Phone, PhoneCall, Send, Shield, Smile, Sparkles, StopCircle, UserPlus, Video, X } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import GiftVisual from '@/components/GiftVisual';
import { triggerGiftEffect } from '@/components/GiftEffects';

const GIFTS = [
    { name: 'Rose', label: 'Rose', icon_url: '/gifts/rose.webp', credit_cost: 1 },
    { name: 'Bouquet', label: 'Bouquet', icon_url: '/gifts/bouquet.webp', credit_cost: 20 },
    { name: 'Diamond Ring of Love', label: 'Diamond Ring', icon_url: '/gifts/diamond-ring.webp', credit_cost: 300 },
    { name: 'The Crown', label: 'Crown', icon_url: '/gifts/crown.webp', credit_cost: 199 },
];

const VOICE_AUDIO_CONSTRAINTS = {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    channelCount: 1,
    sampleRate: 48000,
    sampleSize: 16,
};

function supportedVoiceMimeType() {
    const types = ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg;codecs=opus', 'audio/mp4'];
    if (typeof MediaRecorder === 'undefined') return '';
    return types.find((type) => MediaRecorder.isTypeSupported(type)) || '';
}

const QUICK_REPLIES = [
    { label: 'Hello', text: 'Hello, I would like to know you better.' },
    { label: 'Sweet', text: 'You look sweet and interesting.' },
    { label: 'Interested', text: 'I am interested in your profile.' },
    { label: 'Coffee', text: 'A coffee date sounds nice.' },
    { label: 'Thanks', text: 'Thank you for replying.' },
    { label: 'Call?', text: 'Can we plan a voice call when you are free?' },
];
const REACTION_REPLIES = [
    { name: 'Sparkle', text: 'You have a bright profile.' },
    { name: 'Heart', text: 'I like your profile.' },
    { name: 'Smile', text: 'Your profile made me smile.' },
];

function packageAccess(user) {
    const tier = String(user?.subscription_tier || user?.subscriptionTier || '').toLowerCase();
    const active = Boolean(user?.admin_approved && !user?.package_locked);
    return {
        tier,
        canBrowse: true,
        canMessage: true,
        canGift: active && ['basic', 'silver', 'gold', 'diamond'].includes(tier),
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

function presenceTone(member) {
    if (member?.isOnline) return 'bg-success';
    const seen = member?.lastSeenAt ? Date.now() - new Date(member.lastSeenAt).getTime() : Infinity;
    if (seen < 24 * 60 * 60 * 1000) return 'bg-amber-400';
    return 'bg-gray-300';
}

function memberPath(member, suffix = '') {
    return member?.id ? '/members/' + member.id + suffix : '/members';
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
    const searchParams = useSearchParams();
    const { user, guest, addMessage } = useAuth();
    const access = packageAccess(user);
    const [member, setMember] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [message, setMessage] = useState('');
    const [attachment, setAttachment] = useState(null);
    const [voiceNote, setVoiceNote] = useState('');
    const [recording, setRecording] = useState(false);
    const [status, setStatus] = useState('');
    const [following, setFollowing] = useState(false);
    const [wallet, setWallet] = useState({ giftCatalog: [] });
    const [giftBurst, setGiftBurst] = useState(null);
    const fileInputRef = useRef(null);
    const recorderRef = useRef(null);
    const chunksRef = useRef([]);
    const requestedId = id === 'single.php'
        ? (searchParams.get('id') || searchParams.get('member_id') || searchParams.get('member') || searchParams.get('username') || searchParams.get('u') || id)
        : id;
    const memberId = member?.id || requestedId;
    const isSelfProfile = member?.id === user?.id;

    useEffect(() => {
        const followed = JSON.parse(localStorage.getItem('gscom_followed_members') || '{}');
        setFollowing(Boolean(followed[memberId] || followed[requestedId]));
    }, [memberId, requestedId]);

    useEffect(() => {
        let alive = true;
        async function loadMember() {
            setLoading(true);
            setError('');
            try {
                const query = new URLSearchParams({ id: requestedId });
                if (access.canRevealPhone && user?.id) query.set('viewer_id', user.id);
                const res = await fetch(`/api/members?${query.toString()}`);
                const data = await res.json();
                if (!alive) return;
                if (!res.ok) setError(data.error || 'Unable to load member.');
                const loadedMember = data.members?.[0] || null;
                setMember(loadedMember);
            } catch {
                if (alive) setError('Unable to load member.');
            } finally {
                if (alive) setLoading(false);
            }
        }
        loadMember();
        return () => { alive = false; };
    }, [requestedId, access.canRevealPhone, user?.id, router]);

    useEffect(() => {
        if (!memberId || String(memberId).startsWith('@') || !user?.id) return;
        const key = `gscom_viewed_${memberId}`;
        if (sessionStorage.getItem(key)) return;
        sessionStorage.setItem(key, '1');
        fetch('/api/members', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'view', memberId, actorKey: user.id || getActorKey(), actorUserId: user.id }) })
            .then((res) => res.json().catch(() => ({})).then((data) => ({ ok: res.ok, data })))
            .then(({ ok, data }) => {
                if (!ok) {
                    setStatus(data.error || 'Your daily quota has exhausted. Pay for a package to unlock unlimited access.');
                    window.setTimeout(() => router.push(data.redirectTo || '/packages'), 900);
                }
            })
            .catch(() => {});
    }, [memberId, user?.id, router]);

    async function loadWallet() {
        if (!user?.id) return;
        try {
            const res = await fetch(`/api/wallet?userId=${encodeURIComponent(user.id)}`);
            const data = await res.json().catch(() => ({}));
            if (res.ok) setWallet(data);
        } catch {}
    }

    useEffect(() => { loadWallet(); }, [user?.id]);

    async function postAction(payload, successText) {
        setStatus('');
        const res = await fetch('/api/members', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ memberId, actorKey: user?.id || getActorKey(), actorUserId: user?.id || null, ...payload }) });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            setStatus(data.error || 'Action failed.');
            if (data.redirectTo) window.setTimeout(() => router.push(data.redirectTo), 900);
            return data;
        }
        setStatus(successText);
        return data;
    }

    async function toggleFollow() {
        if (guest || !user) { router.push('/auth/login'); return; }
        setStatus('');
        const res = await fetch('/api/profiles/follows', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userId: user.id, targetId: memberId }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            setStatus(data.error || 'Follow action failed.');
            return;
        }
        setStatus(data.following ? 'Following.' : 'Unfollowed.');
        if (typeof data.following === 'boolean') {
            setFollowing(data.following);
            setMember((current) => current ? { ...current, followersCount: data.followersCount ?? current.followersCount } : current);
            const followed = JSON.parse(localStorage.getItem('gscom_followed_members') || '{}');
            if (data.following) followed[memberId] = true;
            else delete followed[memberId];
            localStorage.setItem('gscom_followed_members', JSON.stringify(followed));
        }
    }

    async function sendMessage(event) {
        event.preventDefault();
        if (!access.canMessage) { router.push('/packages'); return; }
        const text = message.trim();
        if (!text && !attachment && !voiceNote) return;
        setStatus('');
        const res = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                userId: user?.id,
                peerId: memberId,
                message: text,
                attachmentUrl: attachment?.url || '',
                attachmentType: attachment?.type || '',
                attachmentName: attachment?.name || '',
                voiceUrl: voiceNote,
            }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            setStatus(data.error || 'Message failed.');
            if (data.redirectTo || res.status === 402) window.setTimeout(() => router.push(data.redirectTo || '/packages'), 900);
            return;
        }
        setStatus(voiceNote ? 'Voice note saved in conversation.' : attachment ? 'Media message saved in conversation.' : 'Message saved in conversation.');
        addMessage?.({ type: 'member_message', sender: 'You', senderImage: user?.avatar_url || '', title: `Message sent to ${member.name}`, body: text || (voiceNote ? 'Voice note' : attachment?.name || 'Media message'), memberId: member.id });
        setMessage('');
        setAttachment(null);
        setVoiceNote('');
    }

    function attachImage(file) {
        if (!file || !file.type.startsWith('image/')) return;
        const reader = new FileReader();
        reader.onload = (event) => setAttachment({ url: event.target.result, type: 'image', name: file.name || 'Image' });
        reader.readAsDataURL(file);
    }

    async function toggleRecording() {
        if (recording) {
            recorderRef.current?.stop();
            setRecording(false);
            return;
        }
        try {
            if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
                setStatus('Voice notes are not supported on this browser.');
                return;
            }
            const stream = await navigator.mediaDevices.getUserMedia({ audio: VOICE_AUDIO_CONSTRAINTS });
            chunksRef.current = [];
            const mimeType = supportedVoiceMimeType();
            const recorder = new MediaRecorder(stream, { ...(mimeType ? { mimeType } : {}), audioBitsPerSecond: 128000 });
            recorderRef.current = recorder;
            recorder.ondataavailable = (event) => { if (event.data?.size) chunksRef.current.push(event.data); };
            recorder.onstop = () => {
                const blob = new Blob(chunksRef.current, { type: recorder.mimeType || 'audio/webm' });
                const reader = new FileReader();
                reader.onload = (event) => setVoiceNote(event.target.result);
                reader.readAsDataURL(blob);
                stream.getTracks().forEach((track) => track.stop());
            };
            recorder.start();
            setRecording(true);
        } catch {
            setStatus('Allow microphone permission to record a voice note.');
        }
    }

    async function sendGift(gift) {
        if (!access.canGift) { router.push('/packages'); return; }
        setStatus('');
        const res = await fetch('/api/wallet', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'send_gift',
                userId: user?.id,
                receiverId: memberId,
                giftId: gift.id || null,
                giftName: gift.name,
                message: `Sent ${gift.name}`,
            }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            setStatus(data.error || 'Gift failed.');
            if (data.redirectTo) window.setTimeout(() => router.push(data.redirectTo), 900);
            else if (res.status === 402 && String(data.error || '').includes('credits')) window.setTimeout(() => router.push('/wallet'), 900);
            else if (res.status === 402) window.setTimeout(() => router.push('/packages'), 900);
            return;
        }
        setStatus(`${gift.name} delivered${data.usedInventory ? ' from your gift wallet' : ' with credits'} and saved in chat.`);
        triggerGiftEffect(data.catalogGift || gift);
        setGiftBurst({ gift: data.catalogGift || gift, receiver: member?.name || 'member' });
        window.setTimeout(() => setGiftBurst(null), 1800);
        setMember((current) => current ? { ...current, giftsReceivedCount: data.giftsReceivedCount ?? current.giftsReceivedCount } : current);
        addMessage?.({ type: 'gift', sender: 'You', title: `${gift.name} sent to ${member.name}`, body: data.usedInventory ? 'Sent from your gift wallet' : 'Gift sent with credits', memberId: member.id });
        await loadWallet();
    }

    async function requestCall(type) {
        if (!access.canCall) { router.push('/packages'); return; }
        const label = type === 'video' ? 'Video call' : 'Voice call';
        await postAction({ action: 'call_request', callType: type, senderName: user?.display_name || user?.email || 'Member' }, `${label} request recorded. Admin can review and connect approved members.`);
        addMessage?.({ type: 'call_request', sender: 'You', title: `${label} requested`, body: `${label} request for ${member.name}`, memberId: member.id });
    }

    if (loading) return <div className="min-h-[70vh] flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary/25 border-t-primary rounded-full animate-spin" /></div>;
    if (!member) return <div className="min-h-[70vh] flex flex-col items-center justify-center gap-4 px-6 text-center"><h1 className="text-xl font-black text-text-primary">Member Not Found</h1>{error && <p className="text-sm text-text-muted">{error}</p>}<button onClick={() => router.back()} className="px-5 py-3 rounded-2xl font-bold text-white gradient-primary">Go Back</button></div>;

    const inventoryByGift = new Map((wallet.giftInventory || []).map((item) => [item.gift_id, item]));

    return (
        <div className="pb-28">
            {giftBurst && <div className="fixed inset-x-0 top-20 z-50 mx-auto w-[min(92%,360px)] pointer-events-none">
                <div className="gs-gift-burst rounded-[28px] p-4 shadow-2xl text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <GiftVisual gift={giftBurst.gift} className="mx-auto h-28 w-28 rounded-3xl" />
                    <p className="mt-2 text-sm font-black text-text-primary">{giftBurst.gift?.name || 'Gift'} delivered</p>
                    <p className="text-xs text-text-muted">Sent to {giftBurst.receiver}</p>
                </div>
            </div>}
            <section className="relative min-h-[330px] bg-primary/5 overflow-hidden">
                {member.avatarUrl ? <img src={member.avatarUrl} alt={member.name} className="absolute inset-0 w-full h-full object-cover" /> : <div className="absolute inset-0 flex items-center justify-center"><UserAvatar name={member.name} size={120} /></div>}
                <div className="absolute inset-0 bg-gradient-to-t from-black/88 via-black/25 to-black/35" />
                <button onClick={() => router.back()} className="absolute top-4 left-4 w-10 h-10 rounded-full flex items-center justify-center bg-black/55 text-white" aria-label="Back"><ArrowLeft size={21} /></button>
                <div className="absolute bottom-0 left-0 right-0 p-5 text-white space-y-2">
                    <div className="flex items-center gap-2"><span className={`w-3.5 h-3.5 rounded-full ring-2 ring-white/75 ${presenceTone(member)}`} /><h1 className="text-3xl font-black truncate">{member.name}</h1><VerifiedBadge verified={member.verified} size={22} /></div>
                    <div className="flex flex-wrap items-center gap-2 text-sm opacity-90">{member.age && <span>{member.age}</span>}{member.location && <span className="inline-flex items-center gap-1"><MapPin size={14} /> {member.location}</span>}</div>
                    <div className="flex flex-wrap gap-2"><span className="px-3 py-1 rounded-full text-xs font-bold bg-white/18 backdrop-blur-sm">{formatLabel(member.profileLabel)}</span>{member.lookingFor && <span className="px-3 py-1 rounded-full text-xs font-bold bg-white/18 backdrop-blur-sm">Seeking {member.lookingFor}</span>}</div>
                </div>
            </section>

            <div className="px-4 -mt-4 relative z-10 space-y-4">
                <section className="grid grid-cols-6 gap-2">
                    <button onClick={toggleFollow} className={`h-12 rounded-2xl flex items-center justify-center text-white shadow-lg ${following ? 'bg-success' : 'gradient-primary'}`} aria-label="Follow"><UserPlus size={18} /></button>
                    <Link href={`/messages/${member.id}`} className="h-12 rounded-2xl flex items-center justify-center bg-secondary text-white shadow-lg" aria-label="Message"><MessageCircle size={18} /></Link>
                    <button onClick={() => sendGift((wallet.giftCatalog || [])[0] || GIFTS[0])} className="h-12 rounded-2xl flex items-center justify-center bg-amber-500 text-white shadow-lg" aria-label="Send gift"><Gift size={18} /></button>
                    {!isSelfProfile && <Link href={`/calls/${member.id}?type=voice`} className="h-12 rounded-2xl flex items-center justify-center bg-sky-600 text-white shadow-lg" aria-label="Voice call"><PhoneCall size={18} /></Link>}
                    {!isSelfProfile && <Link href={`/calls/${member.id}?type=video`} className="h-12 rounded-2xl flex items-center justify-center bg-teal-600 text-white shadow-lg" aria-label="Video call"><Video size={18} /></Link>}
                    <Link href="/packages" className="h-12 rounded-2xl flex items-center justify-center bg-gray-900 text-white shadow-lg" aria-label="Packages"><Lock size={18} /></Link>
                </section>

                {status && <div className="rounded-2xl p-3 text-sm font-bold text-primary bg-primary/10">{status}</div>}
                <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="text-sm font-black text-text-primary flex items-center gap-2"><Sparkles size={16} className="text-primary" /> Match Intent</h2><p className="text-sm font-bold text-text-primary">{member.intentSummary || `I am a ${formatLabel(member.profileLabel)} looking for ${member.lookingFor || 'a genuine match'}.`}</p><div className="grid gap-2 text-sm text-text-secondary">{member.wants && <p><span className="font-black text-text-primary">What they want:</span> {member.wants}</p>}{member.neededQualities && <p><span className="font-black text-text-primary">Needed qualities:</span> {member.neededQualities}</p>}{member.ageRangePreference && <p><span className="font-black text-text-primary">Preferred age:</span> {member.ageRangePreference}</p>}</div></section>

                <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="text-sm font-black text-text-primary">About</h2><p className="text-sm text-text-secondary leading-relaxed line-clamp-4">{member.bio || 'This member has not added a bio yet.'}</p><div className="flex flex-wrap gap-2">{[...(member.interests || []), ...(member.hobbies || [])].slice(0, 8).map((item) => <span key={item} className="px-2.5 py-1 rounded-full text-[11px] font-bold text-primary bg-primary/10">{item}</span>)}</div></section>

                <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><div className="flex items-center justify-between gap-3"><div className="flex items-center gap-2 min-w-0"><Phone size={17} className="text-primary shrink-0" /><div className="min-w-0"><p className="text-xs font-bold text-text-muted">Phone</p><p className="text-sm font-black text-text-primary truncate tracking-wide">{access.canRevealPhone ? (member.phone || member.phoneMasked || 'Hidden') : (member.phoneMasked || 'Hidden')}</p></div></div><span className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-[11px] font-bold text-primary bg-primary/10">{access.canRevealPhone ? <Shield size={12} /> : <Lock size={12} />} {access.canRevealPhone ? 'Unlocked' : 'Silver+'}</span></div>{!access.canRevealPhone && <div className="space-y-2"><p className="text-xs text-text-muted">Silver or Gold admin-approved packages reveal full phone numbers for lifetime access.</p><Link href="/packages" className="inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2 text-xs font-black text-white gradient-primary"><Lock size={13} /> View Packages</Link></div>}</section>

                <section className="grid grid-cols-3 gap-2"><Stat icon={Heart} label="Followers" value={member.followersCount || 0} /><Stat icon={Eye} label="Views" value={member.totalProfileViews || 0} /><Stat icon={Calendar} label="Joined" value={memberSince(member.createdAt)} /></section>

                <section id="gift" className="rounded-2xl p-4 space-y-3 scroll-mt-24" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><div className="flex items-center justify-between gap-2"><div><h2 className="text-sm font-black text-text-primary">Send a Gift</h2><p className="text-[10px] text-text-muted">Owned gifts send first. New gifts use approved paid credits.</p></div><Link href="/wallet" className="text-[11px] font-black text-primary">Credits: {(wallet.giftWallet?.credits || 0) + (wallet.creditWallet?.credits || 0)}</Link></div><div className="grid grid-cols-3 gap-2 max-h-80 overflow-auto">{((wallet.giftCatalog || []).length ? wallet.giftCatalog : GIFTS).map((gift) => <button key={gift.id || gift.name} onClick={() => sendGift(gift)} className="rounded-2xl p-2 text-center bg-white/80 text-primary font-black text-xs shadow-sm ring-1 ring-black/5"><GiftVisual gift={gift} className="mb-1 h-16 w-full rounded-xl" /><span className="block truncate text-text-primary">{gift.label || gift.name}</span>{gift.id && inventoryByGift.get(gift.id)?.quantity ? <span className="block text-[9px] text-primary">Owned x{inventoryByGift.get(gift.id)?.quantity}</span> : gift.credit_cost !== undefined && <span className="block text-[9px] text-primary">{gift.credit_cost} credits</span>}</button>)}</div></section>

                <section id="message" className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <h2 className="text-sm font-black text-text-primary">Message</h2>
                    <div className="flex flex-wrap gap-2">
                        {QUICK_REPLIES.map((reply) => <button key={reply.label} type="button" onClick={() => setMessage(reply.text)} className="px-3 h-9 rounded-xl bg-primary/10 text-primary text-xs font-black">{reply.label}</button>)}
                        {REACTION_REPLIES.map((reply) => <button key={reply.name} type="button" onClick={() => setMessage(reply.text)} className="px-3 h-9 rounded-xl bg-amber-100 text-gold text-xs font-black">{reply.name}</button>)}
                    </div>
                    {attachment?.type === 'image' && <div className="relative w-24"><img src={attachment.url} alt="" className="w-24 h-24 rounded-xl object-cover" /><button type="button" onClick={() => setAttachment(null)} className="absolute -top-2 -right-2 w-7 h-7 rounded-full bg-danger text-white flex items-center justify-center"><X size={14} /></button></div>}
                    {attachment?.type === 'gif' && <div className="inline-flex items-center gap-2 rounded-xl bg-amber-100 text-gold px-3 py-2 text-xs font-black">GIF {attachment.name}<button type="button" onClick={() => setAttachment(null)}><X size={13} /></button></div>}
                    {voiceNote && <div className="flex items-center gap-2 rounded-xl bg-sky-50 p-2"><audio src={voiceNote} controls className="min-w-0 flex-1" /><button type="button" onClick={() => setVoiceNote('')} className="w-8 h-8 rounded-full bg-danger text-white flex items-center justify-center"><X size={14} /></button></div>}
                    <form onSubmit={sendMessage} className="space-y-2">
                        <div className="flex gap-2">
                            <input value={message} onChange={(event) => setMessage(event.target.value)} placeholder={`Message ${member.name}`} className="min-w-0 flex-1 rounded-2xl px-3 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/40" style={{ background: 'var(--color-surface)' }} />
                            <button type="button" onClick={() => fileInputRef.current?.click()} className="w-11 rounded-2xl bg-primary/10 text-primary flex items-center justify-center" aria-label="Attach image"><ImagePlus size={18} /></button>
                            <button type="button" onClick={toggleRecording} className={`w-11 rounded-2xl flex items-center justify-center ${recording ? 'bg-danger text-white' : 'bg-sky-100 text-sky-700'}`} aria-label="Record voice note">{recording ? <StopCircle size={18} /> : <Mic size={18} />}</button>
                            <button className="w-12 rounded-2xl gradient-primary text-white flex items-center justify-center" aria-label="Send message"><Send size={18} /></button>
                        </div>
                        <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={(event) => { attachImage(event.target.files?.[0]); event.target.value = ''; }} />
                        <p className="text-[11px] text-text-muted flex items-center gap-1"><Smile size={12} /> Images, voice notes, emojis, and GIF reactions are saved with the message.</p>
                    </form>
                </section>

                {member.verified && <section className="rounded-2xl p-4 flex items-center gap-3" style={{ background: 'rgba(14,165,233,0.08)', border: '1px solid rgba(14,165,233,0.18)' }}><Shield size={20} className="text-sky-500" /><p className="text-sm font-bold text-text-primary">Verified adult member</p></section>}
            </div>
        </div>
    );
}

function Stat({ icon: Icon, label, value }) {
    return <div className="rounded-2xl p-3 text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><Icon size={16} className="mx-auto text-primary mb-1" /><p className="text-[10px] text-text-muted">{label}</p><p className="text-sm font-black text-text-primary">{value}</p></div>;
}

