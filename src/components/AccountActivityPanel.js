'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Eye, Heart, Loader2, Lock, Rocket, UserCheck, Users } from 'lucide-react';
import UserAvatar from '@/components/UserAvatar';
import { useAuth } from '@/contexts/AuthContext';

function person(row, key) {
    return row?.[key] || {};
}

function memberPath(user) {
    return user?.id ? '/members/' + user.id : '/members';
}

function timeText(date) {
    if (!date) return '';
    const diff = Math.max(0, Date.now() - new Date(date).getTime());
    if (diff < 60000) return 'now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return `${Math.floor(diff / 86400000)}d ago`;
}

function PersonRow({ row, userKey, label }) {
    const user = person(row, userKey);
    const photo = user.avatar_url || user.photos?.[0] || '';
    return (
        <Link href={memberPath(user)} className="flex items-center gap-2 rounded-xl p-2" style={{ background: 'var(--color-surface)' }}>
            <UserAvatar name={user.display_name || label} src={photo} size={36} />
            <div className="min-w-0 flex-1">
                <p className="truncate text-xs font-black text-text-primary">{user.display_name || 'Member'}</p>
                <p className="truncate text-[10px] text-text-muted">{user.username ? `@${user.username} - ` : ''}{timeText(row.created_at)}</p>
            </div>
        </Link>
    );
}

export default function AccountActivityPanel() {
    const { user } = useAuth();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [status, setStatus] = useState('');

    async function loadActivity() {
        if (!user?.id) return;
        setLoading(true);
        try {
            const res = await fetch(`/api/activity?userId=${encodeURIComponent(user.id)}`);
            const json = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(json.error || 'Could not load activity.');
            setData(json);
        } catch (error) {
            setStatus(error.message || 'Could not load activity.');
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => { loadActivity(); }, [user?.id]);

    async function boostProfile() {
        if (!user?.id) return;
        setStatus('Boosting your profile...');
        try {
            const res = await fetch('/api/activity', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'boost_profile', userId: user.id }),
            });
            const json = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(json.error || 'Boost failed.');
            setStatus('Profile boosted for 24 hours across Members, Discover, Matches, and Messages.');
            await loadActivity();
        } catch (error) {
            setStatus(error.message || 'Boost failed.');
        }
    }

    const locked = data?.locked;
    const activeBoost = (data?.boosts || []).find((boost) => boost.status === 'active' && new Date(boost.expires_at).getTime() > Date.now());

    return (
        <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
            <div className="flex items-start justify-between gap-3">
                <div>
                    <h3 className="text-sm font-black text-text-primary flex items-center gap-1.5"><Rocket size={16} className="text-secondary" /> Silver Activity Center</h3>
                    <p className="text-xs text-text-muted">See who likes, views, and follows you. Boost your profile for more attention.</p>
                </div>
                <button onClick={boostProfile} disabled={loading || locked} className="shrink-0 rounded-xl px-3 py-2 text-[10px] font-black text-white gradient-primary disabled:opacity-50">
                    {activeBoost ? 'Boosted' : 'Boost'}
                </button>
            </div>

            {loading && <div className="rounded-xl bg-primary/10 p-3 text-xs font-black text-primary flex items-center gap-2"><Loader2 size={14} className="animate-spin" /> Loading activity...</div>}
            {status && <div className="rounded-xl bg-primary/10 p-3 text-xs font-bold text-primary">{status}</div>}
            {locked && (
                <div className="rounded-xl bg-amber-100 p-3 text-xs font-bold text-gold flex items-center gap-2">
                    <Lock size={14} /> My likes, my views, follows, and boosts require Silver package or higher.
                </div>
            )}

            <div className="grid grid-cols-4 gap-2">
                <Metric icon={Heart} label="Likes" value={data?.likes?.length || 0} />
                <Metric icon={Eye} label="Views" value={data?.views?.length || 0} />
                <Metric icon={Users} label="Followers" value={data?.followers?.length || 0} />
                <Metric icon={UserCheck} label="Following" value={data?.following?.length || 0} />
            </div>

            {!locked && (
                <div className="grid gap-3 md:grid-cols-2">
                    <List title="My Likes" rows={data?.likes || []} userKey="liker" empty="No likes yet." />
                    <List title="My Views" rows={data?.views || []} userKey="viewer" empty="No profile views yet." />
                    <List title="Followers" rows={data?.followers || []} userKey="follower" empty="No followers yet." />
                    <List title="Following" rows={data?.following || []} userKey="following" empty="You are not following anyone yet." />
                </div>
            )}
        </section>
    );
}

function Metric({ icon: Icon, label, value }) {
    return (
        <div className="rounded-xl p-2 text-center" style={{ background: 'var(--color-surface)' }}>
            <Icon size={15} className="mx-auto text-primary" />
            <p className="mt-1 text-base font-black text-primary">{value}</p>
            <p className="text-[9px] font-bold text-text-muted">{label}</p>
        </div>
    );
}

function List({ title, rows, userKey, empty }) {
    return (
        <div className="space-y-2">
            <p className="text-xs font-black text-text-primary">{title}</p>
            {rows.length === 0 ? <p className="rounded-xl p-3 text-xs text-text-muted" style={{ background: 'var(--color-surface)' }}>{empty}</p> : rows.slice(0, 5).map((row) => <PersonRow key={row.id} row={row} userKey={userKey} label={title} />)}
        </div>
    );
}
