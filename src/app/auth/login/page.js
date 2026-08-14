'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import { Mail, User, ArrowRight, Heart, Gem, Users, LogIn, UserPlus, LockKeyhole, KeyRound, ShieldCheck, Camera, AtSign, Calendar, MapPin, Phone, FileText } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import Logo from '@/components/Logo';

const PREFERENCES = [
    { value: 'sugar_mummy_looking_for_toyboy', label: 'I am a Sugar Mummy', desc: 'Looking for a sugar guy / toyboy', icon: Heart, color: '#E11D48' },
    { value: 'sugar_daddy_looking_for_mistress', label: 'I am a Sugar Daddy', desc: 'Looking for an adult mistress', icon: Gem, color: '#0EA5E9' },
    { value: 'mistress_looking_for_sugar_daddy', label: 'I am a Mistress', desc: 'Looking for a sugar daddy', icon: Users, color: '#0F766E' },
    { value: 'toyboy_looking_for_sugar_mummy', label: 'I am a Sugar Guy / Toyboy', desc: 'Looking for a sugar mummy', icon: Heart, color: '#F59E0B' },
];

const LEGAL_LINKS = [
    { href: '/terms', label: 'Terms & Conditions' },
    { href: '/privacy', label: 'Privacy' },
    { href: '/safety', label: 'Safety' },
    { href: '/community-guidelines', label: 'Rules' },
    { href: '/contact', label: 'Contact' },
];

function isComplete(account) {
    return Boolean((account?.avatar_url || account?.photos?.[0]) && account?.bio && account?.age && account?.location && (account?.phone_number || account?.phone));
}

function hardRedirect(path) {
    if (typeof window === 'undefined') return;
    window.location.assign(path);
    window.setTimeout(() => { window.location.href = path; }, 250);
}

function looksLikeEmail(value) {
    return /@/.test(String(value || ''));
}

function makeUsername(value) {
    return String(value || '')
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/^_+|_+$/g, '')
        .slice(0, 20);
}

function cleanPhone(value) {
    return String(value || '').replace(/[^\d+]/g, '').slice(0, 18);
}

export default function LoginPage() {
    const { user, signIn, signInExisting, requestPasswordReset, resetPassword } = useAuth();
    const photoInputRef = useRef(null);
    const [mode, setMode] = useState('signin');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [resetCode, setResetCode] = useState('');
    const [displayName, setDisplayName] = useState('');
    const [username, setUsername] = useState('');
    const [usernameTouched, setUsernameTouched] = useState(false);
    const [profilePhoto, setProfilePhoto] = useState('');
    const [age, setAge] = useState('');
    const [location, setLocation] = useState('');
    const [phone, setPhone] = useState('');
    const [bio, setBio] = useState('');
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
            if (new URLSearchParams(window.location.search).get('signed_out') === '1') {
                setNotice('You have been signed out.');
            }
        } catch {}
    }, []);

    useEffect(() => {
        if (typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('signed_out') === '1') return;
        if (user) hardRedirect(isComplete(user) ? '/discover' : '/profile?complete=1');
    }, [user]);

    useEffect(() => {
        if (usernameTouched) return;
        setUsername(makeUsername(displayName));
    }, [displayName, usernameTouched]);

    function validEmail(value) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
    }

    function validPassword(value) {
        return String(value || '').length >= 6;
    }

    function validName(value) {
        const text = String(value || '').trim();
        return text.length >= 2 && !looksLikeEmail(text) && /[a-zA-Z]/.test(text) && !/^\d+$/.test(text);
    }

    function validUsername(value) {
        return /^[a-z0-9_]{3,20}$/.test(String(value || '').trim());
    }

    function validAge(value) {
        const number = Number(value);
        return Number.isInteger(number) && number >= 18 && number <= 80;
    }

    function validateProfileStep() {
        if (!profilePhoto) return 'Upload one clear profile photo.';
        if (!validName(displayName)) return 'Add your real first name or public name.';
        if (!validUsername(username)) return 'Username must be 3-20 letters, numbers, or underscores.';
        if (!validAge(age)) return 'Age must be between 18 and 80.';
        if (location.trim().length < 2) return 'Add your city or area.';
        if (cleanPhone(phone).replace(/\D/g, '').length < 7) return 'Add a valid phone number.';
        if (bio.trim().length < 12) return 'Write a short bio so members know you are real.';
        return '';
    }

    function handleProfilePhoto(event) {
        const file = event.target.files?.[0];
        if (!file) return;
        if (!file.type.startsWith('image/')) {
            setError('Choose a real image for your profile photo.');
            event.target.value = '';
            return;
        }
        const reader = new FileReader();
        reader.onload = (ev) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const max = 720;
                let width = img.width;
                let height = img.height;
                if (width > max || height > max) {
                    if (width > height) {
                        height = Math.round(height * max / width);
                        width = max;
                    } else {
                        width = Math.round(width * max / height);
                        height = max;
                    }
                }
                canvas.width = width;
                canvas.height = height;
                canvas.getContext('2d').drawImage(img, 0, 0, width, height);
                setProfilePhoto(canvas.toDataURL('image/webp', 0.82));
                setError('');
            };
            img.onerror = () => setError('Could not read that photo. Try another image.');
            img.src = ev.target.result;
        };
        reader.readAsDataURL(file);
        event.target.value = '';
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
        setStep(2);
    }

    function handleProfileSubmit(event) {
        event.preventDefault();
        setError('');
        setNotice('');
        const message = validateProfileStep();
        if (message) { setError(message); return; }
        setStep(3);
    }

    async function handleCreateAccount() {
        const message = validateProfileStep();
        if (message) { setStep(2); setError(message); return; }
        setLoading(true);
        setError('');
        setNotice('');
        try {
            await Promise.resolve(signIn(email.trim(), password, displayName.trim(), selectedPreference, {
                username: username.trim(),
                avatar_url: profilePhoto,
                photos: [profilePhoto],
                age: age.trim(),
                location: location.trim(),
                phone: cleanPhone(phone),
                phone_number: cleanPhone(phone),
                bio: bio.trim(),
            }));
            hardRedirect('/profile');
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
        <div className="min-h-dvh flex flex-col app-shell">
            <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} className="flex flex-col items-center pt-12 pb-5 px-6">
                <Logo size={76} />
                <p className="text-sm text-text-secondary mt-3 text-center max-w-xs">Sign in, create your profile, or reset your password.</p>
            </motion.div>

            <div className="px-6 max-w-md mx-auto w-full pb-8">
                <div className="grid grid-cols-3 gap-2 mb-5 rounded-2xl p-1 shadow-card" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
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
                                <button className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base">Continue <ArrowRight size={20} /></button>
                            </motion.form>
                        ) : step === 2 ? (
                            <motion.form key="create2" onSubmit={handleProfileSubmit} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-4">
                                <input ref={photoInputRef} type="file" accept="image/*" className="hidden" onChange={handleProfilePhoto} />
                                <button type="button" onClick={() => photoInputRef.current?.click()} className="w-full rounded-2xl p-4 flex items-center gap-4 text-left shadow-card" style={{ background: 'var(--color-bg-card)', border: profilePhoto ? '2px solid rgba(14,143,131,0.40)' : '2px dashed rgba(14,143,131,0.35)' }}>
                                    <div className="w-20 h-20 rounded-2xl overflow-hidden bg-primary/10 flex items-center justify-center shrink-0">
                                        {profilePhoto ? <img src={profilePhoto} alt="" className="w-full h-full object-cover" /> : <Camera size={28} className="text-primary" />}
                                    </div>
                                    <div>
                                        <p className="font-black text-text-primary">{profilePhoto ? 'Profile photo added' : 'Add profile photo'}</p>
                                        <p className="text-xs text-text-muted mt-1">Required for a real dating profile</p>
                                    </div>
                                </button>
                                <Field icon={User} value={displayName} onChange={(value) => { setDisplayName(value); setError(''); }} placeholder="Real first name or public name" autoFocus />
                                <Field icon={AtSign} value={username} onChange={(value) => { setUsernameTouched(true); setUsername(makeUsername(value)); setError(''); }} placeholder="Username" />
                                <div className="grid grid-cols-2 gap-3">
                                    <Field icon={Calendar} value={age} onChange={(value) => { setAge(value.replace(/\D/g, '').slice(0, 2)); setError(''); }} placeholder="Age" inputMode="numeric" />
                                    <Field icon={Phone} value={phone} onChange={(value) => { setPhone(cleanPhone(value)); setError(''); }} placeholder="Phone" type="tel" />
                                </div>
                                <Field icon={MapPin} value={location} onChange={(value) => { setLocation(value); setError(''); }} placeholder="City or area" />
                                <TextAreaField icon={FileText} value={bio} onChange={(value) => { setBio(value.slice(0, 240)); setError(''); }} placeholder="Short bio: who you are and what you want" />
                                <button className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base">Continue <ArrowRight size={20} /></button>
                                <button type="button" onClick={() => setStep(1)} className="w-full py-3 text-sm font-medium text-text-muted">Back</button>
                            </motion.form>
                        ) : (
                            <motion.div key="create3" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-4">
                                <div className="space-y-3">
                                    {PREFERENCES.map((pref) => {
                                        const Icon = pref.icon;
                                        const selected = selectedPreference === pref.value;
                                        return (
                                            <button type="button" key={pref.value} onClick={() => setSelectedPreference(pref.value)} className="w-full flex items-center gap-4 p-4 rounded-2xl transition-all shadow-card" style={{ background: selected ? `${pref.color}12` : 'var(--color-bg-card)', border: `2px solid ${selected ? pref.color : 'rgba(14,143,131,0.10)'}` }}>
                                                <div className="w-12 h-12 rounded-xl flex items-center justify-center" style={{ background: `${pref.color}18` }}><Icon size={24} style={{ color: pref.color }} /></div>
                                                <div className="flex-1 text-left"><p className="font-bold text-text-primary">{pref.label}</p><p className="text-xs text-text-muted">{pref.desc}</p></div>
                                                <div className="w-5 h-5 rounded-full border-2" style={{ borderColor: selected ? pref.color : '#d1d5db', background: selected ? pref.color : 'transparent' }} />
                                            </button>
                                        );
                                    })}
                                </div>
                                <button type="button" onClick={handleCreateAccount} disabled={loading} className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary text-base disabled:opacity-60">{loading ? <Spinner /> : <>Create Account <ArrowRight size={20} /></>}</button>
                                <button type="button" onClick={() => setStep(2)} className="w-full py-3 text-sm font-medium text-text-muted">Back</button>
                            </motion.div>
                        )}
                    </AnimatePresence>
                )}

                <div className="mt-6 space-y-3 text-center">
                    <div className="grid grid-cols-3 gap-2 text-[11px] font-black">
                        <span className="rounded-full bg-success/10 px-2 py-1 text-success">18+ only</span>
                        <span className="rounded-full bg-primary/10 px-2 py-1 text-primary">Manual verification</span>
                        <span className="rounded-full bg-danger/10 px-2 py-1 text-danger">Report abuse</span>
                    </div>
                    <p className="text-[11px] leading-relaxed text-text-muted">
                        By logging in or creating an account, you agree to the website terms and safety rules. Verification badges are manually approved or rejected by admin.
                    </p>
                    <div className="flex flex-wrap justify-center gap-x-3 gap-y-1 text-[11px] font-bold">
                        {LEGAL_LINKS.map((item) => (
                            <Link key={item.href} href={item.href} className="text-primary hover:underline">
                                {item.label}
                            </Link>
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
}

function Field({ icon: Icon, value, onChange, placeholder, type = 'text', autoFocus = false, inputMode, autoComplete }) {
    const fallbackAutoComplete = type === 'password'
        ? (placeholder.toLowerCase().includes('create') || placeholder.toLowerCase().includes('new') ? 'new-password' : 'current-password')
        : type === 'email' ? 'email' : 'off';
    return <div className="relative"><Icon size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted" /><input type={type} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} autoFocus={autoFocus} inputMode={inputMode} autoComplete={autoComplete || fallbackAutoComplete} className="w-full rounded-2xl py-4 pl-12 pr-4 text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50 text-base shadow-card" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }} /></div>;
}

function TextAreaField({ icon: Icon, value, onChange, placeholder }) {
    return (
        <div className="relative">
            <Icon size={20} className="absolute left-4 top-5 text-text-muted" />
            <textarea value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} rows={4} className="w-full rounded-2xl py-4 pl-12 pr-4 text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/50 text-base shadow-card resize-none" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }} />
        </div>
    );
}

function Spinner() {
    return <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />;
}
