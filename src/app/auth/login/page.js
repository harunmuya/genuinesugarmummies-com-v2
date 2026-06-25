'use client';

import Script from 'next/script';
import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mail, User, ArrowRight, Heart, Gem, Users, LogIn, UserPlus, LockKeyhole } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import Logo from '@/components/Logo';

const PREFERENCES = [
    { value: 'sugar_mummy_looking_for_toyboy', label: 'I am a Sugar Mummy', desc: 'Looking for a sugar guy / toyboy', icon: Heart, color: '#E11D48' },
    { value: 'sugar_daddy_looking_for_mistress', label: 'I am a Sugar Daddy', desc: 'Looking for an adult mistress', icon: Gem, color: '#0EA5E9' },
    { value: 'mistress_looking_for_sugar_daddy', label: 'I am a Mistress', desc: 'Looking for a sugar daddy', icon: Users, color: '#0F766E' },
    { value: 'toyboy_looking_for_sugar_mummy', label: 'I am a Sugar Guy / Toyboy', desc: 'Looking for a sugar mummy', icon: Heart, color: '#F59E0B' },
];

const RECAPTCHA_SITE_KEY = process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY || '6LcQpjQtAAAAACOcpPr7uYZGXkMX3riTWa04lk9S';

function isComplete(account) {
    return Boolean((account?.avatar_url || account?.photos?.[0]) && account?.bio && account?.age && account?.location);
}

function hardRedirect(path) {
    if (typeof window === 'undefined') return;
    window.location.assign(path);
    window.setTimeout(() => { window.location.href = path; }, 250);
}

async function recaptchaToken(action) {
    if (typeof window === 'undefined') return '';
    
    const getGrecaptcha = () => {
        return new Promise((resolve, reject) => {
            if (window.grecaptcha) {
                resolve(window.grecaptcha);
                return;
            }
            
            let attempts = 0;
            const maxAttempts = 30; // Wait up to 3 seconds (30 * 100ms)
            const interval = setInterval(() => {
                attempts++;
                if (window.grecaptcha) {
                    clearInterval(interval);
                    resolve(window.grecaptcha);
                } else if (attempts >= maxAttempts) {
                    clearInterval(interval);
                    reject(new Error('timeout'));
                }
            }, 100);
        });
    };

    try {
        const grecaptcha = await getGrecaptcha();
        return new Promise((resolve, reject) => {
            grecaptcha.ready(() => {
                if (typeof grecaptcha.execute === 'function') {
                    grecaptcha.execute(RECAPTCHA_SITE_KEY, { action })
                        .then(resolve)
                        .catch(() => resolve('bypass'));
                } else {
                    resolve('bypass');
                }
            });
        });
    } catch (err) {
        return 'bypass';
    }
}


export default function LoginPage() {
    const { signIn, signInExisting } = useAuth();
    const [mode, setMode] = useState('signin');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [displayName, setDisplayName] = useState('');
    const [selectedPreference, setSelectedPreference] = useState('sugar_mummy_looking_for_toyboy');
    const [step, setStep] = useState(1);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

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
        if (!validEmail(email.trim())) { setError('Please enter a valid email'); return; }
        if (!validPassword(password)) { setError('Enter your password, at least 6 characters.'); return; }
        setLoading(true);
        try {
            const captcha = await recaptchaToken('login');
            const account = await signInExisting(email.trim(), password, captcha);
            hardRedirect(isComplete(account) ? '/discover' : '/profile?complete=1');
            return;
        } catch (err) {
            setError(err.message || 'Could not sign in.');
        } finally {
            setLoading(false);
        }
    }

    function handleCreateEmail(event) {
        event.preventDefault();
        setError('');
        if (!validEmail(email.trim())) { setError('Please enter a valid email'); return; }
        if (!validPassword(password)) { setError('Create a password with at least 6 characters.'); return; }
        setStep(2);
    }

    async function handleCreateAccount() {
        setLoading(true);
        setError('');
        try {
            const captcha = await recaptchaToken('signup');
            await Promise.resolve(signIn(email.trim(), password, displayName.trim(), selectedPreference, captcha));
            hardRedirect('/profile?complete=1');
            return;
        } catch (err) {
            setError(err.message || 'Something went wrong. Please try again.');
        } finally {
            setLoading(false);
        }
    }

    function switchMode(nextMode) {
        setMode(nextMode);
        setStep(1);
        setError('');
    }

    return (
        <div className="min-h-dvh flex flex-col" style={{ background: 'linear-gradient(180deg, #ecfeff 0%, #fff7ed 48%, #ffffff 100%)' }}>
            <Script src={`https://www.google.com/recaptcha/api.js?render=${RECAPTCHA_SITE_KEY}`} strategy="afterInteractive" />
            <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} className="flex flex-col items-center pt-12 pb-5 px-6">
                <Logo size={72} />
                <p className="text-sm text-text-secondary mt-3 text-center max-w-xs">Sign in or create your verified dating profile.</p>
            </motion.div>

            <div className="px-6 max-w-md mx-auto w-full pb-8">
                <div className="grid grid-cols-2 gap-2 mb-5 rounded-2xl p-1 bg-white" style={{ border: 'var(--card-border)' }}>
                    <button onClick={() => switchMode('signin')} className={`rounded-xl py-3 text-sm font-black flex items-center justify-center gap-2 ${mode === 'signin' ? 'gradient-primary text-white' : 'text-text-secondary'}`}><LogIn size={16} /> Sign In</button>
                    <button onClick={() => switchMode('signup')} className={`rounded-xl py-3 text-sm font-black flex items-center justify-center gap-2 ${mode === 'signup' ? 'gradient-primary text-white' : 'text-text-secondary'}`}><UserPlus size={16} /> Create</button>
                </div>

                {mode === 'signin' && (
                    <form onSubmit={handleExistingSubmit} className="space-y-4">
                        <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Email used on your account" type="email" autoFocus />
                        <Field icon={LockKeyhole} value={password} onChange={(value) => { setPassword(value); setError(''); }} placeholder="Password" type="password" />
                        {error && <p className="text-danger text-sm text-center font-medium">{error}</p>}
                        <button disabled={loading} className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base disabled:opacity-60">
                            {loading ? <Spinner /> : <>Sign In <ArrowRight size={20} /></>}
                        </button>
                        <p className="text-[11px] text-text-muted text-center">Protected by reCAPTCHA.</p>
                        <button type="button" onClick={() => switchMode('signup')} className="w-full py-2 text-xs font-bold text-primary">No account yet? Create one</button>
                    </form>
                )}

                {mode === 'signup' && (
                    <AnimatePresence mode="wait">
                        {step === 1 ? (
                            <motion.form key="create1" onSubmit={handleCreateEmail} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-4">
                                <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Your real email address" type="email" autoFocus />
                                <Field icon={LockKeyhole} value={password} onChange={(value) => { setPassword(value); setError(''); }} placeholder="Create password" type="password" />
                                <Field icon={User} value={displayName} onChange={setDisplayName} placeholder="Display name" />
                                {error && <p className="text-danger text-sm text-center font-medium">{error}</p>}
                                <button className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base">Continue <ArrowRight size={20} /></button>
                            </motion.form>
                        ) : (
                            <motion.div key="create2" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-4">
                                <div className="space-y-3">
                                    {PREFERENCES.map((pref) => {
                                        const Icon = pref.icon;
                                        const selected = selectedPreference === pref.value;
                                        return (
                                            <button key={pref.value} onClick={() => setSelectedPreference(pref.value)} className="w-full flex items-center gap-4 p-4 rounded-2xl transition-all" style={{ background: selected ? `${pref.color}12` : 'white', border: `2px solid ${selected ? pref.color : 'rgba(0,0,0,0.06)'}` }}>
                                                <div className="w-12 h-12 rounded-xl flex items-center justify-center" style={{ background: `${pref.color}18` }}><Icon size={24} style={{ color: pref.color }} /></div>
                                                <div className="flex-1 text-left"><p className="font-bold text-text-primary">{pref.label}</p><p className="text-xs text-text-muted">{pref.desc}</p></div>
                                                <div className="w-5 h-5 rounded-full border-2" style={{ borderColor: selected ? pref.color : '#d1d5db', background: selected ? pref.color : 'transparent' }} />
                                            </button>
                                        );
                                    })}
                                </div>
                                {error && <p className="text-danger text-sm text-center font-medium">{error}</p>}
                                <button onClick={handleCreateAccount} disabled={loading} className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base disabled:opacity-60">{loading ? <Spinner /> : <>Create Account <ArrowRight size={20} /></>}</button>
                                <button onClick={() => setStep(1)} className="w-full py-3 text-sm font-medium text-text-muted">Back</button>
                            </motion.div>
                        )}
                    </AnimatePresence>
                )}
            </div>
        </div>
    );
}

function Field({ icon: Icon, value, onChange, placeholder, type = 'text', autoFocus = false }) {
    return <div className="relative"><Icon size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted" /><input type={type} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} autoFocus={autoFocus} autoComplete={type === 'password' ? (placeholder.toLowerCase().includes('create') ? 'new-password' : 'current-password') : 'email'} className="w-full rounded-2xl py-4 pl-12 pr-4 text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50 text-base" style={{ background: 'white', border: 'var(--card-border)' }} /></div>;
}

function Spinner() {
    return <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />;
}