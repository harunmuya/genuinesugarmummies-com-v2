'use client';

import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mail, User, ArrowRight, Heart, Gem, Users, LogIn, UserPlus, LockKeyhole, KeyRound, ShieldCheck } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import Logo from '@/components/Logo';

const PREFERENCES = [
    { value: 'sugar_mummy_looking_for_toyboy', label: 'I am a Sugar Mummy', desc: 'Looking for a sugar guy / toyboy', icon: Heart, color: '#E11D48' },
    { value: 'sugar_daddy_looking_for_mistress', label: 'I am a Sugar Daddy', desc: 'Looking for an adult mistress', icon: Gem, color: '#0EA5E9' },
    { value: 'mistress_looking_for_sugar_daddy', label: 'I am a Mistress', desc: 'Looking for a sugar daddy', icon: Users, color: '#0F766E' },
    { value: 'toyboy_looking_for_sugar_mummy', label: 'I am a Sugar Guy / Toyboy', desc: 'Looking for a sugar mummy', icon: Heart, color: '#F59E0B' },
];

function isComplete(account) {
    return Boolean((account?.avatar_url || account?.photos?.[0]) && account?.bio && account?.age && account?.location);
}

function hardRedirect(path) {
    if (typeof window === 'undefined') return;
    window.location.assign(path);
    window.setTimeout(() => { window.location.href = path; }, 250);
}

export default function LoginPage() {
    const { signIn, signInExisting, requestPasswordReset, resetPassword } = useAuth();
    const [mode, setMode] = useState('signin');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [resetCode, setResetCode] = useState('');
    const [displayName, setDisplayName] = useState('');
    const [selectedPreference, setSelectedPreference] = useState('sugar_mummy_looking_for_toyboy');
    const [step, setStep] = useState(1);
    const [resetSent, setResetSent] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [notice, setNotice] = useState('');

    useEffect(() => {
        try {
            const savedEmail = JSON.parse(localStorage.getItem('gscom_login_email') || 'null');
            if (savedEmail && !email) setEmail(savedEmail);
        } catch {}
    }, []);

    function validEmail(value) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
    }

    function validPassword(value) {
        return String(value || '').length >= 6;
    }

    async function handleExistingSubmit(event) {
        event.preventDefault();
        setError('');
        setNotice('');
        if (!validEmail(email.trim())) { setError('Please enter a valid email.'); return; }
        if (!validPassword(password)) { setError('Enter your password, at least 6 characters.'); return; }
        setLoading(true);
        try {
            const account = await signInExisting(email.trim(), password);
            hardRedirect(isComplete(account) ? '/discover' : '/profile?complete=1');
        } catch (err) {
            setError(err.message || 'Could not sign in.');
        } finally {
            setLoading(false);
        }
    }

    function handleCreateEmail(event) {
        event.preventDefault();
        setError('');
        setNotice('');
        if (!validEmail(email.trim())) { setError('Please enter a valid email.'); return; }
        if (!validPassword(password)) { setError('Create a password with at least 6 characters.'); return; }
        if (!displayName.trim()) { setError('Add your display name.'); return; }
        setStep(2);
    }

    async function handleCreateAccount() {
        setLoading(true);
        setError('');
        setNotice('');
        try {
            await Promise.resolve(signIn(email.trim(), password, displayName.trim(), selectedPreference));
            hardRedirect('/profile?complete=1');
        } catch (err) {
            setError(err.message || 'Something went wrong. Please try again.');
        } finally {
            setLoading(false);
        }
    }

    async function handleSendReset(event) {
        event.preventDefault();
        setError('');
        setNotice('');
        if (!validEmail(email.trim())) { setError('Enter the email on your account.'); return; }
        setLoading(true);
        try {
            await requestPasswordReset(email.trim());
            setResetSent(true);
            setNotice('Reset code sent to your email.');
        } catch (err) {
            setError(err.message || 'Could not send reset code.');
        } finally {
            setLoading(false);
        }
    }

    async function handleResetPassword(event) {
        event.preventDefault();
        setError('');
        setNotice('');
        if (!/^\d{6}$/.test(resetCode.trim())) { setError('Enter the 6-digit reset code.'); return; }
        if (!validPassword(newPassword)) { setError('New password must be at least 6 characters.'); return; }
        setLoading(true);
        try {
            const account = await resetPassword(email.trim(), resetCode.trim(), newPassword);
            hardRedirect(isComplete(account) ? '/discover' : '/profile?complete=1');
        } catch (err) {
            setError(err.message || 'Could not reset password.');
        } finally {
            setLoading(false);
        }
    }

    function switchMode(nextMode) {
        setMode(nextMode);
        setStep(1);
        setResetSent(false);
        setError('');
        setNotice('');
    }

    return (
        <div className="min-h-dvh flex flex-col" style={{ background: 'linear-gradient(180deg, #ecfeff 0%, #fff7ed 48%, #ffffff 100%)' }}>
            <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} className="flex flex-col items-center pt-12 pb-5 px-6">
                <Logo size={76} />
                <p className="text-sm text-text-secondary mt-3 text-center max-w-xs">Sign in, create your profile, or reset your password.</p>
            </motion.div>

            <div className="px-6 max-w-md mx-auto w-full pb-8">
                <div className="grid grid-cols-3 gap-2 mb-5 rounded-2xl p-1 bg-white" style={{ border: 'var(--card-border)' }}>
                    <button type="button" onClick={() => switchMode('signin')} className={`rounded-xl py-3 text-xs font-black flex items-center justify-center gap-1 ${mode === 'signin' ? 'gradient-primary text-white' : 'text-text-secondary'}`}><LogIn size={15} /> Login</button>
                    <button type="button" onClick={() => switchMode('signup')} className={`rounded-xl py-3 text-xs font-black flex items-center justify-center gap-1 ${mode === 'signup' ? 'gradient-primary text-white' : 'text-text-secondary'}`}><UserPlus size={15} /> Sign Up</button>
                    <button type="button" onClick={() => switchMode('forgot')} className={`rounded-xl py-3 text-xs font-black flex items-center justify-center gap-1 ${mode === 'forgot' ? 'gradient-primary text-white' : 'text-text-secondary'}`}><KeyRound size={15} /> Reset</button>
                </div>

                {notice && <p className="mb-4 rounded-2xl bg-success/10 text-success text-sm text-center font-bold p-3">{notice}</p>}
                {error && <p className="mb-4 rounded-2xl bg-danger/10 text-danger text-sm text-center font-bold p-3">{error}</p>}

                {mode === 'signin' && (
                    <form onSubmit={handleExistingSubmit} className="space-y-4">
                        <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Email address" type="email" autoFocus />
                        <Field icon={LockKeyhole} value={password} onChange={(value) => { setPassword(value); setError(''); }} placeholder="Password" type="password" />
                        <button disabled={loading} className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base disabled:opacity-60">
                            {loading ? <Spinner /> : <>Login <ArrowRight size={20} /></>}
                        </button>
                        <button type="button" onClick={() => switchMode('forgot')} className="w-full py-2 text-xs font-bold text-primary">Forgot password?</button>
                    </form>
                )}

                {mode === 'forgot' && (
                    <form onSubmit={resetSent ? handleResetPassword : handleSendReset} className="space-y-4">
                        <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Email on your account" type="email" autoFocus />
                        {resetSent && <Field icon={ShieldCheck} value={resetCode} onChange={(value) => { setResetCode(value.replace(/\D/g, '').slice(0, 6)); setError(''); }} placeholder="6-digit reset code" inputMode="numeric" />}
                        {resetSent && <Field icon={LockKeyhole} value={newPassword} onChange={(value) => { setNewPassword(value); setError(''); }} placeholder="New password" type="password" />}
                        <button disabled={loading} className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base disabled:opacity-60">
                            {loading ? <Spinner /> : resetSent ? <>Reset Password <ArrowRight size={20} /></> : <>Send Reset Code <ArrowRight size={20} /></>}
                        </button>
                        {resetSent && <button type="button" onClick={handleSendReset} className="w-full py-2 text-xs font-bold text-primary">Send a new code</button>}
                    </form>
                )}

                {mode === 'signup' && (
                    <AnimatePresence mode="wait">
                        {step === 1 ? (
                            <motion.form key="create1" onSubmit={handleCreateEmail} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-4">
                                <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Your real email address" type="email" autoFocus />
                                <Field icon={LockKeyhole} value={password} onChange={(value) => { setPassword(value); setError(''); }} placeholder="Create password" type="password" />
                                <Field icon={User} value={displayName} onChange={(value) => { setDisplayName(value); setError(''); }} placeholder="Display name" />
                                <button className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base">Continue <ArrowRight size={20} /></button>
                            </motion.form>
                        ) : (
                            <motion.div key="create2" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-4">
                                <div className="space-y-3">
                                    {PREFERENCES.map((pref) => {
                                        const Icon = pref.icon;
                                        const selected = selectedPreference === pref.value;
                                        return (
                                            <button type="button" key={pref.value} onClick={() => setSelectedPreference(pref.value)} className="w-full flex items-center gap-4 p-4 rounded-2xl transition-all" style={{ background: selected ? `${pref.color}12` : 'white', border: `2px solid ${selected ? pref.color : 'rgba(0,0,0,0.06)'}` }}>
                                                <div className="w-12 h-12 rounded-xl flex items-center justify-center" style={{ background: `${pref.color}18` }}><Icon size={24} style={{ color: pref.color }} /></div>
                                                <div className="flex-1 text-left"><p className="font-bold text-text-primary">{pref.label}</p><p className="text-xs text-text-muted">{pref.desc}</p></div>
                                                <div className="w-5 h-5 rounded-full border-2" style={{ borderColor: selected ? pref.color : '#d1d5db', background: selected ? pref.color : 'transparent' }} />
                                            </button>
                                        );
                                    })}
                                </div>
                                <button type="button" onClick={handleCreateAccount} disabled={loading} className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base disabled:opacity-60">{loading ? <Spinner /> : <>Create Account <ArrowRight size={20} /></>}</button>
                                <button type="button" onClick={() => setStep(1)} className="w-full py-3 text-sm font-medium text-text-muted">Back</button>
                            </motion.div>
                        )}
                    </AnimatePresence>
                )}
            </div>
        </div>
    );
}

function Field({ icon: Icon, value, onChange, placeholder, type = 'text', autoFocus = false, inputMode }) {
    return <div className="relative"><Icon size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted" /><input type={type} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} autoFocus={autoFocus} inputMode={inputMode} autoComplete={type === 'password' ? (placeholder.toLowerCase().includes('create') || placeholder.toLowerCase().includes('new') ? 'new-password' : 'current-password') : 'email'} className="w-full rounded-2xl py-4 pl-12 pr-4 text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50 text-base" style={{ background: 'white', border: 'var(--card-border)' }} /></div>;
}

function Spinner() {
    return <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />;
}
