'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { AnimatePresence, motion, useMotionValue, useTransform } from 'framer-motion';
import { Eye, Heart, LocateFixed, MapPin, MessageCircle, Phone, Radio, RefreshCw, Sparkles, Star, X } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import BoostedMembersStrip from '@/components/BoostedMembersStrip';
import StoriesStrip from '@/components/StoriesStrip';
import { useAuth } from '@/contexts/AuthContext';
import { startPolling, POLL } from '@/lib/poll';

const CACHE_KEY = 'gscom_discover_deck_v3';
const CACHE_LIMIT = 80;

function tier(user) {
    return String(user?.subscription_tier || user?.subscriptionTier || 'free').toLowerCase();
}

function packageAccess(user) {
    const active = Boolean(user?.admin_approved && !user?.package_locked);
    const current = tier(user);
    return {
        active,
        tier: current,
        canBrowseDetails: true,
        canRevealPhone: active && ['silver', 'gold', 'diamond'].includes(current),
        swipeLimit: !active || current === 'free' ? 10 : current === 'basic' ? 30 : 999999,
        likeLimit: !active || current === 'free' ? 5 : current === 'basic' ? 10 : current === 'silver' ? 50 : 999999,
        superLikeLimit: !active || current === 'free' ? 0 : current === 'basic' ? 5 : current === 'silver' ? 100 : 999999,
    };
}

function formatLabel(value) {
    return String(value || 'Member').split('_').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
}

function compactText(member) {
    return [member.intentSummary, member.wants, member.neededQualities, member.excerpt].filter(Boolean)[0] || member.bio || 'Looking for a genuine, respectful connection.';
}

function presenceTone(member) {
    if (member.isOnline) return 'bg-success';
    const seen = member.lastSeenAt ? Date.now() - new Date(member.lastSeenAt).getTime() : Infinity;
    if (seen < 24 * 60 * 60 * 1000) return 'bg-amber-400';
    return 'bg-gray-300';
}

function distanceKm(a, b) {
    if (!a || !b) return null;
    const lat1 = Number(a.latitude);
    const lon1 = Number(a.longitude);
    const lat2 = Number(b.latitude);
    const lon2 = Number(b.longitude);
    if (![lat1, lon1, lat2, lon2].every(Number.isFinite)) return null;
    const toRad = (value) => value * Math.PI / 180;
    const radius = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const s1 = Math.sin(dLat / 2) ** 2;
    const s2 = Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return Math.round(radius * 2 * Math.atan2(Math.sqrt(s1 + s2), Math.sqrt(1 - s1 - s2)));
}

function locationLabelFromCoords(latitude, longitude) {
    const places = [
        { name: 'Nairobi', lat: -1.2921, lng: 36.8219, r: 0.3 },
        { name: 'Mombasa', lat: -4.0435, lng: 39.6682, r: 0.22 },
        { name: 'Kisumu', lat: -0.0917, lng: 34.7680, r: 0.18 },
        { name: 'Nakuru', lat: -0.3031, lng: 36.0800, r: 0.18 },
        { name: 'Eldoret', lat: 0.5143, lng: 35.2698, r: 0.18 },
        { name: 'Thika', lat: -1.0396, lng: 37.0900, r: 0.12 },
        { name: 'Kampala', lat: 0.3476, lng: 32.5825, r: 0.3 },
        { name: 'Dar es Salaam', lat: -6.7924, lng: 39.2083, r: 0.3 },
    ];
    const match = places.find((place) => Math.sqrt((latitude - place.lat) ** 2 + (longitude - place.lng) ** 2) < place.r);
    return match?.name || `${latitude.toFixed(2)}, ${longitude.toFixed(2)}`;
}

function liveDuration(startedAt) {
    const started = startedAt ? new Date(startedAt).getTime() : 0;
    if (!started || Number.isNaN(started)) return '0:00';
    const seconds = Math.max(0, Math.floor((Date.now() - started) / 1000));
    const mins = Math.floor(seconds / 60);
    return `${mins}:${String(seconds % 60).padStart(2, '0')}`;
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

function memberPath(member) {
    return member?.id ? '/members/' + member.id : '/members';
}

function normalizeMember(member) {
    const label = member.profileLabel || member.memberCategory || 'member';
    return {
        ...member,
        id: member.id,
        source: 'member',
        swipeKey: `member:${member.id}`,
        detailPath: member.id ? `/members/${member.id}` : '/members',
        avatarUrl: member.avatarUrl || member.photos?.[0] || '',
        profileLabel: label,
        sortDate: member.createdAt || member.lastSeenAt || '',
        latitude: member.latitude || member.lat || null,
        longitude: member.longitude || member.lng || null,
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
        lastSeenAt: profile.date || '',
        latitude: profile.coords?.latitude || null,
        longitude: profile.coords?.longitude || null,
    };
}

function compactCachedMember(member) {
    return {
        id: member.id,
        source: member.source,
        wpId: member.wpId,
        swipeKey: member.swipeKey,
        detailPath: member.detailPath,
        name: member.name,
        avatarUrl: member.avatarUrl,
        bio: member.bio,
        excerpt: member.excerpt,
        age: member.age,
        location: member.location,
        country: member.country,
        city: member.city,
        profileLabel: member.profileLabel,
        memberCategory: member.memberCategory,
        lookingFor: member.lookingFor,
        intentSummary: member.intentSummary,
        wants: member.wants,
        neededQualities: member.neededQualities,
        ageRangePreference: member.ageRangePreference,
        interests: Array.isArray(member.interests) ? member.interests.slice(0, 5) : [],
        verified: member.verified,
        phone: member.phone,
        phoneMasked: member.phoneMasked,
        phoneLocked: member.phoneLocked,
        createdAt: member.createdAt,
        sortDate: member.sortDate,
        lastSeenAt: member.lastSeenAt,
        latitude: member.latitude,
        longitude: member.longitude,
        randomRank: member.randomRank,
        isOnline: member.isOnline,
        isBoosted: member.isBoosted,
        boostExpiresAt: member.boostExpiresAt,
        boostScore: member.boostScore,
    };
}

function writeDeckCache(members) {
    if (typeof sessionStorage === 'undefined' || !members.length) return;
    try {
        const compactMembers = members.slice(0, CACHE_LIMIT).map(compactCachedMember);
        sessionStorage.setItem(CACHE_KEY, JSON.stringify({ members: compactMembers }));
    } catch {
        try { sessionStorage.removeItem(CACHE_KEY); } catch {}
    }
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
    if (member.isBoosted) score += 22;
    if (member.intentSummary || member.wants || member.excerpt) score += 6;
    if (profileFitsUser(member, user)) score += 14;
    if (member.source === 'wp') score += 3;
    const seed = `${member.swipeKey}-${user?.email || ''}`;
    let hash = 0;
    for (let i = 0; i < seed.length; i++) hash = ((hash << 5) - hash + seed.charCodeAt(i)) | 0;
    score += Math.abs(hash) % 9;
    return Math.max(50, Math.min(98, score));
}

function fallbackAvatarSrc(name = 'Member') {
    const initials = String(name || 'Member').trim().split(/\s+/).slice(0, 2).map((part) => part[0] || '').join('').toUpperCase() || 'GS';
    const svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="520" viewBox="0 0 400 520">',
        '<defs><linearGradient id="g" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#f97316"/><stop offset="1" stop-color="#14b8a6"/></linearGradient></defs>',
        '<rect width="400" height="520" fill="url(#g)"/>',
        '<circle cx="200" cy="190" r="86" fill="rgba(255,255,255,.28)"/>',
        '<text x="200" y="210" text-anchor="middle" font-family="Arial,sans-serif" font-size="78" font-weight="900" fill="white">' + initials + '</text>',
        '<text x="200" y="330" text-anchor="middle" font-family="Arial,sans-serif" font-size="24" font-weight="700" fill="rgba(255,255,255,.86)">Genuine profile</text>',
        '</svg>',
    ].join('');
    return 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg);
}

function useFallbackAvatar(event, name) {
    event.currentTarget.onerror = null;
    event.currentTarget.src = fallbackAvatarSrc(name);
}

export default function DiscoverPage() {
    const router = useRouter();
    const { user, guest, addLike, addSuperLike, addMatch, addPass, isProfileSwiped, clearSwipeHistory, addMessage, updateProfile, updateSettings } = useAuth();
    const [members, setMembers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [direction, setDirection] = useState(null);
    const [notice, setNotice] = useState('');
    const [liveStreams, setLiveStreams] = useState([]);
    const [geo, setGeo] = useState(null);
    const [filter, setFilter] = useState('all');
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
                fetched.current = true;
                setMembers(cached.members);
                setLoading(false);
            }
        } catch {}
    }, []);

    useEffect(() => {
        writeDeckCache(members);
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
                    if (item.swipeKey && !byKey.has(item.swipeKey)) {
                        let hash = 0;
                        const seed = `${item.swipeKey}-${user?.id || user?.email || 'guest'}`;
                        for (let i = 0; i < seed.length; i++) hash = ((hash << 5) - hash + seed.charCodeAt(i)) | 0;
                        byKey.set(item.swipeKey, { ...item, randomRank: Math.abs(hash % 10000) / 10000 });
                    }
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

    useEffect(() => {
        async function loadLiveStreams() {
            try {
                const res = await fetch('/api/live');
                const data = await res.json().catch(() => ({}));
                if (res.ok) setLiveStreams(data.streams || []);
            } catch {}
        }
        loadLiveStreams();
        const stop = startPolling(loadLiveStreams, POLL.LIVE);
        return () => stop();
    }, []);

    async function requestNearby() {
        if (!user?.id) { router.push('/auth/login'); return; }
        if (!navigator.geolocation) {
            setNotice('Location is not supported on this device.');
            return;
        }
        if (navigator.permissions?.query) {
            try {
                const permission = await navigator.permissions.query({ name: 'geolocation' });
                if (permission.state === 'denied') {
                    setNotice('Location is blocked for this browser. Open site settings, allow Location, then tap Use Location again.');
                    return;
                }
            } catch {}
        }
        setNotice('Requesting your device location...');
        navigator.geolocation.getCurrentPosition(async (position) => {
            const next = {
                latitude: position.coords.latitude,
                longitude: position.coords.longitude,
                geo_updated_at: new Date().toISOString(),
            };
            const label = locationLabelFromCoords(next.latitude, next.longitude);
            setGeo(next);
            setFilter('nearby');
            updateProfile?.({
                ...next,
                location: user.location || label,
                city: user.city || label,
            });
            updateSettings?.({ locationEnabled: true, liveLocation: true });
            setNotice(`Nearby matching is on from this device: ${label}.`);
            try {
                const res = await fetch('/api/location', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ userId: user.id, ...next }),
                });
                const data = await res.json().catch(() => ({}));
                if (!res.ok) setNotice(data.error || 'Location was found but could not be saved. Try again.');
            } catch {}
        }, (error) => {
            if (error?.code === error.PERMISSION_DENIED) setNotice('Location permission was denied. Allow Location for this site in your browser settings, then tap Use Location again.');
            else if (error?.code === error.TIMEOUT) setNotice('Location timed out. Turn on GPS/location services and try again.');
            else setNotice('Could not read this device location. Check location services and try again.');
        }, { enableHighAccuracy: true, maximumAge: 5 * 60 * 1000, timeout: 15000 });
    }

    const available = useMemo(() => {
        return members
            .filter((member) => member.swipeKey !== `member:${user?.id}`)
            .filter((member) => profileFitsUser(member, user))
            .filter((member) => {
                if (filter === 'online') return member.isOnline || (member.lastSeenAt && Date.now() - new Date(member.lastSeenAt).getTime() < 5 * 60 * 1000);
                if (filter === 'nearby') {
                    const memberDistance = distanceKm(geo || user, member);
                    if (memberDistance !== null) return memberDistance <= 100;
                    const userLocation = String(user?.location || '').toLowerCase();
                    const memberLocation = String(member.location || member.city || member.country || '').toLowerCase();
                    return Boolean(userLocation && memberLocation && (memberLocation.includes(userLocation) || userLocation.includes(memberLocation)));
                }
                return true;
            })
            .filter((member) => !isProfileSwiped(member.swipeKey))
            .sort((a, b) => {
                if (filter === 'nearby') {
                    const aDistance = distanceKm(geo || user, a);
                    const bDistance = distanceKm(geo || user, b);
                    if (aDistance !== null && bDistance !== null && aDistance !== bDistance) return aDistance - bDistance;
                }
                const scoreGap = matchScore(b, user) - matchScore(a, user);
                if (Math.abs(scoreGap) > 18) return scoreGap;
                return (a.randomRank || 0) - (b.randomRank || 0);
            });
    }, [members, user, isProfileSwiped, filter, geo]);

    const current = available[0];

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

    async function handleLike() {
        if (!beginSwipe('right')) return;
        const profile = normalizedForAuth(current);
        const result = await addLike(profile);
        if (result && !result.ok) {
            setNotice(result.error || 'Your daily quota has exhausted. Pay for a package to unlock unlimited access.');
            swiping.current = false;
            setDirection(null);
            if (result.redirectTo) window.setTimeout(() => router.push(result.redirectTo), 900);
            return;
        }
        const score = matchScore(current, user);
        if (score >= 93) addMatch(profile, score);
        addMessage?.({ type: 'like', sender: 'You', title: `You liked ${current.name}`, body: `${score}% compatibility. Keep interacting to turn this into a stronger match.`, memberId: current.id, senderImage: current.avatarUrl });
        finishSwipe();
    }

    async function handleSuperLike() {
        if (!beginSwipe('right')) return;
        const profile = normalizedForAuth(current);
        const result = await addSuperLike(profile);
        if (result && !result.ok) {
            setNotice(result.error || 'Your daily quota has exhausted. Pay for a package to unlock unlimited access.');
            swiping.current = false;
            setDirection(null);
            if (result.redirectTo) window.setTimeout(() => router.push(result.redirectTo), 900);
            return;
        }
        const score = Math.min(99, matchScore(current, user) + 5);
        if (score >= 88) addMatch(profile, score);
        addMessage?.({ type: 'superlike', sender: 'You', title: `You super liked ${current.name}`, body: `${score}% compatibility. This profile was added to your priority interactions.`, memberId: current.id, senderImage: current.avatarUrl });
        finishSwipe();
    }

    async function handlePass() {
        if (!beginSwipe('left')) return;
        const result = await addPass(current.swipeKey);
        if (result && !result.ok) {
            setNotice(result.error || 'Your daily quota has exhausted. Pay for a package to unlock unlimited access.');
            swiping.current = false;
            setDirection(null);
            if (result.redirectTo) window.setTimeout(() => router.push(result.redirectTo), 900);
            return;
        }
        finishSwipe();
    }

    async function handleView() {
        if (!current) return;
        if (guest || !user) { router.push('/auth/login'); return; }
        const res = await fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'record_interaction', actorUserId: user.id, profileKey: current.swipeKey, kind: 'view', profileName: current.name, profileImage: current.avatarUrl, source: current.source }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            setNotice(data.error || 'Your daily quota has exhausted. Pay for a package to unlock unlimited access.');
            window.setTimeout(() => router.push(data.redirectTo || '/packages'), 900);
            return;
        }
        router.push(current.detailPath);
    }

    async function handleMessage() {
        if (!current) return;
        if (!access.active) {
            setNotice('Messaging is a premium feature. Pay for a package to unlock real conversations.');
            window.setTimeout(() => router.push('/packages'), 900);
            return;
        }
        await handleView();
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
            <StoriesStrip title="Discover Stories" />
            {liveStreams.length > 0 && <section className="rounded-2xl p-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <div className="mb-2 flex items-center justify-between gap-2">
                    <h2 className="text-sm font-black text-text-primary flex items-center gap-1"><Radio size={15} className="text-danger" /> Featured Live Now</h2>
                    <Link href="/live" className="text-[11px] font-black text-primary">Open</Link>
                </div>
                <div className="flex gap-2 overflow-x-auto pb-1">
                    {liveStreams.slice(0, 8).map((stream) => {
                        const host = stream.host || {};
                        const photo = host.avatar_url || host.photos?.[0] || '';
                        return <Link key={stream.id} href={`/live/${stream.id}`} className="min-w-40 rounded-2xl p-2 text-white bg-gray-900">
                            <div className="relative h-24 rounded-xl overflow-hidden bg-primary/20">{photo ? <img src={photo} alt="" className="h-full w-full object-cover" onError={(event) => useFallbackAvatar(event, host.display_name || 'Live')} /> : <UserAvatar name={host.display_name || 'Live'} size={52} />}<span className="absolute left-2 top-2 rounded-full bg-danger px-2 py-0.5 text-[9px] font-black">LIVE</span></div>
                            <p className="mt-2 truncate text-[11px] font-black">{stream.title || 'GS Live'}</p>
                            <p className="text-[10px] text-white/70">{stream.viewer_count || 0} watching � {liveDuration(stream.started_at)}</p>
                            <p className="text-[10px] text-white/70">{stream.total_views || 0} views � {stream.total_likes || 0} likes � {stream.total_gifts || 0} gifts</p>
                        </Link>;
                    })}
                </div>
            </section>}
            <BoostedMembersStrip title="Boosted In Discover" />
            <section className="flex items-center gap-2 overflow-x-auto">
                {[
                    ['all', 'All'],
                    ['online', 'Online'],
                    ['nearby', 'Nearby'],
                ].map(([id, label]) => (
                    <button key={id} onClick={() => id === 'nearby' && !geo ? requestNearby() : setFilter(id)} className={`shrink-0 rounded-2xl px-4 py-2 text-xs font-black ${filter === id ? 'gradient-primary text-white' : 'bg-surface text-text-secondary'}`}>
                        {label}
                    </button>
                ))}
                <button onClick={requestNearby} className="shrink-0 rounded-2xl bg-primary/10 px-4 py-2 text-xs font-black text-primary inline-flex items-center gap-1">
                    <LocateFixed size={13} /> Use Location
                </button>
            </section>
            <div className="relative w-full max-w-sm mx-auto" style={{ aspectRatio: '3/4' }}>
                <AnimatePresence mode="wait">
                    <motion.article key={current.swipeKey} className="absolute inset-0 rounded-[22px] overflow-hidden card-shadow bg-bg-card touch-pan-y" style={{ x, rotate }} drag="x" dragConstraints={{ left: 0, right: 0 }} dragElastic={0.32} onDragEnd={(_, info) => { if (Math.abs(info.offset.x) < 140) { x.set(0); return; } if (info.offset.x > 0) handleLike(); else handlePass(); }} initial={{ scale: 0.96, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ x: direction === 'right' ? 260 : direction === 'left' ? -260 : 0, opacity: 0, transition: { duration: 0.22 } }}>
                        {current.avatarUrl ? <img src={current.avatarUrl} alt={current.name} className="absolute inset-0 w-full h-full object-cover" onError={(event) => useFallbackAvatar(event, current.name)} /> : <div className="absolute inset-0 flex items-center justify-center bg-primary/10"><UserAvatar name={current.name} size={120} /></div>}
                        <div className="absolute inset-0 bg-gradient-to-t from-black/86 via-black/20 to-transparent" />
                        <motion.div className="absolute top-7 left-5 px-4 py-2 rounded-xl border-4 border-success text-success font-black text-2xl -rotate-12 bg-white/80" style={{ opacity: likeOpacity }}>LIKE</motion.div>
                        <motion.div className="absolute top-7 right-5 px-4 py-2 rounded-xl border-4 border-danger text-danger font-black text-2xl rotate-12 bg-white/80" style={{ opacity: nopeOpacity }}>PASS</motion.div>
                        <div className="absolute bottom-0 left-0 right-0 p-4 text-white space-y-2">
                            <div className="flex items-center gap-2"><h2 className="text-2xl font-black truncate">{current.name}</h2>{current.age && <span className="text-lg opacity-85">{current.age}</span>}<VerifiedBadge verified={current.verified} size={19} /></div>
                            <div className="flex flex-wrap items-center gap-2 text-xs"><span className={`w-3 h-3 rounded-full ring-2 ring-white/70 ${presenceTone(current)}`} /><span className="px-2 py-1 rounded-full bg-white/18 font-bold">{formatLabel(current.profileLabel)}</span><span className="px-2 py-1 rounded-full bg-white/18 font-bold">{score}% match</span>{current.source === 'wp' && <span className="px-2 py-1 rounded-full bg-white/18 font-bold">Featured</span>}</div>
                            {current.location && <p className="flex items-center gap-1 text-xs opacity-90"><MapPin size={13} /> {current.location}</p>}
                            {distanceKm(geo || user, current) !== null && <p className="flex items-center gap-1 text-xs opacity-90"><LocateFixed size={13} /> {distanceKm(geo || user, current)} km away</p>}
                            <p className="text-sm leading-snug line-clamp-2 opacity-95">{compactText(current)}</p>
                            <div className="grid grid-cols-2 gap-2 text-[11px]">
                                {current.ageRangePreference && <p><b>Age:</b> {current.ageRangePreference}</p>}
                                {current.neededQualities && <p className="truncate"><b>Qualities:</b> {current.neededQualities}</p>}
                                {current.interests?.[0] && <p className="truncate"><b>Interest:</b> {current.interests[0]}</p>}
                                <p className="flex items-center gap-1 truncate"><Phone size={11} /> <span className="font-bold tracking-wide">{access.canRevealPhone ? (current.phone || current.phoneMasked || 'Hidden') : (current.phoneMasked || 'Hidden')}</span></p>
                            </div>
                        </div>
                    </motion.article>
                </AnimatePresence>
            </div>

            <div className="grid grid-cols-5 gap-3 max-w-sm mx-auto">
                <button onClick={handlePass} className="h-12 rounded-2xl bg-danger/10 text-danger flex items-center justify-center"><X size={24} /></button>
                <button onClick={handleView} className="h-12 rounded-2xl bg-primary/10 text-primary flex items-center justify-center"><Eye size={20} /></button>
                <button onClick={handleSuperLike} className="h-12 rounded-2xl bg-amber-100 text-gold flex items-center justify-center"><Star size={20} fill="currentColor" /></button>
                <button onClick={handleMessage} className="h-12 rounded-2xl bg-sky-100 text-sky-700 flex items-center justify-center"><MessageCircle size={20} /></button>
                <button onClick={handleLike} className="h-12 rounded-2xl gradient-primary text-white flex items-center justify-center"><Heart size={23} fill="white" /></button>
            </div>

            <div className="text-center text-xs text-text-muted">{available.length} compatible profiles left today</div>
        </div>
    );
}

