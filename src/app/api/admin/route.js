import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { emailHtml, sendAndLogEmail } from '@/lib/email';

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@genuinesugarmummies.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'Admin@2026!';
const PACKAGE_TIERS = {
    free: { name: 'Free', price: 0, phoneReveal: false, dailyMessages: 2, likes: 3, swipes: 3, giftAccess: false, calls: false, priority: false },
    basic: { name: 'Basic', price: 650, phoneReveal: false, dailyMessages: 10, likes: 10, swipes: 10, giftAccess: true, calls: false, priority: false },
    silver: { name: 'Silver', price: 1200, phoneReveal: true, dailyMessages: 30, likes: 50, swipes: 50, giftAccess: true, calls: true, priority: true },
    gold: { name: 'Gold International', price: 3500, phoneReveal: true, dailyMessages: 100, likes: 200, swipes: 200, giftAccess: true, calls: true, priority: true },
};

function tokenFor(email, password) {
    return Buffer.from(`${email}:${password}`).toString('base64');
}

function isAuthed(request) {
    const token = request.headers.get('x-admin-token') || '';
    return token === tokenFor(ADMIN_EMAIL, ADMIN_PASSWORD);
}

function jsonError(message, status = 500) {
    return NextResponse.json({ error: message }, { status });
}

function clean(value, fallback = '') {
    return String(value || fallback).trim();
}

function planName(tier) {
    return PACKAGE_TIERS[String(tier || 'free').toLowerCase()]?.name || 'Free';
}

async function safeSelect(supabase, table, select, options = {}) {
    let query = supabase.from(table).select(select, options.count ? { count: 'exact' } : undefined);
    if (options.order) query = query.order(options.order.column, { ascending: options.order.ascending ?? false });
    if (options.limit) query = query.limit(options.limit);
    const result = await query;
    if (result.error) return { data: [], count: 0, error: result.error.message };
    return { data: result.data || [], count: result.count || (result.data || []).length, error: null };
}

async function writeLog(supabase, action, details = {}) {
    try { await supabase.from('admin_logs').insert({ action, details }); } catch {}
}

async function queueUserNotification(supabase, payload) {
    try { await supabase.from('user_notifications').insert(payload); } catch {}
}

async function queueEmail(supabase, payload) {
    return sendAndLogEmail(supabase, {
        to: payload.to || payload.to_email,
        subject: payload.subject,
        text: payload.body || payload.text || '',
        html: payload.html || emailHtml(payload.subject || 'Genuine Sugar Mummies', payload.body || payload.text || ''),
    });
}

async function safeInsertMany(supabase, table, rows) {
    if (!rows?.length) return;
    try { await supabase.from(table).insert(rows); } catch {}
}

async function getUserById(supabase, userId) {
    if (!userId) return null;
    const { data } = await supabase.from('users').select('id, email, display_name, subscription_tier').eq('id', userId).maybeSingle();
    return data || null;
}

async function getPackageRequest(supabase, requestId) {
    if (!requestId) return null;
    const { data } = await supabase.from('package_requests').select('id, user_id, email, display_name, tier, amount_ksh, payment_reference').eq('id', requestId).maybeSingle();
    return data || null;
}

async function updateUser(supabase, userId, patch, select = 'id, display_name, email, verified, verification_status, admin_approved, subscription_tier, package_locked, show_in_public, is_suspended, is_banned') {
    const { data, error } = await supabase.from('users').update(patch).eq('id', userId).select(select).maybeSingle();
    if (error) return { error };
    return { data };
}

async function notifyUser(supabase, userId, { type = 'admin', title, body, emailSubject }) {
    const user = await getUserById(supabase, userId);
    if (!user) return { user: null, email: null };
    await queueUserNotification(supabase, { user_id: user.id, type, title, body });
    const email = user.email ? await queueEmail(supabase, { to_email: user.email, subject: emailSubject || title, body }) : null;
    return { user, email };
}

async function resolveRequestUser(supabase, request) {
    if (request?.user_id) return request.user_id;
    if (!request?.email) return null;
    const { data } = await supabase.from('users').select('id').eq('email', request.email).maybeSingle();
    return data?.id || null;
}

async function sendManyEmails(supabase, recipients, { subject, body }) {
    const results = await Promise.allSettled(
        recipients.filter((user) => user.email).map((user) => queueEmail(supabase, { to_email: user.email, subject, body }))
    );
    return results.filter((item) => item.status === 'fulfilled' && item.value?.ok).length;
}

export async function POST(request) {
    const body = await request.json().catch(() => ({}));

    if (body.action === 'login') {
        if (body.email === ADMIN_EMAIL && body.password === ADMIN_PASSWORD) {
            return NextResponse.json({ ok: true, token: tokenFor(ADMIN_EMAIL, ADMIN_PASSWORD) });
        }
        return jsonError('Invalid admin credentials.', 401);
    }

    if (!isAuthed(request)) return jsonError('Unauthorized.', 401);
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);

    const userId = body.userId;

    if (body.action === 'test_email') {
        const to = clean(body.to || 'principlessmart@gmail.com');
        const result = await queueEmail(supabase, {
            to_email: to,
            subject: body.subject || 'Hello World',
            body: body.message || 'Congrats on sending your first Genuine Sugar Mummies email.',
        });
        await writeLog(supabase, 'test_email', { to, ok: result.ok, error: result.error || null });
        if (!result.ok) return jsonError(result.error || 'Email failed.', 500);
        return NextResponse.json({ ok: true, email: result });
    }

    if (body.action === 'approve_user') {
        const tier = String(body.subscriptionTier || body.tier || 'basic').toLowerCase();
        const result = await updateUser(supabase, userId, {
            verified: true,
            verification_status: 'verified',
            admin_approved: true,
            subscription_tier: tier,
            package_locked: false,
            package_expires_at: body.packageExpiresAt || null,
            show_in_public: true,
            is_suspended: false,
            is_banned: false,
        });
        if (result.error) return jsonError(result.error.message);
        await notifyUser(supabase, userId, {
            type: 'verification',
            title: 'Profile approved',
            body: `Your profile has been manually approved. Your ${planName(tier)} access is active after admin approval.`,
        });
        await writeLog(supabase, 'approve_user', { userId, tier });
        return NextResponse.json({ ok: true, user: result.data });
    }

    if (body.action === 'reject_verification') {
        const reason = body.reason || 'Please upload clearer verification documents.';
        const result = await updateUser(supabase, userId, {
            verified: false,
            verification_status: 'rejected',
            verification_rejection_reason: reason,
            admin_approved: false,
        });
        if (result.error) return jsonError(result.error.message);
        await notifyUser(supabase, userId, { type: 'verification', title: 'Verification rejected', body: reason });
        await writeLog(supabase, 'reject_verification', { userId, reason });
        return NextResponse.json({ ok: true, user: result.data });
    }

    if (body.action === 'revoke_verification') {
        const result = await updateUser(supabase, userId, { verified: false, verification_status: 'pending_admin', admin_approved: false });
        if (result.error) return jsonError(result.error.message);
        await notifyUser(supabase, userId, { type: 'verification', title: 'Verification revoked', body: 'Admin has revoked your verification. Please submit a new selfie, ID/passport, and phone number.' });
        await writeLog(supabase, 'revoke_verification', { userId });
        return NextResponse.json({ ok: true, user: result.data });
    }

    if (body.action === 'set_package') {
        const tier = String(body.tier || 'free').toLowerCase();
        const plan = PACKAGE_TIERS[tier] || PACKAGE_TIERS.free;
        const result = await updateUser(supabase, userId, {
            subscription_tier: tier,
            package_locked: Boolean(body.locked),
            phone_reveal_plan: plan.phoneReveal ? tier : 'silver',
            package_expires_at: body.packageExpiresAt || null,
            admin_approved: tier !== 'free' && !body.locked,
        });
        if (result.error) return jsonError(result.error.message);
        await notifyUser(supabase, userId, {
            type: 'package',
            title: `${plan.name} package ${body.locked ? 'locked' : 'updated'}`,
            body: body.locked ? 'Your package is locked by admin.' : `Your ${plan.name} package is now active. Features are unlocked based on this tier.`,
        });
        await writeLog(supabase, 'set_package', { userId, tier, locked: Boolean(body.locked) });
        return NextResponse.json({ ok: true, user: result.data, plan });
    }

    if (body.action === 'lock_package' || body.action === 'unlock_package') {
        const locked = body.action === 'lock_package';
        const result = await updateUser(supabase, userId, { package_locked: locked, admin_approved: !locked });
        if (result.error) return jsonError(result.error.message);
        await notifyUser(supabase, userId, { type: 'package', title: locked ? 'Package locked' : 'Package unlocked', body: locked ? 'Admin has locked your package access.' : 'Admin has unlocked your package access.' });
        await writeLog(supabase, body.action, { userId });
        return NextResponse.json({ ok: true, user: result.data });
    }

    if (body.action === 'show_user' || body.action === 'hide_user') {
        const show = body.action === 'show_user';
        const result = await updateUser(supabase, userId, { show_in_public: show });
        if (result.error) return jsonError(result.error.message);
        await writeLog(supabase, body.action, { userId });
        return NextResponse.json({ ok: true, user: result.data });
    }

    if (body.action === 'suspend_user' || body.action === 'ban_user') {
        const banned = body.action === 'ban_user';
        const result = await updateUser(supabase, userId, { is_suspended: true, is_banned: banned, show_in_public: false });
        if (result.error) return jsonError(result.error.message);
        await notifyUser(supabase, userId, { type: 'account', title: banned ? 'Account banned' : 'Account suspended', body: banned ? 'Your account has been banned by admin.' : 'Your account has been suspended by admin.' });
        await writeLog(supabase, body.action, { userId });
        return NextResponse.json({ ok: true, user: result.data });
    }

    if (body.action === 'restore_user' || body.action === 'unban_user') {
        const result = await updateUser(supabase, userId, { is_suspended: false, is_banned: false, show_in_public: true });
        if (result.error) return jsonError(result.error.message);
        await notifyUser(supabase, userId, { type: 'account', title: 'Account restored', body: 'Admin has restored your account access.' });
        await writeLog(supabase, body.action, { userId });
        return NextResponse.json({ ok: true, user: result.data });
    }

    if (body.action === 'approve_package_request') {
        const requestRow = await getPackageRequest(supabase, body.requestId);
        const tier = String(body.tier || body.subscriptionTier || requestRow?.tier || 'silver').toLowerCase();
        const plan = PACKAGE_TIERS[tier] || PACKAGE_TIERS.silver;
        const targetUserId = userId || await resolveRequestUser(supabase, requestRow);
        if (targetUserId) {
            const result = await updateUser(supabase, targetUserId, {
                subscription_tier: tier,
                admin_approved: true,
                package_locked: false,
                phone_reveal_plan: plan.phoneReveal ? tier : 'silver',
                package_expires_at: body.packageExpiresAt || null,
            });
            if (result.error) return jsonError(result.error.message);
            await notifyUser(supabase, targetUserId, { type: 'package', title: `${plan.name} package approved`, body: `Your KSh ${plan.price} payment has been approved. ${plan.name} package features are active.` });
        }
        if (body.requestId) {
            await supabase.from('package_requests').update({ status: 'approved', reviewed_at: new Date().toISOString(), admin_note: body.note || '' }).eq('id', body.requestId);
        }
        await writeLog(supabase, 'approve_package_request', { userId: targetUserId, requestId: body.requestId, tier });
        return NextResponse.json({ ok: true, userId: targetUserId, plan });
    }

    if (body.action === 'reject_package_request') {
        const requestRow = await getPackageRequest(supabase, body.requestId);
        const targetUserId = await resolveRequestUser(supabase, requestRow);
        await supabase.from('package_requests').update({ status: 'rejected', reviewed_at: new Date().toISOString(), admin_note: body.note || '' }).eq('id', body.requestId);
        if (targetUserId) await notifyUser(supabase, targetUserId, { type: 'package', title: 'Package payment rejected', body: body.note || 'Your payment reference could not be approved. Please contact admin for help.' });
        await writeLog(supabase, 'reject_package_request', { requestId: body.requestId, userId: targetUserId });
        return NextResponse.json({ ok: true });
    }

    if (body.action === 'create_broadcast') {
        const title = clean(body.title).slice(0, 140);
        const messageBody = clean(body.body).slice(0, 1200);
        if (!title || !messageBody) return jsonError('Broadcast title and message are required.', 400);
        const targetSegment = body.targetSegment || 'all';
        const { data: broadcastRow, error } = await supabase.from('broadcasts').insert({
            title,
            body: messageBody,
            target_segment: targetSegment,
            status: body.status || 'sent',
        }).select('id, title, body').maybeSingle();
        if (error) return jsonError(error.message);

        const { data: users } = await supabase.from('users').select('id, email, display_name, subscription_tier, profile_label, is_suspended, is_banned').limit(2000);
        const recipients = (users || []).filter((user) => !user.is_suspended && !user.is_banned && (targetSegment === 'all' || user.subscription_tier === targetSegment || user.profile_label === targetSegment));
        await safeInsertMany(supabase, 'user_notifications', recipients.map((user) => ({
            user_id: user.id,
            type: 'broadcast',
            title,
            body: messageBody,
            metadata: { broadcast_id: broadcastRow?.id || null, target_segment: targetSegment },
        })));
        const emailsSent = await sendManyEmails(supabase, recipients, { subject: title, body: messageBody });
        await writeLog(supabase, 'create_broadcast', { title, targetSegment, recipients: recipients.length, emailsSent });
        return NextResponse.json({ ok: true, recipients: recipients.length, emailsSent });
    }

    if (body.action === 'email_user') {
        const target = await getUserById(supabase, userId);
        if (!target?.email) return jsonError('User has no email address.', 400);
        const subject = clean(body.subject || 'Message from Genuine Sugar Mummies').slice(0, 160);
        const message = clean(body.message || body.body || 'Admin sent you a message.').slice(0, 1200);
        await queueUserNotification(supabase, { user_id: target.id, type: 'admin_email', title: subject, body: message });
        const email = await queueEmail(supabase, { to_email: target.email, subject, body: message });
        await writeLog(supabase, 'email_user', { userId, subject, ok: email.ok });
        if (!email.ok) return jsonError(email.error || 'Email failed.', 500);
        return NextResponse.json({ ok: true, email });
    }

    if (body.action === 'send_subscription_reminders') {
        const { data: users } = await supabase.from('users').select('id, email, display_name, subscription_tier, admin_approved, package_locked').limit(2000);
        const recipients = (users || []).filter((user) => user.email && (!user.admin_approved || user.package_locked || String(user.subscription_tier || 'free') === 'free'));
        await safeInsertMany(supabase, 'user_notifications', recipients.map((user) => ({
            user_id: user.id,
            type: 'subscription_reminder',
            title: 'Unlock premium access',
            body: 'Choose Basic, Silver, or Gold package and submit your payment reference for admin approval.',
        })));
        const emailsSent = await sendManyEmails(supabase, recipients, {
            subject: 'Unlock your Genuine Sugar Mummies package',
            body: 'Choose Basic, Silver, or Gold package in the app, send payment, paste your transaction ID, and admin will approve your package.',
        });
        await writeLog(supabase, 'send_subscription_reminders', { recipients: recipients.length, emailsSent });
        return NextResponse.json({ ok: true, recipients: recipients.length, emailsSent });
    }

    if (body.action === 'create_ticket') {
        const { error } = await supabase.from('support_tickets').insert({
            user_id: userId || null,
            subject: clean(body.subject || 'Admin note').slice(0, 160),
            body: clean(body.body).slice(0, 1200),
            status: body.status || 'open',
            priority: body.priority || 'normal',
        });
        if (error) return jsonError(error.message);
        await writeLog(supabase, 'create_ticket', { userId, subject: body.subject || '' });
        return NextResponse.json({ ok: true });
    }

    if (body.action === 'respond_ticket') {
        const ticketId = body.ticketId;
        const responseBody = clean(body.message || body.body).slice(0, 1200);
        if (!ticketId || responseBody.length < 2) return jsonError('Ticket and response message are required.', 400);
        const { data: ticketRow } = await supabase.from('support_tickets').select('id, user_id, subject').eq('id', ticketId).maybeSingle();
        const { error } = await supabase.from('ticket_responses').insert({ ticket_id: ticketId, body: responseBody, responder: 'admin' });
        if (error) return jsonError(error.message);
        await supabase.from('support_tickets').update({ status: 'answered' }).eq('id', ticketId);
        if (ticketRow?.user_id) await notifyUser(supabase, ticketRow.user_id, { type: 'ticket', title: `Support reply: ${ticketRow.subject || 'Ticket'}`, body: responseBody });
        await writeLog(supabase, 'respond_ticket', { ticketId });
        return NextResponse.json({ ok: true });
    }

    if (body.action === 'close_ticket') {
        const { error } = await supabase.from('support_tickets').update({ status: 'closed', closed_at: new Date().toISOString() }).eq('id', body.ticketId);
        if (error) return jsonError(error.message);
        await writeLog(supabase, 'close_ticket', { ticketId: body.ticketId });
        return NextResponse.json({ ok: true });
    }

    if (body.action === 'update_limits') {
        const { error } = await supabase.from('app_limits').upsert({
            id: body.limitId || 'global',
            daily_message_limit: Number(body.dailyMessageLimit || 30),
            daily_gift_limit: Number(body.dailyGiftLimit || 20),
            max_photos_per_user: Number(body.maxPhotosPerUser || 6),
            require_manual_verification: body.requireManualVerification !== false,
            ads_enabled: Boolean(body.adsEnabled),
            updated_at: new Date().toISOString(),
        });
        if (error) return jsonError(error.message);
        await writeLog(supabase, 'update_limits', { limitId: body.limitId || 'global' });
        return NextResponse.json({ ok: true });
    }

    if (body.action === 'mark_message_read') {
        const { error } = await supabase.from('member_messages').update({ is_read: true }).eq('id', body.messageId);
        if (error) return jsonError(error.message);
        return NextResponse.json({ ok: true });
    }

    return jsonError('Unsupported action.', 400);
}

export async function GET(request) {
    if (!isAuthed(request)) return jsonError('Unauthorized.', 401);
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);

    const usersFullSelect = 'id, email, display_name, avatar_url, profile_label, member_category, looking_for, phone_number, phone, subscription_tier, package_locked, package_expires_at, verified, verification_status, verification_selfie_url, verification_document_url, verification_document_type, verification_phone, verification_submitted_at, verification_rejection_reason, admin_approved, show_in_public, is_suspended, is_banned, created_at, last_seen_at, followers_count, gifts_received_count, total_profile_views';
    let users = await safeSelect(supabase, 'users', usersFullSelect, { count: true, order: { column: 'created_at', ascending: false }, limit: 500 });
    if (users.error) {
        users = await safeSelect(supabase, 'users', 'id, email, display_name, avatar_url, profile_label, phone_number, subscription_tier, verified, verification_status, admin_approved, show_in_public, is_suspended, is_banned, created_at', { count: true, order: { column: 'created_at', ascending: false }, limit: 500 });
    }

    const messages = await safeSelect(supabase, 'member_messages', 'id, member_id, sender_key, sender_name, body, is_read, created_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const gifts = await safeSelect(supabase, 'member_gifts', 'id, member_id, sender_key, gift_name, emoji, message, created_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const packageRequests = await safeSelect(supabase, 'package_requests', 'id, user_id, email, display_name, tier, amount_ksh, status, payment_reference, note, created_at, reviewed_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const tickets = await safeSelect(supabase, 'support_tickets', 'id, user_id, subject, body, status, priority, created_at, closed_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const broadcasts = await safeSelect(supabase, 'broadcasts', 'id, title, body, target_segment, status, created_at', { order: { column: 'created_at', ascending: false }, limit: 80 });
    const limits = await safeSelect(supabase, 'app_limits', 'id, daily_message_limit, daily_gift_limit, max_photos_per_user, require_manual_verification, ads_enabled, updated_at', { limit: 20 });
    const callRequests = await safeSelect(supabase, 'call_requests', 'id, member_id, requester_key, requester_name, call_type, status, note, created_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const ticketResponses = await safeSelect(supabase, 'ticket_responses', 'id, ticket_id, responder, body, created_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const notifications = await safeSelect(supabase, 'user_notifications', 'id, user_id, type, title, body, read, created_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const emailOutbox = await safeSelect(supabase, 'email_outbox', 'id, to_email, subject, status, provider_response, created_at, sent_at', { order: { column: 'created_at', ascending: false }, limit: 150 });
    const logs = await safeSelect(supabase, 'admin_logs', 'id, action, details, created_at', { order: { column: 'created_at', ascending: false }, limit: 150 });

    const rows = users.data || [];
    const now = Date.now();
    const stats = {
        totalUsers: rows.length,
        pendingVerification: rows.filter((u) => u.verification_status === 'pending_admin').length,
        approvedUsers: rows.filter((u) => u.admin_approved || u.verified).length,
        suspendedUsers: rows.filter((u) => u.is_suspended || u.is_banned).length,
        bannedUsers: rows.filter((u) => u.is_banned).length,
        onlineUsers: rows.filter((u) => u.last_seen_at && now - new Date(u.last_seen_at).getTime() < 5 * 60 * 1000).length,
        offlineUsers: rows.filter((u) => !u.last_seen_at || now - new Date(u.last_seen_at).getTime() >= 5 * 60 * 1000).length,
        maleUsers: rows.filter((u) => ['sugar_daddy', 'toyboy'].includes(u.profile_label || u.member_category)).length,
        femaleUsers: rows.filter((u) => ['sugar_mummy', 'mistress'].includes(u.profile_label || u.member_category)).length,
        freeUsers: rows.filter((u) => !u.subscription_tier || u.subscription_tier === 'free').length,
        paidUsers: rows.filter((u) => ['basic', 'silver', 'gold', 'diamond'].includes(String(u.subscription_tier || '').toLowerCase())).length,
        unreadMessages: messages.data.filter((m) => !m.is_read).length,
        pendingPackageRequests: packageRequests.data.filter((r) => r.status === 'pending').length,
        pendingCallRequests: callRequests.data.filter((r) => r.status === 'pending').length,
    };

    return NextResponse.json({
        users: rows,
        stats,
        packages: PACKAGE_TIERS,
        verificationRequests: rows.filter((u) => u.verification_status === 'pending_admin' || u.verification_selfie_url || u.verification_document_url),
        messages: messages.data,
        gifts: gifts.data,
        packageRequests: packageRequests.data,
        tickets: tickets.data,
        broadcasts: broadcasts.data,
        limits: limits.data,
        callRequests: callRequests.data,
        ticketResponses: ticketResponses.data,
        notifications: notifications.data,
        emailOutbox: emailOutbox.data,
        logs: logs.data,
        tableErrors: {
            users: users.error,
            messages: messages.error,
            gifts: gifts.error,
            packageRequests: packageRequests.error,
            tickets: tickets.error,
            broadcasts: broadcasts.error,
            limits: limits.error,
            callRequests: callRequests.error,
            ticketResponses: ticketResponses.error,
            notifications: notifications.error,
            emailOutbox: emailOutbox.error,
            logs: logs.error,
        },
    });
}