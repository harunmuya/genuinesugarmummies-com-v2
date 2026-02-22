'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { Mail, User, ArrowRight, Eye, Heart, Gem, Users } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import Logo from '@/components/Logo';

const PREFERENCES = [
    { value: 'sugar_mummy', label: 'Sugar Mummy', desc: 'Connect with sugar mummies', icon: Heart, color: '#EC4899' },
    { value: 'sugar_daddy', label: 'Sugar Daddy', desc: 'Connect with sugar daddies', icon: Gem, color: '#7C3AED' },
    { value: 'both', label: 'Both', desc: 'Open to all connections', icon: Users, color: '#14B8A6' },
];

export default function LoginPage() {
    const { signIn, skipLogin } = useAuth();
    const router = useRouter();
    const [email, setEmail] = useState('');
    const [displayName, setDisplayName] = useState('');
    const [selectedPreference, setSelectedPreference] = useState('sugar_mummy');
    const [step, setStep] = useState(1); // 1 = email/name, 2 = preference
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleEmailSubmit = (e) => {
        e.preventDefault();
        if (!email.trim()) { setError('Please enter your email'); return; }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { setError('Please enter a valid email'); return; }
        setStep(2);
    };

    const handleFinalSubmit = () => {
        setLoading(true);
        try {
            signIn(email.trim(), displayName.trim(), selectedPreference);
            router.replace('/discover');
        } catch {
            setError('Something went wrong. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    const handleSkip = () => {
        skipLogin();
        router.replace('/discover');
    };

    return (
        <div className="min-h-dvh flex flex-col" style={{ background: 'linear-gradient(180deg, #f5f3ff 0%, #fdf2f8 50%, #ffffff 100%)' }}>
            {/* Top section */}
            <motion.div
                initial={{ opacity: 0, y: -20 }}
                animate={{ opacity: 1, y: 0 }}
                className="flex flex-col items-center pt-16 pb-6 px-6"
            >
                <Logo size={72} />
                <h1 className="text-2xl font-black text-text-primary mt-4">
                    Genuine Sugar Mummies
                </h1>
                <p className="text-sm text-text-secondary mt-2 text-center max-w-xs">
                    {step === 1
                        ? 'Connect with verified sugar mummies near you. Sign in to start matching.'
                        : 'What are you looking for? This helps us personalize your experience.'}
                </p>
            </motion.div>

            {/* Step 1: Email + Name */}
            <AnimatePresence mode="wait">
                {step === 1 && (
                    <motion.div
                        key="step1"
                        initial={{ opacity: 0, x: 0 }}
                        animate={{ opacity: 1, x: 0 }}
                        exit={{ opacity: 0, x: -100 }}
                        className="flex-1 px-6 max-w-md mx-auto w-full"
                    >
                        <form onSubmit={handleEmailSubmit} className="space-y-4">
                            <div className="relative">
                                <Mail size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted" />
                                <input
                                    type="email" value={email}
                                    onChange={(e) => { setEmail(e.target.value); setError(''); }}
                                    placeholder="Your email address"
                                    className="w-full rounded-2xl py-4 pl-12 pr-4 text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all text-base"
                                    style={{ background: 'white', border: '1px solid rgba(124,58,237,0.15)', boxShadow: '0 2px 12px rgba(124,58,237,0.05)' }}
                                    autoFocus
                                />
                            </div>
                            <div className="relative">
                                <User size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted" />
                                <input
                                    type="text" value={displayName}
                                    onChange={(e) => setDisplayName(e.target.value)}
                                    placeholder="Display name (optional)"
                                    className="w-full rounded-2xl py-4 pl-12 pr-4 text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all text-base"
                                    style={{ background: 'white', border: '1px solid rgba(124,58,237,0.15)', boxShadow: '0 2px 12px rgba(124,58,237,0.05)' }}
                                />
                            </div>
                            {error && (
                                <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="text-danger text-sm text-center font-medium">
                                    {error}
                                </motion.p>
                            )}
                            <button
                                type="submit"
                                className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base transition-all hover:opacity-90 active:scale-[0.98] shadow-lg"
                                style={{ boxShadow: '0 4px 20px rgba(124,58,237,0.3)' }}
                            >
                                Continue <ArrowRight size={20} />
                            </button>
                        </form>

                        <div className="flex items-center gap-4 my-6">
                            <div className="flex-1 h-px bg-text-muted/20" />
                            <span className="text-xs text-text-muted font-medium">or</span>
                            <div className="flex-1 h-px bg-text-muted/20" />
                        </div>

                        <button
                            onClick={handleSkip}
                            className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-semibold text-text-secondary transition-all hover:bg-primary/5 active:scale-[0.98]"
                            style={{ border: '1px solid rgba(124,58,237,0.15)' }}
                        >
                            <Eye size={20} className="text-primary" /> Browse as Guest
                        </button>

                        <p className="text-xs text-text-muted text-center mt-6 leading-relaxed">
                            By continuing, you agree to our Terms of Service.<br />Your email is used only for app features.
                        </p>
                    </motion.div>
                )}

                {/* Step 2: Preference Selection */}
                {step === 2 && (
                    <motion.div
                        key="step2"
                        initial={{ opacity: 0, x: 100 }}
                        animate={{ opacity: 1, x: 0 }}
                        exit={{ opacity: 0, x: 100 }}
                        className="flex-1 px-6 max-w-md mx-auto w-full"
                    >
                        <div className="space-y-3 mb-6">
                            {PREFERENCES.map((pref) => {
                                const Icon = pref.icon;
                                const selected = selectedPreference === pref.value;
                                return (
                                    <button
                                        key={pref.value}
                                        onClick={() => setSelectedPreference(pref.value)}
                                        className="w-full flex items-center gap-4 p-4 rounded-2xl transition-all"
                                        style={{
                                            background: selected ? `${pref.color}10` : 'white',
                                            border: `2px solid ${selected ? pref.color : 'rgba(0,0,0,0.06)'}`,
                                            boxShadow: selected ? `0 4px 20px ${pref.color}20` : '0 2px 8px rgba(0,0,0,0.04)',
                                        }}
                                    >
                                        <div
                                            className="w-12 h-12 rounded-xl flex items-center justify-center"
                                            style={{ background: `${pref.color}15` }}
                                        >
                                            <Icon size={24} style={{ color: pref.color }} />
                                        </div>
                                        <div className="flex-1 text-left">
                                            <p className="font-bold text-text-primary">{pref.label}</p>
                                            <p className="text-xs text-text-muted">{pref.desc}</p>
                                        </div>
                                        <div
                                            className="w-5 h-5 rounded-full border-2 flex items-center justify-center"
                                            style={{ borderColor: selected ? pref.color : '#d1d5db' }}
                                        >
                                            {selected && (
                                                <div className="w-3 h-3 rounded-full" style={{ background: pref.color }} />
                                            )}
                                        </div>
                                    </button>
                                );
                            })}
                        </div>

                        <button
                            onClick={handleFinalSubmit}
                            disabled={loading}
                            className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base disabled:opacity-60 transition-all hover:opacity-90 active:scale-[0.98] shadow-lg"
                            style={{ boxShadow: '0 4px 20px rgba(124,58,237,0.3)' }}
                        >
                            {loading ? (
                                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                            ) : (
                                <>Start Matching <ArrowRight size={20} /></>
                            )}
                        </button>

                        <button
                            onClick={() => setStep(1)}
                            className="w-full py-3 mt-3 text-sm font-medium text-text-muted transition-colors hover:text-text-primary"
                        >
                            ← Back
                        </button>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}
