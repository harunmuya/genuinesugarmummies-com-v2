'use client';

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Heart, Loader2, MessageCircle, Sparkles, Compass } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import StoriesStrip from '@/components/StoriesStrip';
import { startPolling, POLL } from '@/lib/poll';

/**
 * People who liked you back.
 *
 * This screen used to request the entire member directory with per_page=240 and
 * relabel it "matches", so it showed people who had never liked anybody and had
 * no idea this account existed. There was no mutual-like check anywhere in the
 * app, and the matches table had never been written to, so a real match could
 * not have been displayed even in principle.
 *
 * It now reads the matches table, which the like handler fills in when it finds
 * a reciprocal like.
 */

function matchAge(iso) {
    if (!iso) return '';
    const minutes = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
    if (minutes < 1) return 'just now';
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days === 1) return 'yesterday';
    if (days < 7) return `${days} days ago`;
    return new Date(iso).toLocaleDateString();
}

export default function MatchesPage() {
    const { user } = useAuth();
    const [matches, setMatches] = useState([]);
    const [loading, setLoading] = useState(true);
    const [schemaReady, setSchemaReady] = useState(true);

    const load = useCallback(async () => {
        if (!user?.id && !user?.email) return;
        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'matches', memberId: user?.id, email: user?.email }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) return;
            setMatches(data.matches || []);
            setSchemaReady(data.schemaReady !== false);
        } catch {
            // Leave whatever is on screen rather than blanking it.
        } finally {
            setLoading(false);
        }
    }, [user?.id, user?.email]);

    useEffect(() => {
        if (!user?.id && !user?.email) { setLoading(false); return undefined; }
        return startPolling(load, POLL.MESSAGES);
    }, [load, user?.id, user?.email]);

    const waiting = loading && matches.length === 0;

    return (
        <div className="space-y-5 px-4 pb-6 pt-3">
            <StoriesStrip />

            <header className="space-y-1">
                <h1 className="font-display text-2xl font-bold text-text-primary">Matches</h1>
                <p className="text-sm text-text-muted">
                    {matches.length > 0
                        ? `${matches.length} ${matches.length === 1 ? 'person' : 'people'} liked you back`
                        : 'People you liked who liked you back appear here'}
                </p>
            </header>

            {!schemaReady && (
                <p className="rounded-xl bg-surface p-3 text-xs text-text-muted">
                    Matches are still being set up on this account. Nothing is lost; check back shortly.
                </p>
            )}

            {waiting ? (
                <div className="flex items-center justify-center py-16 text-primary">
                    <Loader2 size={26} className="animate-spin" />
                </div>
            ) : matches.length === 0 ? (
                /*
                  An empty matches list is the normal state for a new account,
                  not a failure, so this explains the mechanic and points at the
                  screen where it happens rather than apologising.
                */
                <section className="space-y-4 py-10 text-center">
                    <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
                        <Heart size={28} className="text-primary" />
                    </div>
                    <div className="space-y-1.5">
                        <h2 className="font-display text-lg font-bold text-text-primary">No matches yet</h2>
                        <p className="mx-auto max-w-xs text-sm text-text-muted">
                            When you like someone and they like you back, you both land here and can
                            message each other straight away.
                        </p>
                    </div>
                    <Link
                        href="/discover"
                        className="inline-flex h-12 items-center justify-center gap-2 rounded-xl bg-primary px-6 font-bold text-bg-dark"
                    >
                        <Compass size={18} /> Start browsing
                    </Link>
                </section>
            ) : (
                <section className="space-y-3">
                    {matches.map((match, index) => {
                        const member = match.member;
                        return (
                            <motion.article
                                key={match.id}
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                transition={{ delay: Math.min(index * 0.03, 0.3) }}
                                className="flex items-center gap-3 rounded-xl p-3"
                                style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}
                            >
                                <Link href={`/members/${member.id}`} className="shrink-0">
                                    <UserAvatar name={member.name} src={member.avatarUrl} size={56} />
                                </Link>

                                <div className="min-w-0 flex-1">
                                    <div className="flex items-center gap-1.5">
                                        <Link
                                            href={`/members/${member.id}`}
                                            className="truncate font-semibold text-text-primary"
                                        >
                                            {member.name}
                                        </Link>
                                        {member.verified && <VerifiedBadge size={14} />}
                                        {match.superLike && (
                                            <Sparkles size={13} className="shrink-0 text-accent" aria-label="Super like" />
                                        )}
                                    </div>
                                    <p className="truncate text-xs text-text-muted">
                                        {[member.age, member.location].filter(Boolean).join(' · ')}
                                    </p>
                                    <p className="mt-0.5 text-[11px] text-text-muted">
                                        {match.lastMessageAt
                                            ? `Last message ${matchAge(match.lastMessageAt)}`
                                            : `Matched ${matchAge(match.matchedAt)}`}
                                    </p>
                                </div>

                                <Link
                                    href={`/messages/${member.id}`}
                                    aria-label={`Message ${member.name}`}
                                    className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary text-bg-dark"
                                >
                                    <MessageCircle size={19} />
                                </Link>
                            </motion.article>
                        );
                    })}
                </section>
            )}
        </div>
    );
}
