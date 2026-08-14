'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import { MessageCircle, X } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';

/**
 * The moment two people turn out to have liked each other.
 *
 * Without this a mutual like is invisible: the like API now detects it and
 * returns matched:true, but if the screen simply advances to the next profile
 * nobody ever learns it happened. This is the payoff the whole swipe loop
 * exists for, and it is also the only natural prompt to send a first message.
 *
 * Render it wherever a like can happen and pass the peer returned by the API.
 */
export default function MatchCelebration({ match, me, onClose }) {
    // Escape closes it, because a full-screen overlay with one small button is
    // a trap on a keyboard and for anyone using a screen reader.
    useEffect(() => {
        if (!match) return undefined;
        const onKey = (event) => { if (event.key === 'Escape') onClose?.(); };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
    }, [match, onClose]);

    return (
        <AnimatePresence>
            {match && (
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    role="dialog"
                    aria-modal="true"
                    aria-label="It is a match"
                    className="fixed inset-0 z-[95] flex items-center justify-center px-6"
                    style={{ background: 'rgba(6, 10, 13, 0.92)' }}
                >
                    <button
                        onClick={onClose}
                        aria-label="Close"
                        className="absolute right-4 top-4 rounded-xl p-2.5 text-text-muted"
                    >
                        <X size={22} />
                    </button>

                    <div className="w-full max-w-sm space-y-7 text-center">
                        <motion.div
                            initial={{ scale: 0.8, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            transition={{ delay: 0.05, type: 'spring', stiffness: 220, damping: 18 }}
                            className="space-y-2"
                        >
                            <h2
                                className="font-display text-4xl font-bold"
                                style={{
                                    background: 'var(--gradient-primary)',
                                    WebkitBackgroundClip: 'text',
                                    backgroundClip: 'text',
                                    color: 'transparent',
                                }}
                            >
                                It&apos;s a match
                            </h2>
                            <p className="text-sm text-text-secondary">
                                You and {match.name} liked each other
                            </p>
                        </motion.div>

                        {/* The two faces, overlapping, so it reads as a pair. */}
                        <div className="flex items-center justify-center">
                            <motion.div
                                initial={{ x: -30, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                transition={{ delay: 0.12 }}
                                className="rounded-full ring-4"
                                style={{ ringColor: 'var(--color-bg-dark)', marginRight: -18 }}
                            >
                                <UserAvatar name={me?.display_name || me?.name || 'You'} src={me?.avatarUrl || me?.avatar_url} size={104} />
                            </motion.div>
                            <motion.div
                                initial={{ x: 30, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                transition={{ delay: 0.12 }}
                                className="rounded-full ring-4"
                                style={{ ringColor: 'var(--color-bg-dark)', marginLeft: -18 }}
                            >
                                <UserAvatar name={match.name} src={match.avatarUrl} size={104} />
                            </motion.div>
                        </div>

                        <motion.div
                            initial={{ y: 16, opacity: 0 }}
                            animate={{ y: 0, opacity: 1 }}
                            transition={{ delay: 0.2 }}
                            className="space-y-2.5"
                        >
                            <Link
                                href={`/messages/${match.id}`}
                                onClick={onClose}
                                className="flex h-13 w-full items-center justify-center gap-2 rounded-xl px-6 py-3.5 font-bold text-bg-dark"
                                style={{ background: 'var(--gradient-primary)' }}
                            >
                                <MessageCircle size={19} /> Send a message
                            </Link>
                            <button
                                onClick={onClose}
                                className="h-12 w-full rounded-xl text-sm font-semibold text-text-muted"
                            >
                                Keep browsing
                            </button>
                        </motion.div>
                    </div>
                </motion.div>
            )}
        </AnimatePresence>
    );
}
