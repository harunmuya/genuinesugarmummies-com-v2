'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Mail, User, ArrowRight, Heart, Gem, Users, LockKeyhole, ShieldCheck, Camera, AtSign, Calendar, MapPin, Phone, FileText, ChevronDown } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import Logo from '@/components/Logo';
import MaterialIcon from '@/components/MaterialIcon';

const PREFERENCES = [
    { value: 'sugar_mummy_looking_for_toyboy', label: 'I am a Sugar Mummy', desc: 'Looking for a sugar guy / toyboy', icon: Heart, color: '#E11D48' },
    { value: 'sugar_daddy_looking_for_mistress', label: 'I am a Sugar Daddy', desc: 'Looking for an adult mistress', icon: Gem, color: '#E9034F' },
    { value: 'mistress_looking_for_sugar_daddy', label: 'I am a Mistress', desc: 'Looking for a sugar daddy', icon: Users, color: '#E9034F' },
    { value: 'toyboy_looking_for_sugar_mummy', label: 'I am a Sugar Guy / Toyboy', desc: 'Looking for a sugar mummy', icon: Heart, color: '#F59E0B' },
];

const LEGAL_LINKS = [
    { href: '/terms', label: 'Terms & Conditions' },
    { href: '/privacy', label: 'Privacy' },
    { href: '/safety', label: 'Safety' },
    { href: '/community-guidelines', label: 'Community Guidelines' },
    { href: '/contact#report', label: 'Report abuse or a safety issue' },
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
    const [termsAccepted, setTermsAccepted] = useState(false);
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

    async function handleCreateAccount(event) {
        event.preventDefault();
        setError('');
        setNotice('');
        if (!validEmail(email.trim())) { setError('Please enter a valid email.'); return; }
        if (!validPassword(password)) { setError('Create a password with at least 6 characters.'); return; }
        const message = validateProfileStep();
        if (message) { setError(message); return; }
        if (!termsAccepted) { setError('Confirm that you are 18 or older and accept the Terms and Privacy Policy.'); return; }
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
        setResetSent(false);
        setError('');
        setNotice('');
    }

    return (
        <div className="min-h-dvh flex flex-col app-shell">
            <motion.div initial={{ opacity: 0, y: -16 }} animate={{ opacity: 1, y: 0 }} className="flex flex-col items-center pt-8 pb-5 px-6">
                <Logo size={68} />
                <p className="text-sm text-text-secondary mt-3 text-center max-w-sm">A private account for adults who choose to meet through the desk.</p>
            </motion.div>

            <div className="px-5 max-w-xl mx-auto w-full pb-10">
                {notice && <p className="mb-4 rounded-2xl bg-success/10 text-success text-sm text-center font-bold p-3">{notice}</p>}
                {error && <p className="mb-4 rounded-2xl bg-danger/10 text-danger text-sm text-center font-bold p-3">{error}</p>}

                {mode === 'signin' && (
                    <section>
                        <header className="mb-6">
                            <p className="text-xs font-extrabold uppercase tracking-wider text-primary">Member access</p>
                            <h1 className="mt-1 text-2xl font-extrabold text-text-primary">Sign in</h1>
                            <p className="mt-2 text-sm leading-relaxed text-text-secondary">Use the email and password linked to your account.</p>
                        </header>
                        <form onSubmit={handleExistingSubmit} className="space-y-4">
                            <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Email address" type="email" autoFocus />
                            <Field icon={LockKeyhole} value={password} onChange={(value) => { setPassword(value); setError(''); }} placeholder="Password" type="password" />
                            <button disabled={loading} className="w-full min-h-12 flex items-center justify-center gap-2 py-3 rounded-xl font-bold text-white gradient-primary text-base disabled:opacity-60">
                            {loading ? <Spinner /> : <>Login <ArrowRight size={20} /></>}
                            </button>
                        </form>
                        <div className="mt-5 flex flex-wrap items-center justify-between gap-3 text-sm">
                            <button type="button" onClick={() => switchMode('forgot')} className="font-bold text-primary hover:underline">Forgot password?</button>
                            <p className="text-text-secondary">New here? <button type="button" onClick={() => switchMode('signup')} className="font-extrabold text-primary hover:underline">Create an account</button></p>
                        </div>
                    </section>
                )}

                {mode === 'forgot' && (
                    <section>
                        <header className="mb-6">
                            <p className="text-xs font-extrabold uppercase tracking-wider text-primary">Account recovery</p>
                            <h1 className="mt-1 text-2xl font-extrabold text-text-primary">Reset your password</h1>
                            <p className="mt-2 text-sm leading-relaxed text-text-secondary">We will send a one-time reset code to the email on your account.</p>
                        </header>
                        <form onSubmit={resetSent ? handleResetPassword : handleSendReset} className="space-y-4">
                            <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Email on your account" type="email" autoFocus />
                            {resetSent && <Field icon={ShieldCheck} value={resetCode} onChange={(value) => { setResetCode(value.replace(/\D/g, '').slice(0, 6)); setError(''); }} placeholder="6-digit reset code" inputMode="numeric" />}
                            {resetSent && <Field icon={LockKeyhole} value={newPassword} onChange={(value) => { setNewPassword(value); setError(''); }} placeholder="New password" type="password" />}
                            <button disabled={loading} className="w-full min-h-12 flex items-center justify-center gap-2 py-3 rounded-xl font-bold text-white gradient-primary text-base disabled:opacity-60">
                                {loading ? <Spinner /> : resetSent ? <>Save new password <ArrowRight size={20} /></> : <>Send reset code <ArrowRight size={20} /></>}
                            </button>
                            {resetSent && <button type="button" onClick={handleSendReset} className="w-full py-2 text-sm font-bold text-primary">Send another code</button>}
                        </form>
                        <p className="mt-5 text-sm text-text-secondary">Remembered it? <button type="button" onClick={() => switchMode('signin')} className="font-extrabold text-primary hover:underline">Back to sign in</button></p>
                    </section>
                )}

                {mode === 'signup' && (
                    <section>
                        <header className="mb-6">
                            <p className="text-xs font-extrabold uppercase tracking-wider text-primary">Join the community</p>
                            <h1 className="mt-1 text-2xl font-extrabold text-text-primary">Create your account</h1>
                            <p className="mt-2 text-sm leading-relaxed text-text-secondary">All fields are completed here. Your selected profile category cannot be changed after registration.</p>
                        </header>
                        <form onSubmit={handleCreateAccount} className="space-y-4">
                            <div className="grid gap-4 sm:grid-cols-2">
                                <Field icon={Mail} value={email} onChange={(value) => { setEmail(value); setError(''); }} placeholder="Email address" type="email" autoFocus />
                                <Field icon={LockKeyhole} value={password} onChange={(value) => { setPassword(value); setError(''); }} placeholder="Create password" type="password" />
                            </div>
                            <div className="grid gap-4 sm:grid-cols-2">
                                <Field icon={User} value={displayName} onChange={(value) => { setDisplayName(value); setError(''); }} placeholder="Display name" />
                                <Field icon={AtSign} value={username} onChange={(value) => { setUsernameTouched(true); setUsername(makeUsername(value)); setError(''); }} placeholder="Username (3-20 characters)" />
                            </div>
                            <div className="grid gap-4 sm:grid-cols-2">
                                <Field icon={Calendar} value={age} onChange={(value) => { setAge(value.replace(/\D/g, '').slice(0, 2)); setError(''); }} placeholder="Age (18+)" inputMode="numeric" />
                                <Field icon={Phone} value={phone} onChange={(value) => { setPhone(cleanPhone(value)); setError(''); }} placeholder="Phone number" type="tel" />
                            </div>
                            <Field icon={MapPin} value={location} onChange={(value) => { setLocation(value); setError(''); }} placeholder="City or area" />
                            <label className="block">
                                <span className="mb-2 block text-sm font-bold text-text-secondary">Your profile category</span>
                                <span className="relative block">
                                    <Users size={19} className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted" />
                                    <select value={selectedPreference} onChange={(event) => setSelectedPreference(event.target.value)} className="w-full appearance-none rounded-xl py-4 pl-12 pr-11 text-base text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/50" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                                        {PREFERENCES.map((preference) => <option key={preference.value} value={preference.value}>{preference.label} - {preference.desc}</option>)}
                                    </select>
                                    <ChevronDown size={18} className="pointer-events-none absolute right-4 top-1/2 -translate-y-1/2 text-text-muted" />
                                </span>
                            </label>
                            <TextAreaField icon={FileText} value={bio} onChange={(value) => { setBio(value.slice(0, 240)); setError(''); }} placeholder="A short introduction (at least 12 characters)" />
                            <div>
                                <input ref={photoInputRef} type="file" accept="image/*" className="hidden" onChange={handleProfilePhoto} />
                                <button type="button" onClick={() => photoInputRef.current?.click()} className="w-full min-h-20 rounded-xl px-4 py-3 flex items-center gap-4 text-left" style={{ background: 'var(--color-bg-card)', border: profilePhoto ? '1px solid var(--color-primary)' : '1px dashed color-mix(in srgb, var(--color-primary) 48%, transparent)' }}>
                                    <span className="w-12 h-12 rounded-lg overflow-hidden bg-primary/10 flex items-center justify-center shrink-0">
                                        {profilePhoto ? <img src={profilePhoto} alt="Selected profile photo preview" width="48" height="48" className="w-full h-full object-cover" /> : <Camera size={23} className="text-primary" />}
                                    </span>
                                    <span><span className="block font-bold text-text-primary">{profilePhoto ? 'Profile photo selected' : 'Choose a profile photo'}</span><span className="mt-1 block text-xs leading-relaxed text-text-muted">Use an image you have permission to share. Review cannot guarantee identity or image origin.</span></span>
                                </button>
                            </div>
                            <label className="flex items-start gap-3 rounded-xl p-3 text-sm leading-relaxed text-text-secondary" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                                <input type="checkbox" checked={termsAccepted} onChange={(event) => { setTermsAccepted(event.target.checked); setError(''); }} className="mt-1 accent-primary" />
                                <span>I confirm that I am 18 or older and accept the <Link href="/terms" className="font-bold text-primary underline">Terms</Link> and <Link href="/privacy" className="font-bold text-primary underline">Privacy Policy</Link>.</span>
                            </label>
                            <button disabled={loading} className="w-full min-h-12 flex items-center justify-center gap-2 py-3 rounded-xl font-bold text-white gradient-primary text-base disabled:opacity-60">{loading ? <Spinner /> : <>Create account <ArrowRight size={20} /></>}</button>
                        </form>
                        <p className="mt-5 text-center text-sm text-text-secondary">Already registered? <button type="button" onClick={() => switchMode('signin')} className="font-extrabold text-primary hover:underline">Sign in</button></p>
                    </section>
                )}

                <div className="mt-8 border-t pt-5 text-center" style={{ borderColor: 'var(--color-surface-light)' }}>
                    <p className="mx-auto max-w-lg text-xs leading-relaxed text-text-muted"><Link href="/safety" className="font-bold text-primary hover:underline">Adults aged 18+ only · Safety guidance</Link><br />Profiles, messages, and payment requests are subject to review and safety rules. A profile or badge is not a guarantee of identity, compatibility, or outcome.</p>
                    <div className="mt-4 flex flex-wrap justify-center gap-x-4 gap-y-2 text-xs font-bold">
                        {LEGAL_LINKS.map((item) => (
                            <Link key={item.href} href={item.href} className="text-primary hover:underline">
                                {item.label}
                            </Link>
                        ))}
                    </div>
                    <Link href="/download" className="mt-4 inline-flex min-h-10 items-center gap-2 text-sm font-extrabold text-primary hover:underline">
                        <MaterialIcon name="download" />
                        Get the Android app
                    </Link>
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
