'use client';

import { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import {
    User, Mail, Camera, Trash2, Shield, ShieldCheck, LogOut,
    Settings, ChevronRight, Heart, MessageCircle, Bell, Bookmark,
    MapPin, Edit3, Plus, X, Send, AlertTriangle, ExternalLink,
    Info, HelpCircle, Trash, Clock, Gem, Users, PackageCheck, Headphones,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';

const PREFERENCE_LABELS = {
    sugar_mummy_looking_for_toyboy: 'Sugar Mummy seeking Sugar Guy / Toyboy',
    sugar_daddy_looking_for_mistress: 'Sugar Daddy seeking Mistress',
    mistress_looking_for_sugar_daddy: 'Mistress seeking Sugar Daddy',
    toyboy_looking_for_sugar_mummy: 'Sugar Guy / Toyboy seeking Sugar Mummy',
};

export default function ProfilePage() {
    const {
        user, guest, profile, likes, matches, saved, messages,
        verificationStatus, verificationTimer, settings, preference, liveLocationData,
        signOut, updateProfile, addPhoto, removePhoto,
        updateSettings, updatePreference, verifyProfile, clearVerification, deleteAccount,
    } = useAuth();

    const [activeSection, setActiveSection] = useState(null);
    const [editField, setEditField] = useState(null);
    const [editValue, setEditValue] = useState('');
    const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
    const [showPreferencePicker, setShowPreferencePicker] = useState(false);
    const [moderationCountdown, setModerationCountdown] = useState('');
    const [verificationForm, setVerificationForm] = useState({ selfieDataUrl: '', documentDataUrl: '', documentType: 'id', phone: profile?.phone_number || profile?.phone || '' });
    const [supportForm, setSupportForm] = useState({ subject: '', message: '' });
    const [supportStatus, setSupportStatus] = useState('');
    const fileInputRef = useRef(null);
    const selfieInputRef = useRef(null);
    const documentInputRef = useRef(null);

    const isLoggedIn = !!user;
    const currentTier = String(profile?.subscription_tier || profile?.subscriptionTier || 'free').toLowerCase();
    const packageApproved = Boolean(profile?.admin_approved && !profile?.package_locked);
    const canRevealPhone = packageApproved && ['silver', 'gold', 'diamond'].includes(currentTier);
    const canUseBasic = packageApproved && ['basic', 'silver', 'gold', 'diamond'].includes(currentTier);
    const displayName = profile?.display_name || user?.email?.split('@')[0] || 'Guest';
    const userPhotos = profile?.photos || [];
    const profileComplete = Boolean((profile?.avatar_url || userPhotos[0]) && profile?.bio && profile?.age && profile?.location);
    const effectiveVerificationStatus = profile?.verification_status || verificationStatus;
    const missingFields = [
        !(profile?.avatar_url || userPhotos[0]) && 'profile photo',
        !profile?.bio && 'bio',
        !profile?.age && 'age',
        !profile?.location && 'location',
        !profile?.phone_number && !profile?.phone && 'phone number',
    ].filter(Boolean);

    // Moderation countdown timer
    useEffect(() => {
        if (verificationStatus !== 'moderation_review' || !verificationTimer) return;

        const update = () => {
            const remaining = Math.max(0, verificationTimer - Date.now());
            const min = Math.floor(remaining / 60000);
            const sec = Math.floor((remaining % 60000) / 1000);
            setModerationCountdown(`${min}:${sec.toString().padStart(2, '0')}`);
        };

        update();
        const interval = setInterval(update, 1000);
        return () => clearInterval(interval);
    }, [verificationStatus, verificationTimer]);

    // Photo upload
    const handlePhotoUpload = (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (ev) => {
            const canvas = document.createElement('canvas');
            const img = new Image();
            img.onload = () => {
                const MAX = 800;
                let w = img.width, h = img.height;
                if (w > MAX || h > MAX) {
                    if (w > h) { h = Math.round(h * MAX / w); w = MAX; }
                    else { w = Math.round(w * MAX / h); h = MAX; }
                }
                canvas.width = w; canvas.height = h;
                canvas.getContext('2d').drawImage(img, 0, 0, w, h);
                addPhoto(canvas.toDataURL('image/webp', 0.85));
            };
            img.src = ev.target.result;
        };
        reader.readAsDataURL(file);
        e.target.value = '';
    };

    const readCompressedImage = (file, callback) => {
        const reader = new FileReader();
        reader.onload = (ev) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const MAX = 900;
                let w = img.width, h = img.height;
                if (w > MAX || h > MAX) {
                    if (w > h) { h = Math.round(h * MAX / w); w = MAX; }
                    else { w = Math.round(w * MAX / h); h = MAX; }
                }
                canvas.width = w;
                canvas.height = h;
                canvas.getContext('2d').drawImage(img, 0, 0, w, h);
                callback(canvas.toDataURL('image/webp', 0.82));
            };
            img.src = ev.target.result;
        };
        reader.readAsDataURL(file);
    };

    const handleSelfieCapture = (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        readCompressedImage(file, (dataUrl) => setVerificationForm((current) => ({ ...current, selfieDataUrl: dataUrl })));
        e.target.value = '';
    };

    const handleDocumentCapture = (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        readCompressedImage(file, (dataUrl) => setVerificationForm((current) => ({ ...current, documentDataUrl: dataUrl })));
        e.target.value = '';
    };

    const submitVerification = () => {
        verifyProfile({ ...verificationForm, phone: verificationForm.phone || profile?.phone_number || profile?.phone || '' });
    };

    const submitSupportTicket = async () => {
        const subject = supportForm.subject.trim() || 'Support request';
        const message = supportForm.message.trim();
        if (message.length < 3) { setSupportStatus('Write a short message for support.'); return; }
        setSupportStatus('Submitting...');
        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'support_ticket', memberId: profile?.id || user?.id, subject, message }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(data.error || 'Support request failed.');
            setSupportStatus('Support ticket submitted. Admin can see it in Tickets.');
            setSupportForm({ subject: '', message: '' });
        } catch (error) {
            setSupportStatus(error.message || 'Support request failed.');
        }
    };

    // Edit field
    const startEdit = (field, currentValue) => {
        setEditField(field);
        setEditValue(currentValue || '');
    };

    const saveEdit = () => {
        if (editField && editValue !== undefined) {
            updateProfile({ [editField]: editValue.trim() });
        }
        setEditField(null);
    };

    const handleSignOut = () => { signOut(); window.location.href = '/auth/login'; };
    const handleDeleteAccount = () => { deleteAccount(); window.location.href = '/auth/login'; };

    return (
        <div className="px-4 py-4 pb-28 space-y-4">
            {/* ===== PROFILE HEADER ===== */}
            <div className="rounded-2xl p-5 text-center space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <div className="relative inline-block">
                    <UserAvatar name={displayName} src={profile?.avatar_url} size={80} />
                    {effectiveVerificationStatus === 'verified' && (
                        <div className="absolute -bottom-1 -right-1"><VerifiedBadge size={24} /></div>
                    )}
                </div>
                <div>
                    <h2 className="text-xl font-black text-text-primary flex items-center justify-center gap-1.5">
                        {displayName}
                        {effectiveVerificationStatus === 'verified' && <VerifiedBadge size={18} />}
                    </h2>
                    {isLoggedIn && <p className="text-xs text-text-muted">{user.email}</p>}
                    {guest && <p className="text-xs text-primary font-medium">Guest Mode</p>}
                    {/* Preference badge */}
                    {isLoggedIn && preference && (
                        <button
                            onClick={() => !profile?.preference_locked && setShowPreferencePicker(true)}
                            className="mt-1 inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-semibold text-primary"
                            style={{ background: 'rgba(124,58,237,0.08)' }}
                        >
                            {PREFERENCE_LABELS[preference] || preference} {profile?.preference_locked ? '(locked)' : <Edit3 size={10} />}
                        </button>
                    )}
                </div>

                {/* Stats */}
                <div className="flex items-center justify-center gap-6 pt-2">
                    {[
                        { value: likes.length, label: 'Likes' },
                        { value: matches.length, label: 'Matches' },
                        { value: saved.length, label: 'Saved' },
                        { value: messages.length, label: 'Messages' },
                    ].map(s => (
                        <div key={s.label} className="text-center">
                            <p className="text-lg font-black text-primary">{s.value}</p>
                            <p className="text-[10px] text-text-muted font-medium">{s.label}</p>
                        </div>
                    ))}
                </div>
            </div>

            {isLoggedIn && !profileComplete && (
                <div className="rounded-2xl p-4 space-y-2" style={{ background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.22)' }}>
                    <p className="text-sm font-black text-amber-700">Complete your profile to unlock the app</p>
                    <p className="text-xs text-text-secondary">Add: {missingFields.join(', ')}. Your profile is listed in Members after the required details are saved.</p>
                </div>
            )}

            {isLoggedIn && (
                <div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5"><PackageCheck size={16} className="text-primary" /> Package Access</h3>
                    <div className="grid grid-cols-3 gap-2 text-center">
                        <div className="rounded-xl p-3 bg-primary/10"><p className="text-[10px] text-text-muted">Tier</p><p className="text-sm font-black text-primary">{currentTier.toUpperCase()}</p></div>
                        <div className="rounded-xl p-3 bg-secondary/10"><p className="text-[10px] text-text-muted">Basic</p><p className="text-sm font-black text-secondary">{canUseBasic ? 'ON' : 'OFF'}</p></div>
                        <div className="rounded-xl p-3 bg-amber-100"><p className="text-[10px] text-text-muted">Numbers</p><p className="text-sm font-black text-gold">{canRevealPhone ? 'ON' : 'LOCKED'}</p></div>
                    </div>
                    <Link href="/packages" className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-black text-white gradient-primary"><Gem size={16} /> Manage Packages</Link>
                </div>
            )}

            {/* ===== PHOTOS (always-visible delete button) ===== */}
            {isLoggedIn && (
                <div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                        <Camera size={16} className="text-primary" /> My Photos
                    </h3>
                    <div className="grid grid-cols-3 gap-2">
                        {userPhotos.map((photo, i) => (
                            <div key={i} className="relative aspect-square rounded-xl overflow-hidden">
                                <img src={photo} alt="" className="w-full h-full object-cover" />
                                <button
                                    onClick={() => removePhoto(i)}
                                    className="absolute top-1 right-1 w-7 h-7 rounded-full bg-black/70 flex items-center justify-center"
                                >
                                    <X size={14} className="text-white" />
                                </button>
                                {i === 0 && (
                                    <span className="absolute bottom-1 left-1 px-1.5 py-0.5 rounded-md bg-primary/80 text-[8px] font-bold text-white">
                                        MAIN
                                    </span>
                                )}
                            </div>
                        ))}
                        {userPhotos.length < 6 && (
                            <button
                                onClick={() => fileInputRef.current?.click()}
                                className="aspect-square rounded-xl flex flex-col items-center justify-center gap-1 transition-colors"
                                style={{ background: 'var(--color-surface)', border: '2px dashed rgba(124,58,237,0.2)' }}
                            >
                                <Plus size={20} className="text-primary" />
                                <span className="text-[10px] text-text-muted font-medium">Add</span>
                            </button>
                        )}
                    </div>
                    <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handlePhotoUpload} />
                </div>
            )}

            {isLoggedIn && effectiveVerificationStatus === 'verified' && (
                <div className="rounded-2xl p-4 flex items-center gap-3" style={{ background: 'rgba(5,150,105,0.1)', border: '1px solid rgba(5,150,105,0.22)' }}>
                    <ShieldCheck size={24} className="text-success" />
                    <div>
                        <p className="text-sm font-black text-success">Verification Approved</p>
                        <p className="text-xs text-text-muted">Your blue badge was manually approved by admin.</p>
                    </div>
                </div>
            )}
            {/* ===== MANUAL VERIFICATION ===== */}
            {isLoggedIn && effectiveVerificationStatus !== 'verified' && (
                <div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                        <Shield size={16} className="text-primary" /> Manual Verification
                    </h3>
                    {effectiveVerificationStatus === 'pending_admin' ? (
                        <div className="flex items-center gap-3 p-3 rounded-xl" style={{ background: 'rgba(124,58,237,0.08)' }}>
                            <Clock size={24} className="text-primary" />
                            <div className="flex-1">
                                <p className="text-sm font-bold text-primary">Waiting for Admin Review</p>
                                <p className="text-xs text-text-muted">Admin will approve or reject this request in the control panel.</p>
                            </div>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            <p className="text-xs text-text-muted leading-relaxed">
                                Submit a clear selfie, your ID or passport, and your phone number. Admin approval is required before the verified badge and premium package unlocks appear.
                            </p>
                            <div className="grid grid-cols-2 gap-2">
                                <button onClick={() => selfieInputRef.current?.click()} className="rounded-xl py-3 px-3 text-xs font-bold bg-primary/10 text-primary flex items-center justify-center gap-2">
                                    <Camera size={16} /> {verificationForm.selfieDataUrl ? 'Selfie Added' : 'Add Selfie'}
                                </button>
                                <button onClick={() => documentInputRef.current?.click()} className="rounded-xl py-3 px-3 text-xs font-bold bg-secondary/10 text-secondary flex items-center justify-center gap-2">
                                    <Shield size={16} /> {verificationForm.documentDataUrl ? 'Document Added' : 'Add ID/Passport'}
                                </button>
                            </div>
                            <select value={verificationForm.documentType} onChange={(e) => setVerificationForm((current) => ({ ...current, documentType: e.target.value }))} className="w-full rounded-xl py-3 px-3 text-sm" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }}>
                                <option value="id">National ID</option>
                                <option value="passport">Passport</option>
                            </select>
                            <input value={verificationForm.phone} onChange={(e) => setVerificationForm((current) => ({ ...current, phone: e.target.value }))} placeholder="Phone number for verification" className="w-full rounded-xl py-3 px-3 text-sm" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                            <button onClick={submitVerification} className="w-full py-3 rounded-xl font-semibold text-white gradient-primary flex items-center justify-center gap-2">
                                <Send size={18} /> Submit Verification Request
                            </button>
                            {effectiveVerificationStatus === 'failed' && <p className="text-xs text-danger font-medium text-center">Selfie, ID/passport, and phone number are required.</p>}
                        </div>
                    )}
                    <input ref={selfieInputRef} type="file" accept="image/*" capture="user" className="hidden" onChange={handleSelfieCapture} />
                    <input ref={documentInputRef} type="file" accept="image/*" className="hidden" onChange={handleDocumentCapture} />
                </div>
            )}
            {/* ===== PROFILE INFO (editable) ===== */}
            {isLoggedIn && (
                <div className="rounded-2xl overflow-hidden" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <div className="px-4 py-3" style={{ borderBottom: '1px solid rgba(124,58,237,0.08)' }}>
                        <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                            <Edit3 size={16} className="text-primary" /> Profile Info
                        </h3>
                    </div>
                    {[
                        { key: 'display_name', label: 'Name', value: profile?.display_name },
                        { key: 'bio', label: 'Bio', value: profile?.bio },
                        { key: 'age', label: 'Age', value: profile?.age },
                        { key: 'location', label: 'Location', value: profile?.location },
                        { key: 'phone_number', label: 'Phone Number', value: profile?.phone_number || profile?.phone },
                        { key: 'wants', label: 'What I want', value: profile?.wants },
                        { key: 'needed_qualities', label: 'Needed qualities', value: profile?.needed_qualities },
                        { key: 'age_range_preference', label: 'Preferred age range', value: profile?.age_range_preference },
                        { key: 'looking_for', label: 'Looking for', value: profile?.looking_for },
                    ].map((field) => (
                        <div key={field.key}
                            className="flex items-center justify-between px-4 py-3 cursor-pointer transition-colors hover:bg-primary/5"
                            style={{ borderBottom: '1px solid rgba(0,0,0,0.04)' }}
                            onClick={() => startEdit(field.key, field.value)}
                        >
                            <div>
                                <p className="text-xs text-text-muted font-medium">{field.label}</p>
                                <p className="text-sm text-text-primary font-medium">{field.value || 'Add...'}</p>
                            </div>
                            <ChevronRight size={16} className="text-text-muted" />
                        </div>
                    ))}
                </div>
            )}

            {/* ===== MESSAGES ===== */}
            {isLoggedIn && messages.length > 0 && (
                <div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                        <MessageCircle size={16} className="text-primary" /> Messages ({messages.length})
                    </h3>
                    {messages.slice(0, 5).map((msg, i) => (
                        <div key={msg.id || i} className="flex items-start gap-3 py-2" style={{ borderBottom: '1px solid rgba(0,0,0,0.04)' }}>
                            <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                <Mail size={14} className="text-primary" />
                            </div>
                            <div className="flex-1 min-w-0">
                                <p className="text-xs font-bold text-text-primary truncate">{msg.title}</p>
                                <p className="text-[10px] text-text-muted line-clamp-2 mt-0.5">{msg.body}</p>
                            </div>
                        </div>
                    ))}
                </div>
            )}


            {/* ===== SETTINGS ===== */}
            {isLoggedIn && (
                <div className="rounded-2xl overflow-hidden" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <div className="px-4 py-3" style={{ borderBottom: '1px solid rgba(124,58,237,0.08)' }}>
                        <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                            <Settings size={16} className="text-primary" /> Settings
                        </h3>
                    </div>

                    {[
                        { key: 'notifications', label: 'Push Notifications' },
                        { key: 'darkMode', label: 'Dark Mode' },
                        { key: 'showOnline', label: 'Show Online Status' },
                        { key: 'showAge', label: 'Show Age' },
                        { key: 'isPublic', label: 'Public Profile' },
                        { key: 'emailNotifications', label: 'Email Updates' },
                        { key: 'liveLocation', label: 'Live Location Matching' },
                    ].map((setting) => (
                        <div key={setting.key}
                            className="flex items-center justify-between px-4 py-3"
                            style={{ borderBottom: '1px solid rgba(0,0,0,0.04)' }}
                        >
                            <div className="flex items-center gap-2">
                                <span className="text-sm text-text-primary">{setting.label}</span>
                                {setting.key === 'liveLocation' && settings.liveLocation && liveLocationData?.city && (
                                    <span className="flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-medium bg-success/10 text-success">
                                        <MapPin size={10} /> {liveLocationData.city}
                                    </span>
                                )}
                            </div>
                            <button
                                onClick={() => updateSettings({ [setting.key]: !settings[setting.key] })}
                                className={`w-10 h-6 rounded-full transition-all duration-300 ${settings[setting.key] ? 'bg-primary' : 'bg-gray-300'}`}
                            >
                                <div className={`w-4 h-4 bg-white rounded-full shadow transition-all duration-300 ${settings[setting.key] ? 'translate-x-5' : 'translate-x-1'}`} />
                            </button>
                        </div>
                    ))}
                </div>
            )}

            {/* ===== SUPPORT & HELP ===== */}
            <div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5"><Headphones size={16} className="text-primary" /> Support & Help</h3>
                <input value={supportForm.subject} onChange={(e) => setSupportForm({ ...supportForm, subject: e.target.value })} placeholder="Subject" className="w-full rounded-xl py-3 px-3 text-sm" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                <textarea value={supportForm.message} onChange={(e) => setSupportForm({ ...supportForm, message: e.target.value })} placeholder="Tell support what you need" rows={3} className="w-full rounded-xl py-3 px-3 text-sm resize-none" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                <button onClick={submitSupportTicket} className="w-full py-3 rounded-xl font-bold text-white gradient-primary flex items-center justify-center gap-2"><Send size={16} /> Submit Ticket</button>
                {supportStatus && <p className="text-xs font-bold text-primary bg-primary/10 rounded-xl p-3">{supportStatus}</p>}
                <a href="https://t.me/GSADMINMARYGAGENCY" target="_blank" rel="noopener noreferrer" className="flex items-center gap-2 text-sm font-bold text-primary"><ExternalLink size={15} /> Telegram Admin Support</a>
            </div>
            {/* ===== SIGN OUT / DELETE ===== */}
            <div className="space-y-2">
                {isLoggedIn && (
                    <button onClick={handleSignOut}
                        className="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl font-semibold text-text-primary transition-colors hover:bg-gray-100"
                        style={{ border: '1px solid rgba(0,0,0,0.1)' }}
                    >
                        <LogOut size={18} /> Sign Out
                    </button>
                )}
                {isLoggedIn && (
                    <button onClick={() => setShowDeleteConfirm(true)}
                        className="w-full flex items-center justify-center gap-2 py-3 rounded-2xl text-sm font-medium text-danger/60 transition-colors hover:text-danger hover:bg-danger/5"
                    >
                        <Trash size={16} /> Delete Account
                    </button>
                )}
            </div>

            {/* ===== EDIT MODAL ===== */}
            <AnimatePresence>
                {editField && (
                    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                        className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm px-6"
                        onClick={() => setEditField(null)}
                    >
                        <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }}
                            className="w-full max-w-sm rounded-2xl p-5 space-y-4"
                            style={{ background: 'var(--color-bg-card)' }}
                            onClick={(e) => e.stopPropagation()}
                        >
                            <h3 className="text-lg font-bold text-text-primary capitalize">Edit {editField.replace('_', ' ')}</h3>
                            {editField === 'bio' ? (
                                <textarea value={editValue} onChange={(e) => setEditValue(e.target.value)} rows={4}
                                    className="w-full rounded-xl py-3 px-4 text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/50 resize-none"
                                    style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} autoFocus
                                />
                            ) : (
                                <input type="text" value={editValue} onChange={(e) => setEditValue(e.target.value)}
                                    className="w-full rounded-xl py-3 px-4 text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/50"
                                    style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} autoFocus
                                />
                            )}
                            <div className="flex gap-3">
                                <button onClick={() => setEditField(null)} className="flex-1 py-3 rounded-xl font-medium text-text-secondary" style={{ border: 'var(--card-border)' }}>Cancel</button>
                                <button onClick={saveEdit} className="flex-1 py-3 rounded-xl font-bold text-white gradient-primary">Save</button>
                            </div>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* ===== PREFERENCE PICKER MODAL ===== */}
            <AnimatePresence>
                {showPreferencePicker && (
                    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                        className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm"
                        onClick={() => setShowPreferencePicker(false)}
                    >
                        <motion.div
                            initial={{ y: 200 }} animate={{ y: 0 }} exit={{ y: 200 }}
                            className="w-full max-w-md rounded-t-3xl p-5 space-y-3"
                            style={{ background: 'var(--color-bg-card)' }}
                            onClick={(e) => e.stopPropagation()}
                        >
                            <h3 className="text-lg font-bold text-text-primary text-center">Your Preference</h3>
                            {Object.entries(PREFERENCE_LABELS).map(([key, label]) => (
                                <button key={key}
                                    onClick={() => { updatePreference(key); setShowPreferencePicker(false); }}
                                    className="w-full flex items-center justify-between px-4 py-3.5 rounded-xl transition-all"
                                    style={{
                                        background: preference === key ? 'rgba(124,58,237,0.08)' : 'transparent',
                                        border: `2px solid ${preference === key ? '#7C3AED' : 'rgba(0,0,0,0.06)'}`,
                                    }}
                                >
                                    <span className="text-sm font-semibold text-text-primary">{label}</span>
                                    {preference === key && <div className="w-4 h-4 rounded-full bg-primary" />}
                                </button>
                            ))}
                            <button onClick={() => setShowPreferencePicker(false)}
                                className="w-full py-3 text-sm font-medium text-text-muted"
                            >
                                Cancel
                            </button>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* ===== DELETE CONFIRMATION ===== */}
            <AnimatePresence>
                {showDeleteConfirm && (
                    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                        className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm px-6"
                        onClick={() => setShowDeleteConfirm(false)}
                    >
                        <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }}
                            className="w-full max-w-sm rounded-2xl p-6 space-y-4 text-center"
                            style={{ background: 'var(--color-bg-card)' }}
                            onClick={(e) => e.stopPropagation()}
                        >
                            <div className="w-14 h-14 mx-auto rounded-full bg-danger/10 flex items-center justify-center">
                                <AlertTriangle size={28} className="text-danger" />
                            </div>
                            <h3 className="text-lg font-bold text-text-primary">Delete Account?</h3>
                            <p className="text-sm text-text-muted">This will permanently delete your profile, likes, matches, and all saved data.</p>
                            <div className="flex gap-3">
                                <button onClick={() => setShowDeleteConfirm(false)} className="flex-1 py-3 rounded-xl font-medium text-text-secondary" style={{ border: 'var(--card-border)' }}>Cancel</button>
                                <button onClick={handleDeleteAccount} className="flex-1 py-3 rounded-xl font-bold text-white bg-danger">Delete</button>
                            </div>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}




