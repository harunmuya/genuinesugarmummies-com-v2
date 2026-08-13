import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';

function jsonError(message, status = 500) {
    return NextResponse.json({ error: message }, { status });
}

async function countRows(supabase, column, userId) {
    const { count } = await supabase
        .from('user_follows')
        .select('id', { count: 'exact', head: true })
        .eq(column, userId);
    return count || 0;
}

async function refreshCounts(supabase, userId) {
    if (!userId) return {};
    const [followersCount, followingCount] = await Promise.all([
        countRows(supabase, 'following_id', userId),
        countRows(supabase, 'follower_id', userId),
    ]);
    await supabase.from('users').update({ followers_count: followersCount, following_count: followingCount }).eq('id', userId);
    return { followersCount, followingCount };
}

export async function GET(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    const targetId = searchParams.get('targetId');
    const list = searchParams.get('list');
    if (!userId && !targetId) return jsonError('User id is required.', 400);

    if (list === 'followers' || list === 'following') {
        const column = list === 'followers' ? 'following_id' : 'follower_id';
        const select = list === 'followers'
            ? 'id, follower_id, created_at, follower:users!user_follows_follower_id_fkey(id, display_name, avatar_url, photos, profile_label, verified)'
            : 'id, following_id, created_at, following:users!user_follows_following_id_fkey(id, display_name, avatar_url, photos, profile_label, verified)';
        const { data, error } = await supabase.from('user_follows').select(select).eq(column, targetId || userId).order('created_at', { ascending: false }).limit(100);
        if (error) return jsonError(error.message);
        return NextResponse.json({ ok: true, follows: data || [] });
    }

    let isFollowing = false;
    if (userId && targetId) {
        const { data } = await supabase.from('user_follows').select('id').eq('follower_id', userId).eq('following_id', targetId).maybeSingle();
        isFollowing = Boolean(data?.id);
    }
    const counts = await refreshCounts(supabase, targetId || userId);
    return NextResponse.json({ ok: true, isFollowing, ...counts });
}

export async function POST(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const body = await request.json().catch(() => ({}));
    const userId = body.userId;
    const targetId = body.targetId;
    if (!userId || !targetId) return jsonError('Follower and profile are required.', 400);
    if (userId === targetId) return jsonError('You cannot follow yourself.', 400);

    const existing = await supabase.from('user_follows').select('id').eq('follower_id', userId).eq('following_id', targetId).maybeSingle();
    if (existing.error && existing.error.code !== 'PGRST116') return jsonError(existing.error.message);

    let following = false;
    if (existing.data?.id) {
        const deleted = await supabase.from('user_follows').delete().eq('id', existing.data.id);
        if (deleted.error) return jsonError(deleted.error.message);
    } else {
        const inserted = await supabase.from('user_follows').insert({ follower_id: userId, following_id: targetId });
        if (inserted.error) return jsonError(inserted.error.message);
        following = true;
        try {
            const { data: follower } = await supabase
                .from('users')
                .select('id, username, display_name, email, avatar_url, photos')
                .eq('id', userId)
                .maybeSingle();
            const followerName = follower?.display_name || follower?.email?.split('@')[0] || 'A member';
            const followerUsername = follower?.username ? `@${follower.username}` : '';
            await supabase.from('user_notifications').insert({
                user_id: targetId,
                type: 'follow',
                title: `${followerName} followed you`,
                body: followerUsername ? `${followerName} (${followerUsername}) followed your profile.` : `${followerName} followed your profile.`,
                metadata: {
                    followerId: userId,
                    followerName,
                    followerUsername,
                    followerAvatar: follower?.avatar_url || follower?.photos?.[0] || '',
                    actionLink: '/members/' + userId,
                },
            });
        } catch {}
    }

    const targetCounts = await refreshCounts(supabase, targetId);
    const userCounts = await refreshCounts(supabase, userId);
    return NextResponse.json({ ok: true, following, ...targetCounts, myFollowingCount: userCounts.followingCount || 0 });
}
