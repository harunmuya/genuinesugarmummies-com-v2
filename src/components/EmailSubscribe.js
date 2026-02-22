'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mail, Bell, CheckCircle, AlertCircle, Loader2, X } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

export default function EmailSubscribe({ compact = false, onClose }) {
    const { user, verificationStatus } = useAuth();
    const [email, setEmail] = useState(user?.email || '');
    const [name, setName] = useState(user?.display_name || '');
    const [loading, setLoading] = useState(false);
    const [result, setResult] = useState(null);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!email || loading) return;

        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            setResult({ success: false, message: 'Please enter a valid email address.' });
            return;
        }

        setLoading(true);
        setResult(null);

        try {
            const res = await fetch('/api/subscribe', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    email: email.trim(),
                    name: name.trim(),
                    is_verified: verificationStatus === 'verified',
                }),
            });

            const data = await res.json();
            setResult({ success: true, message: data.message || 'Check your email to confirm!' });
        } catch {
            setResult({ success: false, message: 'Network error. Please try again.' });
        } finally {
            setLoading(false);
        }
    };

    if (compact) {
        return (
            <div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                            <Bell size={16} className="text-primary" />
                        </div>
                        <div>
                            <h4 className="text-sm font-bold text-text-primary">Get Notified</h4>
                            <p className="text-[10px] text-text-muted">New profiles straight to your inbox</p>
                        </div>
                    </div>
                    {onClose && (
                        <button onClick={onClose} className="p-1">
                            <X size={14} className="text-text-muted" />
                        </button>
                    )}
                </div>

                {result?.success ? (
                    <div className="flex items-center gap-2 py-2">
                        <CheckCircle size={16} className="text-success shrink-0" />
                        <span className="text-xs text-success font-medium">{result.message}</span>
                    </div>
                ) : (
                    <form onSubmit={handleSubmit} className="flex gap-2">
                        <input
                            type="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            placeholder="your@email.com"
                            className="flex-1 rounded-xl py-2.5 px-3 text-sm text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50"
                            style={{ background: 'var(--color-bg-input)', border: 'var(--card-border)' }}
                        />
                        <button
                            type="submit"
                            disabled={loading || !email}
                            className="px-4 py-2.5 rounded-xl font-semibold text-white gradient-primary disabled:opacity-50 text-sm flex items-center gap-1.5"
                        >
                            {loading ? <Loader2 size={14} className="animate-spin" /> : <Mail size={14} />}
                            {loading ? '' : 'Subscribe'}
                        </button>
                    </form>
                )}

                {result && !result.success && (
                    <div className="flex items-center gap-2">
                        <AlertCircle size={14} className="text-danger shrink-0" />
                        <span className="text-xs text-danger">{result.message}</span>
                    </div>
                )}
            </div>
        );
    }

    return (
        <div className="rounded-2xl p-5 space-y-4" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
            <div className="text-center space-y-2">
                <div className="w-14 h-14 mx-auto rounded-full bg-primary/10 flex items-center justify-center">
                    <Bell size={28} className="text-primary" />
                </div>
                <h3 className="text-lg font-bold text-text-primary">Stay Updated</h3>
                <p className="text-sm text-text-secondary leading-relaxed">
                    Get email notifications when new sugar mummy profiles are posted. Never miss a connection!
                </p>
            </div>

            {result?.success ? (
                <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
                    className="text-center py-4 space-y-2">
                    <CheckCircle size={40} className="text-success mx-auto" />
                    <p className="text-sm font-semibold text-success">{result.message}</p>
                    <p className="text-xs text-text-muted">Check your inbox (and spam folder) for the confirmation email.</p>
                </motion.div>
            ) : (
                <form onSubmit={handleSubmit} className="space-y-3">
                    <input
                        type="text"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        placeholder="Your Name"
                        className="w-full rounded-xl py-3 px-4 text-sm text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50"
                        style={{ background: 'var(--color-bg-input)', border: 'var(--card-border)' }}
                    />
                    <input
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        placeholder="your@email.com"
                        required
                        className="w-full rounded-xl py-3 px-4 text-sm text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50"
                        style={{ background: 'var(--color-bg-input)', border: 'var(--card-border)' }}
                    />
                    <button
                        type="submit"
                        disabled={loading || !email}
                        className="w-full py-3.5 rounded-2xl font-semibold text-white gradient-primary disabled:opacity-50 flex items-center justify-center gap-2"
                    >
                        {loading ? (
                            <Loader2 size={18} className="animate-spin" />
                        ) : (
                            <>
                                <Mail size={18} />
                                Subscribe to Updates
                            </>
                        )}
                    </button>

                    {result && !result.success && (
                        <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-danger/10">
                            <AlertCircle size={14} className="text-danger shrink-0" />
                            <span className="text-xs text-danger">{result.message}</span>
                        </div>
                    )}

                    <p className="text-[10px] text-text-muted text-center leading-relaxed">
                        We'll only email you about new profiles. You can unsubscribe anytime.
                    </p>
                </form>
            )}
        </div>
    );
}
