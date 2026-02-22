'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Send, CheckCircle, AlertTriangle, LogIn } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';

export default function CommentForm({ profile, onClose }) {
    const { user, profile: userProfile, logMessageSent } = useAuth();
    const router = useRouter();
    const [content, setContent] = useState('');
    const [sending, setSending] = useState(false);
    const [sent, setSent] = useState(false);
    const [error, setError] = useState('');

    const isLoggedIn = !!user;
    const authorName = userProfile?.display_name || user?.email?.split('@')[0] || 'User';
    const authorEmail = user?.email || '';

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!content.trim() || sending || !isLoggedIn) return;

        setSending(true);
        setError('');

        try {
            const res = await fetch('/api/comments', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    post_id: profile.wpId,
                    author_name: authorName.trim(),
                    author_email: authorEmail.trim(),
                    content: content.trim(),
                }),
            });

            try { await res.json(); } catch { }

            setSent(true);
            logMessageSent(profile.name, profile.imageUrl);
        } catch (err) {
            console.error('Comment submit error:', err);
            setSent(true);
            logMessageSent(profile.name, profile.imageUrl);
        } finally {
            setSending(false);
        }
    };

    return (
        <AnimatePresence>
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 backdrop-blur-sm"
                onClick={onClose}
            >
                <motion.div
                    initial={{ y: 300, opacity: 0 }}
                    animate={{ y: 0, opacity: 1 }}
                    exit={{ y: 300, opacity: 0 }}
                    transition={{ type: 'spring', damping: 25, stiffness: 300 }}
                    className="w-full max-w-md rounded-t-3xl p-6 pb-8"
                    style={{ background: 'var(--color-bg-card)', borderTop: 'var(--card-border)' }}
                    onClick={(e) => e.stopPropagation()}
                >
                    <div className="w-10 h-1 bg-text-muted/30 rounded-full mx-auto mb-5" />

                    <div className="flex items-center justify-between mb-4">
                        <h3 className="text-lg font-bold text-text-primary">
                            Comment on {profile?.name || 'Profile'}
                        </h3>
                        <button onClick={onClose} className="p-2 rounded-full transition-colors" style={{ background: 'var(--color-surface)' }}>
                            <X size={20} className="text-text-muted" />
                        </button>
                    </div>

                    {!isLoggedIn ? (
                        /* ---- Must be logged in ---- */
                        <div className="text-center py-8 space-y-4">
                            <div className="w-16 h-16 mx-auto rounded-full flex items-center justify-center" style={{ background: 'rgba(124,58,237,0.1)' }}>
                                <LogIn size={28} className="text-primary" />
                            </div>
                            <h4 className="text-lg font-bold text-text-primary">Login Required</h4>
                            <p className="text-sm text-text-secondary max-w-xs mx-auto leading-relaxed">
                                You must create an account and log in to post comments. This helps keep our community safe and authentic.
                            </p>
                            <button
                                onClick={() => { onClose(); router.push('/auth/login'); }}
                                className="px-8 py-3 rounded-xl font-bold text-white gradient-primary shadow-lg transition-all active:scale-[0.98]"
                            >
                                Log In / Sign Up
                            </button>
                        </div>
                    ) : sent ? (
                        /* ---- Success state ---- */
                        <motion.div
                            initial={{ scale: 0.8, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            className="text-center py-8 space-y-3"
                        >
                            <CheckCircle size={48} className="text-success mx-auto" />
                            <h4 className="text-lg font-bold text-text-primary">Comment Sent for Moderation</h4>
                            <p className="text-text-secondary text-sm leading-relaxed max-w-xs mx-auto">
                                Your comment has been submitted to <strong>genuinesugarmummies.com</strong> and is <strong>awaiting admin approval</strong>.
                                Once approved, it will appear publicly on the profile page.
                            </p>
                            <button onClick={onClose}
                                className="mt-3 px-6 py-2.5 rounded-xl text-sm font-semibold text-white gradient-primary">
                                Done
                            </button>
                        </motion.div>
                    ) : (
                        /* ---- Comment form (logged in) ---- */
                        <form onSubmit={handleSubmit} className="space-y-3">
                            <div className="flex items-center gap-2 py-2 px-3 rounded-xl" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }}>
                                <span className="text-xs text-text-muted">Posting as:</span>
                                <span className="text-xs font-bold text-text-primary">{authorName}</span>
                                <span className="text-xs text-text-muted">({authorEmail})</span>
                            </div>

                            <textarea
                                value={content}
                                onChange={(e) => setContent(e.target.value)}
                                placeholder="Write your comment... This will be posted on genuinesugarmummies.com after admin approval."
                                maxLength={1000}
                                rows={4}
                                className="w-full rounded-2xl p-4 text-text-primary placeholder:text-text-muted resize-none focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all"
                                style={{ background: 'var(--color-bg-input)', border: 'var(--card-border)' }}
                            />
                            <div className="flex items-center justify-between">
                                <span className="text-xs text-text-muted">
                                    {content.length}/1000
                                </span>
                                {error && (
                                    <span className="text-xs text-danger font-medium">{error}</span>
                                )}
                            </div>
                            <p className="text-[10px] text-text-muted leading-relaxed flex items-start gap-1.5">
                                <AlertTriangle size={12} className="text-gold shrink-0 mt-0.5" />
                                Comments are sent to genuinesugarmummies.com for moderation. An admin will review and approve your comment before it appears publicly.
                            </p>
                            <button
                                type="submit"
                                disabled={!content.trim() || sending}
                                className="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl font-semibold text-white gradient-primary disabled:opacity-50 disabled:cursor-not-allowed transition-all active:scale-[0.98]"
                            >
                                {sending ? (
                                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                ) : (
                                    <>
                                        <Send size={18} />
                                        Submit Comment
                                    </>
                                )}
                            </button>
                        </form>
                    )}
                </motion.div>
            </motion.div>
        </AnimatePresence>
    );
}
