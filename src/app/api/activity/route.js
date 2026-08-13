import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { activeTierId } from '@/lib/packageAccess';

const SILVER_PLUS = new Set(['silver', 'gold', 'diamond']);

function jsonError(message, status = 500, extra = {}) {
    return NextResponse.json({ error: message, ...extra }, { status });
}

function isMissingSchema(error) {
    return ['42P01', '42703', 'PGRST204', 'PGRST205'].includes(error?.code) || String(error?.message || '').includes('schema cache');
}

function canUseActivity(user) {
    return SILVER_PLUS.has(activeTierId(user));
}

async function getUser(supabase, userId) {
    if (!userId) return null;
    const { data } = await supabase
        .from('users')
        .select('id, username, display_name, email, avatar_url, photos, subscription_tier, admin_approved, package_locked, verified')
        .eq('id', userId)
        .maybeSingle();
    return data || null;
}

function publicUser(user = {}) {
    return {
        id: user.id || '',
        username: user.username || '',
        display_name: user.display_name || user.email?.split('@')[0] || 'Member',
        avatar_url: user.avatar_url || '',
        photos: Array.isArray(user.photos) ? user.photos : [],
        verified: Boolean(user.verified),
    };
}

function parseDataUrl(dataUrl) {
    const match = String(dataUrl || '').match(/^data:([^;,]+)(?:;[^,]*)?;base64,(.+)$/);
    if (!match) return null;
    return { contentType: match[1], buffer: Buffer.from(match[2], 'base64') };
}

async function uploadStoryMedia(supabase, rawUrl, { ownerId, mediaType }) {
    if (!rawUrl || !String(rawUrl).startsWith('data:')) return rawUrl || '';
    const parsed = parseDataUrl(rawUrl);
    if (!parsed || parsed.buffer.length > 8 * 1024 * 1024) return rawUrl;
    const extMap = {
        'image/jpeg': 'jpg',
        'image/png': 'png',
        'image/webp': 'webp',
        'image/gif': 'gif',
        'video/mp4': 'mp4',
        'video/webm': 'webm',
    };
    const ext = extMap[parsed.contentType] || (mediaType === 'video' ? 'mp4' : 'webp');
    const cleanOwner = String(ownerId || 'member').replace(/[^a-zA-Z0-9-]/g, '').slice(0, 80);
    const path = `${cleanOwner}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
    try {
        const uploaded = await supabase.storage.from('story-media').upload(path, parsed.buffer, {
            contentType: parsed.contentType,
            upsert: false,
        });
        if (uploaded.error) return rawUrl;
        const { data } = supabase.storage.from('story-media').getPublicUrl(path);
        return data?.publicUrl || rawUrl;
    } catch {
        return rawUrl;
    }
}

async function listStories(supabase, viewerId) {
    const { data, error } = await supabase
        .from('user_stories')
        .select('id, user_id, caption, media_url, media_type, background, created_at, expires_at, user:users!user_stories_user_id_fkey(id, username, display_name, avatar_url, photos, verified)')
        .eq('status', 'active')
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(80);
    if (error) return isMissingSchema(error) ? { data: [] } : { error };
    const storyIds = (data || []).map((story) => story.id);
    const [{ data: views }, { data: likes }] = await Promise.all([
        storyIds.length ? supabase.from('story_views').select('story_id, viewer_id, viewer:users!story_views_viewer_id_fkey(id, username, display_name, avatar_url, photos, verified), created_at').in('story_id', storyIds) : { data: [] },
        storyIds.length ? supabase.from('story_likes').select('story_id, user_id, user:users!story_likes_user_id_fkey(id, username, display_name, avatar_url, photos, verified), created_at').in('story_id', storyIds) : { data: [] },
    ]);
    const viewsByStory = new Map();
    const likesByStory = new Map();
    (views || []).forEach((row) => viewsByStory.set(row.story_id, [...(viewsByStory.get(row.story_id) || []), row]));
    (likes || []).forEach((row) => likesByStory.set(row.story_id, [...(likesByStory.get(row.story_id) || []), row]));
    return {
        data: (data || []).map((story) => {
            const storyViews = viewsByStory.get(story.id) || [];
            const storyLikes = likesByStory.get(story.id) || [];
            const owner = story.user_id === viewerId;
            return {
                ...story,
                user: publicUser(story.user),
                viewCount: storyViews.length,
                likeCount: storyLikes.length,
                likedByMe: storyLikes.some((row) => row.user_id === viewerId),
                viewedByMe: storyViews.some((row) => row.viewer_id === viewerId),
                viewers: owner ? storyViews.slice(-40).reverse().map((row) => ({ ...row, viewer: publicUser(row.viewer) })) : [],
                likes: owner ? storyLikes.slice(-40).reverse().map((row) => ({ ...row, user: publicUser(row.user) })) : [],
            };
        }),
    };
}

async function activityOverview(supabase, user) {
    const userId = user.id;
    if (!canUseActivity(user)) {
        return { locked: true, tier: activeTierId(user), likes: [], views: [], followers: [], following: [], boosts: [], stories: [] };
    }

    const [likes, views, followers, following, boosts, stories] = await Promise.all([
        supabase
            .from('member_likes')
            .select('id, liker_id, is_super_like, created_at, liker:users!member_likes_liker_id_fkey(id, username, display_name, avatar_url, photos, verified)')
            .eq('liked_id', userId)
            .order('created_at', { ascending: false })
            .limit(80),
        supabase
            .from('profile_views')
            .select('id, viewer_id, created_at, viewer:users!profile_views_viewer_id_fkey(id, username, display_name, avatar_url, photos, verified)')
            .eq('viewed_id', userId)
            .order('created_at', { ascending: false })
            .limit(80),
        supabase
            .from('user_follows')
            .select('id, follower_id, created_at, follower:users!user_follows_follower_id_fkey(id, username, display_name, avatar_url, photos, verified)')
            .eq('following_id', userId)
            .order('created_at', { ascending: false })
            .limit(80),
        supabase
            .from('user_follows')
            .select('id, following_id, created_at, following:users!user_follows_following_id_fkey(id, username, display_name, avatar_url, photos, verified)')
            .eq('follower_id', userId)
            .order('created_at', { ascending: false })
            .limit(80),
        supabase
            .from('profile_boosts')
            .select('id, status, starts_at, expires_at, created_at')
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .limit(10),
        listStories(supabase, userId),
    ]);

    const normalizeRows = (result, key) => (result.data || []).map((row) => ({ ...row, [key]: publicUser(row[key]) }));
    return {
        locked: false,
        tier: activeTierId(user),
        likes: normalizeRows(likes, 'liker'),
        views: normalizeRows(views, 'viewer'),
        followers: normalizeRows(followers, 'follower'),
        following: normalizeRows(following, 'following'),
        boosts: boosts.data || [],
        stories: stories.data || [],
        errors: [likes, views, followers, following, boosts, stories].filter((result) => result.error).map((result) => result.error.message),
    };
}

export async function GET(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    const type = searchParams.get('type') || 'overview';

    if (type === 'stories') {
        const result = await listStories(supabase, userId || '');
        if (result.error) return isMissingSchema(result.error) ? NextResponse.json({ ok: true, stories: [] }) : jsonError(result.error.message);
        return NextResponse.json({ ok: true, stories: result.data || [] });
    }

    const user = await getUser(supabase, userId);
    if (!user?.id) return jsonError('Signed-in user is required.', 400);
    const overview = await activityOverview(supabase, user);
    return NextResponse.json({ ok: true, ...overview });
}

export async function POST(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const body = await request.json().catch(() => ({}));
    const action = String(body.action || '').trim();
    const user = await getUser(supabase, body.userId);
    if (!user?.id) return jsonError('Signed-in user is required.', 400);

    if (action === 'create_story') {
        const mediaType = String(body.mediaType || 'image').slice(0, 20);
        const mediaUrl = await uploadStoryMedia(supabase, String(body.mediaUrl || '').trim(), { ownerId: user.id, mediaType });
        const caption = String(body.caption || '').slice(0, 240);
        if (!mediaUrl && !caption) return jsonError('Add a story photo, video, or text.', 400);
        const { data, error } = await supabase
            .from('user_stories')
            .insert({
                user_id: user.id,
                caption,
                media_url: mediaUrl || '',
                media_type: mediaUrl ? mediaType : 'text',
                background: String(body.background || 'gradient-primary').slice(0, 60),
                expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
            })
            .select('id, user_id, caption, media_url, media_type, background, created_at, expires_at')
            .maybeSingle();
        if (error) return jsonError(error.message);
        return NextResponse.json({ ok: true, story: data });
    }

    if (action === 'view_story') {
        const storyId = body.storyId;
        if (!storyId) return jsonError('Story id is required.', 400);
        const existing = await supabase
            .from('story_views')
            .select('id')
            .eq('story_id', storyId)
            .eq('viewer_id', user.id)
            .maybeSingle();
        if (existing.error && !['PGRST116'].includes(existing.error.code)) return jsonError(existing.error.message);
        if (existing.data?.id) return NextResponse.json({ ok: true });
        const { error } = await supabase.from('story_views').insert({
            story_id: storyId,
            viewer_id: user.id,
            viewer_key: user.id,
        });
        if (error) return jsonError(error.message);
        return NextResponse.json({ ok: true });
    }

    if (action === 'like_story') {
        const storyId = body.storyId;
        if (!storyId) return jsonError('Story id is required.', 400);
        const existing = await supabase.from('story_likes').select('id').eq('story_id', storyId).eq('user_id', user.id).maybeSingle();
        if (existing.data?.id) {
            const deleted = await supabase.from('story_likes').delete().eq('id', existing.data.id);
            if (deleted.error) return jsonError(deleted.error.message);
            return NextResponse.json({ ok: true, liked: false });
        }
        const inserted = await supabase.from('story_likes').insert({ story_id: storyId, user_id: user.id });
        if (inserted.error) return jsonError(inserted.error.message);
        return NextResponse.json({ ok: true, liked: true });
    }

    if (action === 'boost_profile') {
        if (!canUseActivity(user)) return jsonError('Profile boost requires Silver package or higher.', 402, { redirectTo: '/packages' });
        const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
        const startedAt = new Date().toISOString();
        const boost = await supabase
            .from('profile_boosts')
            .insert({ user_id: user.id, tier: activeTierId(user), status: 'active', starts_at: startedAt, expires_at: expiresAt })
            .select('id, status, starts_at, expires_at')
            .maybeSingle();
        if (boost.error) return jsonError(boost.error.message);
        await supabase
            .from('users')
            .update({ boost_started_at: startedAt, boost_expires_at: expiresAt, boost_score: 100, updated_at: startedAt })
            .eq('id', user.id);
        return NextResponse.json({ ok: true, boost: boost.data, boostExpiresAt: expiresAt });
    }

    return jsonError('Unknown activity action.', 400);
}
