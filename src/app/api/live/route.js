import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { canUseFeature, getUserPackageAccess } from '@/lib/packageAccess';
import { emailHtml, sendAndLogEmail } from '@/lib/email';

function jsonError(message, status = 500) {
    return NextResponse.json({ error: message }, { status });
}

async function getUser(supabase, userId) {
    if (!userId) return null;
    const { data } = await supabase.from('users').select('id, display_name, avatar_url, photos, subscription_tier, admin_approved, package_locked, package_expires_at').eq('id', userId).maybeSingle();
    return data || null;
}

async function getGift(supabase, giftId) {
    if (!giftId) return null;
    const { data } = await supabase.from('gift_catalog').select('*').eq('id', giftId).maybeSingle();
    return data || null;
}

async function notifyFollowersLive(supabase, host, stream) {
    try {
        const { data: follows } = await supabase
            .from('user_follows')
            .select('follower_id, follower:users!user_follows_follower_id_fkey(id, email, display_name)')
            .eq('following_id', host.id)
            .limit(100);
        const followers = (follows || []).map((row) => row.follower).filter((follower) => follower?.id);
        if (!followers.length) return;
        const hostName = host.display_name || 'A member you follow';
        const streamTitle = stream.title || `${hostName} is live`;
        const title = `${hostName} is live now`;
        const body = `Hello {{accountName}},\n\n${hostName} is online now on Genuine Sugar Mummies.\n\nLive title: ${streamTitle}\n\nOpen the app to join the live room, watch, comment, like, and send gifts.`;
        await supabase.from('user_notifications').insert(followers.map((follower) => ({
            user_id: follower.id,
            type: 'followed_live',
            title,
            body: body.replace('{{accountName}}', follower.display_name || 'there'),
            metadata: { streamId: stream.id, hostId: host.id, actionLink: `/live/${stream.id}` },
        })));
        await Promise.all(followers.filter((follower) => follower.email).slice(0, 40).map((follower) => sendAndLogEmail(supabase, {
            to: follower.email,
            subject: title,
            text: body.replace('{{accountName}}', follower.display_name || 'there'),
            html: emailHtml(title, body.replace('{{accountName}}', follower.display_name || 'there'), {
                preview: `${hostName} is online now in GS Live.`,
                accountName: follower.display_name || 'GS Member',
                accountEmail: follower.email,
                onlineName: hostName,
                badge: 'Live alert',
                actionLabel: 'Join Live in GS App',
                actionUrl: `/live/${stream.id}`,
                secondaryActionLabel: 'Open Live section',
                secondaryActionUrl: '/live',
                metaRows: [
                    { label: 'Live host', value: hostName },
                    { label: 'Live title', value: streamTitle },
                    { label: 'Status', value: 'Online now' },
                ],
            }),
        })));
    } catch {}
}

export async function GET(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const { searchParams } = new URL(request.url);
    const streamId = searchParams.get('streamId');

    if (streamId) {
        const [stream, comments, gifts, viewers] = await Promise.all([
            supabase.from('live_streams').select('*, host:users!live_streams_host_id_fkey(id, display_name, avatar_url, photos, verified, followers_count)').eq('id', streamId).maybeSingle(),
            supabase.from('live_comments').select('*, user:users!live_comments_user_id_fkey(id, display_name, avatar_url, photos)').eq('stream_id', streamId).order('created_at', { ascending: true }).limit(100),
            supabase.from('live_gifts').select('*').eq('stream_id', streamId).order('created_at', { ascending: false }).limit(60),
            supabase.from('live_viewers').select('*', { count: 'exact', head: true }).eq('stream_id', streamId),
        ]);
        if (stream.error) return jsonError(stream.error.message);
        if (!stream.data?.id) return jsonError('Live stream not found.', 404);
        return NextResponse.json({
            ok: true,
            stream: {
                ...stream.data,
                viewer_count: viewers.count ?? stream.data.viewer_count ?? 0,
                total_comments: Math.max(Number(stream.data.total_comments || 0), (comments.data || []).length),
                total_gifts: Math.max(Number(stream.data.total_gifts || 0), (gifts.data || []).length),
                total_likes: stream.data.total_likes ?? 0,
            },
            comments: comments.data || [],
            gifts: gifts.data || [],
        });
    }

    const { data, error } = await supabase
        .from('live_streams')
        .select('*, host:users!live_streams_host_id_fkey(id, display_name, avatar_url, photos, verified, followers_count)')
        .eq('is_active', true)
        .order('viewer_count', { ascending: false })
        .order('started_at', { ascending: false })
        .limit(50);
    if (error) return jsonError(error.message);
    const streams = await Promise.all((data || []).map(async (stream) => {
        const [comments, gifts, viewers] = await Promise.all([
            supabase.from('live_comments').select('*', { count: 'exact', head: true }).eq('stream_id', stream.id),
            supabase.from('live_gifts').select('*', { count: 'exact', head: true }).eq('stream_id', stream.id),
            supabase.from('live_viewers').select('*', { count: 'exact', head: true }).eq('stream_id', stream.id),
        ]);
        return {
            ...stream,
            viewer_count: viewers.count ?? stream.viewer_count ?? 0,
            total_comments: Math.max(Number(stream.total_comments || 0), Number(comments.count || 0)),
            total_gifts: Math.max(Number(stream.total_gifts || 0), Number(gifts.count || 0)),
            total_likes: stream.total_likes ?? 0,
        };
    }));
    streams.sort((a, b) => (
        Number(b.viewer_count || 0) - Number(a.viewer_count || 0)
        || Number(b.total_likes || 0) - Number(a.total_likes || 0)
        || Number(b.total_gifts || 0) - Number(a.total_gifts || 0)
        || Number(b.total_comments || 0) - Number(a.total_comments || 0)
        || new Date(b.started_at || b.created_at || 0) - new Date(a.started_at || a.created_at || 0)
    ));
    return NextResponse.json({ ok: true, streams });
}

export async function POST(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const body = await request.json().catch(() => ({}));
    const action = body.action;
    const userId = body.userId;

    if (action === 'start_stream') {
        const host = await getUser(supabase, userId);
        if (!host?.id) return jsonError('Sign in before going live.', 401);
        const access = await getUserPackageAccess(supabase, host);
        if (!canUseFeature(access.tier, 'live')) return NextResponse.json({ error: 'Going live requires Silver package or higher.', redirectTo: '/packages' }, { status: 402 });
        const existing = await supabase.from('live_streams').select('*').eq('host_id', userId).eq('is_active', true).order('started_at', { ascending: false }).limit(1).maybeSingle();
        if (existing.data?.id) return NextResponse.json({ ok: true, stream: existing.data });
        const { data, error } = await supabase.from('live_streams').insert({
            host_id: userId,
            title: String(body.title || `${host.display_name || 'Member'} is live`).slice(0, 120),
            is_active: true,
            viewer_count: 0,
            total_gifts: 0,
            total_coins: 0,
            total_likes: 0,
            total_comments: 0,
            total_views: 0,
        }).select('*').maybeSingle();
        if (error && ['42703', 'PGRST204'].includes(error.code)) {
            const fallback = await supabase.from('live_streams').insert({
                host_id: userId,
                title: String(body.title || `${host.display_name || 'Member'} is live`).slice(0, 120),
                is_active: true,
                viewer_count: 0,
                total_gifts: 0,
                total_coins: 0,
            }).select('*').maybeSingle();
            if (fallback.error) return jsonError(fallback.error.message);
            await supabase.from('users').update({ is_live: true }).eq('id', userId);
            await notifyFollowersLive(supabase, host, fallback.data);
            return NextResponse.json({ ok: true, stream: fallback.data });
        }
        if (error) return jsonError(error.message);
        await supabase.from('users').update({ is_live: true }).eq('id', userId);
        await notifyFollowersLive(supabase, host, data);
        return NextResponse.json({ ok: true, stream: data });
    }

    if (action === 'end_stream') {
        const streamId = body.streamId;
        if (!streamId || !userId) return jsonError('Stream and host are required.', 400);
        const { data, error } = await supabase.from('live_streams').update({ is_active: false, ended_at: new Date().toISOString() }).eq('id', streamId).eq('host_id', userId).select('*').maybeSingle();
        if (error) return jsonError(error.message);
        await supabase.from('users').update({ is_live: false }).eq('id', userId);
        await supabase.from('live_viewers').delete().eq('stream_id', streamId);
        return NextResponse.json({ ok: true, stream: data });
    }

    if (action === 'join_stream' || action === 'leave_stream') {
        const streamId = body.streamId;
        if (!streamId || !userId) return jsonError('Stream and user are required.', 400);
        if (action === 'join_stream') {
            const existingViewer = await supabase.from('live_viewers').select('user_id').eq('stream_id', streamId).eq('user_id', userId).maybeSingle();
            const { error } = await supabase.from('live_viewers').upsert({ stream_id: streamId, user_id: userId, joined_at: new Date().toISOString() }, { onConflict: 'stream_id,user_id' });
            if (error) return jsonError(error.message);
            if (!existingViewer.data?.user_id) {
                const { data: streamRow } = await supabase.from('live_streams').select('host_id, total_views').eq('id', streamId).maybeSingle();
                const nextTotalViews = Number(streamRow?.total_views || 0) + 1;
                const viewUpdate = await supabase.from('live_streams').update({ total_views: nextTotalViews }).eq('id', streamId).select('id').maybeSingle();
                if (viewUpdate.error && ['42703', 'PGRST204'].includes(viewUpdate.error.code)) {
                    await supabase.from('live_streams').update({ viewer_count: 1 }).eq('id', streamId).select('id').maybeSingle();
                }
                if (streamRow?.host_id && streamRow.host_id !== userId) {
                    const { data: host } = await supabase.from('users').select('total_profile_views').eq('id', streamRow.host_id).maybeSingle();
                    if (host) await supabase.from('users').update({ total_profile_views: Number(host.total_profile_views || 0) + 1 }).eq('id', streamRow.host_id);
                }
            }
        } else {
            await supabase.from('live_viewers').delete().eq('stream_id', streamId).eq('user_id', userId);
        }
        const { count } = await supabase.from('live_viewers').select('*', { count: 'exact', head: true }).eq('stream_id', streamId);
        await supabase.from('live_streams').update({ viewer_count: count || 0 }).eq('id', streamId);
        return NextResponse.json({ ok: true, viewerCount: count || 0 });
    }

    if (action === 'send_comment') {
        const content = String(body.content || '').trim().slice(0, 220);
        if (!body.streamId || !userId || !content) return jsonError('Comment details are required.', 400);
        const { data, error } = await supabase.from('live_comments').insert({ stream_id: body.streamId, user_id: userId, content }).select('*').maybeSingle();
        if (error) return jsonError(error.message);
        return NextResponse.json({ ok: true, comment: data });
    }

    if (action === 'like_stream') {
        const streamId = body.streamId;
        if (!streamId || !userId) return jsonError('Stream and user are required.', 400);
        let { data: streamRow, error: streamError } = await supabase.from('live_streams').select('id, host_id, total_likes').eq('id', streamId).maybeSingle();
        if (streamError && ['42703', 'PGRST204'].includes(streamError.code)) {
            const fallback = await supabase.from('live_streams').select('id, host_id').eq('id', streamId).maybeSingle();
            streamRow = fallback.data;
            streamError = fallback.error;
        }
        if (streamError) return jsonError(streamError.message);
        if (!streamRow?.id) return jsonError('Live stream not found.', 404);
        const nextLikes = Number(streamRow.total_likes || 0) + 1;
        const update = await supabase.from('live_streams').update({ total_likes: nextLikes }).eq('id', streamId).select('id, total_likes').maybeSingle();
        if (update.error && ['42703', 'PGRST204'].includes(update.error.code)) return NextResponse.json({ ok: true, totalLikes: nextLikes, persisted: false });
        if (update.error) return jsonError(update.error.message);
        return NextResponse.json({ ok: true, totalLikes: update.data?.total_likes ?? nextLikes, persisted: true });
    }

    if (action === 'send_gift') {
        if (!body.streamId || !userId || !body.giftId) return jsonError('Gift details are required.', 400);
        const [sender, streamResult] = await Promise.all([
            getUser(supabase, userId),
            supabase.from('live_streams').select('id, host_id').eq('id', body.streamId).maybeSingle(),
        ]);
        if (!streamResult.data?.id) return jsonError('Live stream not found.', 404);
        const access = await getUserPackageAccess(supabase, sender);
        if (!canUseFeature(access.tier, 'gifts')) return NextResponse.json({ error: 'Live gifts require a package with gift access.', redirectTo: '/packages' }, { status: 402 });
        const gift = await getGift(supabase, body.giftId);
        if (!gift?.id) return jsonError('Gift not found.', 404);
        if (Number(gift.tier || 1) > Number(access.tier.max_gift_tier || 0)) {
            return NextResponse.json({ error: `${gift.name} requires a higher package tier.`, redirectTo: '/packages' }, { status: 402 });
        }
        const { data: wallet } = await supabase.from('credit_wallet').select('credits').eq('user_id', userId).maybeSingle();
        const credits = wallet?.credits || 0;
        const cost = gift.credit_cost || 0;
        if (credits < cost) return NextResponse.json({ error: 'Not enough credits for this live gift.', redirectTo: '/wallet' }, { status: 402 });
        await supabase.from('credit_wallet').update({ credits: credits - cost, updated_at: new Date().toISOString() }).eq('user_id', userId);
        const { data, error } = await supabase.from('live_gifts').insert({
            stream_id: body.streamId,
            sender_id: userId,
            gift_name: gift.name,
            gift_visual: gift.icon_url || gift.gif_url || gift.emoji || '',
            gift_cost: cost,
        }).select('*').maybeSingle();
        if (error) return jsonError(error.message);
        if (streamResult.data?.host_id) {
            const counter = await supabase.from('users').select('gifts_received_count').eq('id', streamResult.data.host_id).maybeSingle();
            if (counter.data) await supabase.from('users').update({ gifts_received_count: Number(counter.data.gifts_received_count || 0) + 1 }).eq('id', streamResult.data.host_id);
        }
        await supabase.from('wallet_transactions').insert({ user_id: userId, wallet_type: 'credit', direction: 'debit', amount: cost, balance_after: credits - cost, source: 'live_gift', status: 'posted', reference: data?.id || '', metadata: { giftId: gift.id, streamId: body.streamId } });
        return NextResponse.json({ ok: true, gift: data, catalogGift: gift, credits: credits - cost });
    }

    return jsonError('Unsupported live action.', 400);
}
