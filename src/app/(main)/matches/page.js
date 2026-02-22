'use client';

import { useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { Heart, MessageCircle, ExternalLink, Sparkles, Users } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

function timeAgo(ts) {
    const diff = (Date.now() - new Date(ts).getTime()) / 1000;
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
}

export default function MatchesPage() {
    const router = useRouter();
    const { matches, likes, activity } = useAuth();

    const sortedMatches = useMemo(() => {
        return [...matches].sort((a, b) => new Date(b.matchedAt) - new Date(a.matchedAt));
    }, [matches]);

    // Recent activity summary
    const recentActivity = useMemo(() => {
        return activity
            .filter(a => ['like', 'match', 'connection_request', 'request_hookup'].includes(a.type))
            .slice(0, 5);
    }, [activity]);

    return (
        <div className="px-4 py-4 space-y-6">
            {/* Header */}
            <div>
                <h1 className="text-xl font-black text-text-primary">Your Matches</h1>
                <p className="text-xs text-text-muted mt-1">
                    {matches.length} matches · {likes.length} likes
                </p>
            </div>

            {sortedMatches.length === 0 ? (
                <div className="text-center py-16 space-y-4">
                    <div className="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center">
                        <Heart size={32} className="text-primary" />
                    </div>
                    <h3 className="text-lg font-bold text-text-primary">No Matches Yet</h3>
                    <p className="text-sm text-text-muted max-w-xs mx-auto">
                        Start liking profiles to get matched! Matches appear when there's mutual interest.
                    </p>
                    <button
                        onClick={() => router.push('/discover')}
                        className="px-6 py-3 rounded-2xl font-semibold text-white gradient-primary"
                    >
                        <Sparkles size={18} className="inline mr-1" /> Discover Profiles
                    </button>
                </div>
            ) : (
                <div className="space-y-3">
                    {sortedMatches.map((match, i) => (
                        <motion.div
                            key={match.wpId || i}
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: i * 0.05 }}
                            onClick={() => router.push(`/discover/${match.wpId}`)}
                            className="flex items-center gap-3 p-3 rounded-2xl cursor-pointer transition-all active:scale-[0.98] hover:bg-primary/5"
                            style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}
                        >
                            {/* Avatar */}
                            <div className="w-14 h-14 rounded-full overflow-hidden shrink-0 ring-2 ring-primary/20">
                                {match.imageUrl ? (
                                    <img src={match.imageUrl} alt={match.name} className="w-full h-full object-cover" loading="lazy" />
                                ) : (
                                    <div className="w-full h-full bg-primary/10 flex items-center justify-center">
                                        <Users size={24} className="text-primary" />
                                    </div>
                                )}
                            </div>

                            {/* Info */}
                            <div className="flex-1 min-w-0">
                                <div className="flex items-center gap-2">
                                    <h3 className="text-sm font-bold text-text-primary truncate">{match.name}</h3>
                                    <span className="text-xs font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-full shrink-0">
                                        {match.score}%
                                    </span>
                                </div>
                                {match.location && (
                                    <p className="text-xs text-text-muted truncate mt-0.5">{match.location}</p>
                                )}
                                <p className="text-[10px] text-text-muted mt-1">{timeAgo(match.matchedAt)}</p>
                            </div>

                            {/* Actions */}
                            <div className="flex items-center gap-2 shrink-0">
                                <button
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        const msg = encodeURIComponent(`Hi, need a match connection with ${match.name}`);
                                        window.open(`https://t.me/GSADMINMARYGAGENCY?text=${msg}`, '_blank');
                                    }}
                                    className="w-9 h-9 rounded-full flex items-center justify-center transition-colors"
                                    style={{ background: 'rgba(124,58,237,0.1)' }}
                                    title="Request Connection"
                                >
                                    <ExternalLink size={16} className="text-primary" />
                                </button>
                            </div>
                        </motion.div>
                    ))}
                </div>
            )}

            {/* Recent Activity */}
            {recentActivity.length > 0 && (
                <div className="space-y-3">
                    <h2 className="text-sm font-bold text-text-primary">Recent Activity</h2>
                    {recentActivity.map((item, i) => (
                        <div key={item.id || i} className="flex items-center gap-3 py-2">
                            <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                {item.type === 'like' ? <Heart size={14} className="text-pink-500" /> :
                                    item.type === 'match' ? <Sparkles size={14} className="text-primary" /> :
                                        <MessageCircle size={14} className="text-blue-500" />}
                            </div>
                            <div className="flex-1 min-w-0">
                                <p className="text-xs font-medium text-text-primary truncate">{item.title}</p>
                                <p className="text-[10px] text-text-muted">{timeAgo(item.timestamp)}</p>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
