'use client';

import { useState, useEffect, use } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import {
    Heart, ArrowLeft, Share2, Bookmark, BookmarkCheck,
    MapPin, Calendar, MessageCircle, Sparkles, ExternalLink,
    Clock, Users, Tag,
} from 'lucide-react';
import BlurImage from '@/components/BlurImage';
import VerifiedBadge from '@/components/VerifiedBadge';
import CommentForm from '@/components/CommentForm';
import ContactButtons from '@/components/ContactButtons';
import { useAuth } from '@/contexts/AuthContext';

// Relative time helper
function timeAgo(dateStr) {
    if (!dateStr) return '';
    const now = new Date();
    const date = new Date(dateStr);
    const secs = Math.floor((now - date) / 1000);
    if (secs < 60) return 'Just now';
    const mins = Math.floor(secs / 60);
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    if (days < 7) return `${days}d ago`;
    if (days < 30) return `${Math.floor(days / 7)}w ago`;
    if (days < 365) return `${Math.floor(days / 30)}mo ago`;
    return `${Math.floor(days / 365)}y ago`;
}

export default function ProfileDetailPage({ params }) {
    const { id } = use(params);
    const router = useRouter();
    const {
        user, guest, addLike, addMatch, likes, saveProfile, unsaveProfile,
        isProfileSaved, logProfileView, requestConnection,
        computeMatchScore, shouldMatchProfile, settings,
    } = useAuth();
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [showCommentForm, setShowCommentForm] = useState(false);
    const [comments, setComments] = useState([]);
    const [liked, setLiked] = useState(false);

    useEffect(() => {
        async function loadProfile() {
            try {
                const res = await fetch(`/api/profiles?id=${id}`);
                const data = await res.json();
                if (data.profiles?.[0]) {
                    setProfile(data.profiles[0]);
                    logProfileView(data.profiles[0]);
                }
            } catch (err) {
                console.error('Failed to load profile:', err);
            } finally {
                setLoading(false);
            }
        }
        loadProfile();
    }, [id, logProfileView]);

    // Fetch comments
    useEffect(() => {
        async function loadComments() {
            try {
                const res = await fetch(`/api/comments?post=${id}`);
                const data = await res.json();
                if (data.comments) setComments(data.comments);
            } catch { }
        }
        if (id) loadComments();
    }, [id]);

    // Check if already liked
    useEffect(() => {
        if (profile && likes.some(l => l.wpId === profile.wpId)) setLiked(true);
    }, [profile, likes]);

    const handleLike = () => {
        if (!profile || liked) return;
        if (guest || !user) { router.push('/auth/login'); return; }
        setLiked(true);
        addLike(profile);

        if (shouldMatchProfile(profile, user, settings)) {
            const score = computeMatchScore(profile, user, settings);
            addMatch(profile, score);
        }
    };

    const handleSave = () => {
        if (!profile) return;
        if (guest || !user) { router.push('/auth/login'); return; }
        if (isProfileSaved(profile.wpId)) unsaveProfile(profile.wpId);
        else saveProfile(profile);
    };

    const handleShare = async () => {
        if (!profile) return;
        if (guest || !user) { router.push('/auth/login'); return; }
        const url = `${window.location.origin}/discover/${profile.wpId}`;
        if (navigator.share) {
            try { await navigator.share({ title: profile.name, text: `Check out ${profile.name} on GenuineSugarMummies.com`, url }); } catch { }
        } else {
            navigator.clipboard?.writeText(url);
        }
    };

    const handleRequestConnection = () => {
        if (!profile) return;
        if (guest || !user) { router.push('/auth/login'); return; }
        requestConnection(profile.name, profile.wpId);
        const msg = encodeURIComponent(`Hi, need a match connection with ${profile.name}`);
        window.open(`https://t.me/GSADMINMARYGAGENCY?text=${msg}`, '_blank');
    };

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center">
                <div className="w-8 h-8 border-3 border-primary/30 border-t-primary rounded-full animate-spin" />
            </div>
        );
    }

    if (!profile) {
        return (
            <div className="min-h-screen flex flex-col items-center justify-center gap-4 px-6">
                <h2 className="text-xl font-bold text-text-primary">Profile Not Found</h2>
                <button onClick={() => router.back()} className="px-6 py-3 rounded-2xl font-semibold text-white gradient-primary">
                    Go Back
                </button>
            </div>
        );
    }

    const saved = isProfileSaved(profile.wpId);

    return (
        <div className="pb-24">
            {/* Hero Image */}
            <div className="relative w-full" style={{ aspectRatio: '3/4', maxHeight: '65vh' }}>
                <BlurImage src={profile.imageUrl} alt={profile.name} fill className="absolute inset-0" priority />
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-black/20" />

                {/* Back button */}
                <button
                    onClick={() => router.back()}
                    className="absolute top-4 left-4 w-10 h-10 rounded-full flex items-center justify-center shadow-lg"
                    style={{ background: 'rgba(0,0,0,0.7)' }}
                >
                    <ArrowLeft size={22} className="text-white" />
                </button>

                {/* Actions */}
                <div className="absolute top-4 right-4 flex gap-2">
                    <button onClick={handleShare}
                        className="w-10 h-10 rounded-full flex items-center justify-center shadow-lg"
                        style={{ background: 'rgba(0,0,0,0.6)' }}
                    >
                        <Share2 size={20} className="text-white" />
                    </button>
                    <button onClick={handleSave}
                        className="w-10 h-10 rounded-full flex items-center justify-center shadow-lg"
                        style={{ background: saved ? 'rgba(124,58,237,0.8)' : 'rgba(0,0,0,0.6)' }}
                    >
                        {saved ? <BookmarkCheck size={20} className="text-white" /> : <Bookmark size={20} className="text-white" />}
                    </button>
                </div>

                {/* Profile info on image */}
                <div className="absolute bottom-0 left-0 right-0 p-5 text-white">
                    <div className="flex items-center gap-2 mb-1">
                        <h1 className="text-3xl font-black truncate">{profile.name}</h1>
                        {profile.age && <span className="text-2xl font-light opacity-80">{profile.age}</span>}
                        <VerifiedBadge verified={profile.verified} size={22} />
                    </div>
                    {profile.location && (
                        <div className="flex items-center gap-1 text-sm opacity-80">
                            <MapPin size={14} />
                            <span>{profile.location}</span>
                        </div>
                    )}
                </div>
            </div>

            {/* Content */}
            <div className="px-4 space-y-5 -mt-3 relative z-10">
                {/* Action bar */}
                <div className="flex items-center justify-center gap-3 py-3">
                    <button
                        onClick={handleLike}
                        disabled={liked}
                        className={`flex items-center gap-2 px-6 py-3 rounded-2xl font-bold text-white transition-all active:scale-95 ${liked ? 'opacity-70' : 'shadow-lg'}`}
                        style={{
                            background: liked ? '#F472B6' : 'var(--gradient-primary)',
                            backgroundImage: liked ? 'none' : 'var(--gradient-primary)',
                            boxShadow: liked ? 'none' : '0 4px 20px rgba(124,58,237,0.3)',
                        }}
                    >
                        <Heart size={20} fill={liked ? 'white' : 'none'} />
                        {liked ? 'Liked!' : 'Like'}
                    </button>

                    <button
                        onClick={() => {
                            if (guest || !user) { router.push('/auth/login'); return; }
                            setShowCommentForm(true);
                        }}
                        className="flex items-center gap-2 px-6 py-3 rounded-2xl font-bold text-white transition-all active:scale-95"
                        style={{ background: '#1a1a2e', boxShadow: '0 2px 12px rgba(0,0,0,0.15)' }}
                    >
                        <MessageCircle size={20} />
                        Comment
                    </button>
                </div>

                {/* Profile Stats */}
                <div className="grid grid-cols-3 gap-2">
                    <div className="rounded-xl p-3 text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                        <Calendar size={16} className="mx-auto text-primary mb-1" />
                        <p className="text-[10px] text-text-muted">Posted</p>
                        <p className="text-xs font-bold text-text-primary">{profile.date ? timeAgo(profile.date) : 'N/A'}</p>
                    </div>
                    <div className="rounded-xl p-3 text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                        <MessageCircle size={16} className="mx-auto text-secondary mb-1" />
                        <p className="text-[10px] text-text-muted">Comments</p>
                        <p className="text-xs font-bold text-text-primary">{comments.length || profile.commentCount || 0}</p>
                    </div>
                    <div className="rounded-xl p-3 text-center" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                        <Heart size={16} className="mx-auto text-pink-500 mb-1" />
                        <p className="text-[10px] text-text-muted">Likes</p>
                        <p className="text-xs font-bold text-text-primary">{liked ? 1 : 0}</p>
                    </div>
                </div>

                {/* Bio / Excerpt */}
                {profile.excerpt && (
                    <div className="rounded-2xl p-4 space-y-2" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                        <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                            <Sparkles size={16} className="text-primary" /> About
                        </h3>
                        <div className="text-sm text-text-secondary leading-relaxed" dangerouslySetInnerHTML={{ __html: profile.excerpt }} />
                    </div>
                )}

                {/* Full content */}
                {profile.content && (
                    <div className="rounded-2xl p-4" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                        <div className="text-sm text-text-secondary leading-relaxed prose prose-sm max-w-none" dangerouslySetInnerHTML={{ __html: profile.content }} />
                    </div>
                )}

                {/* Contact Admin */}
                <ContactButtons profileName={profile.name} />

                {/* Request Connection CTA */}
                <button
                    onClick={handleRequestConnection}
                    className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold text-white gradient-primary shadow-lg transition-all active:scale-[0.98]"
                    style={{ boxShadow: '0 4px 20px rgba(124,58,237,0.3)' }}
                >
                    <ExternalLink size={20} />
                    Request Connection on Telegram
                </button>

                {/* Comments Section */}
                <div className="space-y-3">
                    <div className="flex items-center justify-between">
                        <h3 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                            <MessageCircle size={16} className="text-primary" />
                            Comments ({comments.length})
                        </h3>
                        <button
                            onClick={() => {
                                if (guest || !user) { router.push('/auth/login'); return; }
                                setShowCommentForm(true);
                            }}
                            className="text-xs font-semibold text-primary"
                        >
                            + Add Comment
                        </button>
                    </div>

                    {comments.length > 0 ? (
                        comments.map((c, i) => (
                            <div key={i} className="rounded-xl p-3 space-y-1.5" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }}>
                                <div className="flex items-center gap-2.5">
                                    {c.avatar_url ? (
                                        <img
                                            src={c.avatar_url}
                                            alt={c.author_name}
                                            className="w-8 h-8 rounded-full object-cover shrink-0"
                                            onError={(e) => { e.target.style.display = 'none'; }}
                                        />
                                    ) : (
                                        <div className="w-8 h-8 rounded-full flex items-center justify-center shrink-0 text-white text-xs font-bold" style={{ background: 'var(--gradient-primary)' }}>
                                            {(c.author_name || 'A')[0].toUpperCase()}
                                        </div>
                                    )}
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-1.5">
                                            <span className="text-xs font-bold text-text-primary truncate">{c.author_name}</span>
                                            <span className="text-[10px] text-text-muted shrink-0 flex items-center gap-0.5">
                                                <Clock size={10} />
                                                {timeAgo(c.date)}
                                            </span>
                                        </div>
                                    </div>
                                </div>
                                <div className="text-xs text-text-secondary pl-[42px] leading-relaxed" dangerouslySetInnerHTML={{ __html: c.content?.rendered || c.content }} />
                            </div>
                        ))
                    ) : (
                        <div className="rounded-xl p-5 text-center" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }}>
                            <MessageCircle size={24} className="mx-auto text-text-muted/40 mb-2" />
                            <p className="text-xs text-text-muted">No comments yet. Be the first to comment!</p>
                        </div>
                    )}
                </div>

                {/* View on Website */}
                {profile.link && (
                    <a href={profile.link} target="_blank" rel="noopener noreferrer"
                        className="flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-medium text-primary transition-all hover:bg-primary/5"
                        style={{ border: '1px solid rgba(124,58,237,0.15)' }}
                    >
                        <ExternalLink size={16} /> View on Website
                    </a>
                )}
            </div>

            {/* Comment Form Modal */}
            {showCommentForm && (
                <CommentForm profile={profile} onClose={() => setShowCommentForm(false)} />
            )}
        </div>
    );
}
