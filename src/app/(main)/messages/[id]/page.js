'use client';

import { use, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Gift, ImagePlus, Lock, PhoneCall, Send, Video, Wallet, X } from 'lucide-react';
import { createBrowserSupabaseClient, isSupabaseConfigured } from '@/lib/supabaseClient';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import GiftVisual from '@/components/GiftVisual';
import { triggerGiftEffect } from '@/components/GiftEffects';
import VoiceRecorder from '@/components/VoiceRecorder';
import { startPolling, POLL } from '@/lib/poll';

const QUICK_REPLIES = [
    { label: 'Hello', text: 'Hello, I would like to know you better.' },
    { label: 'Interested', text: 'I am interested in your profile.' },
    { label: 'Sweet', text: 'You look sweet and interesting.' },
    { label: 'Coffee', text: 'A coffee date sounds nice.' },
    { label: 'Thanks', text: 'Thank you for replying.' },
    { label: 'Call?', text: 'Can we plan a voice call when you are free?' },
];
const REACTION_REPLIES = [
    { name: 'Sparkle', text: 'You have a bright profile.' },
    { name: 'Heart', text: 'I like your profile.' },
    { name: 'Smile', text: 'Your profile made me smile.' },
];
function timeText(date) {
    try { return new Date(date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); } catch { return ''; }
}

function presenceTone(peer) {
    const seen = peer?.last_seen_at ? Date.now() - new Date(peer.last_seen_at).getTime() : Infinity;
    if (seen < 3 * 60 * 1000) return 'bg-success';
    if (seen < 24 * 60 * 60 * 1000) return 'bg-amber-400';
    return 'bg-gray-300';
}

export default function MessageThreadPage({ params }) {
    const { id: peerId } = use(params);
    const router = useRouter();
    const { user } = useAuth();
    const [peer, setPeer] = useState(null);
    const [conversation, setConversation] = useState(null);
    const [messages, setMessages] = useState([]);
    const [text, setText] = useState('');
    const [attachment, setAttachment] = useState(null);
    const [voiceNote, setVoiceNote] = useState(null);
    const [canMessage, setCanMessage] = useState(false);
    const [wallet, setWallet] = useState({ giftCatalog: [] });
    const [giftPanelOpen, setGiftPanelOpen] = useState(false);
    const [giftBurst, setGiftBurst] = useState(null);
    const [status, setStatus] = useState('');
    const [loading, setLoading] = useState(true);
    const bottomRef = useRef(null);
    const fileInputRef = useRef(null);
    const seenGiftMessagesRef = useRef(new Set());
    const chatChannelRef = useRef(null);
    const typingTimerRef = useRef(null);
    const lastTypingSentRef = useRef(0);
    const [peerTyping, setPeerTyping] = useState(false);

    async function loadThread({ silent = false } = {}) {
        if (!user?.id || !peerId) return;
        if (!silent) setLoading(true);
        try {
            const res = await fetch(`/api/chat?userId=${encodeURIComponent(user.id)}&peerId=${encodeURIComponent(peerId)}`);
            const data = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(data.error || 'Could not open chat.');
            setPeer(data.peer || null);
            setConversation(data.conversation || null);
            setMessages(data.messages || []);
            setCanMessage(Boolean(data.canMessage));
        } catch (err) {
            setStatus(err.message || 'Could not open chat.');
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => { loadThread(); }, [user?.id, peerId]);

    async function loadWallet() {
        if (!user?.id) return;
        try {
            const res = await fetch(`/api/wallet?userId=${encodeURIComponent(user.id)}`);
            const data = await res.json().catch(() => ({}));
            if (res.ok) setWallet(data);
        } catch {}
    }

    useEffect(() => { loadWallet(); }, [user?.id]);

    useEffect(() => {
        if (!conversation?.id) return;
        let stop = startPolling(() => loadThread({ silent: true }), POLL.THREAD);
        let channel = null;
        try {
            if (isSupabaseConfigured()) {
                const supabase = createBrowserSupabaseClient();
                channel = supabase
                    .channel(`gs-chat-${conversation.id}`)
                    .on('postgres_changes', { event: '*', schema: 'public', table: 'messages', filter: `conversation_id=eq.${conversation.id}` }, () => loadThread({ silent: true }))
                    .on('broadcast', { event: 'typing' }, ({ payload }) => {
                        if (payload?.userId && payload.userId !== user?.id) {
                            setPeerTyping(true);
                            window.clearTimeout(typingTimerRef.current);
                            typingTimerRef.current = window.setTimeout(() => setPeerTyping(false), 2500);
                        }
                    })
                    .subscribe();
                chatChannelRef.current = channel;
            }
        } catch {}
        return () => {
            stop();
            chatChannelRef.current = null;
            window.clearTimeout(typingTimerRef.current);
            try { if (channel) createBrowserSupabaseClient().removeChannel(channel); } catch {}
        };
    }, [conversation?.id, user?.id]);

    useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' }); }, [messages.length]);

    useEffect(() => {
        messages.forEach((message) => {
            if (!message.metadata?.gift?.name || seenGiftMessagesRef.current.has(message.id)) return;
            seenGiftMessagesRef.current.add(message.id);
            if (message.sender_id !== user?.id) {
                triggerGiftEffect({
                    name: message.metadata.gift.name,
                    icon_url: message.metadata.gift.iconUrl,
                    gif_url: message.metadata.gift.gifUrl,
                    credit_cost: message.metadata.gift.creditCost,
                    tier: message.metadata.gift.tier,
                });
            }
        });
    }, [messages, user?.id]);

    function attachImage(file) {
        if (!file || !file.type.startsWith('image/')) return;
        const reader = new FileReader();
        reader.onload = (event) => setAttachment({ url: event.target.result, type: 'image', name: file.name || 'Image' });
        reader.readAsDataURL(file);
    }

    function handleTextChange(event) {
        setText(event.target.value);
        if (!conversation?.id || !chatChannelRef.current || !user?.id) return;
        const now = Date.now();
        if (now - lastTypingSentRef.current < 1600) return;
        lastTypingSentRef.current = now;
        chatChannelRef.current.send({ type: 'broadcast', event: 'typing', payload: { userId: user.id, conversationId: conversation.id } }).catch(() => {});
        fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'typing', userId: user.id, peerId }),
        }).catch(() => {});
    }

    async function reactToMessage(message, reaction = 'heart') {
        if (!message?.id || !user?.id) return;
        try {
            const res = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'reaction', userId: user.id, peerId, messageId: message.id, reaction }),
            });
            if (res.ok) await loadThread({ silent: true });
        } catch {}
    }

    async function sendMessage(event) {
        event.preventDefault();
        if (!canMessage) { router.push('/packages'); return; }
        const message = text.trim();
        if (!message && !attachment && !voiceNote?.url) return;
        setStatus('');
        try {
            const res = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    userId: user.id,
                    peerId,
                    message,
                    attachmentUrl: attachment?.url || '',
                    attachmentType: attachment?.type || '',
                    attachmentName: attachment?.name || '',
                    voiceUrl: voiceNote?.url || '',
                    voiceDurationSeconds: voiceNote?.durationSeconds || 0,
                }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(data.error || 'Message failed.');
            setText('');
            setAttachment(null);
            setVoiceNote(null);
            await loadThread({ silent: true });
        } catch (err) {
            setStatus(err.message || 'Message failed.');
            if (String(err.message || '').includes('premium')) window.setTimeout(() => router.push('/packages'), 900);
        }
    }

    async function sendGift(gift) {
        if (!canMessage) { router.push('/packages'); return; }
        setStatus('');
        try {
            const res = await fetch('/api/wallet', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'send_gift',
                    userId: user.id,
                    receiverId: peerId,
                    giftId: gift.id,
                    giftName: gift.name,
                    conversationId: conversation?.id || null,
                    message: `Sent ${gift.name}`,
                }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(data.error || 'Gift failed.');
            setStatus(`${gift.name} delivered${data.usedInventory ? ' from your gift wallet' : ' with credits'} and saved in chat.`);
            triggerGiftEffect(data.catalogGift || gift);
            setGiftBurst({ gift: data.catalogGift || gift, receiver: peer?.display_name || 'member' });
            window.setTimeout(() => setGiftBurst(null), 1800);
            setGiftPanelOpen(false);
            await Promise.all([loadWallet(), loadThread({ silent: true })]);
        } catch (err) {
            setStatus(err.message || 'Gift failed.');
            if (String(err.message || '').includes('credits')) window.setTimeout(() => router.push('/wallet'), 900);
            if (String(err.message || '').includes('package')) window.setTimeout(() => router.push('/packages'), 900);
        }
    }

    const peerPhoto = peer?.avatar_url || peer?.photos?.[0] || '';
    const isSelfThread = peerId === user?.id;
    const inventoryByGift = new Map((wallet.giftInventory || []).map((item) => [item.gift_id, item]));

    return (
        <div className="min-h-[calc(100dvh-70px)] pb-24 flex flex-col">
            {giftBurst && <div className="fixed inset-x-0 top-20 z-50 mx-auto w-[min(92%,360px)] pointer-events-none">
                <div className="gs-gift-burst rounded-[28px] p-4 shadow-2xl text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <GiftVisual gift={giftBurst.gift} className="mx-auto h-28 w-28 rounded-3xl" />
                    <p className="mt-2 text-sm font-black text-text-primary">{giftBurst.gift?.name || 'Gift'} delivered</p>
                    <p className="text-xs text-text-muted">Sent to {giftBurst.receiver}</p>
                </div>
            </div>}
            <header className="sticky top-0 z-20 flex items-center gap-3 p-3 backdrop-blur-xl" style={{ background: 'rgba(255,255,255,0.92)', borderBottom: '1px solid rgba(15,118,110,0.12)' }}>
                <button onClick={() => router.back()} className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center" aria-label="Back"><ArrowLeft size={19} /></button>
                <div className="relative">
                    <UserAvatar name={peer?.display_name || 'Member'} src={peerPhoto} size={44} />
                    <span className={`absolute right-0 bottom-0 w-3.5 h-3.5 rounded-full ring-2 ring-white ${presenceTone(peer)}`} />
                </div>
                <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-1">
                        <h1 className="text-sm font-black text-text-primary truncate">{peer?.display_name || 'Member'}</h1>
                        <VerifiedBadge verified={peer?.verified} size={14} />
                    </div>
                    <p className="text-[10px] text-text-muted">{peerTyping ? 'typing...' : canMessage ? 'Chat active' : 'Daily quota reached'}</p>
                </div>
                {!isSelfThread && <Link href={`/calls/${peerId}?type=voice`} className="w-9 h-9 rounded-full bg-sky-100 text-sky-700 flex items-center justify-center" aria-label="Voice call"><PhoneCall size={16} /></Link>}
                {!isSelfThread && <Link href={`/calls/${peerId}?type=video`} className="w-9 h-9 rounded-full bg-primary/10 text-primary flex items-center justify-center" aria-label="Video call"><Video size={16} /></Link>}
            </header>

            {status && <div className="mx-4 mt-3 rounded-2xl p-3 text-xs font-bold text-primary bg-primary/10">{status}</div>}
            {loading ? <div className="p-6 text-center text-primary font-black">Opening chat...</div> : (
                <main className="flex-1 px-4 py-4 space-y-3">
                    {messages.map((message) => {
                        const mine = message.sender_id === user?.id;
                        const attachmentMeta = message.metadata?.attachment;
                        const voiceMeta = message.metadata?.voice;
                        const callMeta = message.metadata?.call;
                        return (
                            <div key={message.id} className={`flex ${mine ? 'justify-end' : 'justify-start'}`}>
                                <div onDoubleClick={() => reactToMessage(message, 'heart')} className={`max-w-[82%] rounded-[22px] p-3 shadow-sm ${mine ? 'rounded-br-md text-white gradient-primary' : 'rounded-bl-md text-text-primary'}`} style={!mine ? { background: 'var(--color-bg-card)', border: 'var(--card-border)' } : {}}>
                                    {callMeta?.id && <CallLogCard call={callMeta} mine={mine} />}
                                    {attachmentMeta?.type === 'image' && attachmentMeta.url && <img src={attachmentMeta.url} alt={attachmentMeta.name || 'Attachment'} className="mb-2 max-h-56 rounded-2xl object-cover" />}
                                    {attachmentMeta?.type === 'gif' && attachmentMeta.url && <img src={attachmentMeta.url} alt={attachmentMeta.name || 'Reaction'} className="mb-2 max-h-48 rounded-2xl object-cover" />}
                                    {attachmentMeta?.type === 'gif' && !attachmentMeta.url && <p className="mb-2 rounded-xl bg-white/20 px-3 py-2 text-xs font-black">{attachmentMeta.name || 'Reaction'}</p>}
                                    {message.metadata?.gift?.name && <GiftMessageCard gift={message.metadata.gift} mine={mine} />}
                                    {voiceMeta?.url && <div className={`mb-2 rounded-2xl p-2 ${mine ? 'bg-white/18' : 'bg-sky-50'}`}>
                                        <audio src={voiceMeta.url} controls className="max-w-full" />
                                        {voiceMeta.durationSeconds ? <p className={`mt-1 text-[10px] font-bold ${mine ? 'text-white/75' : 'text-text-muted'}`}>Voice note · {voiceMeta.durationSeconds}s</p> : null}
                                    </div>}
                                    {!callMeta?.id && <p className="text-sm whitespace-pre-wrap">{message.body}</p>}
                                    {message.metadata?.reactions && Object.keys(message.metadata.reactions).length > 0 && <div className="mt-2 flex flex-wrap gap-1">
                                        {Object.entries(message.metadata.reactions).map(([name, users]) => (
                                            <button key={name} type="button" onClick={() => reactToMessage(message, name)} className={`rounded-full px-2 py-0.5 text-[10px] font-black ${mine ? 'bg-white/20 text-white' : 'bg-rose-50 text-rose-700'}`}>
                                                {name === 'heart' ? 'Love' : name} {Array.isArray(users) ? users.length : 0}
                                            </button>
                                        ))}
                                    </div>}
                                    <p className={`mt-1 text-[9px] ${mine ? 'text-white/75' : 'text-text-muted'}`}>{timeText(message.created_at)} {mine ? `· ${message.read_at ? 'read' : message.delivered_at ? 'delivered' : message.status}` : ''}</p>
                                </div>
                            </div>
                        );
                    })}
                    <div ref={bottomRef} />
                </main>
            )}

            <form onSubmit={sendMessage} className="fixed bottom-[72px] left-0 right-0 z-30 px-3">
                <div className="max-w-md mx-auto rounded-3xl p-2 shadow-xl space-y-2" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <div className="flex flex-wrap gap-1 px-1">
                        {QUICK_REPLIES.map((reply) => <button key={reply.label} type="button" onClick={() => setText(reply.text)} className="px-2 h-8 rounded-xl bg-primary/10 text-primary text-[10px] font-black">{reply.label}</button>)}
                        {REACTION_REPLIES.map((reply) => <button key={reply.name} type="button" onClick={() => setText(reply.text)} className="px-2 h-8 rounded-xl bg-amber-100 text-gold text-[10px] font-black">{reply.name}</button>)}
                        <button type="button" onClick={() => setGiftPanelOpen((open) => !open)} className="px-2 h-8 rounded-xl bg-secondary/10 text-secondary text-[10px] font-black flex items-center gap-1"><Gift size={12} /> Gifts</button>
                    </div>
                    {giftPanelOpen && <div className="mx-1 rounded-2xl p-2" style={{ background: 'var(--color-surface)' }}>
                        <div className="mb-2 flex items-center justify-between gap-2">
                            <p className="text-[10px] font-black text-text-primary">Gift credits: {(wallet.giftWallet?.credits || 0) + (wallet.creditWallet?.credits || 0)}</p>
                            <Link href="/wallet" className="text-[10px] font-black text-primary inline-flex items-center gap-1"><Wallet size={11} /> Buy credits</Link>
                        </div>
                        <p className="mb-2 text-[10px] text-text-muted">Owned gifts send first. If you do not own the gift, approved credits are used and the receiver keeps it in their gift wallet.</p>
                        <div className="grid grid-cols-3 gap-2 max-h-72 overflow-auto">
                            {(wallet.giftCatalog || []).length === 0 ? <p className="col-span-3 text-xs text-text-muted">No gifts are active yet. Ask admin to activate gift catalog.</p> : wallet.giftCatalog.map((gift) => (
                                <button key={gift.id} type="button" onClick={() => sendGift(gift)} className="rounded-xl p-2 text-left bg-white/80 shadow-sm ring-1 ring-black/5">
                                    <GiftVisual gift={gift} className="mb-1 h-14 w-full rounded-lg" />
                                    <span className="block truncate text-[10px] font-black text-text-primary">{gift.name}</span>
                                    <span className="text-[9px] font-black text-primary">{inventoryByGift.get(gift.id)?.quantity ? `Owned x${inventoryByGift.get(gift.id)?.quantity}` : `${gift.credit_cost || 0} credits`}</span>
                                </button>
                            ))}
                        </div>
                    </div>}
                    {attachment?.type === 'image' && <Preview onClear={() => setAttachment(null)}><img src={attachment.url} alt="" className="w-20 h-20 rounded-xl object-cover" /></Preview>}
                    {attachment?.type === 'gif' && <Preview onClear={() => setAttachment(null)}><span className="text-xs font-black text-gold">{attachment.name}</span></Preview>}
                    {voiceNote?.url && <Preview onClear={() => setVoiceNote(null)}><div className="flex items-center gap-2"><audio src={voiceNote.url} controls className="max-w-[210px]" /><span className="text-[10px] font-black text-primary">{voiceNote.durationSeconds || 0}s</span></div></Preview>}
                    <div className="flex items-center gap-2">
                        <input value={text} onChange={handleTextChange} placeholder={canMessage ? 'Type a message' : 'Upgrade for more messages'} className="min-w-0 flex-1 rounded-2xl px-3 py-3 text-sm" style={{ background: 'var(--color-surface)' }} />
                        <button type="button" onClick={() => fileInputRef.current?.click()} className="w-10 h-10 rounded-2xl bg-primary/10 text-primary flex items-center justify-center" aria-label="Attach image"><ImagePlus size={17} /></button>
                        <VoiceRecorder disabled={!canMessage} onRecorded={setVoiceNote} onError={setStatus} />
                        <button className="w-11 h-10 rounded-2xl gradient-primary text-white flex items-center justify-center" aria-label="Send"><Send size={17} /></button>
                    </div>
                    {!canMessage && <p className="px-2 text-[10px] font-bold text-text-muted flex items-center gap-1"><Lock size={11} /> Your message quota is exhausted. Upgrade for more access.</p>}
                    <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={(event) => { attachImage(event.target.files?.[0]); event.target.value = ''; }} />
                </div>
            </form>
        </div>
    );
}

function Preview({ children, onClear }) {
    return <div className="mx-1 flex items-center justify-between gap-2 rounded-2xl bg-primary/10 p-2">{children}<button type="button" onClick={onClear} className="w-7 h-7 rounded-full bg-danger text-white flex items-center justify-center"><X size={13} /></button></div>;
}

function GiftMessageCard({ gift, mine }) {
    const normalized = {
        id: gift.id,
        name: gift.name,
        category: gift.category,
        gif_url: gift.gifUrl || gift.gif_url || '',
        icon_url: gift.iconUrl || gift.icon_url || '',
        credit_cost: gift.creditCost || gift.credit_cost || 0,
    };
    return (
        <div className={`mb-2 rounded-2xl p-2 ${mine ? 'bg-white/18' : 'bg-amber-50'}`}>
            <GiftVisual gift={normalized} className="mb-2 h-24 w-full rounded-2xl" />
            <div className="flex items-center justify-between gap-2">
                <div className="min-w-0">
                    <p className={`truncate text-xs font-black ${mine ? 'text-white' : 'text-text-primary'}`}>{normalized.name}</p>
                    <p className={`text-[10px] ${mine ? 'text-white/75' : 'text-text-muted'}`}>{gift.source === 'gift_wallet' ? 'Sent from gift wallet' : 'Premium gift delivered'}</p>
                </div>
                <span className={`rounded-full px-2 py-1 text-[10px] font-black ${mine ? 'bg-white/20 text-white' : 'bg-primary/10 text-primary'}`}>{gift.creditsSpent || normalized.credit_cost || 0} cr</span>
            </div>
        </div>
    );
}

function formatCallDuration(seconds) {
    const value = Math.max(0, Number(seconds || 0));
    const mins = Math.floor(value / 60);
    const secs = value % 60;
    return `${mins}:${String(secs).padStart(2, '0')}`;
}

function CallLogCard({ call, mine }) {
    const isVideo = call.type === 'video';
    return (
        <div className={`mb-2 rounded-2xl p-3 ${mine ? 'bg-white/18' : 'bg-sky-50'}`}>
            <div className="flex items-center gap-2">
                <span className={`flex h-9 w-9 items-center justify-center rounded-full ${mine ? 'bg-white/20 text-white' : 'bg-sky-100 text-sky-700'}`}>
                    {isVideo ? <Video size={16} /> : <PhoneCall size={16} />}
                </span>
                <div className="min-w-0">
                    <p className={`text-xs font-black ${mine ? 'text-white' : 'text-text-primary'}`}>{isVideo ? 'Video call' : 'Voice call'} {call.status || 'ended'}</p>
                    <p className={`text-[10px] ${mine ? 'text-white/75' : 'text-text-muted'}`}>Duration {formatCallDuration(call.durationSeconds)}</p>
                </div>
            </div>
        </div>
    );
}
