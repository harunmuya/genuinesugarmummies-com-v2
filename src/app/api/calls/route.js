import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { canUseFeature, getUserPackageAccess } from '@/lib/packageAccess';

const LIVE_CALL_STATUSES = ['ringing', 'accepted', 'active'];
const CLOSED_CALL_STATUSES = ['ended', 'rejected', 'declined', 'missed'];

function jsonError(message, status = 500) {
    return NextResponse.json({ error: message }, { status });
}

async function getUser(supabase, userId) {
    const { data } = await supabase.from('users').select('id, display_name, avatar_url, photos, subscription_tier, admin_approved, package_locked').eq('id', userId).maybeSingle();
    return data || null;
}

function pairIds(a, b) {
    return [a, b].sort();
}

function callDurationSeconds(session, endTime = new Date()) {
    const startRaw = session?.started_at || session?.created_at;
    const start = startRaw ? new Date(startRaw).getTime() : Date.now();
    const end = endTime instanceof Date ? endTime.getTime() : new Date(endTime).getTime();
    return Math.max(0, Math.floor((end - start) / 1000));
}

function formatCallDuration(seconds) {
    const value = Math.max(0, Number(seconds || 0));
    const mins = Math.floor(value / 60);
    const secs = value % 60;
    return `${mins}:${String(secs).padStart(2, '0')}`;
}

async function logCallEvent(supabase, sessionId, actorId, eventType, metadata = {}) {
    if (!sessionId || !eventType) return;
    try {
        await supabase.from('call_events').insert({
            call_session_id: sessionId,
            actor_id: actorId || null,
            event_type: eventType,
            metadata,
        });
    } catch {}
}

async function ensureConversation(supabase, userId, peerId) {
    if (!userId || !peerId) return { data: null };
    const [userOne, userTwo] = pairIds(userId, peerId);
    let result = await supabase
        .from('conversations')
        .select('id, user_one_id, user_two_id, status, last_message_at, created_at, updated_at')
        .eq('user_one_id', userOne)
        .eq('user_two_id', userTwo)
        .maybeSingle();
    if (result.error && result.error.code !== 'PGRST116') return { error: result.error };
    if (result.data?.id) return { data: result.data };
    result = await supabase
        .from('conversations')
        .insert({ user_one_id: userOne, user_two_id: userTwo, status: 'active' })
        .select('id, user_one_id, user_two_id, status, last_message_at, created_at, updated_at')
        .maybeSingle();
    return result;
}

async function writeCallMessage(supabase, session, actorId, status, durationSeconds) {
    if (!session?.caller_id || !session?.receiver_id || session.caller_id === session.receiver_id) return null;
    try {
        const conversation = await ensureConversation(supabase, session.caller_id, session.receiver_id);
        if (conversation.error || !conversation.data?.id) return null;
        const actorIsCaller = actorId === session.caller_id;
        const senderId = actorIsCaller ? session.caller_id : session.receiver_id;
        const receiverId = actorIsCaller ? session.receiver_id : session.caller_id;
        const isVideo = session.call_type === 'video';
        const title = status === 'ended'
            ? `${isVideo ? 'Video' : 'Voice'} call ended`
            : `${isVideo ? 'Video' : 'Voice'} call ${status}`;
        const body = status === 'ended'
            ? `${title} · ${formatCallDuration(durationSeconds)}`
            : title;
        const now = new Date().toISOString();
        const inserted = await supabase.from('messages').insert({
            conversation_id: conversation.data.id,
            sender_id: senderId,
            receiver_id: receiverId,
            body,
            message_type: 'call_log',
            status: 'sent',
            delivered_at: now,
            metadata: {
                call: {
                    id: session.id,
                    type: session.call_type,
                    status,
                    durationSeconds,
                    startedAt: session.started_at || session.created_at,
                    endedAt: session.ended_at || now,
                },
            },
        }).select('id').maybeSingle();
        await supabase.from('conversations').update({ last_message_at: now, updated_at: now }).eq('id', conversation.data.id);
        return inserted.data || null;
    } catch {
        return null;
    }
}

export async function GET(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const { searchParams } = new URL(request.url);
    const sessionId = searchParams.get('sessionId');
    const userId = searchParams.get('userId');
    if (!sessionId) {
        if (!userId) return jsonError('Call session id or user id is required.', 400);
        const { data, error } = await supabase
            .from('call_sessions')
            .select('*')
            .or(`caller_id.eq.${userId},receiver_id.eq.${userId}`)
            .in('status', ['ringing', 'accepted', 'active'])
            .order('created_at', { ascending: false })
            .limit(20);
        if (error) return jsonError(error.message);
        const rows = data || [];
        const invalidSelfCalls = rows.filter((row) => row.caller_id && row.caller_id === row.receiver_id).map((row) => row.id);
        if (invalidSelfCalls.length) {
            await supabase.from('call_sessions').update({ status: 'ended', ended_at: new Date().toISOString(), receiver_id: null }).in('id', invalidSelfCalls);
        }
        const staleRingingIds = rows
            .filter((row) => row.status === 'ringing' && Date.now() - new Date(row.created_at).getTime() > 120000)
            .map((row) => row.id);
        if (staleRingingIds.length) {
            await supabase.from('call_sessions').update({ status: 'missed', missed_at: new Date().toISOString() }).in('id', staleRingingIds);
        }
        const validRows = rows.filter((row) => (
            row.caller_id &&
            row.receiver_id &&
            row.caller_id !== row.receiver_id &&
            !staleRingingIds.includes(row.id)
        ));
        const callerIds = [...new Set(validRows.map((row) => row.caller_id).filter(Boolean))];
        const receiverIds = [...new Set(validRows.map((row) => row.receiver_id).filter(Boolean))];
        const userIds = [...new Set([...callerIds, ...receiverIds])];
        const { data: users } = userIds.length
            ? await supabase.from('users').select('id, display_name, avatar_url, photos, verified').in('id', userIds)
            : { data: [] };
        const usersById = new Map((users || []).map((row) => [row.id, row]));
        return NextResponse.json({
            ok: true,
            sessions: validRows.map((session) => ({
                ...session,
                caller: usersById.get(session.caller_id) || null,
                receiver: usersById.get(session.receiver_id) || null,
                incoming: session.receiver_id === userId && session.caller_id !== userId,
                outgoing: session.caller_id === userId && session.receiver_id !== userId,
            })),
        });
    }

    const [sessionResult, signalResult] = await Promise.all([
        supabase.from('call_sessions').select('*').eq('id', sessionId).maybeSingle(),
        supabase.from('call_signals').select('*').eq('call_session_id', sessionId).order('created_at', { ascending: true }).limit(200),
    ]);
    if (sessionResult.error) return jsonError(sessionResult.error.message);
    if (!sessionResult.data?.id) return jsonError('Call not found.', 404);
    const session = sessionResult.data;
    if (session.caller_id && session.caller_id === session.receiver_id) {
        await supabase.from('call_sessions').update({ status: 'ended', ended_at: new Date().toISOString(), receiver_id: null }).eq('id', session.id);
        return jsonError('Invalid self-call was closed.', 400);
    }
    if (userId && ![session.caller_id, session.receiver_id].includes(userId)) return jsonError('You are not part of this call.', 403);
    return NextResponse.json({ ok: true, session, signals: signalResult.data || [] });
}

export async function POST(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const body = await request.json().catch(() => ({}));
    const action = body.action || 'start';
    const userId = body.userId;

    if (action === 'start') {
        const peerId = body.peerId;
        const callType = String(body.callType || 'voice').slice(0, 20);
        if (!userId || !peerId) return jsonError('Caller and receiver are required.', 400);
        if (userId === peerId) return jsonError('You cannot call yourself.', 400);
        const [caller, receiver] = await Promise.all([getUser(supabase, userId), getUser(supabase, peerId)]);
        if (!caller?.id || !receiver?.id) return jsonError('Caller or receiver was not found.', 404);
        const access = await getUserPackageAccess(supabase, caller);
        if (!canUseFeature(access.tier, 'calls')) return NextResponse.json({ error: 'Voice and video calls require Silver or Gold package approval.', redirectTo: '/packages' }, { status: 402 });
        const { data: existing } = await supabase
            .from('call_sessions')
            .select('*')
            .eq('caller_id', caller.id)
            .eq('receiver_id', receiver.id)
            .in('status', LIVE_CALL_STATUSES)
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();
        if (existing?.id) return NextResponse.json({ ok: true, session: existing });
        const { data, error } = await supabase.from('call_sessions').insert({
            caller_id: caller.id,
            receiver_id: receiver.id,
            call_type: callType,
            status: 'ringing',
            metadata: { callerName: caller.display_name, receiverName: receiver.display_name },
        }).select('*').maybeSingle();
        if (error) return jsonError(error.message);
        await logCallEvent(supabase, data.id, caller.id, 'started', { callType, receiverId: receiver.id });
        await supabase.from('user_notifications').insert({
            user_id: receiver.id,
            type: 'incoming_call',
            title: `${callType === 'video' ? 'Video' : 'Voice'} call from ${caller.display_name || 'Member'}`,
            body: 'Answer or decline inside the app.',
            metadata: { callSessionId: data.id, callerId: caller.id, actionLink: `/calls/${caller.id}?session=${data.id}&role=receiver` },
        });
        await supabase.from('admin_logs').insert({ action: 'call_started', details: { sessionId: data.id, callerId: caller.id, receiverId: receiver.id, callType } });
        return NextResponse.json({ ok: true, session: data });
    }

    if (action === 'signal') {
        const sessionId = body.sessionId;
        const receiverId = body.receiverId;
        const signalType = String(body.signalType || '').slice(0, 40);
        if (!sessionId || !userId || !receiverId || !signalType) return jsonError('Signal details are required.', 400);
        if (userId === receiverId) return jsonError('You cannot signal yourself.', 400);
        const sessionCheck = await supabase.from('call_sessions').select('*').eq('id', sessionId).maybeSingle();
        if (sessionCheck.error) return jsonError(sessionCheck.error.message);
        const session = sessionCheck.data;
        if (!session?.id) return jsonError('Call not found.', 404);
        if (session.caller_id === session.receiver_id) return jsonError('Invalid self-call.', 400);
        if (![session.caller_id, session.receiver_id].includes(userId) || ![session.caller_id, session.receiver_id].includes(receiverId)) return jsonError('Signal user is not part of this call.', 403);
        if (CLOSED_CALL_STATUSES.includes(session.status)) return jsonError('This call is already closed.', 409);
        const { data, error } = await supabase.from('call_signals').insert({
            call_session_id: sessionId,
            sender_id: userId,
            receiver_id: receiverId,
            signal_type: signalType,
            payload: body.payload || {},
        }).select('*').maybeSingle();
        if (error) return jsonError(error.message);
        return NextResponse.json({ ok: true, signal: data });
    }

    if (action === 'status') {
        const sessionId = body.sessionId;
        const status = String(body.status || '').slice(0, 40);
        if (!sessionId || !status) return jsonError('Session and status are required.', 400);
        const current = await supabase.from('call_sessions').select('*').eq('id', sessionId).maybeSingle();
        if (current.error) return jsonError(current.error.message);
        if (!current.data?.id) return jsonError('Call not found.', 404);
        if (current.data.caller_id && current.data.caller_id === current.data.receiver_id) {
            await supabase.from('call_sessions').update({ status: 'ended', ended_at: new Date().toISOString(), receiver_id: null }).eq('id', sessionId);
            return jsonError('Invalid self-call was closed.', 400);
        }
        if (userId && ![current.data.caller_id, current.data.receiver_id].includes(userId)) return jsonError('You are not part of this call.', 403);
        if (!['ringing', 'accepted', 'active', 'ended', 'rejected', 'declined', 'missed'].includes(status)) return jsonError('Unsupported call status.', 400);
        const now = new Date();
        const patch = { status, updated_at: now.toISOString() };
        if (['accepted', 'active'].includes(status) && !current.data.started_at) patch.started_at = now.toISOString();
        const durationSeconds = ['ended', 'rejected', 'declined', 'missed'].includes(status) ? callDurationSeconds(current.data, now) : 0;
        if (['ended', 'rejected', 'declined'].includes(status)) {
            patch.ended_at = now.toISOString();
            patch.duration_seconds = durationSeconds;
        }
        if (status === 'missed') patch.missed_at = new Date().toISOString();
        let updateResult = await supabase.from('call_sessions').update(patch).eq('id', sessionId).select('*').maybeSingle();
        if (updateResult.error && ['42703', 'PGRST204'].includes(updateResult.error.code)) {
            const fallbackPatch = { ...patch };
            delete fallbackPatch.duration_seconds;
            updateResult = await supabase.from('call_sessions').update(fallbackPatch).eq('id', sessionId).select('*').maybeSingle();
        }
        const { data, error } = updateResult;
        if (error) return jsonError(error.message);
        await logCallEvent(supabase, sessionId, userId, status, { callType: data.call_type, durationSeconds });
        if (['ended', 'rejected', 'declined', 'missed'].includes(status)) {
            await writeCallMessage(supabase, { ...data, duration_seconds: durationSeconds }, userId, status, durationSeconds);
        }
        if (['rejected', 'declined', 'missed', 'ended'].includes(status)) {
            const notifyUserId = userId === data.caller_id ? data.receiver_id : data.caller_id;
            if (notifyUserId) {
                await supabase.from('user_notifications').insert({
                    user_id: notifyUserId,
                    type: 'call_status',
                    title: status === 'ended' ? 'Call ended' : 'Call not answered',
                    body: status === 'ended' ? `The ${data.call_type || 'voice'} call ended after ${formatCallDuration(durationSeconds)}.` : `The ${data.call_type || 'voice'} call was ${status}.`,
                    metadata: { callSessionId: data.id, actionLink: `/messages/${userId}` },
                });
            }
        }
        await supabase.from('admin_logs').insert({ action: 'call_status', details: { sessionId, status, userId } });
        return NextResponse.json({ ok: true, session: data });
    }

    return jsonError('Unsupported call action.', 400);
}
