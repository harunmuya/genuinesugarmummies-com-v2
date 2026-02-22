'use client';

import { useEffect, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Heart, MessageCircle, Bell, Eye, UserCheck,
    Zap, Send, Star, Sparkles, ExternalLink,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';

const ICON_MAP = {
    like: { icon: Heart, color: '#EC4899', bg: '#fce7f3' },
    match: { icon: Sparkles, color: '#7C3AED', bg: '#ede9fe' },
    meetup_ready: { icon: Zap, color: '#F59E0B', bg: '#fef3c7' },
    connection_request: { icon: UserCheck, color: '#14B8A6', bg: '#ccfbf1' },
    request_hookup: { icon: Star, color: '#EC4899', bg: '#fce7f3' },
    message: { icon: Send, color: '#3B82F6', bg: '#dbeafe' },
    view: { icon: Eye, color: '#6B7280', bg: '#f3f4f6' },
    profile_update: { icon: Bell, color: '#7C3AED', bg: '#ede9fe' },
    login: { icon: UserCheck, color: '#10B981', bg: '#d1fae5' },
    comment_sent: { icon: MessageCircle, color: '#3B82F6', bg: '#dbeafe' },
};

function timeAgo(ts) {
    const diff = (Date.now() - new Date(ts).getTime()) / 1000;
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
}

export default function AlertsPage() {
    const router = useRouter();
    const { activity, markActivityRead } = useAuth();

    useEffect(() => {
        const timer = setTimeout(() => markActivityRead(), 2000);
        return () => clearTimeout(timer);
    }, [markActivityRead]);

    const sortedActivity = useMemo(() => {
        return [...activity]
            .filter(a => a.type !== 'login' && a.type !== 'profile_update')
            .slice(0, 50);
    }, [activity]);

    const unreadCount = sortedActivity.filter(a => !a.read).length;

    const handleAlertClick = (item) => {
        if (item.profileId) {
            router.push(`/discover/${item.profileId}`);
        } else if (item.type === 'connection_request' || item.type === 'meetup_ready' || item.type === 'request_hookup') {
            const msg = encodeURIComponent(`Hi, I'm interested in connecting`);
            window.open(`https://t.me/GSADMINMARYGAGENCY?text=${msg}`, '_blank');
        }
    };

    return (
        <div className="px-4 py-4 space-y-4">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-xl font-black text-text-primary">Alerts</h1>
                    {unreadCount > 0 && (
                        <p className="text-xs text-primary font-medium">{unreadCount} new notifications</p>
                    )}
                </div>
            </div>

            {sortedActivity.length === 0 ? (
                <div className="text-center py-16 space-y-4">
                    <div className="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center">
                        <Bell size={32} className="text-primary" />
                    </div>
                    <h3 className="text-lg font-bold text-text-primary">No Alerts Yet</h3>
                    <p className="text-sm text-text-muted max-w-xs mx-auto">
                        When sugar mummies interact with you, your alerts will appear here.
                    </p>
                </div>
            ) : (
                <div className="space-y-2">
                    <AnimatePresence initial={false}>
                        {sortedActivity.map((item, i) => {
                            const config = ICON_MAP[item.type] || ICON_MAP.view;
                            const Icon = config.icon;
                            const isClickable = item.profileId || ['connection_request', 'meetup_ready', 'request_hookup'].includes(item.type);

                            return (
                                <motion.div
                                    key={item.id}
                                    initial={{ opacity: 0, y: 10 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    transition={{ delay: i * 0.03 }}
                                    onClick={() => isClickable && handleAlertClick(item)}
                                    className={`flex items-start gap-3 p-3 rounded-2xl transition-all ${!item.read ? 'bg-primary/5' : ''
                                        } ${isClickable ? 'cursor-pointer active:scale-[0.98]' : ''}`}
                                    style={{ border: 'var(--card-border)' }}
                                >
                                    {/* Icon or Avatar */}
                                    {item.image ? (
                                        <div className="w-10 h-10 rounded-full overflow-hidden shrink-0">
                                            <img src={item.image} alt="" className="w-full h-full object-cover" loading="lazy" />
                                        </div>
                                    ) : (
                                        <div className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                                            style={{ backgroundColor: config.bg }}>
                                            <Icon size={18} style={{ color: config.color }} />
                                        </div>
                                    )}

                                    {/* Content */}
                                    <div className="flex-1 min-w-0">
                                        <p className="text-sm font-semibold text-text-primary leading-snug truncate">
                                            {item.title}
                                        </p>
                                        {item.message && (
                                            <p className="text-xs text-text-muted mt-0.5 truncate">{item.message}</p>
                                        )}
                                        <p className="text-[10px] text-text-muted mt-1">{timeAgo(item.timestamp)}</p>
                                    </div>

                                    {/* Unread dot */}
                                    {!item.read && (
                                        <div className="w-2 h-2 rounded-full bg-primary shrink-0 mt-2" />
                                    )}

                                    {isClickable && (
                                        <ExternalLink size={14} className="text-text-muted shrink-0 mt-1.5" />
                                    )}
                                </motion.div>
                            );
                        })}
                    </AnimatePresence>
                </div>
            )}
        </div>
    );
}
