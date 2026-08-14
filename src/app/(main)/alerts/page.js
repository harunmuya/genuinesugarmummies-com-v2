'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowLeft, Bell, CheckCheck, Gift, HeartHandshake, Mail, MessageCircle, PackageCheck, ShieldCheck, UserCheck, ExternalLink } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

const ICONS = {
    message: MessageCircle,
    member_message: MessageCircle,
    package: PackageCheck,
    package_request: PackageCheck,
    verification: ShieldCheck,
    gift: Gift,
    match: HeartHandshake,
    like: UserCheck,
    superlike: HeartHandshake,
    default: Bell,
};

function timeAgo(ts) {
    const diff = Math.max(0, (Date.now() - new Date(ts || Date.now()).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
}

function fullTime(ts) {
    try { return new Date(ts).toLocaleString(); } catch { return ''; }
}

function normalizeMessage(message) {
    const unreadCount = Math.max(0, Number(message.unreadCount || 0));
    return {
        id: message.id,
        type: message.type || 'message',
        title: message.title || message.sender || 'Message',
        body: message.body || message.message || '',
        image: message.senderImage || message.image || '',
        timestamp: message.timestamp || message.created_at || new Date().toISOString(),
        read: unreadCount > 0 ? false : Boolean(message.read),
        unreadCount,
        conversationId: message.conversationId,
        memberId: message.memberId || message.profileId,
        sender: message.sender || 'GS Admin',
    };
}

function normalizeActivity(item) {
    return {
        id: item.id,
        type: item.type || 'default',
        title: item.title || 'Activity',
        body: item.message || item.body || '',
        image: item.image || '',
        timestamp: item.timestamp || item.created_at || new Date().toISOString(),
        read: Boolean(item.read),
        memberId: item.memberId || item.profileId,
        sender: item.sender || 'Genuine Sugar Mummies',
    };
}

export default function AlertsPage() {
    const router = useRouter();
    const { activity, messages, markActivityRead, markMessagesRead } = useAuth();
    const [tab, setTab] = useState('inbox');
    const [selected, setSelected] = useState(null);
    const [tick, setTick] = useState(0);

    useEffect(() => {
        const interval = setInterval(() => setTick((value) => value + 1), 5000);
        return () => clearInterval(interval);
    }, []);

    const inbox = useMemo(() => {
        const messageItems = (messages || []).map(normalizeMessage);
        const activityItems = (activity || [])
            .filter((item) => !['login'].includes(item.type))
            .map(normalizeActivity);
        const merged = [...messageItems, ...activityItems];
        const unique = new Map();
        merged.forEach((item) => unique.set(item.id || `${item.type}-${item.timestamp}`, item));
        return [...unique.values()].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp)).slice(0, 100);
    }, [messages, activity, tick]);

    const visible = tab === 'messages'
        ? inbox.filter((item) => ['message', 'member_message', 'comment_sent', 'verification', 'package', 'package_request', 'admin_email', 'welcome', 'security'].includes(item.type))
        : tab === 'activity'
            ? inbox.filter((item) => !['message', 'member_message'].includes(item.type))
            : inbox;
    const unreadCount = inbox.filter((item) => !item.read).length;

    function markAllRead() {
        markActivityRead?.();
        markMessagesRead?.();
    }

    function openItem(item) {
        setSelected(item);
        markAllRead();
    }

    function openTarget(item) {
        if (item?.conversationId && item?.memberId) {
            router.push(`/messages/${item.memberId}`);
            return;
        }
        if (item?.memberId) router.push(`/members/${item.memberId}`);
    }

    if (selected) {
        const Icon = ICONS[selected.type] || ICONS.default;
        return (
            <div className="min-h-[calc(100dvh-120px)] px-4 py-4 pb-28 flex flex-col">
                <header className="flex items-center gap-3 rounded-2xl p-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <button onClick={() => setSelected(null)} className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center" aria-label="Back to inbox"><ArrowLeft size={19} /></button>
                    <div className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center overflow-hidden">
                        {selected.image ? <img src={selected.image} alt="" className="w-full h-full object-cover" /> : <Icon size={18} />}
                    </div>
                    <div className="min-w-0">
                        <p className="text-sm font-black text-text-primary truncate">{selected.sender || selected.type}</p>
                        <p className="text-[11px] text-text-muted">{fullTime(selected.timestamp)}</p>
                    </div>
                </header>

                <section className="flex-1 py-5 space-y-3">
                    <div className="max-w-[86%] rounded-[22px] rounded-tl-md p-4 shadow-sm" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                        <p className="text-xs font-black text-primary mb-1">{selected.title}</p>
                        <p className="text-sm leading-relaxed text-text-secondary whitespace-pre-wrap">{selected.body || 'No message body.'}</p>
                    </div>
                    <p className="text-center text-[11px] text-text-muted">Saved in your GS account inbox</p>
                </section>

                {selected.memberId && <button onClick={() => openTarget(selected)} className="w-full rounded-2xl py-3 font-black text-white gradient-primary flex items-center justify-center gap-2"><ExternalLink size={16} /> {selected.conversationId ? 'Open Chat' : 'Open Profile'}</button>}
            </div>
        );
    }

    return (
        <div className="px-4 py-4 pb-28 space-y-4">
            <div className="flex items-center justify-between gap-3">
                <div>
                    <h1 className="text-xl font-black text-text-primary">Inbox & Alerts</h1>
                    <p className="text-xs text-text-muted">Open messages, package updates, gifts, verification, and match activity.</p>
                </div>
                <button onClick={markAllRead} className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center" aria-label="Mark read">
                    <CheckCheck size={18} />
                </button>
            </div>

            <div className="grid grid-cols-3 gap-2">
                {[
                    ['inbox', 'All'],
                    ['messages', 'Messages'],
                    ['activity', 'Activity'],
                ].map(([id, label]) => <button key={id} onClick={() => setTab(id)} className={`rounded-xl py-2 text-xs font-black ${tab === id ? 'gradient-primary text-white' : 'bg-surface text-text-secondary'}`}>{label}</button>)}
            </div>

            {unreadCount > 0 && <div className="rounded-2xl p-3 text-xs font-bold text-primary bg-primary/10">{unreadCount > 99 ? '99+' : unreadCount} unread item{unreadCount === 1 ? '' : 's'}</div>}

            {visible.length === 0 ? (
                <div className="text-center py-16 space-y-4">
                    <div className="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center"><Mail size={30} className="text-primary" /></div>
                    <h3 className="text-lg font-bold text-text-primary">No Records Yet</h3>
                    <p className="text-sm text-text-muted max-w-xs mx-auto">Messages, gifts, package requests, and support replies will be recorded here.</p>
                </div>
            ) : (
                <div className="space-y-2">
                    <AnimatePresence initial={false}>
                        {visible.map((item, index) => {
                            const Icon = ICONS[item.type] || ICONS.default;
                            return (
                                <motion.button key={item.id || `${item.type}-${index}`} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: index * 0.02 }} onClick={() => openItem(item)} className="w-full text-left rounded-2xl p-3 flex items-start gap-3 active:scale-[0.99]" style={{ background: item.read ? 'var(--color-bg-card)' : 'rgba(15,118,110,0.07)', border: 'var(--card-border)' }}>
                                    <div className="w-11 h-11 rounded-full bg-primary/10 text-primary flex items-center justify-center shrink-0 overflow-hidden">
                                        {item.image ? <img src={item.image} alt="" className="w-full h-full object-cover" /> : <Icon size={19} />}
                                    </div>
                                    <div className="min-w-0 flex-1">
                                        <p className="text-sm font-black text-text-primary truncate">{item.title}</p>
                                        {item.body && <p className="text-xs text-text-secondary mt-0.5 line-clamp-2">{item.body}</p>}
                                        <p className="text-[11px] text-text-muted mt-1">{timeAgo(item.timestamp)}</p>
                                    </div>
                                    {!item.read && <span className="w-2.5 h-2.5 rounded-full bg-secondary mt-2" />}
                                </motion.button>
                            );
                        })}
                    </AnimatePresence>
                </div>
            )}
        </div>
    );
}
