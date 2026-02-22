'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence, useMotionValue, useTransform } from 'framer-motion';
import { Heart, X, Star, MapPin, RefreshCw, Sparkles, ChevronDown } from 'lucide-react';
import BlurImage from '@/components/BlurImage';
import SkeletonCard from '@/components/SkeletonCard';
import EmailSubscribe from '@/components/EmailSubscribe';
import VerifiedBadge from '@/components/VerifiedBadge';
import { useAuth } from '@/contexts/AuthContext';

const CACHE_KEY = 'gscom_discover_cache_v2';

export default function DiscoverPage() {
    const router = useRouter();
    const { user, guest, addLike, addMatch, addPass, isProfileSwiped, clearSwipeHistory, computeMatchScore, shouldMatchProfile, settings } = useAuth();
    const [profiles, setProfiles] = useState([]);
    const [currentIndex, setCurrentIndex] = useState(0);
    const [page, setPage] = useState(1);
    const [loading, setLoading] = useState(true);
    const [hasMore, setHasMore] = useState(true);
    const [direction, setDirection] = useState(null);
    const [showSubscribe, setShowSubscribe] = useState(false);
    const fetchedPages = useRef(new Set());

    // Load cached profiles (only if they have valid data)
    useEffect(() => {
        try {
            const cached = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null');
            // Validate cache: only use if profiles have imageUrl and name set
            const valid = cached?.profiles?.length &&
                cached.profiles.some(p => p.imageUrl && p.name && p.name !== 'undefined');
            if (valid) {
                setProfiles(cached.profiles);
                setCurrentIndex(cached.currentIndex || 0);
                setPage(cached.page || 1);
                setLoading(false);
            }
        } catch { }
    }, []);

    // Save to cache
    useEffect(() => {
        if (profiles.length > 0) {
            try {
                sessionStorage.setItem(CACHE_KEY, JSON.stringify({ profiles: profiles.slice(0, 50), currentIndex, page }));
            } catch { }
        }
    }, [profiles, currentIndex, page]);

    // Fetch profiles
    const fetchProfiles = useCallback(async (pageNum = 1) => {
        if (fetchedPages.current.has(pageNum)) return;
        fetchedPages.current.add(pageNum);

        try {
            const res = await fetch(`/api/profiles?page=${pageNum}&per_page=25`);
            const data = await res.json();

            if (data.profiles?.length) {
                setProfiles(prev => {
                    const existingIds = new Set(prev.map(p => p.wpId));
                    const newProfiles = data.profiles.filter(p => !existingIds.has(p.wpId));
                    return [...prev, ...newProfiles];
                });
                setHasMore(data.profiles.length >= 20);
            } else {
                setHasMore(false);
            }
        } catch (err) {
            console.error('Failed to fetch profiles:', err);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => { fetchProfiles(1); }, [fetchProfiles]);

    // Auto-load next page
    useEffect(() => {
        if (profiles.length > 0 && currentIndex >= profiles.length - 5 && hasMore) {
            const nextPage = page + 1;
            setPage(nextPage);
            fetchProfiles(nextPage);
        }
    }, [currentIndex, profiles.length, hasMore, page, fetchProfiles]);

    // Show subscribe after 3 swipes
    useEffect(() => {
        if (currentIndex === 3 && !showSubscribe) {
            setShowSubscribe(true);
        }
    }, [currentIndex, showSubscribe]);

    // Filter already-swiped
    const availableProfiles = profiles.filter(p => !isProfileSwiped(p.wpId));
    const currentProfile = availableProfiles[0];

    const handleLike = () => {
        if (!currentProfile) return;
        if (guest || !user) { router.push('/auth/login'); return; }
        setDirection('right');
        addLike(currentProfile);

        // Smart matching algorithm
        if (shouldMatchProfile(currentProfile, user, settings)) {
            const score = computeMatchScore(currentProfile, user, settings);
            addMatch(currentProfile, score);
        }

        setTimeout(() => {
            setCurrentIndex(prev => prev + 1);
            setDirection(null);
        }, 300);
    };

    const handlePass = () => {
        if (!currentProfile) return;
        if (guest || !user) { router.push('/auth/login'); return; }
        setDirection('left');
        addPass(currentProfile.wpId);
        setTimeout(() => {
            setCurrentIndex(prev => prev + 1);
            setDirection(null);
        }, 300);
    };

    const handleRefresh = () => {
        clearSwipeHistory();
        setCurrentIndex(0);
        sessionStorage.removeItem(CACHE_KEY);
    };

    const handleViewProfile = (id) => {
        router.push(`/discover/${id}`);
    };

    // Swipe gesture
    const x = useMotionValue(0);
    const rotate = useTransform(x, [-200, 200], [-20, 20]);
    const likeOpacity = useTransform(x, [0, 100], [0, 1]);
    const nopeOpacity = useTransform(x, [-100, 0], [1, 0]);

    const handleDragEnd = (_, info) => {
        if (guest || !user) { router.push('/auth/login'); return; }
        if (info.offset.x > 100) handleLike();
        else if (info.offset.x < -100) handlePass();
    };

    if (loading) {
        return (
            <div className="px-4 py-6">
                <SkeletonCard />
            </div>
        );
    }

    if (!currentProfile) {
        return (
            <div className="px-4 py-12 text-center space-y-6">
                <div className="w-20 h-20 mx-auto rounded-full bg-primary/10 flex items-center justify-center">
                    <Sparkles size={36} className="text-primary" />
                </div>
                <h2 className="text-xl font-bold text-text-primary">You've Seen All Profiles!</h2>
                <p className="text-text-secondary text-sm max-w-xs mx-auto">
                    Check back later for new sugar mummies, or refresh to see profiles again.
                </p>
                <button
                    onClick={handleRefresh}
                    className="flex items-center gap-2 mx-auto px-6 py-3 rounded-2xl font-semibold text-white gradient-primary"
                >
                    <RefreshCw size={18} /> Refresh Profiles
                </button>
                <div className="mt-8">
                    <EmailSubscribe />
                </div>
            </div>
        );
    }

    return (
        <div className="relative px-4 py-4">
            {/* Subscribe banner */}
            <AnimatePresence>
                {showSubscribe && (
                    <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        className="mb-4 overflow-hidden"
                    >
                        <EmailSubscribe compact onClose={() => setShowSubscribe(false)} />
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Card Stack */}
            <div className="relative w-full max-w-sm mx-auto" style={{ aspectRatio: '3/4' }}>
                <AnimatePresence mode="popLayout">
                    <motion.div
                        key={currentProfile.wpId}
                        className="absolute inset-0 rounded-3xl overflow-hidden card-shadow cursor-grab active:cursor-grabbing"
                        style={{ x, rotate }}
                        drag="x"
                        dragConstraints={{ left: 0, right: 0 }}
                        dragElastic={0.7}
                        onDragEnd={handleDragEnd}
                        initial={{ scale: 0.95, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        exit={{
                            x: direction === 'right' ? 300 : direction === 'left' ? -300 : 0,
                            opacity: 0,
                            transition: { duration: 0.3 }
                        }}
                        onClick={() => handleViewProfile(currentProfile.wpId)}
                    >
                        <BlurImage
                            src={currentProfile.imageUrl}
                            alt={currentProfile.name}
                            fill
                            className="absolute inset-0"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent" />

                        {/* LIKE / NOPE indicators */}
                        <motion.div
                            className="absolute top-8 left-6 px-4 py-2 rounded-xl border-4 border-success text-success font-black text-2xl -rotate-12"
                            style={{ opacity: likeOpacity }}
                        >
                            LIKE
                        </motion.div>
                        <motion.div
                            className="absolute top-8 right-6 px-4 py-2 rounded-xl border-4 border-danger text-danger font-black text-2xl rotate-12"
                            style={{ opacity: nopeOpacity }}
                        >
                            NOPE
                        </motion.div>

                        {/* Profile info */}
                        <div className="absolute bottom-0 left-0 right-0 p-5 text-white">
                            <div className="flex items-center gap-2 mb-1">
                                <h2 className="text-2xl font-black truncate">{currentProfile.name}</h2>
                                {currentProfile.age && (
                                    <span className="text-xl font-light opacity-80">{currentProfile.age}</span>
                                )}
                                <VerifiedBadge verified={currentProfile.verified} size={20} />
                            </div>
                            {currentProfile.location && (
                                <div className="flex items-center gap-1 text-sm opacity-80 mb-2">
                                    <MapPin size={14} />
                                    <span>{currentProfile.location}</span>
                                </div>
                            )}
                            {currentProfile.excerpt && (
                                <p className="text-sm opacity-70 line-clamp-2">{currentProfile.excerpt}</p>
                            )}
                            <div className="flex items-center gap-1 mt-3 text-xs opacity-60">
                                <ChevronDown size={14} />
                                <span>Tap for details</span>
                            </div>
                        </div>
                    </motion.div>
                </AnimatePresence>
            </div>

            {/* ===== ACTION BUTTONS (COLORED & HIGH CONTRAST) ===== */}
            <div className="flex items-center justify-center gap-5 mt-6">
                {/* PASS — Red background */}
                <button
                    onClick={handlePass}
                    className="w-14 h-14 rounded-full flex items-center justify-center transition-all hover:scale-110 active:scale-90 shadow-lg"
                    style={{ background: '#FEE2E2', border: '2px solid #FECACA' }}
                >
                    <X size={26} className="text-danger" />
                </button>

                {/* SUPER LIKE / VIEW — Gold background */}
                <button
                    onClick={() => handleViewProfile(currentProfile.wpId)}
                    className="w-12 h-12 rounded-full flex items-center justify-center transition-all hover:scale-110 active:scale-90 shadow-md"
                    style={{ background: 'linear-gradient(135deg, #F59E0B, #D97706)', border: 'none' }}
                >
                    <Star size={22} className="text-white" fill="white" />
                </button>

                {/* LIKE — Purple/Pink gradient */}
                <button
                    onClick={handleLike}
                    className="w-14 h-14 rounded-full flex items-center justify-center transition-all hover:scale-110 active:scale-90 shadow-lg gradient-primary"
                >
                    <Heart size={26} className="text-white" fill="white" />
                </button>
            </div>

            {/* Stats */}
            <div className="text-center mt-4">
                <p className="text-xs text-text-muted">
                    {availableProfiles.length} profiles available
                </p>
            </div>
        </div>
    );
}
