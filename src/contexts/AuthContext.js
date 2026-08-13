'use client';

import { createContext, useContext, useEffect, useState, useCallback, useRef } from 'react';
import { createBrowserSupabaseClient, isSupabaseConfigured } from '@/lib/supabaseClient';
import { startPolling, POLL } from '@/lib/poll';
import { clearCache } from '@/lib/cachedFetch';

const AuthContext = createContext({});

const STORAGE_KEYS = {
    USER: 'gscom_user',
    LIKES: 'gscom_likes',
    MATCHES: 'gscom_matches',
    PASSES: 'gscom_passes',
    SAVED: 'gscom_saved',
    ACTIVITY: 'gscom_activity',
    SETTINGS: 'gscom_settings',
    GUEST: 'gscom_guest_mode',
    MESSAGES: 'gscom_messages',
    VERIFICATION: 'gscom_verification',
    VERIFICATION_SELFIE: 'gscom_verification_selfie',
    VERIFICATION_TIMER: 'gscom_verification_timer',
    LOCATION: 'gscom_location',
    SUBSCRIBED: 'gscom_subscribed',
    LAST_POST_ID: 'gscom_last_post_id',
    LIVE_LOCATION: 'gscom_live_location',
    PREFERENCE: 'gscom_preference',
    LOGIN_EMAIL: 'gscom_login_email',
    SIGNED_OUT_UNTIL: 'gscom_signed_out_until',
};

function cleanDisplayName(value, email = '') {
    const emailText = String(email || '').trim().toLowerCase();
    const localPart = emailText.split('@')[0] || '';
    let name = String(value || '').trim().replace(/\s+/g, ' ').slice(0, 80);
    if (!name || name.includes('@') || name.toLowerCase() === emailText || name.toLowerCase() === localPart) {
        name = localPart
            ? localPart.replace(/[._-]+/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase()).slice(0, 40)
            : 'GS Member';
    }
    if (!name || name.includes('@')) name = 'GS Member';
    return name;
}

function getStored(key, fallback = null) {
    if (typeof window === 'undefined') return fallback;
    try {
        const val = localStorage.getItem(key);
        return val ? JSON.parse(val) : fallback;
    } catch { return fallback; }
}

function setStored(key, value) {
    if (typeof window === 'undefined') return;
    try { localStorage.setItem(key, JSON.stringify(value)); } catch { }
}

const DEFAULT_SETTINGS = {
    isPublic: true,
    locationEnabled: false,
    notifications: true,
    showOnline: true,
    showAge: true,
    emailNotifications: false,
    liveLocation: false,
    darkMode: false,
};

// ==========================================
// SMART MATCHING ALGORITHM
// ==========================================
function computeMatchScore(profile, user, settings) {
    let score = 50; // Base score

    // Verified profiles get a boost
    if (profile.verified) score += 12;

    // Profile completeness bonus
    if (profile.imageUrl) score += 5;
    if (profile.location) score += 4;
    if (profile.excerpt) score += 3;
    if (profile.age) score += 3;

    // User engagement bonus (verified users match better)
    if (user?.verification === 'verified') score += 8;

    // Location proximity (if both have locations, boost when nearby)
    if (profile.location && settings.liveLocation) {
        const liveData = getStored(STORAGE_KEYS.LIVE_LOCATION);
        if (liveData?.city && profile.location.toLowerCase().includes(liveData.city.toLowerCase())) {
            score += 15; // Same city boost
        }
    }

    // Time-based freshness — newer profiles score slightly higher
    const profileAge = Date.now() - new Date(profile.date || Date.now()).getTime();
    if (profileAge < 7 * 86400000) score += 5; // Less than 7 days old

    // Deterministic component for consistency (using profile+user seed)
    const seed = `${profile.wpId || ''}-${user?.id || 'guest'}`;
    let hash = 0;
    for (let i = 0; i < seed.length; i++) {
        hash = ((hash << 5) - hash + seed.charCodeAt(i)) | 0;
    }
    const jitter = (Math.abs(hash) % 20) - 10; // -10 to +10
    score += jitter;

    // Clamp to realistic range
    return Math.max(60, Math.min(98, Math.round(score)));
}

function shouldMatchProfile(profile, user, settings) {
    const score = computeMatchScore(profile, user, settings);
    // Higher scores have higher match probability
    const seed = `${profile.wpId}-${user?.id || 'guest'}-match`;
    let hash = 0;
    for (let i = 0; i < seed.length; i++) {
        hash = ((hash << 5) - hash + seed.charCodeAt(i)) | 0;
    }
    const roll = Math.abs(hash) % 100;
    // ~55% base chance, boosted by score
    return roll < (score * 0.6);
}

// ==========================================
// AI FACE ANALYSIS ENGINE
// ==========================================
async function analyzeSelfie(selfieDataUrl, profilePicUrl) {
    const loadImage = (src) => new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = () => resolve(img);
        img.onerror = () => reject(new Error('Image load failed'));
        img.src = src;
    });

    try {
        const selfieImg = await loadImage(selfieDataUrl);

        // ---- Minimum resolution check ----
        if (selfieImg.width < 120 || selfieImg.height < 120) {
            return { status: 'failed', reason: 'Your selfie is too small. Please upload a clear photo of at least 120×120 pixels.' };
        }

        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        const S = 120;
        canvas.width = S;
        canvas.height = S;
        ctx.drawImage(selfieImg, 0, 0, S, S);
        const data = ctx.getImageData(0, 0, S, S).data;
        const totalPixels = S * S;

        // ---- 1. Skin tone detection (broad range for all skin types) ----
        let skinPixels = 0;
        for (let i = 0; i < data.length; i += 4) {
            const r = data[i], g = data[i + 1], b = data[i + 2];
            // HSV-based skin detection for diverse skin tones
            const max = Math.max(r, g, b), min = Math.min(r, g, b);
            const brightness = max / 255;
            const saturation = max === 0 ? 0 : (max - min) / max;

            // Skin pixels: warm hues, moderate saturation, not too dark or bright
            if (r > 40 && g > 25 && b > 15 &&
                r > g && (r - g) > 5 && r > b &&
                brightness > 0.15 && brightness < 0.95 &&
                saturation > 0.05 && saturation < 0.85) {
                skinPixels++;
            }
        }
        const skinRatio = skinPixels / totalPixels;

        if (skinRatio < 0.06) {
            return { status: 'failed', reason: 'No face detected in your selfie. Please upload a clear photo showing your face. Avoid screenshots, landscapes, or objects.' };
        }

        // ---- 2. Face region analysis (center-weighted) ----
        // Faces should have skin concentrated in the center of the image
        let centerSkin = 0, edgeSkin = 0;
        const cx = S / 2, cy = S / 2, faceR = S * 0.35;
        for (let y = 0; y < S; y++) {
            for (let x = 0; x < S; x++) {
                const idx = (y * S + x) * 4;
                const r = data[idx], g = data[idx + 1], b = data[idx + 2];
                const isSkin = r > 40 && g > 25 && b > 15 && r > g && r > b;
                if (isSkin) {
                    const dist = Math.sqrt((x - cx) ** 2 + (y - cy) ** 2);
                    if (dist < faceR) centerSkin++;
                    else edgeSkin++;
                }
            }
        }
        const centerRatio = centerSkin / (centerSkin + edgeSkin + 1);
        if (centerRatio < 0.25) {
            return { status: 'failed', reason: 'Face not properly centered. Please take a selfie with your face clearly visible in the center of the image.' };
        }

        // ---- 3. Brightness check ----
        let totalBrightness = 0;
        for (let i = 0; i < data.length; i += 4) {
            totalBrightness += (data[i] + data[i + 1] + data[i + 2]) / 3;
        }
        const avgBrightness = totalBrightness / totalPixels;
        if (avgBrightness < 30) {
            return { status: 'failed', reason: 'Your selfie is too dark. Please take a photo in a well-lit area.' };
        }
        if (avgBrightness > 240) {
            return { status: 'failed', reason: 'Your selfie is overexposed/too bright. Please retake in normal lighting.' };
        }

        // ---- 4. Color variety (reject blank/solid images) ----
        const colorBuckets = new Set();
        for (let i = 0; i < data.length; i += 16) {
            colorBuckets.add(`${data[i] >> 5}-${data[i + 1] >> 5}-${data[i + 2] >> 5}`);
        }
        if (colorBuckets.size < 20) {
            return { status: 'failed', reason: 'Your image appears to be blank, solid-colored, or a screenshot. Please upload a real selfie photograph.' };
        }

        // ---- 5. Edge detection (faces have high edge density in facial features) ----
        let edgeCount = 0;
        for (let y = 1; y < S - 1; y++) {
            for (let x = 1; x < S - 1; x++) {
                const i = (y * S + x) * 4;
                const gx = Math.abs(data[i] - data[i - 4]) + Math.abs(data[i + 1] - data[i - 3]);
                const gy = Math.abs(data[i] - data[(i - S * 4)]) + Math.abs(data[i + 1] - data[(i - S * 4 + 1)]);
                if (gx + gy > 40) edgeCount++;
            }
        }
        const edgeRatio = edgeCount / totalPixels;
        if (edgeRatio < 0.03) {
            return { status: 'failed', reason: 'The image lacks facial detail. Please upload a clear, focused selfie (not a blurry or heavily filtered image).' };
        }

        // ---- 6. Aspect ratio check (selfies should be roughly portrait or square) ----
        const aspect = selfieImg.width / selfieImg.height;
        if (aspect > 3 || aspect < 0.25) {
            return { status: 'failed', reason: 'This doesn\'t look like a selfie (unusual aspect ratio). Please upload a standard portrait or square photo.' };
        }

        // ---- 7. Same-image detection (prevent re-uploading profile pic as selfie) ----
        if (profilePicUrl && profilePicUrl.startsWith('data:image/')) {
            try {
                const profileImg = await loadImage(profilePicUrl);
                canvas.width = S; canvas.height = S;
                ctx.drawImage(profileImg, 0, 0, S, S);
                const profileData = ctx.getImageData(0, 0, S, S).data;

                let matchCount = 0;
                for (let i = 0; i < data.length; i += 4) {
                    if (Math.abs(data[i] - profileData[i]) < 8 &&
                        Math.abs(data[i + 1] - profileData[i + 1]) < 8 &&
                        Math.abs(data[i + 2] - profileData[i + 2]) < 8) {
                        matchCount++;
                    }
                }
                if (matchCount / totalPixels > 0.92) {
                    return { status: 'failed', reason: 'Your selfie is too similar to your profile photo. Please take a new, different selfie for verification.' };
                }
            } catch { }
        }

        // ---- 8. Previously submitted selfie comparison ----
        const prevSelfie = getStored(STORAGE_KEYS.VERIFICATION_SELFIE);
        if (prevSelfie && prevSelfie === selfieDataUrl.slice(0, 200)) {
            return { status: 'failed', reason: 'You have already submitted this selfie. Please take a new selfie for verification.' };
        }

        // All checks passed — this looks like a real face selfie
        return { status: 'passed', reason: null };
    } catch (err) {
        return { status: 'failed', reason: 'Could not process your selfie. Please try a JPEG or PNG photo.' };
    }
}


export function AuthProvider({ children }) {
    const [user, setUser] = useState(null);
    const [guest, setGuest] = useState(false);
    const [loading, setLoading] = useState(true);
    const [likes, setLikes] = useState([]);
    const [matches, setMatches] = useState([]);
    const [passes, setPasses] = useState([]);
    const [saved, setSaved] = useState([]);
    const [activity, setActivity] = useState([]);
    const [settings, setSettings] = useState(DEFAULT_SETTINGS);
    const [messages, setMessages] = useState([]);
    const [verificationStatus, setVerificationStatus] = useState(null);
    const [verificationTimer, setVerificationTimer] = useState(null); // timestamp when moderation ends
    const [realProfilePool, setRealProfilePool] = useState([]);
    const [preference, setPreference] = useState('sugar_mummy_looking_for_toyboy');
    const [subscribed, setSubscribed] = useState(false);
    const [liveLocationData, setLiveLocationData] = useState(null);

    // Load from localStorage
    useEffect(() => {
        setUser(getStored(STORAGE_KEYS.USER));
        setGuest(getStored(STORAGE_KEYS.GUEST, false));
        setLikes(getStored(STORAGE_KEYS.LIKES, []));
        setMatches(getStored(STORAGE_KEYS.MATCHES, []));
        setPasses(getStored(STORAGE_KEYS.PASSES, []));
        setSaved(getStored(STORAGE_KEYS.SAVED, []));
        setActivity(getStored(STORAGE_KEYS.ACTIVITY, []));
        setSettings({ ...DEFAULT_SETTINGS, ...getStored(STORAGE_KEYS.SETTINGS, {}) });
        setMessages(getStored(STORAGE_KEYS.MESSAGES, []));
        setVerificationStatus(getStored(STORAGE_KEYS.VERIFICATION, null));
        setVerificationTimer(getStored(STORAGE_KEYS.VERIFICATION_TIMER, null));
        setPreference(getStored(STORAGE_KEYS.PREFERENCE, 'sugar_mummy_looking_for_toyboy'));
        setSubscribed(getStored(STORAGE_KEYS.SUBSCRIBED, false));
        setLiveLocationData(getStored(STORAGE_KEYS.LIVE_LOCATION, null));
        setLoading(false);
    }, []);

    useEffect(() => {
        // Google OAuth is disabled for the GS app because provider redirects leave
        // the Android wrapper and return to the public Vercel URL.
        try {
            if (!isSupabaseConfigured()) return;
            const signedOutUntil = Number(getStored(STORAGE_KEYS.SIGNED_OUT_UNTIL, 0) || 0);
            if (signedOutUntil && Date.now() < signedOutUntil) return;
            const url = new URL(window.location.href);
            const hasOAuthParams = url.hash.includes('access_token=') || url.searchParams.has('code') || url.searchParams.has('provider_token');
            if (!hasOAuthParams) return;
            createBrowserSupabaseClient().auth.signOut({ scope: 'local' }).catch(() => {});
            url.hash = '';
            url.searchParams.delete('code');
            url.searchParams.delete('provider_token');
            window.history.replaceState({}, '', url.pathname + (url.search ? url.search : ''));
        } catch {}
    }, []);

    /*
      Whose responses are sitting in the cache.

      cachedFetch keys on URL alone, and several of those URLs carry a viewer_id
      whose response differs by account: phone numbers are masked or revealed
      depending on the viewer's package. Clearing on sign out alone is not
      enough, because the account can change without one, so this watches the
      identity itself and empties the cache whenever it moves.
    */
    const cachedForRef = useRef(null);
    useEffect(() => {
        const identity = user?.id || null;
        if (cachedForRef.current === identity) return;
        cachedForRef.current = identity;
        clearCache();
    }, [user?.id]);

    // Refresh server account state so admin approvals and package unlocks reach the device.
    useEffect(() => {
        if (!user?.email || loading) return;
        let alive = true;
        async function refreshAccount() {
            try {
                const res = await fetch('/api/members', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: 'refresh_account', memberId: user.id, email: user.email }),
                });
                const data = await res.json().catch(() => ({}));
                if (!alive || !res.ok || !data.member) return;
                const account = { ...user, ...accountFromMember(data.member, user.email) };
                setUser(account);
                setVerificationStatus(account.verification_status || null);
                setStored(STORAGE_KEYS.USER, account);
                setStored(STORAGE_KEYS.VERIFICATION, account.verification_status || null);
                loadAccountInbox(account);
                loadChatInbox(account);
                loadRemoteSettings(account);
                loadAccountState(account);
                requestAccountReminders(account);
            } catch {}
        }
        /*
          This was every 10 seconds, and it is not one request: the body below
          fans out into refresh_account plus the inbox, chat inbox, remote
          settings, account state and reminder loads. Six requests every ten
          seconds, from every open tab, running just as happily with the app in
          the background. That is around 2000 requests an hour per user and it
          is the single largest contributor to the egress overage that got this
          project restricted.

          What it exists for is admin approvals and package unlocks reaching the
          device. Those are minute-scale events, not ten-second ones, and
          startPolling refreshes the moment the user returns to the app, so a
          slower interval is not felt.
        */
        const stop = startPolling(refreshAccount, POLL.ACCOUNT);
        return () => { alive = false; stop(); };
    }, [user?.email, loading]);

    useEffect(() => {
        if (!user?.id || loading) return;
        let stopped = false;
        let channel = null;

        async function heartbeat() {
            if (stopped || document.visibilityState === 'hidden') return;
            try {
                await fetch('/api/members', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: 'heartbeat', memberId: user.id, email: user.email }),
                });
            } catch {}
        }

        try {
            if (isSupabaseConfigured()) {
                const supabase = createBrowserSupabaseClient();
                channel = supabase.channel('gs-online-presence', {
                    config: { presence: { key: user.id } },
                });
                channel.subscribe((status) => {
                    if (status === 'SUBSCRIBED') {
                        channel.track({
                            userId: user.id,
                            name: user.display_name || 'Member',
                            at: new Date().toISOString(),
                        }).catch(() => {});
                    }
                });
            }
        } catch {}

        heartbeat();
        const interval = window.setInterval(heartbeat, 60 * 1000);
        const onFocus = () => heartbeat();
        const onVisibility = () => { if (document.visibilityState === 'visible') heartbeat(); };
        window.addEventListener('focus', onFocus);
        document.addEventListener('visibilitychange', onVisibility);

        return () => {
            stopped = true;
            window.clearInterval(interval);
            window.removeEventListener('focus', onFocus);
            document.removeEventListener('visibilitychange', onVisibility);
            try { if (channel) createBrowserSupabaseClient().removeChannel(channel); } catch {}
        };
    }, [user?.id, user?.email, user?.display_name, loading]);
    // ---- Fetch Real Profile Pool for AI engagement ----
    useEffect(() => {
        async function loadProfilePool() {
            try {
                const res = await fetch('/api/profiles?page=1&per_page=30');
                const data = await res.json();
                if (data.profiles?.length > 0) {
                    setRealProfilePool(data.profiles);
                    // Store last known post id for subscription updates
                    const firstId = data.profiles[0]?.wpId;
                    const lastKnown = getStored(STORAGE_KEYS.LAST_POST_ID);
                    if (!lastKnown && firstId) setStored(STORAGE_KEYS.LAST_POST_ID, firstId);
                }
            } catch (err) {
                console.error('Failed to load profile pool for AI:', err);
            }
        }
        loadProfilePool();
    }, []);

    // ---- Activity Logger (with notification dispatch) ----
    const logActivity = useCallback((type, data) => {
        const entry = {
            id: `${type}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
            type, ...data,
            timestamp: new Date().toISOString(),
            read: false,
        };
        setActivity(prev => {
            const updated = [entry, ...prev].slice(0, 100);
            setStored(STORAGE_KEYS.ACTIVITY, updated);
            return updated;
        });
        // Dispatch for NotificationManager
        if (typeof window !== 'undefined' && data?.title) {
            window.dispatchEvent(new CustomEvent('gs-notification', {
                detail: { title: data.title, body: data.message || '', image: data.image || '', type }
            }));
        }
    }, []);

    const markActivityRead = useCallback(() => {
        setActivity(prev => {
            const updated = prev.map(a => ({ ...a, read: true }));
            setStored(STORAGE_KEYS.ACTIVITY, updated);
            return updated;
        });
    }, []);

    // ---- Messages ----
    const addMessage = useCallback((msg) => {
        const entry = {
            id: `msg-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
            ...msg, timestamp: new Date().toISOString(), read: false,
        };
        setMessages(prev => {
            const updated = [entry, ...prev].slice(0, 200);
            setStored(STORAGE_KEYS.MESSAGES, updated);
            return updated;
        });
    }, []);

    const markMessagesRead = useCallback(() => {
        setMessages(prev => {
            const updated = prev.map(m => ({ ...m, read: true, unreadCount: 0 }));
            setStored(STORAGE_KEYS.MESSAGES, updated);
            return updated;
        });
    }, []);

    async function syncAccountToServer(account, auth = {}) {
        if (!account?.email) return null;
        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'upsert_account', ...account, password: auth.password }),
            });
            const data = await res.json();
            if (!res.ok || !data.member) return null;
            const synced = {
                ...account,
                id: data.member.id || account.id,
                username: data.member.username || account.username,
                display_name: data.member.name || account.display_name,
                avatar_url: data.member.avatarUrl || account.avatar_url,
                photos: data.member.photos || account.photos || [],
                bio: data.member.bio || account.bio,
                age: data.member.age || account.age,
                location: data.member.location || account.location,
                country: data.member.country || account.country,
                city: data.member.city || account.city,
                latitude: data.member.latitude ?? account.latitude,
                longitude: data.member.longitude ?? account.longitude,
                geo_updated_at: data.member.geoUpdatedAt || account.geo_updated_at,
                phone: data.member.phone || account.phone,
                phone_number: data.member.phone || data.member.phone_number || account.phone_number || account.phone,
                profile_label: data.member.profileLabel || account.profile_label,
                member_category: data.member.memberCategory || account.member_category,
                looking_for: data.member.lookingFor || account.looking_for,
                intent_summary: data.member.intentSummary || account.intent_summary,
                wants: data.member.wants || account.wants,
                needed_qualities: data.member.neededQualities || account.needed_qualities,
                age_range_preference: data.member.ageRangePreference || account.age_range_preference,
                hobbies: data.member.hobbies || account.hobbies || [],
                interests: data.member.interests || account.interests || [],
                subscription_tier: data.member.subscriptionTier || account.subscription_tier,
                admin_approved: data.member.adminApproved ?? account.admin_approved,
                package_locked: data.member.packageLocked ?? account.package_locked,
                show_in_public: data.member.showInPublic ?? account.show_in_public,
                verification_status: data.member.verified ? 'verified' : (data.member.verificationStatus || account.verification_status),
                verified: Boolean(data.member.verified),
            };
            setUser(synced);
            setStored(STORAGE_KEYS.USER, synced);
            return synced;
        } catch {
            return null;
        }
    }

    function accountFromMember(member, email) {
        return {
            id: member.id || btoa(email),
            username: member.username || String(member.name || member.display_name || email.split('@')[0] || 'member')
                .trim()
                .toLowerCase()
                .replace(/[^a-z0-9_]+/g, '_')
                .replace(/^_+|_+$/g, '')
                .slice(0, 24) || 'member',
            email: member.email || email,
            display_name: member.name || member.display_name || email.split('@')[0],
            avatar_url: member.avatarUrl || member.avatar_url || '',
            photos: member.photos || [],
            bio: member.bio || '',
            age: member.age || '',
            location: member.location || '',
            country: member.country || '',
            city: member.city || '',
            latitude: member.latitude ?? null,
            longitude: member.longitude ?? null,
            geo_updated_at: member.geoUpdatedAt || null,
            phone_number: member.phone || member.phone_number || '',
            phone: member.phone || member.phone_number || '',
            profile_label: member.profileLabel || member.memberCategory || 'member',
            member_category: member.memberCategory || member.profileLabel || 'member',
            looking_for: member.lookingFor || '',
            intent_summary: member.intentSummary || '',
            wants: member.wants || '',
            needed_qualities: member.neededQualities || '',
            age_range_preference: member.ageRangePreference || '',
            interests: member.interests || [],
            hobbies: member.hobbies || [],
            subscription_tier: member.subscriptionTier || 'free',
            admin_approved: Boolean(member.adminApproved),
            package_locked: Boolean(member.packageLocked),
            show_in_public: member.showInPublic !== false,
            verification_status: member.verified ? 'verified' : (member.verificationStatus || null),
            verified: Boolean(member.verified),
            preference_locked: true,
        };
    }

    async function loadAccountInbox(account) {
        if (!account?.email && !account?.id) return;
        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'account_inbox', memberId: account.id, email: account.email }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok || !Array.isArray(data.notifications)) return;
            const inboxItems = data.notifications.map((item) => ({
                id: `admin-${item.id}`,
                type: item.type || 'admin',
                sender: item.metadata?.senderLabel || item.metadata?.team || 'GS Admin',
                title: item.title,
                body: item.body,
                timestamp: item.created_at,
                read: Boolean(item.read),
            }));
            setMessages((prev) => {
                const seen = new Set(prev.map((item) => item.id));
                const merged = [...inboxItems.filter((item) => !seen.has(item.id)), ...prev].slice(0, 250);
                setStored(STORAGE_KEYS.MESSAGES, merged);
                return merged;
            });
        } catch {}
    }

    async function loadChatInbox(account) {
        if (!account?.id) return;
        try {
            const res = await fetch(`/api/chat?userId=${encodeURIComponent(account.id)}`);
            const data = await res.json().catch(() => ({}));
            if (!res.ok || !Array.isArray(data.conversations)) return;
            const chatItems = data.conversations.map((conversation) => {
                const peer = conversation.peer || {};
                const latest = conversation.latestMessage || {};
                const unreadCount = Math.max(0, Number(conversation.unreadCount || 0));
                return {
                    id: `chat-${conversation.id}`,
                    type: 'member_message',
                    sender: peer.display_name || 'Member',
                    senderImage: peer.avatar_url || peer.photos?.[0] || '',
                    title: peer.display_name ? `Message from ${peer.display_name}` : 'Member message',
                    body: latest.body || 'Conversation opened',
                    timestamp: latest.created_at || conversation.updated_at || conversation.created_at || new Date().toISOString(),
                    read: unreadCount <= 0,
                    unreadCount,
                    memberId: conversation.peerId,
                    conversationId: conversation.id,
                };
            });
            setMessages((prev) => {
                const nonChatItems = prev.filter((item) => !String(item.id || '').startsWith('chat-'));
                const merged = [...chatItems, ...nonChatItems]
                    .sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0))
                    .slice(0, 250);
                setStored(STORAGE_KEYS.MESSAGES, merged);
                return merged;
            });
        } catch {}
    }

    function applyRemoteSettings(remoteSettings) {
        if (!remoteSettings || typeof remoteSettings !== 'object') return null;
        const merged = { ...DEFAULT_SETTINGS, ...getStored(STORAGE_KEYS.SETTINGS, {}), ...remoteSettings };
        setSettings(merged);
        setStored(STORAGE_KEYS.SETTINGS, merged);
        return merged;
    }

    async function loadRemoteSettings(account) {
        if (!account?.email && !account?.id) return null;
        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'account_settings', memberId: account.id, email: account.email }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok || !data.settings) return null;
            return applyRemoteSettings(data.settings);
        } catch {
            return null;
        }
    }

    async function loadAccountState(account) {
        if (!account?.email && !account?.id) return null;
        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'account_state', memberId: account.id, email: account.email }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) return null;
            if (Array.isArray(data.likes)) {
                setLikes(data.likes);
                setStored(STORAGE_KEYS.LIKES, data.likes);
            }
            if (Array.isArray(data.matches)) {
                setMatches(data.matches);
                setStored(STORAGE_KEYS.MATCHES, data.matches);
            }
            if (Array.isArray(data.passes)) {
                setPasses(data.passes);
                setStored(STORAGE_KEYS.PASSES, data.passes);
            }
            if (Array.isArray(data.saved)) {
                setSaved(data.saved);
                setStored(STORAGE_KEYS.SAVED, data.saved);
            }
            return data;
        } catch {
            return null;
        }
    }

    async function requestAccountReminders(account) {
        if (!account?.email && !account?.id) return;
        const today = new Date().toISOString().slice(0, 10);
        const key = `gscom_reminders_${account.id || account.email}`;
        if (getStored(key) === today) return;
        setStored(key, today);
        try {
            await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'account_reminders', memberId: account.id, email: account.email }),
            });
            loadAccountInbox(account);
            loadChatInbox(account);
        } catch {}
    }

    async function signInExisting(email, password) {
        setStored(STORAGE_KEYS.SIGNED_OUT_UNTIL, null);
        const cleanEmail = String(email || '').trim().toLowerCase();
        if (!cleanEmail || !cleanEmail.includes('@')) throw new Error('Enter a valid email address.');
        const res = await fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'login_account', email: cleanEmail, password }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.member) throw new Error(data.error || 'Could not sign in.');
        const account = accountFromMember(data.member, cleanEmail);
        setUser(account);
        setGuest(false);
        setPreference(account.preference || getStored(STORAGE_KEYS.PREFERENCE, 'sugar_mummy_looking_for_toyboy'));
        setStored(STORAGE_KEYS.USER, account);
        setStored(STORAGE_KEYS.LOGIN_EMAIL, cleanEmail);
        setStored(STORAGE_KEYS.VERIFICATION, account.verification_status || null);
        setVerificationStatus(account.verification_status || null);
        setStored(STORAGE_KEYS.GUEST, false);
        logActivity('login', { title: 'Signed in', message: `Welcome back, ${account.display_name}!` });
        loadAccountInbox(account);
        loadChatInbox(account);
        loadRemoteSettings(account);
        loadAccountState(account);
        requestAccountReminders(account);
        return account;
    }

    async function syncOAuthAccount(sessionUser) {
        const cleanEmail = String(sessionUser?.email || '').trim().toLowerCase();
        if (!cleanEmail) return null;
        const res = await fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'oauth_account',
                auth_user_id: sessionUser.id,
                email: cleanEmail,
                display_name: sessionUser.user_metadata?.full_name || sessionUser.user_metadata?.name || cleanEmail.split('@')[0],
                avatar_url: sessionUser.user_metadata?.avatar_url || '',
            }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.member) throw new Error(data.error || 'Could not sync Google account.');
        const account = accountFromMember(data.member, cleanEmail);
        setPreference(account.preference || getStored(STORAGE_KEYS.PREFERENCE, 'toyboy_looking_for_sugar_mummy'));
        setVerificationStatus(account.verification_status || null);
        return account;
    }

    async function signInWithGoogle() {
        throw new Error('Google login has been removed. Use email and password to continue inside the GS app.');
    }


    async function requestPasswordReset(email) {
        const cleanEmail = String(email || '').trim().toLowerCase();
        if (!cleanEmail || !cleanEmail.includes('@')) throw new Error('Enter the email on your account.');
        const res = await fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'request_password_reset', email: cleanEmail }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || 'Could not send reset code.');
        setStored(STORAGE_KEYS.LOGIN_EMAIL, cleanEmail);
        return data;
    }

    async function resetPassword(email, code, password) {
        setStored(STORAGE_KEYS.SIGNED_OUT_UNTIL, null);
        const cleanEmail = String(email || '').trim().toLowerCase();
        if (!cleanEmail || !cleanEmail.includes('@')) throw new Error('Enter the email on your account.');
        if (!/^\d{6}$/.test(String(code || '').trim())) throw new Error('Enter the 6-digit reset code.');
        if (String(password || '').length < 6) throw new Error('New password must be at least 6 characters.');
        const res = await fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'reset_password', email: cleanEmail, code: String(code).trim(), password }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.member) throw new Error(data.error || 'Could not reset password.');
        const account = accountFromMember(data.member, cleanEmail);
        setUser(account);
        setGuest(false);
        setStored(STORAGE_KEYS.USER, account);
        setStored(STORAGE_KEYS.LOGIN_EMAIL, cleanEmail);
        setStored(STORAGE_KEYS.GUEST, false);
        logActivity('security', { title: 'Password reset', message: 'Your password was changed successfully.' });
        loadRemoteSettings(account);
        loadAccountInbox(account);
        loadChatInbox(account);
        loadAccountState(account);
        requestAccountReminders(account);
        return account;
    }
    // ---- Auth Methods ----
    async function signIn(email, password, displayName, userPreference, profileDetails = {}) {
        setStored(STORAGE_KEYS.SIGNED_OUT_UNTIL, null);
        const cleanEmail = String(email || '').trim().toLowerCase();
        const cleanedName = cleanDisplayName(displayName || profileDetails.display_name || profileDetails.realName, cleanEmail);
        const photos = Array.isArray(profileDetails.photos)
            ? profileDetails.photos.filter(Boolean).slice(0, 6)
            : (profileDetails.avatar_url || profileDetails.photo ? [profileDetails.avatar_url || profileDetails.photo] : []);
        const avatarUrl = profileDetails.avatar_url || photos[0] || '';
        const cleanUsername = String(profileDetails.username || cleanedName)
            .trim()
            .toLowerCase()
            .replace(/[^a-z0-9_]+/g, '_')
            .replace(/^_+|_+$/g, '')
            .slice(0, 24);
        const intentMap = {
            sugar_mummy_looking_for_toyboy: { profile_label: 'sugar_mummy', looking_for: 'Sugar Guy / Toyboy', intent_summary: 'I am a sugar mummy looking for a sugar guy / toyboy.' },
            sugar_daddy_looking_for_mistress: { profile_label: 'sugar_daddy', looking_for: 'Mistress', intent_summary: 'I am a sugar daddy looking for an adult mistress.' },
            mistress_looking_for_sugar_daddy: { profile_label: 'mistress', looking_for: 'Sugar Daddy', intent_summary: 'I am an adult mistress looking for a sugar daddy.' },
            toyboy_looking_for_sugar_mummy: { profile_label: 'toyboy', looking_for: 'Sugar Mummy', intent_summary: 'I am a sugar guy / toyboy looking for a sugar mummy.' },
        };
        const selectedIntent = intentMap[userPreference] || intentMap.sugar_mummy_looking_for_toyboy;
        const userData = {
            id: btoa(cleanEmail), email: cleanEmail,
            display_name: cleanedName,
            username: cleanUsername || 'member',
            avatar_url: avatarUrl,
            photos,
            bio: String(profileDetails.bio || '').trim(),
            interests: Array.isArray(profileDetails.interests) ? profileDetails.interests.slice(0, 12) : [],
            hobbies: Array.isArray(profileDetails.hobbies) ? profileDetails.hobbies.slice(0, 12) : [],
            orientation: '',
            age: String(profileDetails.age || '').trim(),
            location: String(profileDetails.location || '').trim(),
            city: String(profileDetails.city || profileDetails.location || '').trim(),
            country: String(profileDetails.country || '').trim(),
            phone: String(profileDetails.phone || profileDetails.phone_number || '').trim(),
            phone_number: String(profileDetails.phone_number || profileDetails.phone || '').trim(),
            preference: userPreference || 'sugar_mummy_looking_for_toyboy',
            ...selectedIntent,
            subscription_tier: 'free', admin_approved: true, package_locked: false, preference_locked: true,
            created_at: new Date().toISOString(),
        };
        const existing = getStored(STORAGE_KEYS.USER);
        const merged = existing?.email === cleanEmail
            ? { ...userData, ...existing, ...profileDetails, display_name: cleanedName, username: cleanUsername || existing.username || userData.username, preference: userPreference || existing.preference || 'sugar_mummy_looking_for_toyboy' }
            : userData;
        setUser(merged);
        setGuest(false);
        setPreference(merged.preference);
        setStored(STORAGE_KEYS.USER, merged);
        setStored(STORAGE_KEYS.LOGIN_EMAIL, String(email || '').trim().toLowerCase());
        setStored(STORAGE_KEYS.GUEST, false);
        setStored(STORAGE_KEYS.PREFERENCE, merged.preference);
        logActivity('login', { title: 'Signed in', message: `Welcome back, ${merged.display_name}!` });
        const synced = await syncAccountToServer(merged, { password });
        if (!synced) {
            setUser(null);
            setStored(STORAGE_KEYS.USER, null);
            throw new Error('Could not create account. Check your email and password, then try again.');
        }
        loadAccountInbox(synced);
        loadChatInbox(synced);
        loadRemoteSettings(synced);
        loadAccountState(synced);
        requestAccountReminders(synced);

        // Welcome message (first sign-in only)
        const existingMessages = getStored(STORAGE_KEYS.MESSAGES, []);
        if (!existingMessages.some(m => m.type === 'gs_support')) {
            setTimeout(() => {
                addMessage({
                    type: 'gs_support', sender: 'GS Support', senderImage: '',
                    title: 'Welcome to GenuineSugarMummies.com!',
                    body: `Hi ${merged.display_name}! Welcome to GenuineSugarMummies.com — your premium connection platform. Browse profiles, like & match, then request hookup connections. Admin Mary G on Telegram @GSADMINMARYGAGENCY facilitates all connections. Enjoy!`,
                });
            }, 2000);
        }
        return merged;
    }

    function skipLogin() {
        setGuest(true);
        setStored(STORAGE_KEYS.GUEST, true);
    }

    async function signOut() {
        /*
          Drop every cached API response before anything else. cachedFetch keys
          on URL alone, and some of those URLs carry a viewer_id whose response
          differs per account: phone numbers are masked or revealed depending on
          the viewer's package. Leaving the cache in place across a sign out on a
          shared phone would show the next person the previous one's view.
        */
        clearCache();
        setStored(STORAGE_KEYS.SIGNED_OUT_UNTIL, Date.now() + 2 * 60 * 1000);
        try {
            if (isSupabaseConfigured()) {
                const supabase = createBrowserSupabaseClient();
                await supabase.auth.signOut({ scope: 'local' });
                await supabase.auth.signOut();
            }
        } catch {}
        try {
            if (typeof window !== 'undefined') {
                Object.keys(localStorage).forEach((key) => {
                    if (key.startsWith('sb-') || key.includes('supabase') || key.includes('auth-token')) {
                        localStorage.removeItem(key);
                    }
                });
                Object.keys(sessionStorage).forEach((key) => {
                    if (key.startsWith('sb-') || key.includes('supabase') || key.includes('auth-token')) {
                        sessionStorage.removeItem(key);
                    }
                });
            }
        } catch {}
        setUser(null); setGuest(false);
        setLikes([]); setMatches([]); setPasses([]); setSaved([]);
        setMessages([]); setVerificationStatus(null); setVerificationTimer(null);
        setStored(STORAGE_KEYS.USER, null);
        setStored(STORAGE_KEYS.GUEST, false);
        setStored(STORAGE_KEYS.LIKES, []);
        setStored(STORAGE_KEYS.MATCHES, []);
        setStored(STORAGE_KEYS.PASSES, []);
        setStored(STORAGE_KEYS.SAVED, []);
        setStored(STORAGE_KEYS.MESSAGES, []);
        setStored(STORAGE_KEYS.VERIFICATION, null);
        setStored(STORAGE_KEYS.VERIFICATION_TIMER, null);
        return true;
    }

    function resetVerificationForPhotoChange(account, reason = 'Your profile photo was changed. Please submit verification again.') {
        const updated = {
            ...account,
            verified: false,
            verification_status: 'reverify_required',
            verification_selfie_url: '',
            verification_document_url: '',
            verification_document_type: '',
            verification_phone: '',
            verification_submitted_at: null,
            verification_rejection_reason: reason,
        };
        setVerificationStatus('reverify_required');
        setVerificationTimer(null);
        setStored(STORAGE_KEYS.VERIFICATION, 'reverify_required');
        setStored(STORAGE_KEYS.VERIFICATION_TIMER, null);
        setStored(STORAGE_KEYS.VERIFICATION_SELFIE, null);
        return updated;
    }

    function updateProfile(updates) {
        if (!user) return;
        const updated = { ...user, ...updates };
        if (updates.preference) {
            setPreference(updates.preference);
            setStored(STORAGE_KEYS.PREFERENCE, updates.preference);
        }
        setUser(updated);
        setStored(STORAGE_KEYS.USER, updated);
        logActivity('profile_update', { title: 'Profile updated', message: 'You updated your profile info' });
        syncAccountToServer(updated);
        return updated;
    }

    function addPhoto(dataUrl) {
        if (!user) return;
        const changesProfilePhoto = !(user.avatar_url || user.photos?.[0]);
        const photos = [...(user.photos || []), dataUrl].slice(0, 6);
        let updated = { ...user, photos };
        if (!updated.avatar_url && photos.length > 0) updated.avatar_url = photos[0];
        if (changesProfilePhoto && (user.verified || user.verification_status === 'verified')) {
            updated = resetVerificationForPhotoChange(updated);
            addMessage({
                type: 'verification',
                sender: 'GS Verification Team',
                senderImage: '',
                title: 'Verification reset',
                body: 'Your profile photo changed. Your badge was removed until you submit selfie, ID/passport, and phone details again.',
            });
        }
        setUser(updated);
        setStored(STORAGE_KEYS.USER, updated);
        logActivity('photo_added', { title: 'Photo added', message: 'You added a new photo' });
        syncAccountToServer(updated);
    }

    function removePhoto(index) {
        if (!user) return;
        {
            const photos = [...(user.photos || [])];
            const removingPrimary = index === 0;
            photos.splice(index, 1);
            let updated = { ...user, photos, avatar_url: photos[0] || '' };
            if ((removingPrimary || photos.length === 0) && (user.verified || user.verification_status === 'verified')) {
                updated = resetVerificationForPhotoChange(updated, 'Your profile photo was removed or changed. Please submit verification again.');
                logActivity('profile_update', { title: 'Verification reset', message: 'Your profile photo was changed. Please re-verify your identity.' });
                addMessage({
                    type: 'verification',
                    sender: 'GS Verification Team',
                    senderImage: '',
                    title: 'Verification reset',
                    body: 'Your profile picture was removed or changed. Your badge has been revoked. Please re-submit selfie, ID/passport, and phone details.',
                });
            }
            setUser(updated);
            setStored(STORAGE_KEYS.USER, updated);
            syncAccountToServer(updated);
            return;
        }
        const photos = [...(user.photos || [])];
        const removingPrimary = index === 0;
        photos.splice(index, 1);
        const updated = { ...user, photos, avatar_url: photos[0] || '' };
        setUser(updated);
        setStored(STORAGE_KEYS.USER, updated);

        // If primary photo deleted → ALWAYS reset verification
        if (removingPrimary || photos.length === 0) {
            setVerificationStatus(null);
            setVerificationTimer(null);
            setStored(STORAGE_KEYS.VERIFICATION, null);
            setStored(STORAGE_KEYS.VERIFICATION_TIMER, null);
            setStored(STORAGE_KEYS.VERIFICATION_SELFIE, null);
            logActivity('profile_update', { title: 'Verification reset', message: 'Your profile photo was changed. Please re-verify your identity.' });
        syncAccountToServer(updated);
            addMessage({
                type: 'verification', sender: 'GS Verification Team', senderImage: '',
                title: '⚠️ Verification Reset',
                body: 'Your profile picture was removed. Your verification badge has been revoked. Please re-verify with a new selfie.',
            });
        }
    }

    // ==========================================
    // MANUAL VERIFICATION REQUEST
    // ==========================================
    async function verifyProfile(input) {
        if (!user) {
            setVerificationStatus('failed');
            setStored(STORAGE_KEYS.VERIFICATION, 'failed');
            addMessage({ type: 'verification', sender: 'GS Verification Team', senderImage: '', title: 'Verification Failed', body: 'You must be signed in to verify your profile.' });
            return 'failed';
        }

        const request = typeof input === 'string'
            ? { selfieDataUrl: input }
            : (input || {});
        const selfieDataUrl = request.selfieDataUrl || request.verification_selfie_url || '';
        const documentDataUrl = request.documentDataUrl || request.verification_document_url || '';
        const documentType = request.documentType || request.verification_document_type || 'id';
        const phone = request.phone || request.verification_phone || user.phone_number || user.phone || '';
        const profilePic = user.avatar_url || (user.photos && user.photos[0]);

        if (!profilePic) {
            setVerificationStatus('failed');
            setStored(STORAGE_KEYS.VERIFICATION, 'failed');
            addMessage({ type: 'verification', sender: 'GS Verification Team', senderImage: '', title: 'Verification Failed', body: 'Upload a profile photo before requesting manual verification.' });
            return 'failed';
        }

        if (!selfieDataUrl || !selfieDataUrl.startsWith('data:image/')) {
            setVerificationStatus('failed');
            setStored(STORAGE_KEYS.VERIFICATION, 'failed');
            addMessage({ type: 'verification', sender: 'GS Verification Team', senderImage: '', title: 'Selfie Required', body: 'Please upload a clear selfie photograph.' });
            return 'failed';
        }

        if (!documentDataUrl || !documentDataUrl.startsWith('data:image/')) {
            setVerificationStatus('failed');
            setStored(STORAGE_KEYS.VERIFICATION, 'failed');
            addMessage({ type: 'verification', sender: 'GS Verification Team', senderImage: '', title: 'ID or Passport Required', body: 'Please upload a clear photo of your ID or passport.' });
            return 'failed';
        }

        if (!String(phone).trim()) {
            setVerificationStatus('failed');
            setStored(STORAGE_KEYS.VERIFICATION, 'failed');
            addMessage({ type: 'verification', sender: 'GS Verification Team', senderImage: '', title: 'Phone Required', body: 'Please add your phone number before verification.' });
            return 'failed';
        }

        setVerificationStatus('pending_admin');
        setStored(STORAGE_KEYS.VERIFICATION, 'pending_admin');
        setStored(STORAGE_KEYS.VERIFICATION_SELFIE, selfieDataUrl.slice(0, 200));

        const updated = {
            ...user,
            verification_status: 'pending_admin',
            verified: false,
            verification_selfie_url: selfieDataUrl,
            verification_document_url: documentDataUrl,
            verification_document_type: documentType,
            verification_phone: phone,
            phone_number: phone,
            phone,
            verification_submitted_at: new Date().toISOString(),
        };
        setUser(updated);
        setStored(STORAGE_KEYS.USER, updated);

        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'submit_verification',
                    memberId: updated.id,
                    email: updated.email,
                    verification_selfie_url: selfieDataUrl,
                    verification_document_url: documentDataUrl,
                    verification_document_type: documentType,
                    verification_phone: phone,
                }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(data.error || 'Verification submission failed.');
            if (data.member) {
                const synced = {
                    ...updated,
                    id: data.member.id || updated.id,
                    verification_status: 'pending_admin',
                    verified: false,
                };
                setUser(synced);
                setStored(STORAGE_KEYS.USER, synced);
            }
        } catch (error) {
            addMessage({ type: 'verification', sender: 'GS Verification Team', senderImage: '', title: 'Saved Locally', body: 'Your verification request is saved on this device. Run the admin SQL if it does not appear in the control panel.' });
        }

        logActivity('profile_update', { title: 'Verification submitted', message: 'Your selfie, ID/passport, and phone are waiting for manual admin approval.' });
        addMessage({ type: 'verification', sender: 'GS Verification Team', senderImage: '', title: 'Manual Verification Pending', body: 'Admin will review your selfie, ID/passport, phone number, and approve your badge from the admin panel.' });
        return 'pending_admin';
    }
    function clearVerification() {
        setVerificationStatus(null);
        setVerificationTimer(null);
        setStored(STORAGE_KEYS.VERIFICATION, null);
        setStored(STORAGE_KEYS.VERIFICATION_TIMER, null);
        setStored(STORAGE_KEYS.VERIFICATION_SELFIE, null);
    }

    useEffect(() => {
        if (typeof document === 'undefined') return;
        document.documentElement.dataset.theme = settings.darkMode ? 'dark' : 'light';
    }, [settings.darkMode]);

    // ---- Settings ----
    function updateSettings(updates) {
        const updated = { ...settings, ...updates };
        setSettings(updated);
        setStored(STORAGE_KEYS.SETTINGS, updated);

        if (user?.email || user?.id) {
            fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'update_settings', memberId: user.id, email: user.email, settings: updated }),
            })
                .then((res) => res.json().catch(() => ({})).then((data) => ({ ok: res.ok, data })))
                .then(({ ok, data }) => {
                    if (ok && data.settings) applyRemoteSettings(data.settings);
                })
                .catch(() => {});
        }

        // Live location toggle
        if ('liveLocation' in updates) {
            if (updates.liveLocation) {
                startLiveLocation();
            } else {
                stopLiveLocation();
            }
        }
        if (updates.notifications === true && typeof window !== 'undefined') {
            window.dispatchEvent(new CustomEvent('gs-request-notifications'));
        }
    }

    // ---- Live Location ----
    const watchIdRef = useRef(null);

    function startLiveLocation() {
        if (!navigator.geolocation) return;
        watchIdRef.current = navigator.geolocation.watchPosition(
            (pos) => {
                const locData = {
                    lat: pos.coords.latitude,
                    lng: pos.coords.longitude,
                    accuracy: pos.coords.accuracy,
                    city: null, // Reverse geocoded below
                    timestamp: Date.now(),
                };
                // Simple reverse geocoding via timezone & coords
                const cities = [
                    { name: 'Nairobi', lat: -1.2921, lng: 36.8219, r: 0.3 },
                    { name: 'Mombasa', lat: -4.0435, lng: 39.6682, r: 0.2 },
                    { name: 'Kisumu', lat: -0.0917, lng: 34.7680, r: 0.15 },
                    { name: 'Nakuru', lat: -0.3031, lng: 36.0800, r: 0.15 },
                    { name: 'Eldoret', lat: 0.5143, lng: 35.2698, r: 0.15 },
                    { name: 'Thika', lat: -1.0396, lng: 37.0900, r: 0.1 },
                    { name: 'Kampala', lat: 0.3476, lng: 32.5825, r: 0.3 },
                    { name: 'Dar es Salaam', lat: -6.7924, lng: 39.2083, r: 0.3 },
                ];
                for (const c of cities) {
                    const d = Math.sqrt((pos.coords.latitude - c.lat) ** 2 + (pos.coords.longitude - c.lng) ** 2);
                    if (d < c.r) { locData.city = c.name; break; }
                }
                if (!locData.city) locData.city = `${pos.coords.latitude.toFixed(2)}°, ${pos.coords.longitude.toFixed(2)}°`;
                setLiveLocationData(locData);
                setStored(STORAGE_KEYS.LIVE_LOCATION, locData);
                if (user?.id) {
                    const updatedUser = {
                        ...user,
                        latitude: pos.coords.latitude,
                        longitude: pos.coords.longitude,
                        geo_updated_at: new Date().toISOString(),
                        location: user.location || locData.city,
                        city: user.city || locData.city,
                    };
                    setUser(updatedUser);
                    setStored(STORAGE_KEYS.USER, updatedUser);
                    fetch('/api/location', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            userId: user.id,
                            latitude: pos.coords.latitude,
                            longitude: pos.coords.longitude,
                        }),
                    }).catch(() => {});
                }
            },
            () => { }, { enableHighAccuracy: true, maximumAge: 30000 }
        );
    }

    function stopLiveLocation() {
        if (watchIdRef.current !== null) {
            navigator.geolocation.clearWatch(watchIdRef.current);
            watchIdRef.current = null;
        }
        setLiveLocationData(null);
        setStored(STORAGE_KEYS.LIVE_LOCATION, null);
    }

    // Resume live location on mount if setting is on
    useEffect(() => {
        if (!loading && settings.liveLocation) startLiveLocation();
        return () => { if (watchIdRef.current) navigator.geolocation?.clearWatch(watchIdRef.current); };
    }, [loading, settings.liveLocation]);

    // ---- Preference ----
    function updatePreference(pref) {
        setPreference(pref);
        setStored(STORAGE_KEYS.PREFERENCE, pref);
        if (user) {
            const updated = { ...user, preference: pref };
            setUser(updated);
            setStored(STORAGE_KEYS.USER, updated);
        }
    }

    // ---- Subscription ----
    function toggleSubscription(value) {
        setSubscribed(value);
        setStored(STORAGE_KEYS.SUBSCRIBED, value);
    }

    // ---- Like/Match/Pass ----
    const addLike = useCallback(async (profile) => {
        if (user?.id) {
            const memberId = profile?.id || (String(profile?.wpId || '').startsWith('member:') ? String(profile.wpId).slice(7) : null);
            const payload = memberId
                ? { action: 'like', memberId, actorUserId: user.id, senderName: user.display_name || user.email, profileName: profile.name, profileImage: profile.imageUrl, score: profile.score }
                : { action: 'record_interaction', actorUserId: user.id, profileKey: profile.wpId, kind: 'like', profileName: profile.name, profileImage: profile.imageUrl, source: profile.source || 'wp', score: profile.score };
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) return { ok: false, error: data.error || 'Like limit reached.', redirectTo: data.redirectTo };
        }
        setLikes(prev => {
            if (prev.find(l => l.wpId === profile.wpId)) return prev;
            const updated = [...prev, { ...profile, likedAt: new Date().toISOString() }];
            setStored(STORAGE_KEYS.LIKES, updated);
            return updated;
        });
        logActivity('like', { title: `You liked ${profile.name || 'someone'}`, message: profile.location || '', image: profile.imageUrl, profileId: profile.wpId });
        return { ok: true };
    }, [logActivity, user?.id, user?.display_name, user?.email]);

    const addMatch = useCallback((profile, score = 85) => {
        setMatches(prev => {
            if (prev.find(m => m.wpId === profile.wpId)) return prev;
            const updated = [...prev, { ...profile, score, matchedAt: new Date().toISOString() }];
            setStored(STORAGE_KEYS.MATCHES, updated);
            return updated;
        });
        if (user?.id) {
            fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'record_interaction', actorUserId: user.id, profileKey: profile.wpId, kind: 'match', profileName: profile.name, profileImage: profile.imageUrl, source: profile.source || '', score }),
            }).catch(() => {});
        }
        logActivity('match', { title: `Matched with ${profile.name || 'someone'}!`, message: `${score}% compatibility`, image: profile.imageUrl, profileId: profile.wpId });
    }, [logActivity, user?.id]);

    const addPass = useCallback(async (profileWpId) => {
        const memberId = String(profileWpId || '').startsWith('member:') ? String(profileWpId).slice(7) : '';
        if (user?.id) {
            const payload = memberId
                ? { action: 'swipe_pass', memberId, actorUserId: user.id }
                : { action: 'record_interaction', actorUserId: user.id, profileKey: profileWpId, kind: 'pass', source: 'wp' };
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) return { ok: false, error: data.error || 'Swipe limit reached.', redirectTo: data.redirectTo };
        }
        setPasses(prev => {
            if (prev.includes(profileWpId)) return prev;
            const updated = [...prev, profileWpId];
            setStored(STORAGE_KEYS.PASSES, updated);
            return updated;
        });
        return { ok: true };
    }, [user?.id]);

    const isProfileSwiped = useCallback((wpId) => {
        return likes.some(l => l.wpId === wpId) || passes.includes(wpId);
    }, [likes, passes]);

    // ---- Save/Unsave ----
    const saveProfile = useCallback((profile) => {
        setSaved(prev => {
            if (prev.find(s => s.wpId === profile.wpId)) return prev;
            const updated = [...prev, { ...profile, savedAt: new Date().toISOString() }];
            setStored(STORAGE_KEYS.SAVED, updated);
            return updated;
        });
        if (user?.id) {
            const memberId = profile?.id || (String(profile?.wpId || '').startsWith('member:') ? String(profile.wpId).slice(7) : null);
            fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'save_profile', memberId, actorUserId: user.id, savedKey: profile.wpId || memberId, savedName: profile.name, savedImage: profile.imageUrl || profile.avatarUrl }),
            }).catch(() => {});
        }
        logActivity('save', { title: `Saved ${profile.name || 'a profile'}`, message: 'Added to your saved list', image: profile.imageUrl, profileId: profile.wpId });
    }, [logActivity, user?.id]);

    const unsaveProfile = useCallback((wpId) => {
        setSaved(prev => {
            const updated = prev.filter(s => s.wpId !== wpId);
            setStored(STORAGE_KEYS.SAVED, updated);
            return updated;
        });
        if (user?.id) {
            const memberId = String(wpId || '').startsWith('member:') ? String(wpId).slice(7) : null;
            fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'unsave_profile', memberId, actorUserId: user.id, savedKey: wpId || memberId }),
            }).catch(() => {});
        }
    }, [user?.id]);

    const isProfileSaved = useCallback((wpId) => saved.some(s => s.wpId === wpId), [saved]);

    // ---- Super Like ----
    const addSuperLike = useCallback(async (profile) => {
        if (user?.id) {
            const memberId = profile?.id || (String(profile?.wpId || '').startsWith('member:') ? String(profile.wpId).slice(7) : null);
            const payload = memberId
                ? { action: 'superlike', memberId, actorUserId: user.id, senderName: user.display_name || user.email, profileName: profile.name, profileImage: profile.imageUrl, score: profile.score }
                : { action: 'record_interaction', actorUserId: user.id, profileKey: profile.wpId, kind: 'superlike', profileName: profile.name, profileImage: profile.imageUrl, source: profile.source || 'wp', score: profile.score };
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) return { ok: false, error: data.error || 'Super like limit reached.', redirectTo: data.redirectTo };
        }
        setLikes(prev => {
            if (prev.find(l => l.wpId === profile.wpId)) return prev;
            const updated = [...prev, { ...profile, likedAt: new Date().toISOString(), super: true }];
            setStored(STORAGE_KEYS.LIKES, updated);
            return updated;
        });
        logActivity('like', { title: `You super liked ${profile.name || 'someone'}`, message: `${profile.location || ''} - Super Like!`, image: profile.imageUrl, profileId: profile.wpId });
        return { ok: true };
    }, [logActivity, user?.id, user?.display_name, user?.email]);

    // ---- Request Connection ----
    const requestConnection = useCallback((profileName, profileId) => {
        logActivity('connection_request', { title: `Connection requested with ${profileName}`, message: 'Admin Mary G will facilitate on Telegram', profileId });
        addMessage({ type: 'connection', sender: 'GS Support', senderImage: '', title: `Connection request sent for ${profileName}`, body: `Contact admin @GSADMINMARYGAGENCY on Telegram for faster response.` });
    }, [logActivity, addMessage]);

    // ---- Log Message/View ----
    const logMessageSent = useCallback((profileName, profileImage) => {
        logActivity('message', { title: `Message sent to ${profileName}`, message: 'Awaiting moderation', image: profileImage });
        addMessage({ type: 'comment_sent', sender: 'You', senderImage: '', title: `Comment on ${profileName}'s profile`, body: 'Your comment has been submitted and is awaiting admin approval.' });
    }, [logActivity, addMessage]);

    const logProfileView = useCallback((profile) => {
        logActivity('view', { title: `Viewed ${profile.name || 'a profile'}`, message: profile.location || '', image: profile.imageUrl, profileId: profile.wpId });
    }, [logActivity]);

    // ==========================================
    // POST SUBSCRIPTION CHECKER
    // ==========================================
    useEffect(() => {
        if (!subscribed || loading) return;

        const checkNewPosts = async () => {
            try {
                const res = await fetch('/api/profiles?page=1&per_page=5');
                const data = await res.json();
                if (data.profiles?.length) {
                    const latestId = data.profiles[0].wpId;
                    const lastKnown = getStored(STORAGE_KEYS.LAST_POST_ID);
                    if (lastKnown && latestId !== lastKnown) {
                        const newProfile = data.profiles[0];
                        setStored(STORAGE_KEYS.LAST_POST_ID, latestId);
                        logActivity('new_post', {
                            title: `New profile: ${newProfile.name || 'New Sugar Mummy'}`,
                            message: `${newProfile.location || 'Check it out'} — Just posted!`,
                            image: newProfile.imageUrl, profileId: newProfile.wpId,
                        });
                        addMessage({
                            type: 'subscription_update', sender: 'GS Updates', senderImage: '',
                            title: `📢 New Profile: ${newProfile.name}`,
                            body: `A new profile just dropped! ${newProfile.name} from ${newProfile.location || 'Kenya'}. Check it out now.`,
                            profileId: newProfile.wpId,
                        });
                    }
                }
            } catch { }
        };

        // Five minutes was already reasonable; the change is that it no longer
        // runs with the app in the background, and checks once on return.
        return startPolling(checkNewPosts, 5 * 60 * 1000);
    }, [subscribed, loading, logActivity, addMessage]);

    // ---- Clear Swipe History ----
    const clearSwipeHistory = useCallback(() => {
        setPasses([]); setStored(STORAGE_KEYS.PASSES, []);
    }, []);

    // ---- Delete Account ----
    function deleteAccount() {
        Object.values(STORAGE_KEYS).forEach(k => {
            if (typeof window !== 'undefined') localStorage.removeItem(k);
        });
        stopLiveLocation();
        setUser(null); setGuest(false); setLikes([]); setMatches([]);
        setPasses([]); setSaved([]); setActivity([]); setSettings(DEFAULT_SETTINGS);
        setMessages([]); setVerificationStatus(null); setVerificationTimer(null);
        setSubscribed(false); setLiveLocationData(null);
    }

    const value = {
        user, guest, loading, profile: user,
        likes, matches, saved, activity, settings,
        messages, verificationStatus, verificationTimer, realProfilePool,
        preference, subscribed, liveLocationData,
        signIn, signInExisting, signInWithGoogle, requestPasswordReset, resetPassword, signOut, skipLogin,
        updateProfile, addPhoto, removePhoto,
        updateSettings, updatePreference, toggleSubscription,
        addLike, addMatch, addPass, isProfileSwiped, addSuperLike, clearSwipeHistory,
        saveProfile, unsaveProfile, isProfileSaved,
        logActivity, logMessageSent, logProfileView, markActivityRead,
        requestConnection,
        addMessage, markMessagesRead,
        verifyProfile, clearVerification,
        deleteAccount,
        // Algorithm exports
        computeMatchScore, shouldMatchProfile,
    };

    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);








