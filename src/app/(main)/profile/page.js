'use client';

import { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    User, Mail, Camera, Trash2, Shield, ShieldCheck, LogOut,
    Settings, ChevronRight, Heart, MessageCircle, Bell, Bookmark,
    MapPin, Edit3, Plus, X, Send, AlertTriangle, ExternalLink,
    Info, HelpCircle, Trash, Clock, Gem, Users,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import EmailSubscribe from '@/components/EmailSubscribe';

const PREFERENCE_LABELS = {
    sugar_mummy: '💃 Sugar Mummy',
    sugar_daddy: '🕺 Sugar Daddy',
    both: '💕 Both',
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
    const fileInputRef = useRef(null);
    const selfieInputRef = useRef(null);

    const isLoggedIn = !!user;
    const displayName = profile?.display_name || user?.email?.split('@')[0] || 'Guest';
    const userPhotos = profile?.photos || [];

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

    // Selfie verification
    const handleSelfieCapture = (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (ev) => verifyProfile(ev.target.result);
        reader.readAsDataURL(file);
        e.target.value = '';
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
                    {verificationStatus === 'verified' && (
                        <div className="absolute -bottom-1 -right-1"><VerifiedBadge size={24} /></div>
                    )}
                </div>
                <div>
                    <h2 className="text-xl font-black text-text-primary flex items-center justify-center gap-1.5">
                        {displayName}
                        {verificationStatus === 'verified' && <VerifiedBadge size={18} />}
                    </h2>
                    {isLoggedIn && <p className="text-xs text-text-muted">{user.email}</p>}
                    {guest && <p className="text-xs text-primary font-medium">Guest Mode</p>}
                    {/* Preference badge */}
                    {isLoggedIn && preference && (
                        <button
                            onClick={() => setShowPreferencePicker(true)}
                            className="mt-1 inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-semibold text-primary"
                            style={{ background: 'rgba(124,58,237,0.08)' }}
                        >
                            {PREFERENCE_LABELS[preference] || preference} <Edit3 size={10} />
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

            {/* ===== AI VERIFICATION (with 10-min moderation timer) ===== */}
            {isLoggedIn && (
                <div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                    <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                        <Shield size={16} className="text-primary" /> AI Verification
                    </h3>

                    {verificationStatus === 'verified' ? (
                        <div className="flex items-center gap-3 p-3 rounded-xl bg-success/10">
                            <ShieldCheck size={24} className="text-success" />
                            <div>
                                <p className="text-sm font-bold text-success">Verified ✓</p>
                                <p className="text-xs text-text-muted">Your identity has been confirmed</p>
                            </div>
                        </div>
                    ) : verificationStatus === 'moderation_review' ? (
                        <div className="space-y-3">
                            <div className="flex items-center gap-3 p-3 rounded-xl" style={{ background: 'rgba(124,58,237,0.08)' }}>
                                <Clock size={24} className="text-primary" />
                                <div className="flex-1">
                                    <p className="text-sm font-bold text-primary">Under Moderation Review</p>
                                    <p className="text-xs text-text-muted">Your selfie passed AI analysis. Our team is reviewing...</p>
                                </div>
                            </div>
                            {/* Countdown timer */}
                            <div className="flex flex-col items-center gap-2 py-4">
                                <div className="w-20 h-20 rounded-full border-4 border-primary/30 flex items-center justify-center relative">
                                    <div className="absolute inset-0 rounded-full border-4 border-primary border-t-transparent animate-spin" style={{ animationDuration: '3s' }} />
                                    <span className="text-lg font-black text-primary">{moderationCountdown}</span>
                                </div>
                                <p className="text-xs text-text-muted font-medium">Estimated time remaining</p>
                            </div>
                        </div>
                    ) : verificationStatus === 'processing' ? (
                        <div className="flex items-center gap-3 p-3 rounded-xl bg-primary/10">
                            <div className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                            <p className="text-sm font-medium text-primary">AI is analyzing your selfie...</p>
                        </div>
                    ) : (
                        <div className="space-y-2">
                            <p className="text-xs text-text-muted leading-relaxed">
                                Upload a selfie to verify your identity. Our AI analyzes facial features, then moderators review. You'll get a blue badge!
                            </p>
                            <button
                                onClick={() => selfieInputRef.current?.click()}
                                className="w-full py-3 rounded-xl font-semibold text-white gradient-primary flex items-center justify-center gap-2"
                            >
                                <Camera size={18} /> Take Selfie to Verify
                            </button>
                            {verificationStatus === 'failed' && (
                                <p className="text-xs text-danger font-medium text-center">
                                    Verification failed. Please try again with a clear, well-lit selfie of your face.
                                </p>
                            )}
                        </div>
                    )}
                    <input ref={selfieInputRef} type="file" accept="image/*" capture="user" className="hidden" onChange={handleSelfieCapture} />
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
                        { key: 'orientation', label: 'Looking for', value: profile?.orientation },
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

            {/* ===== EMAIL SUBSCRIPTION ===== */}
            <EmailSubscribe />

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
                        { key: 'showOnline', label: 'Show Online Status' },
                        { key: 'showAge', label: 'Show Age' },
                        { key: 'isPublic', label: 'Public Profile' },
                        { key: 'liveLocation', label: 'Share Live Location' },
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

            {/* ===== CONTACT & HELP ===== */}
            <div className="rounded-2xl overflow-hidden" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <a href="https://t.me/GSADMINMARYGAGENCY" target="_blank" rel="noopener noreferrer"
                    className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-primary/5"
                    style={{ borderBottom: '1px solid rgba(0,0,0,0.04)' }}
                >
                    <HelpCircle size={18} className="text-primary" />
                    <span className="text-sm text-text-primary flex-1">Contact Admin @GSADMINMARYGAGENCY</span>
                    <ExternalLink size={14} className="text-text-muted" />
                </a>
                <a href="https://genuinesugarmummies.com" target="_blank" rel="noopener noreferrer"
                    className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-primary/5"
                >
                    <Info size={18} className="text-primary" />
                    <span className="text-sm text-text-primary flex-1">Visit Website</span>
                    <ExternalLink size={14} className="text-text-muted" />
                </a>
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
