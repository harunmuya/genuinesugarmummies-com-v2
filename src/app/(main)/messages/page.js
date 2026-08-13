'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Megaphone, MessageCircle, Rocket, Search } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import LiveNowStrip from '@/components/LiveNowStrip';
import BoostedMembersStrip from '@/components/BoostedMembersStrip';
import StoriesStrip from '@/components/StoriesStrip';
import { useAuth } from '@/contexts/AuthContext';
import { startPolling, POLL } from '@/lib/poll';

function timeText(date) {
    if (!date) return '';
    const diff = Math.max(0, Date.now() - new Date(date).getTime());
    if (diff < 60000) return 'now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h`;
    return `${Math.floor(diff / 86400000)}d`;
}

function onlineTone(peer) {
    const seen = peer?.last_seen_at ? Date.now() - new Date(peer.last_seen_at).getTime() : Infinity;
    if (seen < 5 * 60 * 1000) return 'bg-success';
    if (seen < 24 * 60 * 60 * 1000) return 'bg-amber-400';
    return 'bg-gray-300';
}

export default function MessagesPage() {
    const { user } = useAuth();
    const [conversations, setConversations] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [error, setError] = useState('');

    useEffect(() => {
        if (!user?.id) return;
        let alive = true;
        async function load() {
            setError('');
            try {
                const res = await fetch(`/api/chat?userId=${encodeURIComponent(user.id)}`);
                const data = await res.json().catch(() => ({}));
                if (!alive) return;
                if (!res.ok) throw new Error(data.error || 'Could not load messages.');
                setConversations(data.conversations || []);
            } catch (err) {
                if (alive) setError(err.message || 'Could not load messages.');
            } finally {
                if (alive) setLoading(false);
            }
        }
        load();
        const stop = startPolling(load, POLL.MESSAGES);
        return () => { alive = false; stop(); };
    }, [user?.id]);

    const visible = conversations.filter((item) => {
        const text = `${item.peer?.display_name || ''} ${item.latestMessage?.body || ''}`.toLowerCase();
        return text.includes(search.toLowerCase());
    });

    return (
        <div className="px-4 py-4 pb-28 space-y-4">
            <div className="flex items-center justify-between gap-3">
                <div>
                    <h1 className="text-xl font-black text-text-primary">Messages</h1>
                    <p className="text-xs text-text-muted">Real member conversations, voice notes, GIFs, gifts, and media.</p>
                </div>
                <div className="w-11 h-11 rounded-full gradient-primary text-white flex items-center justify-center">
                    <MessageCircle size={20} />
                </div>
            </div>

            <LiveNowStrip title="Live Members You Can Join" />
            <StoriesStrip title="Message Stories" />
            <BoostedMembersStrip title="Boosted Members To Message" />

            <Link href="/messages/community" className="flex items-center gap-3 rounded-2xl p-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <div className="h-12 w-12 rounded-2xl gradient-primary text-white flex items-center justify-center"><Megaphone size={20} /></div>
                <div className="min-w-0 flex-1">
                    <p className="text-sm font-black text-text-primary">GS App Community</p>
                    <p className="text-xs text-text-muted truncate">Official updates, user instructions, safety tips, boosts, stories, and package guidance.</p>
                </div>
                <span className="rounded-full bg-secondary/10 px-2 py-1 text-[10px] font-black text-secondary inline-flex items-center gap-1"><Rocket size={11} /> New</span>
            </Link>

            <label className="relative block">
                <Search size={17} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted" />
                <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search conversations" className="w-full rounded-2xl py-3 pl-10 pr-4 text-sm" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }} />
            </label>

            {error && <div className="rounded-2xl p-3 text-xs font-bold text-danger bg-danger/10">{error}</div>}
            {loading && <div className="rounded-2xl p-4 text-sm font-bold text-primary bg-primary/10">Loading conversations...</div>}

            {!loading && visible.length === 0 ? (
                <div className="text-center py-16 space-y-3">
                    <div className="w-16 h-16 mx-auto rounded-full bg-primary/10 text-primary flex items-center justify-center"><MessageCircle size={30} /></div>
                    <h2 className="text-lg font-black text-text-primary">No Conversations Yet</h2>
                    <p className="text-sm text-text-muted max-w-xs mx-auto">Open a member profile and start a premium message thread. Your chats will appear here.</p>
                    <Link href="/members" className="inline-flex rounded-2xl px-5 py-3 text-sm font-black text-white gradient-primary">Browse Members</Link>
                </div>
            ) : (
                <div className="space-y-2">
                    {visible.map((item) => {
                        const peer = item.peer || {};
                        const latest = item.latestMessage;
                        const photo = peer.avatar_url || peer.photos?.[0] || '';
                        return (
                            <Link key={item.id} href={`/messages/${item.peerId}`} className="flex items-center gap-3 rounded-2xl p-3 active:scale-[0.99]" style={{ background: item.unreadCount ? 'rgba(15,118,110,0.08)' : 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                                <div className="relative shrink-0">
                                    <UserAvatar name={peer.display_name || 'Member'} src={photo} size={52} />
                                    <span className={`absolute bottom-0 right-0 h-3.5 w-3.5 rounded-full ring-2 ring-white ${onlineTone(peer)}`} />
                                    {item.unreadCount > 0 && <span className="absolute -right-1 -top-1 min-w-5 h-5 rounded-full bg-secondary text-white text-[10px] font-black flex items-center justify-center px-1">{item.unreadCount > 99 ? '99+' : item.unreadCount}</span>}
                                </div>
                                <div className="min-w-0 flex-1">
                                    <div className="flex items-center gap-1">
                                        <p className="text-sm font-black text-text-primary truncate">{peer.display_name || 'Member'}</p>
                                        <VerifiedBadge verified={peer.verified} size={14} />
                                    </div>
                                    <p className="text-xs text-text-secondary truncate">{latest?.body || 'Conversation opened'}</p>
                                </div>
                                <span className="text-[10px] font-bold text-text-muted">{timeText(latest?.created_at || item.updated_at)}</span>
                            </Link>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
