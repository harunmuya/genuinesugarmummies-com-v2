'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { Bell, CheckCheck, Gift, Mail, MessageCircle, PackageCheck, ShieldCheck, Sparkles, UserCheck } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

const ICONS = {
    message: MessageCircle,
    member_message: MessageCircle,
    package_request: PackageCheck,
    verification: ShieldCheck,
    gift: Gift,
    match: Sparkles,
    like: UserCheck,
    default: Bell,
};

function timeAgo(ts) {
    const diff = Math.max(0, (Date.now() - new Date(ts || Date.now()).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
}

function normalizeMessage(message) {
    return {
        id: message.id,
        type: message.type || 'message',
        title: message.title || message.sender || 'Message',
        body: message.body || message.message || '',
        image: message.senderImage || message.image || '',
        timestamp: message.timestamp || message.created_at || new Date().toISOString(),
        read: Boolean(message.read),
        memberId: message.memberId || message.profileId,
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
    };
}

export default function AlertsPage() {
    const router = useRouter();
    const { activity, messages, markActivityRead, markMessagesRead } = useAuth();
    const [tab, setTab] = useState('inbox');
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
        ? inbox.filter((item) => ['message', 'member_message', 'comment_sent', 'verification', 'package_request'].includes(item.type))
        : inbox;
    const unreadCount = inbox.filter((item) => !item.read).length;

    function markAllRead() {
        markActivityRead?.();
        markMessagesRead?.();
    }

    function openItem(item) {
        if (item.memberId) router.push(`/members/${item.memberId}`);
    }

    return (
        <div className="px-4 py-4 pb-28 space-y-4">
            <div className="flex items-center justify-between gap-3">
                <div>
                    <h1 className="text-xl font-black text-text-primary">Inbox & Alerts</h1>
                    <p className="text-xs text-text-muted">Messages, package updates, gifts, verification, and match activity.</p>
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
                ].map(([id, label]) => <button key={id} onClick={() => setTab(id)} className={`rounded-xl py-2 text-xs font-black ${tab === id ? 'gradient-primary text-white' : 'bg-white text-text-secondary'}`}>{label}</button>)}
            </div>

            {unreadCount > 0 && <div className="rounded-2xl p-3 text-xs font-bold text-primary bg-primary/10">{unreadCount} unread item{unreadCount === 1 ? '' : 's'}</div>}

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
                                        <p className="text-[10px] text-text-muted mt-1">{timeAgo(item.timestamp)}</p>
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
