'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { AnimatePresence, motion, useMotionValue, useTransform } from 'framer-motion';
import { Eye, Heart, MapPin, MessageCircle, Phone, RefreshCw, Sparkles, Star, X } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import { useAuth } from '@/contexts/AuthContext';

const CACHE_KEY = 'gscom_discover_deck_v3';
const DAILY_KEY = 'gscom_daily_limits';

function tier(user) {
    return String(user?.subscription_tier || user?.subscriptionTier || 'free').toLowerCase();
}

function packageAccess(user) {
    const active = Boolean(user?.admin_approved && !user?.package_locked);
    const current = tier(user);
    return {
        active,
        tier: current,
        canBrowseDetails: active && ['basic', 'silver', 'gold', 'diamond'].includes(current),
        canRevealPhone: active && ['silver', 'gold', 'diamond'].includes(current),
        swipeLimit: current === 'free' ? 3 : current === 'basic' ? 10 : current === 'silver' ? 40 : 100,
        likeLimit: current === 'free' ? 3 : current === 'basic' ? 10 : current === 'silver' ? 40 : 100,
        superLikeLimit: current === 'free' ? 1 : current === 'basic' ? 3 : current === 'silver' ? 10 : 25,
    };
}

function todayUsage() {
    if (typeof window === 'undefined') return { date: '', swipes: 0, likes: 0, superlikes: 0 };
    const today = new Date().toISOString().slice(0, 10);
    const saved = JSON.parse(localStorage.getItem(DAILY_KEY) || '{}');
    if (saved.date !== today) return { date: today, swipes: 0, likes: 0, superlikes: 0 };
    return { date: today, swipes: 0, likes: 0, superlikes: 0, ...saved };
}

function saveUsage(next) {
    localStorage.setItem(DAILY_KEY, JSON.stringify(next));
}

function formatLabel(value) {
    return String(value || 'Member').split('_').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
}

function compactText(member) {
    return [member.intentSummary, member.wants, member.neededQualities, member.excerpt].filter(Boolean)[0] || member.bio || 'Looking for a genuine, respectful connection.';
}

function userProfileLabel(user) {
    const label = String(user?.profile_label || user?.member_category || '').toLowerCase();
    if (['sugar_mummy', 'sugar_daddy', 'mistress', 'toyboy'].includes(label)) return label;
    const pref = String(user?.preference || '').toLowerCase();
    if (pref.includes('toyboy')) return 'toyboy';
    if (pref.includes('sugar_daddy')) return 'sugar_daddy';
    if (pref.includes('mistress')) return 'mistress';
    if (pref.includes('sugar_mummy')) return 'sugar_mummy';
    return 'sugar_mummy';
}

function targetLabelsForUser(user) {
    const label = userProfileLabel(user);
    if (label === 'toyboy') return new Set(['sugar_mummy']);
    if (label === 'mistress') return new Set(['sugar_daddy']);
    if (label === 'sugar_daddy') return new Set(['mistress']);
    return null;
}

function normalizeMember(member) {
    const label = member.profileLabel || member.memberCategory || 'member';
    return {
        ...member,
        id: member.id,
        source: 'member',
        swipeKey: `member:${member.id}`,
        detailPath: `/members/${member.id}`,
        avatarUrl: member.avatarUrl || member.photos?.[0] || '',
        profileLabel: label,
        sortDate: member.createdAt || member.lastSeenAt || '',
    };
}

function normalizeWpProfile(profile) {
    return {
        id: null,
        source: 'wp',
        wpId: profile.wpId,
        swipeKey: `wp:${profile.wpId}`,
        detailPath: `/discover/${profile.wpId}`,
        name: profile.name || 'Sugar Mummy',
        avatarUrl: profile.imageUrl || '',
        photos: profile.imageUrl ? [profile.imageUrl] : [],
        bio: profile.bio || profile.excerpt || '',
        excerpt: profile.excerpt || profile.bio || '',
        age: profile.age || null,
        location: profile.location || '',
        country: '',
        city: '',
        profileLabel: 'sugar_mummy',
        memberCategory: 'sugar_mummy',
        lookingFor: 'Sugar Guy / Toyboy',
        intentSummary: profile.excerpt || 'Sugar mummy profile from featured posts.',
        wants: '',
        neededQualities: '',
        ageRangePreference: '',
        interests: [],
        verified: false,
        phone: null,
        phoneMasked: null,
        phoneLocked: false,
        createdAt: profile.date || null,
        sortDate: profile.date || '',
    };
}

function profileFitsUser(member, user) {
    const targets = targetLabelsForUser(user);
    if (!targets) return true;
    return targets.has(String(member.profileLabel || member.memberCategory || '').toLowerCase());
}

function matchScore(member, user) {
    let score = 54;
    const userLocation = String(user?.location || '').toLowerCase();
    const memberLocation = String(member.location || member.country || '').toLowerCase();
    if (userLocation && memberLocation && (memberLocation.includes(userLocation) || userLocation.includes(memberLocation))) score += 18;
    if (member.verified) score += 8;
    if (member.intentSummary || member.wants || member.excerpt) score += 6;
    if (profileFitsUser(member, user)) score += 14;
    if (member.source === 'wp') score += 3;
    const seed = `${member.swipeKey}-${user?.email || ''}`;
    let hash = 0;
    for (let i = 0; i < seed.length; i++) hash = ((hash << 5) - hash + seed.charCodeAt(i)) | 0;
    score += Math.abs(hash) % 9;
    return Math.max(50, Math.min(98, score));
}

export default function DiscoverPage() {
    const router = useRouter();
    const { user, guest, addLike, addSuperLike, addMatch, addPass, isProfileSwiped, clearSwipeHistory, addMessage } = useAuth();
    const [members, setMembers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [direction, setDirection] = useState(null);
    const [notice, setNotice] = useState('');
    const fetched = useRef(false);
    const swiping = useRef(false);
    const access = packageAccess(user);

    const x = useMotionValue(0);
    const rotate = useTransform(x, [-200, 200], [-14, 14]);
    const likeOpacity = useTransform(x, [0, 100], [0, 1]);
    const nopeOpacity = useTransform(x, [-100, 0], [1, 0]);

    useEffect(() => {
        try {
            const cached = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null');
            if (cached?.members?.length) {
                setMembers(cached.members);
                setLoading(false);
            }
        } catch {}
    }, []);

    useEffect(() => {
        if (members.length) sessionStorage.setItem(CACHE_KEY, JSON.stringify({ members: members.slice(0, 360) }));
    }, [members]);

    useEffect(() => {
        if (fetched.current) return;
        fetched.current = true;
        async function loadDeck() {
            try {
                const memberParams = new URLSearchParams({ per_page: '240' });
                if (access.canRevealPhone && user?.id) memberParams.set('viewer_id', user.id);
                const [membersRes, wpRes] = await Promise.allSettled([
                    fetch(`/api/members?${memberParams.toString()}`),
                    fetch('/api/profiles?random=1&per_page=100'),
                ]);
                const memberData = membersRes.status === 'fulfilled' ? await membersRes.value.json().catch(() => ({})) : {};
                const wpData = wpRes.status === 'fulfilled' ? await wpRes.value.json().catch(() => ({})) : {};
                const memberDeck = (memberData.members || []).map(normalizeMember);
                const wpDeck = (wpData.profiles || []).filter((profile) => profile.imageUrl).map(normalizeWpProfile);
                const byKey = new Map();
                [...memberDeck, ...wpDeck].forEach((item) => {
                    if (item.swipeKey && !byKey.has(item.swipeKey)) byKey.set(item.swipeKey, { ...item, randomRank: Math.random() });
                });
                setMembers(Array.from(byKey.values()).sort((a, b) => a.randomRank - b.randomRank));
            } catch {
                setNotice('Profiles are temporarily unavailable.');
            } finally {
                setLoading(false);
            }
        }
        loadDeck();
    }, [access.canRevealPhone, user?.id]);

    const available = useMemo(() => {
        return members
            .filter((member) => member.swipeKey !== `member:${user?.id}`)
            .filter((member) => profileFitsUser(member, user))
            .filter((member) => !isProfileSwiped(member.swipeKey))
            .sort((a, b) => {
                const scoreGap = matchScore(b, user) - matchScore(a, user);
                if (Math.abs(scoreGap) > 18) return scoreGap;
                return (a.randomRank || 0) - (b.randomRank || 0);
            });
    }, [members, user, isProfileSwiped]);

    const current = available[0];

    function enforceLimit(kind) {
        const usage = todayUsage();
        const limit = kind === 'superlikes' ? access.superLikeLimit : kind === 'likes' ? access.likeLimit : access.swipeLimit;
        if ((usage[kind] || 0) >= limit) {
            setNotice(`${kind === 'superlikes' ? 'Super like' : kind === 'likes' ? 'Like' : 'Swipe'} limit reached for today. Upgrade your package to continue.`);
            return false;
        }
        const next = { ...usage, [kind]: (usage[kind] || 0) + 1 };
        saveUsage(next);
        return true;
    }

    function normalizedForAuth(member) {
        return {
            wpId: member.swipeKey,
            id: member.source === 'member' ? member.id : null,
            name: member.name,
            imageUrl: member.avatarUrl,
            location: member.location,
            age: member.age,
            excerpt: compactText(member),
            verified: member.verified,
            date: member.createdAt,
            score: matchScore(member, user),
            source: member.source,
        };
    }

    function finishSwipe() {
        window.setTimeout(() => {
            x.set(0);
            setDirection(null);
            swiping.current = false;
        }, 240);
    }

    function beginSwipe(nextDirection) {
        if (!current || swiping.current) return false;
        if (guest || !user) { router.push('/auth/login'); return false; }
        swiping.current = true;
        setNotice('');
        setDirection(nextDirection);
        return true;
    }

    function handleLike() {
        if (!beginSwipe('right')) return;
        if (!enforceLimit('likes')) { swiping.current = false; setDirection(null); return; }
        const profile = normalizedForAuth(current);
        addLike(profile);
        const score = matchScore(current, user);
        if (score >= 93) addMatch(profile, score);
        addMessage?.({ type: 'like', sender: 'You', title: `You liked ${current.name}`, body: `${score}% compatibility. Keep interacting to turn this into a stronger match.`, memberId: current.id, senderImage: current.avatarUrl });
        finishSwipe();
    }

    function handleSuperLike() {
        if (!beginSwipe('right')) return;
        if (!enforceLimit('superlikes')) { swiping.current = false; setDirection(null); return; }
        const profile = normalizedForAuth(current);
        addSuperLike(profile);
        const score = Math.min(99, matchScore(current, user) + 5);
        if (score >= 88) addMatch(profile, score);
        addMessage?.({ type: 'superlike', sender: 'You', title: `You super liked ${current.name}`, body: `${score}% compatibility. This profile was added to your priority interactions.`, memberId: current.id, senderImage: current.avatarUrl });
        finishSwipe();
    }

    function handlePass() {
        if (!beginSwipe('left')) return;
        if (!enforceLimit('swipes')) { swiping.current = false; setDirection(null); return; }
        addPass(current.swipeKey);
        finishSwipe();
    }

    function handleView() {
        if (!current) return;
        if (!access.canBrowseDetails) { router.push('/packages'); return; }
        router.push(current.detailPath);
    }

    function handleRefresh() {
        clearSwipeHistory();
        sessionStorage.removeItem(CACHE_KEY);
        setNotice('Swipe history cleared.');
    }

    if (loading) return <div className="px-4 py-14 text-center text-primary font-black">Loading members...</div>;

    if (!current) {
        return <div className="px-4 py-12 text-center space-y-4"><div className="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center"><Sparkles size={30} className="text-primary" /></div><h2 className="text-xl font-black text-text-primary">No More Profiles</h2><p className="text-sm text-text-muted">Refresh to review profiles again.</p><button onClick={handleRefresh} className="mx-auto px-5 py-3 rounded-2xl font-black text-white gradient-primary flex items-center gap-2"><RefreshCw size={17} /> Refresh</button></div>;
    }

    const score = matchScore(current, user);

    return (
        <div className="px-4 py-4 pb-28 space-y-4">
            {notice && <div className="rounded-2xl p-3 text-xs font-bold text-primary bg-primary/10">{notice}</div>}
            <div className="relative w-full max-w-sm mx-auto" style={{ aspectRatio: '3/4' }}>
                <AnimatePresence mode="wait">
                    <motion.article key={current.swipeKey} className="absolute inset-0 rounded-[22px] overflow-hidden card-shadow bg-white touch-pan-y" style={{ x, rotate }} drag="x" dragConstraints={{ left: 0, right: 0 }} dragElastic={0.45} onDragEnd={(_, info) => { if (info.offset.x > 90) handleLike(); else if (info.offset.x < -90) handlePass(); else x.set(0); }} initial={{ scale: 0.96, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ x: direction === 'right' ? 260 : direction === 'left' ? -260 : 0, opacity: 0, transition: { duration: 0.22 } }}>
                        {current.avatarUrl ? <img src={current.avatarUrl} alt={current.name} className="absolute inset-0 w-full h-full object-cover" /> : <div className="absolute inset-0 flex items-center justify-center bg-primary/10"><UserAvatar name={current.name} size={120} /></div>}
                        <div className="absolute inset-0 bg-gradient-to-t from-black/86 via-black/20 to-transparent" />
                        <motion.div className="absolute top-7 left-5 px-4 py-2 rounded-xl border-4 border-success text-success font-black text-2xl -rotate-12 bg-white/80" style={{ opacity: likeOpacity }}>LIKE</motion.div>
                        <motion.div className="absolute top-7 right-5 px-4 py-2 rounded-xl border-4 border-danger text-danger font-black text-2xl rotate-12 bg-white/80" style={{ opacity: nopeOpacity }}>PASS</motion.div>
                        <div className="absolute bottom-0 left-0 right-0 p-4 text-white space-y-2">
                            <div className="flex items-center gap-2"><h2 className="text-2xl font-black truncate">{current.name}</h2>{current.age && <span className="text-lg opacity-85">{current.age}</span>}<VerifiedBadge verified={current.verified} size={19} /></div>
                            <div className="flex flex-wrap gap-2 text-xs"><span className="px-2 py-1 rounded-full bg-white/18 font-bold">{formatLabel(current.profileLabel)}</span><span className="px-2 py-1 rounded-full bg-white/18 font-bold">{score}% match</span>{current.source === 'wp' && <span className="px-2 py-1 rounded-full bg-white/18 font-bold">Featured</span>}</div>
                            {current.location && <p className="flex items-center gap-1 text-xs opacity-90"><MapPin size={13} /> {current.location}</p>}
                            <p className="text-sm leading-snug line-clamp-2 opacity-95">{compactText(current)}</p>
                            <div className="grid grid-cols-2 gap-2 text-[11px]">
                                {current.ageRangePreference && <p><b>Age:</b> {current.ageRangePreference}</p>}
                                {current.neededQualities && <p className="truncate"><b>Qualities:</b> {current.neededQualities}</p>}
                                {current.interests?.[0] && <p className="truncate"><b>Interest:</b> {current.interests[0]}</p>}
                                <p className="flex items-center gap-1 truncate"><Phone size={11} /> <span className={access.canRevealPhone ? '' : 'blur-[2px] select-none'}>{access.canRevealPhone ? (current.phone || current.phoneMasked || 'Hidden') : (current.phoneMasked || 'Hidden')}</span></p>
                            </div>
                        </div>
                    </motion.article>
                </AnimatePresence>
            </div>

            <div className="grid grid-cols-5 gap-3 max-w-sm mx-auto">
                <button onClick={handlePass} className="h-12 rounded-2xl bg-danger/10 text-danger flex items-center justify-center"><X size={24} /></button>
                <button onClick={handleView} className="h-12 rounded-2xl bg-primary/10 text-primary flex items-center justify-center"><Eye size={20} /></button>
                <button onClick={handleSuperLike} className="h-12 rounded-2xl bg-amber-100 text-gold flex items-center justify-center"><Star size={20} fill="currentColor" /></button>
                <Link href={access.canBrowseDetails ? current.detailPath : '/packages'} className="h-12 rounded-2xl bg-sky-100 text-sky-700 flex items-center justify-center"><MessageCircle size={20} /></Link>
                <button onClick={handleLike} className="h-12 rounded-2xl gradient-primary text-white flex items-center justify-center"><Heart size={23} fill="white" /></button>
            </div>

            <div className="text-center text-xs text-text-muted">{available.length} compatible profiles left today</div>
        </div>
    );
}

