import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { emailHtml, sendAndLogEmail } from '@/lib/email';
import { hashPassword, verifyPassword, createResetCode, hashResetCode } from '@/lib/security';
import { activeTierId, dailyLimitForFeature, getPackageTier } from '@/lib/packageAccess';
import { classifySupabaseError } from '@/lib/supabaseError';

/*
  The column list behind the member directory. It has to stay a plain list of
  column names: it is interpolated straight into a PostgREST select, so anything
  written between these backticks is sent to the database, comments included.

  password_hash used to be in here. Three screens request 240 rows of this list,
  so every browse pulled 240 password hashes out of the users table. They never
  reached the browser, because normalizeMember builds an explicit object and
  never spreads the raw row, so this was not a leak. It was still a hash leaving
  the table on every listing for no reason, and one careless spread away from
  becoming one.

  Sign-in and account creation, the two paths that genuinely need it, select it
  by name further down this file, so removing it here changes nothing for them.
*/
const FULL_MEMBER_FIELDS = `
    id,
    username,
    display_name,
    email,
    avatar_url,
    photos,
    bio,
    description,
    age,
    location,
    country,
    city,
    latitude,
    longitude,
    geo_updated_at,
    phone,
    phone_number,
    profile_label,
    member_category,
    looking_for,
    intent_summary,
    wants,
    needed_qualities,
    age_range_preference,
    hobbies,
    interests,
    body_type,
    subscription_tier,
    verified,
    verification_status,
    show_in_public,
    is_banned,
    is_suspended,
    total_profile_views,
    followers_count,
    gifts_received_count,
    admin_approved,
    package_locked,
    package_expires_at,
    verification_selfie_url,
    verification_document_url,
    verification_document_type,
    verification_phone,
    verification_submitted_at,
    verification_rejection_reason,
    phone_reveal_plan,
    created_at,
    last_seen_at,
    last_seen,
    is_seed_profile,
    boost_expires_at,
    boost_score
`;

const BASIC_MEMBER_FIELDS = `
    id,
    username,
    display_name,
    email,
    avatar_url,
    photos,
    bio,
    description,
    age,
    location,
    country,
    city,
    phone,
    phone_number,
    profile_label,
    subscription_tier,
    verified,
    verification_status,
    show_in_public,
    is_banned,
    is_suspended,
    total_profile_views,
    created_at,
    last_seen_at,
    last_seen
`;

const UNLOCKED_PLANS = new Set(['silver', 'gold', 'diamond']);
const PAID_PLANS = new Set(['basic', 'silver', 'gold', 'diamond']);

const LIMIT_NOTICE = 'Your daily quota has been exhausted. Pay for a package to unlock unlimited access.';

function booleanSetting(value, fallback) {
    if (typeof value === 'boolean') return value;
    if (value === 'true') return true;
    if (value === 'false') return false;
    return fallback;
}

function settingsPayload(input = {}) {
    const source = input.settings && typeof input.settings === 'object' ? input.settings : input;
    return {
        notifications: booleanSetting(source.notifications, true),
        email_notifications: booleanSetting(source.emailNotifications ?? source.email_notifications, false),
        dark_mode: booleanSetting(source.darkMode ?? source.dark_mode, false),
        show_online: booleanSetting(source.showOnline ?? source.show_online, true),
        show_age: booleanSetting(source.showAge ?? source.show_age, true),
        is_public: booleanSetting(source.isPublic ?? source.is_public, true),
        live_location: booleanSetting(source.liveLocation ?? source.live_location, false),
        location_enabled: booleanSetting(source.locationEnabled ?? source.location_enabled, false),
        push_token: String(source.pushToken ?? source.push_token ?? '').slice(0, 500),
        push_platform: String(source.pushPlatform ?? source.push_platform ?? '').slice(0, 80),
        notification_permission: String(source.notificationPermission ?? source.notification_permission ?? 'default').slice(0, 40),
        preferences: source.preferences && typeof source.preferences === 'object' ? source.preferences : {},
        updated_at: new Date().toISOString(),
    };
}

function normalizeSettings(row = {}) {
    return {
        notifications: row.notifications !== false,
        emailNotifications: Boolean(row.email_notifications),
        darkMode: Boolean(row.dark_mode),
        showOnline: row.show_online !== false,
        showAge: row.show_age !== false,
        isPublic: row.is_public !== false,
        liveLocation: Boolean(row.live_location),
        locationEnabled: Boolean(row.location_enabled),
        pushToken: row.push_token || '',
        pushPlatform: row.push_platform || '',
        notificationPermission: row.notification_permission || 'default',
        preferences: row.preferences || {},
    };
}

async function resolveUserId(supabase, body) {
    if (body.memberId || body.userId) return body.memberId || body.userId;
    const email = String(body.email || '').trim().toLowerCase();
    if (!email) return null;
    const { data } = await supabase.from('users').select('id').eq('email', email).maybeSingle();
    return data?.id || null;
}

async function getUserSettings(supabase, userId) {
    if (!userId) return null;
    const result = await supabase.from('user_settings').select('*').eq('user_id', userId).maybeSingle();
    if (result.error && result.error.code !== 'PGRST116') return { error: result.error };
    if (!result.data) return { data: normalizeSettings({}) };
    return { data: normalizeSettings(result.data) };
}

/**
 * Should this standing reminder be posted again?
 *
 * These are not events. "Complete your profile", "Manual verification is
 * available" and "Unlock premium GS features" are conditions: they stay true
 * until the member does something about them.
 *
 * The rule was once every 24 hours, which posted a fresh copy of each one every
 * single day for as long as the condition held. A free account that had not
 * verified collected three new inbox messages a day, identical to yesterday's,
 * which is how an inbox reaches 58 items showing the same two notices over and
 * over. It also buries the messages that are events — a real message, a match —
 * under nags nobody has asked to see again.
 *
 * Two rules instead:
 *
 *   Never post one while an unread copy is already sitting there. Repeating
 *   something the member has not read yet cannot inform them of anything.
 *
 *   Once read, wait a week. The condition is still true and worth raising
 *   again eventually, but not tomorrow.
 */
const REMINDER_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;

async function reminderIsDue(supabase, userId, type) {
    const { data } = await supabase
        .from('user_notifications')
        .select('id, read, created_at')
        .eq('user_id', userId)
        .eq('type', type)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

    if (!data?.id) return true;
    // Still unread: saying it twice adds nothing.
    if (!data.read) return false;
    return Date.now() - new Date(data.created_at).getTime() > REMINDER_COOLDOWN_MS;
}

async function notifyOnceDaily(supabase, userId, payload) {
    if (!userId || !payload?.type) return false;
    if (!await reminderIsDue(supabase, userId, payload.type)) return false;
    await supabase.from('user_notifications').insert({ user_id: userId, ...payload });
    return true;
}

const SUPPORT_RESPONSE_TEMPLATES = {
    payment_issue: {
        team: 'Billing Team',
        title: 'Payment issue received',
        shortStatus: 'Payment issue received. Billing has replied in your inbox and email.',
        body: ({ name, subject }) => `Hello ${name},\n\nWe have received your payment issue${subject ? ` about "${subject}"` : ''}. The Billing Team will check the transaction ID, amount paid, selected package, and admin approval status.\n\nPlease keep your M-PESA, Airtel Money, or bank payment message safe. If any detail is missing, Admin Mary G support will request it from you before the package is unlocked or corrected.\n\nYou will receive the next update in your GS app inbox and on your email.`,
    },
    package_unlock: {
        team: 'Billing Team',
        title: 'Package unlock request received',
        shortStatus: 'Package unlock request received. Billing has replied in your inbox and email.',
        body: ({ name }) => `Hello ${name},\n\nYour package unlock request has been received. The Billing Team will confirm the payment reference, the package you selected, and the account that should be unlocked.\n\nAfter approval, the paid features on your lifetime package will open from the admin control panel. If you paid for Silver or Gold, contact reveal, unlimited messaging, gifts, and supported premium features will update on your account after approval.\n\nFor urgent help, you can also contact Admin Mary G on Telegram @GSADMINMARYGAGENCY.`,
    },
    refund: {
        team: 'Billing Team',
        title: 'Refund request received',
        shortStatus: 'Refund request received. Billing has replied in your inbox and email.',
        body: ({ name }) => `Hello ${name},\n\nWe have received your refund or cancellation request. The Billing Team will review your payment status, package access, and service history.\n\nIf your refund is approved, eligible payments are processed within 24 hours after approval. Please keep your payment transaction ID available so the team can confirm the correct record.\n\nYou will receive an update in your GS app inbox and email after review.`,
    },
    verification: {
        team: 'Verification Team',
        title: 'Verification help request received',
        shortStatus: 'Verification request received. The Verification Team has replied.',
        body: ({ name }) => `Hello ${name},\n\nYour verification help request has been received. The Verification Team reviews profile photo, selfie, ID or passport image, and phone number before a badge is approved.\n\nIf any required item is missing or unclear, you will be asked to upload it again. The blue badge appears only after manual admin approval.\n\nPlease use clear photos and make sure the details match your account information.`,
    },
    safety_report: {
        team: 'Safety Team',
        title: 'Safety report received',
        shortStatus: 'Safety report received. The Safety Team has replied.',
        body: ({ name }) => `Hello ${name},\n\nYour scam or fake profile report has been received. The Safety Team will review the profile, message, payment claim, or contact details you reported.\n\nPlease do not send more money or private documents to anyone outside the official Admin Mary G support route. If you have screenshots or usernames, keep them ready for the review.\n\nWe will update you in your GS app inbox and email when action is taken.`,
    },
    account_profile: {
        team: 'Technical Support',
        title: 'Account support request received',
        shortStatus: 'Account request received. Technical Support has replied.',
        body: ({ name }) => `Hello ${name},\n\nYour account or profile help request has reached Technical Support. The team will check profile photos, saved details, login state, visibility settings, preferences, and any missing account information.\n\nPlease keep your app updated and avoid deleting your account while support is reviewing the issue.\n\nYou will receive the next reply inside your GS inbox and email.`,
    },
    direct_connection: {
        team: 'Admin Mary G Support',
        title: 'Direct connection request received',
        shortStatus: 'Direct connection request received. Admin Mary G Support has replied.',
        body: ({ name }) => `Hello ${name},\n\nYour direct connection service request has been received by Admin Mary G Support. Connections are handled through the official support route, and you choose the person you want help with. We do not assign random connections.\n\nIf your package or direct connection payment is approved, Admin Mary G will guide the next step, including Telegram assistance where needed.\n\nFor faster help, contact @GSADMINMARYGAGENCY on Telegram using the same name as your GS account.`,
    },
    general: {
        team: 'GS Support Team',
        title: 'Support request received',
        shortStatus: 'Support request received. A GS Support reply has been sent.',
        body: ({ name }) => `Hello ${name},\n\nWe have received your support request. The GS Support Team will review your message and direct it to the correct department if Billing, Verification, Safety, Technical Support, or Admin Mary G needs to handle it.\n\nYou can continue using the app while the request is reviewed. The next update will appear in your GS inbox and email.`,
    },
};

function buildSupportAutoResponse(service, { name = 'Member', subject = '' } = {}) {
    const key = SUPPORT_RESPONSE_TEMPLATES[service] ? service : 'general';
    const template = SUPPORT_RESPONSE_TEMPLATES[key];
    return {
        service: key,
        team: template.team,
        senderLabel: template.team,
        title: template.title,
        body: template.body({ name, subject }),
        shortStatus: template.shortStatus,
    };
}

function maskPhone(phone) {
    if (!phone) return null;
    const digits = String(phone).replace(/\D/g, '');
    if (digits.length < 7) return 'Hidden';
    const normalized = digits.startsWith('0') && digits.length === 10 ? `254${digits.slice(1)}` : digits;
    const start = normalized.slice(0, Math.min(4, normalized.length - 4));
    const end = normalized.slice(-4);
    return `${start}****${end}`;
}

function getDisplayName(member) {
    return member.display_name || member.email?.split('@')[0] || 'Member';
}

function getPrimaryPhoto(member) {
    if (member.avatar_url) return member.avatar_url;
    if (Array.isArray(member.photos) && member.photos[0]) return member.photos[0];
    return '';
}

function hasProfilePhoto(member) {
    return Boolean(getPrimaryPhoto(member));
}

function recentDisplayTime(member) {
    const real = member.last_seen_at || member.last_seen;
    const realMs = real ? new Date(real).getTime() : 0;
    if (!realMs || Number.isNaN(realMs)) return null;
    return new Date(realMs).toISOString();
}

function stableHash(value) {
    const text = String(value || '');
    let hash = 0;
    for (let index = 0; index < text.length; index++) hash = ((hash << 5) - hash + text.charCodeAt(index)) | 0;
    return Math.abs(hash);
}

function livelySeedTime(member) {
    if (!member.is_seed_profile) return recentDisplayTime(member);
    const hash = stableHash(member.id || member.email || member.display_name);
    const bucket = hash % 8;
    const minutesAgo = bucket <= 2
        ? (hash % 4)
        : bucket <= 4
            ? 18 + (hash % 42)
            : bucket <= 6
                ? 2 * 60 + (hash % (5 * 60))
                : 11 * 60 + (hash % (10 * 60));
    return new Date(Date.now() - minutesAgo * 60 * 1000).toISOString();
}

function activeBoost(member) {
    const expires = member.boost_expires_at ? new Date(member.boost_expires_at).getTime() : 0;
    return Boolean(expires && !Number.isNaN(expires) && expires > Date.now());
}

function isUnlockedViewer(viewer) {
    if (!viewer) return false;
    const tier = String(viewer.subscription_tier || '').toLowerCase();
    return Boolean(viewer.admin_approved && !viewer.package_locked && UNLOCKED_PLANS.has(tier));
}

async function getUserPlan(supabase, userId) {
    if (!userId) return 'free';
    const { data } = await supabase
        .from('users')
        .select('subscription_tier, admin_approved, package_locked')
        .eq('id', userId)
        .maybeSingle();
    return activeTierId(data);
}

async function enforceDailyLimit(supabase, userId, kind) {
    if (!userId || !kind) return { ok: true, plan: 'free', remaining: null };
    const plan = await getUserPlan(supabase, userId);
    const tier = await getPackageTier(supabase, plan);
    const limit = dailyLimitForFeature(tier, kind);
    if (limit === null || limit === undefined) return { ok: true, plan, limit: null, remaining: null };
    const usageDate = new Date().toISOString().slice(0, 10);
    let result = await supabase
        .from('user_daily_usage')
        .select('id, count')
        .eq('user_id', userId)
        .eq('usage_date', usageDate)
        .eq('kind', kind)
        .maybeSingle();
    if (result.error && result.error.code === 'PGRST205') return { ok: true, plan, limit, remaining: Math.max(0, limit - 1), skipped: true };
    if (result.error && result.error.code !== 'PGRST116') return { ok: true, plan, limit, remaining: Math.max(0, limit - 1), skipped: true };
    const current = result.data?.count || 0;
    if (current >= limit) {
        return { ok: false, plan, limit, used: current, remaining: 0, message: LIMIT_NOTICE, redirectTo: '/packages' };
    }
    if (result.data?.id) {
        await supabase.from('user_daily_usage').update({ count: current + 1, updated_at: new Date().toISOString() }).eq('id', result.data.id);
    } else {
        await supabase.from('user_daily_usage').insert({ user_id: userId, usage_date: usageDate, kind, count: 1 });
    }
    return { ok: true, plan, limit, used: current + 1, remaining: Math.max(0, limit - current - 1) };
}

/**
 * Turn a pair of likes into a match, if the other one already exists.
 *
 * Likes were being recorded and never read back the other way, so two people
 * liking each other produced two rows and nothing else. The matches table has
 * existed since 20260703_120 and no code had ever written to it, which is why
 * the matches screen listed the whole member directory instead.
 *
 * The pair is stored in a fixed order. `matches` has UNIQUE(user_one_id,
 * user_two_id), and that constraint does not know the two columns are
 * interchangeable: inserting (A,B) and (B,A) would create two rows for one
 * match, and then every match would appear twice for one of the two people
 * involved. Sorting the ids makes the constraint mean what it looks like it
 * means.
 *
 * Returns `{ matched, peer }`. A failure to write the match is deliberately not
 * fatal to the like: the like is the thing the user asked for, and losing it
 * because the match bookkeeping failed would be the worse outcome.
 */
async function recordMatchIfMutual(supabase, actorUserId, memberId, options = {}) {
    if (!actorUserId || !memberId || actorUserId === memberId) {
        return { matched: false, peer: null };
    }

    try {
        // Did they like us first?
        const reciprocal = await supabase
            .from('member_likes')
            .select('id, is_super_like, created_at')
            .eq('liker_id', memberId)
            .eq('liked_id', actorUserId)
            .maybeSingle();

        if (reciprocal.error || !reciprocal.data?.id) return { matched: false, peer: null };

        const [userOne, userTwo] = [actorUserId, memberId].sort();
        const inserted = await supabase
            .from('matches')
            .upsert({
                user_one_id: userOne,
                user_two_id: userTwo,
                source_key: options.superLike || reciprocal.data.is_super_like ? 'superlike' : 'like',
            }, { onConflict: 'user_one_id,user_two_id' })
            .select('id, created_at')
            .maybeSingle();

        if (inserted.error) return { matched: false, peer: null };

        // The peer's profile, so the client can show who it matched with
        // without a second round trip.
        const peer = await supabase
            .from('users')
            .select('id, display_name, username, avatar_url, photos, age, location, verified, verification_status')
            .eq('id', memberId)
            .maybeSingle();

        // Both sides get told. The liker sees it in the response; the person
        // who liked first is not looking at the app and needs the notification.
        try {
            await supabase.from('user_notifications').insert({
                user_id: memberId,
                type: 'match',
                title: 'It is a match',
                body: `You and ${String(options.actorName || 'someone').slice(0, 80)} liked each other. Say hello.`,
                metadata: { actorUserId, matchId: inserted.data?.id || null },
            });
        } catch { /* the match itself is what matters */ }

        return {
            matched: true,
            peer: peer.data ? normalizeMember(peer.data, { canViewPhone: false }) : null,
        };
    } catch {
        return { matched: false, peer: null };
    }
}

async function recordInteraction(supabase, userId, profileKey, action, details = {}) {
    if (!userId || !profileKey || !action) return;
    try {
        await supabase.from('user_interactions').upsert({
            user_id: userId,
            profile_key: String(profileKey).slice(0, 180),
            action,
            profile_name: String(details.profileName || details.name || '').slice(0, 120),
            profile_image: String(details.profileImage || details.imageUrl || '').slice(0, 500),
            is_super_like: Boolean(details.isSuperLike),
            metadata: details.metadata || {},
            updated_at: new Date().toISOString(),
        }, { onConflict: 'user_id,profile_key,action' });
    } catch {}
}

function parseDataUrl(dataUrl) {
    const match = String(dataUrl || '').match(/^data:([^;,]+)(?:;[^,]*)?;base64,(.+)$/);
    if (!match) return null;
    return {
        contentType: match[1],
        buffer: Buffer.from(match[2], 'base64'),
    };
}

async function uploadMessageAsset(supabase, rawUrl, { ownerId, type, name }) {
    if (!rawUrl || !String(rawUrl).startsWith('data:')) return rawUrl || '';
    const parsed = parseDataUrl(rawUrl);
    if (!parsed || parsed.buffer.length > 6 * 1024 * 1024) return rawUrl;

    const extMap = {
        'image/jpeg': 'jpg',
        'image/png': 'png',
        'image/webp': 'webp',
        'image/gif': 'gif',
        'audio/webm': 'webm',
        'audio/mp4': 'm4a',
        'audio/mpeg': 'mp3',
        'audio/wav': 'wav',
    };
    const ext = extMap[parsed.contentType] || (String(type).includes('voice') ? 'webm' : 'bin');
    const cleanOwner = String(ownerId || 'guest').replace(/[^a-zA-Z0-9-]/g, '').slice(0, 80) || 'guest';
    const cleanName = String(name || type || 'message').replace(/[^a-zA-Z0-9.-]/g, '-').slice(0, 80);
    const path = `${cleanOwner}/${Date.now()}-${Math.random().toString(36).slice(2)}-${cleanName}.${ext}`;

    try {
        const uploaded = await supabase.storage
            .from('message-attachments')
            .upload(path, parsed.buffer, { contentType: parsed.contentType, upsert: false });
        if (uploaded.error) return rawUrl;
        const { data } = supabase.storage.from('message-attachments').getPublicUrl(path);
        return data?.publicUrl || rawUrl;
    } catch {
        return rawUrl;
    }
}

function normalizeMember(member, { canViewPhone = false, includeEmail = false } = {}) {
    const phone = member.phone_number || member.phone || '';
    const verified = Boolean(member.verified || member.verification_status === 'verified');
    const lastSeenAt = livelySeedTime(member);
    const lastSeenMs = lastSeenAt ? new Date(lastSeenAt).getTime() : 0;
    const isOnline = Boolean(lastSeenMs && Date.now() - lastSeenMs < 3 * 60 * 1000);
    const isBoosted = activeBoost(member);

    return {
        id: member.id,
        username: member.username || `${makeUsername(member.display_name || member.email || 'member')}_${String(member.id || '').slice(0, 6)}`,
        name: getDisplayName(member),
        email: includeEmail ? (member.email || '') : '',
        avatarUrl: getPrimaryPhoto(member),
        photos: Array.isArray(member.photos) ? member.photos : [],
        bio: member.description || member.bio || '',
        age: member.age || null,
        location: member.location || member.city || member.country || '',
        country: member.country || '',
        city: member.city || '',
        latitude: member.latitude ?? null,
        longitude: member.longitude ?? null,
        geoUpdatedAt: member.geo_updated_at || null,
        profileLabel: member.profile_label || member.member_category || 'member',
        memberCategory: member.member_category || member.profile_label || 'member',
        lookingFor: member.looking_for || '',
        intentSummary: member.intent_summary || '',
        wants: member.wants || '',
        neededQualities: member.needed_qualities || '',
        ageRangePreference: member.age_range_preference || '',
        hobbies: Array.isArray(member.hobbies) ? member.hobbies : [],
        interests: Array.isArray(member.interests) ? member.interests : [],
        bodyType: member.body_type || '',
        subscriptionTier: member.subscription_tier || 'free',
        verified,
        verificationStatus: member.verification_status || (verified ? 'verified' : 'unsubmitted'),
        showInPublic: member.show_in_public !== false,
        adminApproved: Boolean(member.admin_approved),
        packageLocked: Boolean(member.package_locked),
        packageExpiresAt: member.package_expires_at || null,
        verificationSelfieUrl: member.verification_selfie_url || '',
        verificationDocumentUrl: member.verification_document_url || '',
        verificationDocumentType: member.verification_document_type || '',
        verificationPhone: member.verification_phone || '',
        verificationSubmittedAt: member.verification_submitted_at || null,
        verificationRejectionReason: member.verification_rejection_reason || '',
        phone: canViewPhone ? phone || null : null,
        phoneMasked: phone ? maskPhone(phone) : null,
        phoneLocked: Boolean(phone && !canViewPhone),
        totalProfileViews: member.total_profile_views || 0,
        followersCount: member.followers_count || 0,
        giftsReceivedCount: member.gifts_received_count || 0,
        isSeedProfile: Boolean(member.is_seed_profile),
        isBoosted,
        boostExpiresAt: member.boost_expires_at || null,
        boostScore: isBoosted ? Number(member.boost_score || 0) : 0,
        createdAt: member.created_at || null,
        lastSeenAt,
        isOnline,
    };
}

function applyFilters(query, searchParams, { fullSchema, directLookup = false }) {
    const search = searchParams.get('search')?.trim();
    const country = searchParams.get('country')?.trim();
    const label = searchParams.get('label')?.trim();
    const online = searchParams.get('mode') === 'online';
    const boosted = searchParams.get('boosted') === '1';

    if (fullSchema && !directLookup) {
        if (label && label !== 'all') query = query.eq('profile_label', label);
        if (country && country !== 'all') query = query.ilike('country', `%${country}%`);
        if (boosted) query = query.gt('boost_expires_at', new Date().toISOString());
        if (online) {
            const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
            query = query.gte('last_seen_at', fiveMinutesAgo);
        }
    }

    if (search) {
        const searchable = fullSchema
            ? `display_name.ilike.%${search}%,username.ilike.%${search}%,email.ilike.%${search}%,location.ilike.%${search}%,country.ilike.%${search}%,looking_for.ilike.%${search}%`
            : `display_name.ilike.%${search}%,email.ilike.%${search}%,location.ilike.%${search}%,country.ilike.%${search}%`;
        query = query.or(searchable);
    }

    return query;
}

async function fetchMembers(supabase, searchParams, { fullSchema }) {
    const id = searchParams.get('id');
    const usernameKey = String(searchParams.get('username') || '').trim().replace(/^@+/, '').toLowerCase();
    const directLookup = Boolean(id || usernameKey);
    const page = Math.max(parseInt(searchParams.get('page') || '1', 10), 1);
    const perPage = Math.min(Math.max(parseInt(searchParams.get('per_page') || '240', 10), 1), 240);
    const from = (page - 1) * perPage;
    const to = from + perPage - 1;

    let query = supabase
        .from('users')
        /*
          This asked for an exact count, which makes Postgres count every
          matching row on every directory request. The number is then used for
          exactly one thing: `(result.count || 0) > 0` in the schemaReady test
          below. The response's own `count` field is publicRows.length, not this.

          A planner estimate answers "are there any rows" just as well and costs
          nothing, so the scan goes away.
        */
        .select(fullSchema ? FULL_MEMBER_FIELDS : BASIC_MEMBER_FIELDS, { count: 'planned' });

    if (id) {
        const cleanId = String(id).trim();
        const usernameFromId = cleanId.replace(/^@+/, '').toLowerCase();
        if (/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(cleanId)) query = query.eq('id', cleanId);
        else if (fullSchema) query = query.ilike('username', usernameFromId);
        else query = query.eq('id', cleanId);
    }
    if (!id && usernameKey) query = fullSchema ? query.ilike('username', usernameKey) : query.eq('username', usernameKey);
    query = applyFilters(query, searchParams, { fullSchema, directLookup });
    if (fullSchema) query = query.order('boost_expires_at', { ascending: false, nullsFirst: false });
    query = query.order('created_at', { ascending: false }).range(from, to);

    return query;
}

function mixedMemberRows(rows) {
    const boosted = [];
    const real = [];
    const seeded = [];
    rows.forEach((row) => {
        if (activeBoost(row)) boosted.push(row);
        else if (row.is_seed_profile) seeded.push(row);
        else real.push(row);
    });
    boosted.sort((a, b) => (Number(b.boost_score || 0) - Number(a.boost_score || 0)) || new Date(b.boost_expires_at || 0) - new Date(a.boost_expires_at || 0));
    real.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
    seeded.sort((a, b) => stableHash(a.id) - stableHash(b.id));
    const mixed = [];
    const max = Math.max(real.length, seeded.length);
    for (let index = 0; index < max; index++) {
        if (real[index]) mixed.push(real[index]);
        if (seeded[index]) mixed.push(seeded[index]);
        if (seeded[index + max]) mixed.push(seeded[index + max]);
    }
    return [...boosted, ...mixed];
}

async function getViewerUnlock(supabase, searchParams) {
    const viewerId = searchParams.get('viewer_id');
    if (!viewerId) return false;

    const { data } = await supabase
        .from('users')
        .select('subscription_tier, admin_approved, package_locked')
        .eq('id', viewerId)
        .maybeSingle();

    return isUnlockedViewer(data);
}

export async function GET(request) {
    const supabase = createServerSupabaseClient({ admin: true }) || createServerSupabaseClient({ admin: false });

    if (!supabase) {
        return NextResponse.json({
            members: [],
            count: 0,
            setupRequired: true,
            error: 'Supabase environment variables are not configured.',
        }, { status: 503 });
    }

    const { searchParams } = new URL(request.url);
    const privateLookup = Boolean(searchParams.get('viewer_id') || searchParams.get('id') || searchParams.get('username'));
    const cacheControl = privateLookup ? 'private, max-age=20' : 'public, s-maxage=60, stale-while-revalidate=300';
    const canViewPhone = await getViewerUnlock(supabase, searchParams);

    let fullSchema = true;
    let result = await fetchMembers(supabase, searchParams, { fullSchema });

    if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
        fullSchema = false;
        result = await fetchMembers(supabase, searchParams, { fullSchema });
    }

    if (!fullSchema && searchParams.get('boosted') === '1') {
        return NextResponse.json({
            members: [],
            count: 0,
            schemaReady: false,
        }, {
            headers: { 'Cache-Control': cacheControl },
        });
    }

    if (result.error) {
        /*
          setupRequired was set on every error here, so a project restricted for
          exceeding its egress quota reported that its schema was missing and
          named a migration to run. That migration had been applied months
          earlier. The message sent people to re-run SQL against a healthy
          database while the real cause, a billing limit, went unmentioned.
        */
        const problem = classifySupabaseError(result.error);
        console.error('Members API error:', problem.kind, problem.actionable, result.error);
        return NextResponse.json({
            members: [],
            count: 0,
            // Only a genuinely absent schema should send anyone to the
            // migrations folder.
            setupRequired: problem.kind === 'schema',
            serviceRestricted: problem.kind === 'quota',
            error: problem.message,
        // 503 for a restriction: it is temporary and not this app's fault.
        }, { status: problem.kind === 'quota' ? 503 : 500 });
    }

    const rows = (result.data || []).filter((member) => member.is_banned !== true && member.is_suspended !== true);
    const directLookup = Boolean(searchParams.get('id') || searchParams.get('username'));
    const rowsWithPhotos = rows.filter(hasProfilePhoto);
    const publicRows = directLookup ? rows : mixedMemberRows(rowsWithPhotos.length ? rowsWithPhotos : rows);

    return NextResponse.json({
        members: publicRows.map((member) => normalizeMember(member, { canViewPhone, includeEmail: false })),
        count: publicRows.length,
        schemaReady: fullSchema || (result.count || 0) > 0,
    }, {
        headers: { 'Cache-Control': cacheControl },
    });
}


function profileLabelFromPreference(preference) {
    const value = String(preference || '');
    if (value.includes('sugar_daddy')) return 'sugar_daddy';
    if (value.includes('mistress')) return 'mistress';
    if (value.includes('toyboy')) return 'toyboy';
    return 'sugar_mummy';
}

function lookingForFromPreference(preference) {
    const value = String(preference || '');
    if (value.includes('sugar_daddy')) return 'mistress';
    if (value.includes('mistress')) return 'sugar_daddy';
    if (value.includes('toyboy')) return 'sugar_mummy';
    return 'toyboy';
}

function cleanDisplayName(value, email = '') {
    const emailText = String(email || '').trim().toLowerCase();
    const localPart = emailText.split('@')[0] || '';
    let name = String(value || '').trim().replace(/\s+/g, ' ').slice(0, 80);
    if (!name || name.includes('@') || name.toLowerCase() === emailText || name.toLowerCase() === localPart) {
        name = localPart
            ? localPart.replace(/[._-]+/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase()).slice(0, 40)
            : 'GS Member';
    }
    if (!name || name.includes('@')) name = 'GS Member';
    return name;
}

function makeUsername(value, fallback = 'member') {
    const raw = String(value || fallback || 'member')
        .trim()
        .toLowerCase()
        .replace(/@.*/, '')
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/^_+|_+$/g, '')
        .slice(0, 24);
    return raw || 'member';
}

async function uniqueUsername(supabase, desired, existingId = null) {
    const base = makeUsername(desired);
    for (let index = 0; index < 30; index++) {
        const suffix = index === 0 ? '' : `_${index + 1}`;
        const candidate = `${base.slice(0, Math.max(3, 24 - suffix.length))}${suffix}`;
        const result = await supabase
            .from('users')
            .select('id')
            .eq('username', candidate)
            .limit(1)
            .maybeSingle();
        if (result.error && ['42703', 'PGRST204', 'PGRST205'].includes(result.error.code)) return candidate;
        if (result.error && result.error.code !== 'PGRST116') return candidate;
        if (!result.data?.id || result.data.id === existingId) return candidate;
    }
    const tag = String(existingId || Date.now()).replace(/[^a-zA-Z0-9]/g, '').slice(0, 6).toLowerCase();
    return `${base.slice(0, 17)}_${tag || 'user'}`;
}

function accountPayload(body, { fullSchema = true } = {}) {
    const email = String(body.email || '').trim().toLowerCase();
    const profileLabel = body.profile_label || profileLabelFromPreference(body.preference);
    const lookingFor = body.looking_for || lookingForFromPreference(body.preference);
    const photos = Array.isArray(body.photos) ? body.photos.filter(Boolean).slice(0, 6) : [];
    const avatar = body.avatar_url || photos[0] || '';
    const phone = String(body.phone || body.phone_number || '').slice(0, 40);
    const profileComplete = Boolean(avatar && body.bio && body.age && body.location && phone);
    const base = {
        email,
        display_name: cleanDisplayName(body.display_name, email),
        avatar_url: avatar,
        photos,
        bio: String(body.bio || '').slice(0, 1200),
        description: String(body.description || body.bio || '').slice(0, 1200),
        age: body.age ? Number(body.age) : null,
        location: String(body.location || '').slice(0, 120),
        country: String(body.country || '').slice(0, 80),
        city: String(body.city || body.location || '').slice(0, 120),
        phone,
        phone_number: phone,
        profile_label: profileLabel,
        subscription_tier: String(body.subscription_tier || 'free').slice(0, 40),
        verified: false,
        verification_status: body.verification_submitted_at ? 'pending_admin' : 'unsubmitted',
        show_in_public: body.show_in_public === false ? false : profileComplete,
        is_banned: false,
        is_suspended: false,
        last_seen_at: new Date().toISOString(),
        last_seen: new Date().toISOString(),
    };

    if (!fullSchema) return base;

    return {
        ...base,
        username: makeUsername(body.username || body.display_name || email),
        member_category: profileLabel,
        auth_user_id: body.auth_user_id || body.supabase_auth_id || null,
        looking_for: lookingFor,
        intent_summary: body.intent_summary || `I am a ${profileLabel.replace(/_/g, ' ')} looking for ${lookingFor}.`,
        wants: String(body.wants || '').slice(0, 500),
        needed_qualities: String(body.needed_qualities || '').slice(0, 500),
        age_range_preference: String(body.age_range_preference || '').slice(0, 80),
        hobbies: Array.isArray(body.hobbies) ? body.hobbies.slice(0, 12) : [],
        interests: Array.isArray(body.interests) ? body.interests.slice(0, 12) : [],
        admin_approved: true,
        phone_reveal_plan: 'silver',
        package_locked: false,
        ...(Number.isFinite(Number(body.latitude)) ? { latitude: Number(body.latitude) } : {}),
        ...(Number.isFinite(Number(body.longitude)) ? { longitude: Number(body.longitude) } : {}),
        ...(body.geo_updated_at ? { geo_updated_at: body.geo_updated_at } : {}),
        verification_selfie_url: String(body.verification_selfie_url || '').slice(0, 2000000),
        verification_document_url: String(body.verification_document_url || '').slice(0, 2000000),
        verification_document_type: String(body.verification_document_type || '').slice(0, 40),
        verification_phone: String(body.verification_phone || body.phone_number || body.phone || '').slice(0, 40),
        verification_submitted_at: body.verification_submitted_at || null,
        verification_rejection_reason: '',
        is_seed_profile: false,
        ...(body.password ? { password_hash: hashPassword(body.password), password_updated_at: new Date().toISOString() } : {}),
    };
}

function accountCompletionError(body) {
    const photos = Array.isArray(body.photos) ? body.photos.filter(Boolean) : [];
    const avatar = body.avatar_url || photos[0] || '';
    const phone = String(body.phone || body.phone_number || '').replace(/\D/g, '');
    const age = Number(body.age);
    const name = cleanDisplayName(body.display_name, body.email);
    if (!avatar) return 'A clear profile photo is required before creating an account.';
    if (!name || name === 'GS Member') return 'A real profile name is required before creating an account.';
    if (!Number.isInteger(age) || age < 18 || age > 80) return 'Age must be between 18 and 80.';
    if (String(body.location || '').trim().length < 2) return 'City or area is required before creating an account.';
    if (phone.length < 7) return 'A valid phone number is required before creating an account.';
    if (String(body.bio || '').trim().length < 12) return 'A short bio is required before creating an account.';
    return '';
}

async function incrementUserCounter(supabase, memberId, column) {
    const { data, error } = await supabase.from('users').select(column).eq('id', memberId).maybeSingle();
    if (error) return { error };
    const nextValue = (data?.[column] || 0) + 1;
    return supabase.from('users').update({ [column]: nextValue }).eq('id', memberId).select(column).maybeSingle();
}

export async function POST(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) {
        return NextResponse.json({ error: 'Supabase admin environment variables are not configured.' }, { status: 503 });
    }

    const body = await request.json().catch(() => ({}));
    const action = body.action;
    const memberId = body.memberId;
    const actorKey = String(body.actorKey || 'guest').slice(0, 120);

    if (action === 'account_settings') {
        const userId = await resolveUserId(supabase, body);
        if (!userId) return NextResponse.json({ settings: normalizeSettings({}) });
        const settingsResult = await getUserSettings(supabase, userId);
        if (settingsResult?.error) return NextResponse.json({ error: 'User settings table is missing. Run supabase/migrations/20260626_080_user_alert_settings.sql.' }, { status: 500 });
        return NextResponse.json({ ok: true, settings: settingsResult.data || normalizeSettings({}) });
    }

    if (action === 'update_settings') {
        const userId = await resolveUserId(supabase, body);
        if (!userId) return NextResponse.json({ error: 'Account id or email is required.' }, { status: 400 });
        const payload = { user_id: userId, ...settingsPayload(body) };
        const result = await supabase
            .from('user_settings')
            .upsert(payload, { onConflict: 'user_id' })
            .select('*')
            .maybeSingle();
        if (result.error) return NextResponse.json({ error: 'User settings table is missing. Run supabase/migrations/20260626_080_user_alert_settings.sql.' }, { status: 500 });
        return NextResponse.json({ ok: true, settings: normalizeSettings(result.data) });
    }

    if (action === 'push_subscription') {
        const userId = await resolveUserId(supabase, body);
        if (!userId) return NextResponse.json({ error: 'Account id or email is required.' }, { status: 400 });
        const subscription = body.subscription || {};
        const endpoint = String(subscription.endpoint || body.endpoint || '').slice(0, 1000);
        if (!endpoint) return NextResponse.json({ error: 'Push subscription endpoint is required.' }, { status: 400 });
        const keys = subscription.keys || {};
        const payload = {
            user_id: userId,
            endpoint,
            p256dh: String(keys.p256dh || body.p256dh || '').slice(0, 500),
            auth: String(keys.auth || body.auth || '').slice(0, 500),
            platform: String(body.platform || 'web').slice(0, 80),
            permission: String(body.permission || 'granted').slice(0, 40),
            user_agent: String(body.userAgent || '').slice(0, 500),
            updated_at: new Date().toISOString(),
        };
        const result = await supabase.from('push_subscriptions').upsert(payload, { onConflict: 'endpoint' }).select('id').maybeSingle();
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, persisted: !result.error });
    }

    if (action === 'account_inbox') {
        const email = String(body.email || '').trim().toLowerCase();
        let userId = body.memberId || body.userId || null;
        if (!userId && email) {
            const { data: found } = await supabase.from('users').select('id').eq('email', email).maybeSingle();
            userId = found?.id || null;
        }
        if (!userId) return NextResponse.json({ notifications: [] });
        let result = await supabase
            .from('user_notifications')
            .select('id, type, title, body, read, metadata, created_at')
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .limit(100);
        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            result = await supabase
                .from('user_notifications')
                .select('id, type, title, body, read, created_at')
                .eq('user_id', userId)
                .order('created_at', { ascending: false })
                .limit(100);
        }
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, notifications: result.data || [] });
    }

    /*
      The real matches for an account.

      The matches screen used to request the whole member directory and relabel
      it, so it showed people who had never liked anybody. This returns rows
      from the matches table, which now actually gets written when two likes
      meet, with each peer's profile and any conversation already open with
      them so the screen can show a last message and go straight to the thread.
    */
    if (action === 'matches') {
        const userId = await resolveUserId(supabase, body);
        if (!userId) return NextResponse.json({ error: 'Account id or email is required.' }, { status: 400 });

        const limit = Math.min(Math.max(parseInt(body.limit || '60', 10), 1), 100);
        const rows = await supabase
            .from('matches')
            .select('id, user_one_id, user_two_id, created_at, source_key')
            // The pair is stored sorted, so this account can be on either side.
            .or(`user_one_id.eq.${userId},user_two_id.eq.${userId}`)
            .order('created_at', { ascending: false })
            .limit(limit);

        if (rows.error) {
            // The table is missing on an instance that has not run the
            // migrations. An empty list is a better answer than a 500.
            if (['42P01', 'PGRST205'].includes(rows.error.code)) {
                return NextResponse.json({ ok: true, matches: [], schemaReady: false });
            }
            return NextResponse.json({ error: rows.error.message }, { status: 500 });
        }

        const matchRows = rows.data || [];
        const peerIds = matchRows
            .map((row) => (row.user_one_id === userId ? row.user_two_id : row.user_one_id))
            .filter(Boolean);

        if (!peerIds.length) return NextResponse.json({ ok: true, matches: [], schemaReady: true });

        const [peers, conversations] = await Promise.all([
            supabase
                .from('users')
                .select('id, display_name, username, avatar_url, photos, age, location, city, country, verified, verification_status, subscription_tier, last_seen_at, is_seed_profile')
                .in('id', peerIds),
            supabase
                .from('conversations')
                .select('id, user_one_id, user_two_id, last_message_at')
                .or(`user_one_id.eq.${userId},user_two_id.eq.${userId}`),
        ]);

        const peerById = new Map((peers.data || []).map((row) => [row.id, row]));
        const conversationByPeer = new Map();
        (conversations.data || []).forEach((row) => {
            const other = row.user_one_id === userId ? row.user_two_id : row.user_one_id;
            if (other) conversationByPeer.set(other, row);
        });

        const matches = matchRows.map((row) => {
            const peerId = row.user_one_id === userId ? row.user_two_id : row.user_one_id;
            const peer = peerById.get(peerId);
            const conversation = conversationByPeer.get(peerId) || null;
            return {
                id: row.id,
                matchedAt: row.created_at,
                superLike: row.source_key === 'superlike',
                conversationId: conversation?.id || null,
                lastMessageAt: conversation?.last_message_at || null,
                member: peer ? normalizeMember(peer, { canViewPhone: false }) : null,
            };
        // A peer whose account was deleted leaves a match with nobody in it.
        }).filter((match) => match.member);

        return NextResponse.json({ ok: true, matches, schemaReady: true });
    }

    if (action === 'account_state') {
        const userId = await resolveUserId(supabase, body);
        if (!userId) return NextResponse.json({ ok: true, likes: [], matches: [], passes: [], saved: [], usage: {} });
        const today = new Date().toISOString().slice(0, 10);
        const [interactionsResult, savesResult, usageResult] = await Promise.all([
            supabase
                .from('user_interactions')
                .select('profile_key, action, profile_name, profile_image, is_super_like, metadata, created_at, updated_at')
                .eq('user_id', userId)
                .order('updated_at', { ascending: false })
                .limit(500),
            supabase
                .from('member_saves')
                .select('saved_key, saved_name, saved_image, created_at')
                .eq('user_id', userId)
                .order('created_at', { ascending: false })
                .limit(250),
            supabase
                .from('user_daily_usage')
                .select('kind, count')
                .eq('user_id', userId)
                .eq('usage_date', today),
        ]);
        const rows = interactionsResult.error ? [] : (interactionsResult.data || []);
        const mapInteraction = (row) => ({
            wpId: row.profile_key,
            name: row.profile_name || row.metadata?.name || 'Profile',
            imageUrl: row.profile_image || row.metadata?.imageUrl || '',
            likedAt: row.created_at,
            savedAt: row.created_at,
            matchedAt: row.created_at,
            super: Boolean(row.is_super_like),
            score: row.metadata?.score || null,
            source: row.metadata?.source || '',
        });
        const likes = rows.filter((row) => row.action === 'like' || row.action === 'superlike').map(mapInteraction);
        const matches = rows.filter((row) => row.action === 'match').map(mapInteraction);
        const passes = rows.filter((row) => row.action === 'pass' || row.action === 'swipe_pass').map((row) => row.profile_key);
        const interactionSaved = rows.filter((row) => row.action === 'save').map(mapInteraction);
        const tableSaved = savesResult.error ? [] : (savesResult.data || []).map((row) => ({
            wpId: row.saved_key,
            name: row.saved_name || 'Saved profile',
            imageUrl: row.saved_image || '',
            savedAt: row.created_at,
        }));
        const savedByKey = new Map([...interactionSaved, ...tableSaved].map((item) => [item.wpId, item]));
        const usage = {};
        if (!usageResult.error) (usageResult.data || []).forEach((row) => { usage[row.kind] = row.count || 0; });
        return NextResponse.json({ ok: true, likes, matches, passes, saved: Array.from(savedByKey.values()), usage });
    }

    if (action === 'account_reminders') {
        const userId = await resolveUserId(supabase, body);
        if (!userId) return NextResponse.json({ ok: true, created: 0 });
        const { data: account } = await supabase
            .from('users')
            .select('id, display_name, avatar_url, photos, bio, age, location, phone, phone_number, verified, verification_status, subscription_tier, admin_approved, package_locked')
            .eq('id', userId)
            .maybeSingle();
        if (!account?.id) return NextResponse.json({ ok: true, created: 0 });
        let created = 0;
        const hasPhoto = Boolean(account.avatar_url || (Array.isArray(account.photos) && account.photos[0]));
        const complete = Boolean(hasPhoto && account.bio && account.age && account.location && (account.phone || account.phone_number));
        if (!complete && await notifyOnceDaily(supabase, userId, {
            type: 'profile_reminder',
            title: 'Complete your GS profile',
            body: 'Add a profile photo, bio, age, location, and phone number so your account can appear properly in Members.',
        })) created++;
        if (account.verification_status !== 'verified' && await notifyOnceDaily(supabase, userId, {
            type: 'verification',
            title: 'Manual verification is available',
            body: 'Request your blue badge from Account by uploading a clear selfie, ID/passport, and phone number for admin review.',
        })) created++;
        const paid = Boolean(account.admin_approved && !account.package_locked && ['basic', 'silver', 'gold', 'diamond'].includes(String(account.subscription_tier || '').toLowerCase()));
        if (!paid && await notifyOnceDaily(supabase, userId, {
            type: 'package',
            title: 'Unlock premium GS features',
            body: 'Basic unlocks limited messaging and one chosen Telegram direct connection. Silver is recommended for phone reveal, stronger messaging, gifts, and priority support.',
        })) created++;
        return NextResponse.json({ ok: true, created });
    }

    if (action === 'refresh_account') {
        const email = String(body.email || '').trim().toLowerCase();
        const userId = body.memberId || body.userId || null;
        if (!email && !userId) return NextResponse.json({ error: 'Account id or email is required.' }, { status: 400 });

        let query = supabase.from('users').select(FULL_MEMBER_FIELDS);
        if (userId && email) query = query.eq('id', userId).eq('email', email);
        else if (userId) query = query.eq('id', userId);
        else query = query.eq('email', email);
        const result = await query.maybeSingle();

        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            return NextResponse.json({ error: 'Latest account fields are missing. Run the auth/package SQL migration.' }, { status: 500 });
        }
        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        if (!result.data) return NextResponse.json({ error: 'Account not found.' }, { status: 404 });
        await supabase.from('users').update({ last_seen_at: new Date().toISOString(), last_seen: new Date().toISOString() }).eq('id', result.data.id);
        return NextResponse.json({ ok: true, member: normalizeMember(result.data, { canViewPhone: true, includeEmail: true }) });
    }

    if (action === 'heartbeat') {
        const userId = await resolveUserId(supabase, body);
        if (!userId) return NextResponse.json({ ok: true, updated: false });
        const now = new Date().toISOString();
        const result = await supabase
            .from('users')
            .update({ last_seen_at: now, last_seen: now })
            .eq('id', userId)
            .select('id, last_seen_at')
            .maybeSingle();
        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, updated: Boolean(result.data?.id), lastSeenAt: result.data?.last_seen_at || now });
    }
    if (action === 'request_password_reset') {
        const email = String(body.email || '').trim().toLowerCase();
        if (!email || !email.includes('@')) return NextResponse.json({ error: 'A valid email is required.' }, { status: 400 });

        const { data: account, error: accountError } = await supabase
            .from('users')
            .select('id, email, display_name')
            .eq('email', email)
            .maybeSingle();
        if (accountError) return NextResponse.json({ error: accountError.message }, { status: 500 });

        if (!account?.id) {
            return NextResponse.json({ ok: true, message: 'If an account exists, a reset code has been sent.' });
        }

        const code = createResetCode();
        const expiresAt = new Date(Date.now() + 20 * 60 * 1000).toISOString();
        const payload = {
            user_id: account.id,
            email,
            code_hash: hashResetCode(email, code),
            expires_at: expiresAt,
        };
        const inserted = await supabase.from('password_reset_codes').insert(payload);
        if (inserted.error && inserted.error.code !== 'PGRST205') return NextResponse.json({ error: inserted.error.message }, { status: 500 });
        if (inserted.error?.code === 'PGRST205') return NextResponse.json({ error: 'Password reset table is missing. Run the latest SQL migration.' }, { status: 500 });

        const title = 'Reset your Genuine Sugar Mummies password';
        const text = `Your password reset code is ${code}. It expires in 20 minutes.`;
        await sendAndLogEmail(supabase, {
            to: email,
            subject: title,
            text,
            html: emailHtml(title, `<p>Use this reset code:</p><h2 style="letter-spacing:4px">${code}</h2><p>This code expires in 20 minutes.</p>`),
        });
        try { await supabase.from('admin_logs').insert({ action: 'password_reset_requested', details: { userId: account.id, email } }); } catch {}
        return NextResponse.json({ ok: true, message: 'Reset code sent to your email.' });
    }

    if (action === 'reset_password') {
        const email = String(body.email || '').trim().toLowerCase();
        const code = String(body.code || '').trim();
        const password = String(body.password || '');
        if (!email || !email.includes('@')) return NextResponse.json({ error: 'A valid email is required.' }, { status: 400 });
        if (!/^\d{6}$/.test(code)) return NextResponse.json({ error: 'Enter the 6-digit reset code.' }, { status: 400 });
        if (password.length < 6) return NextResponse.json({ error: 'New password must be at least 6 characters.' }, { status: 400 });

        const codeHash = hashResetCode(email, code);
        const codeResult = await supabase
            .from('password_reset_codes')
            .select('id, user_id, expires_at, used_at')
            .eq('email', email)
            .eq('code_hash', codeHash)
            .is('used_at', null)
            .gt('expires_at', new Date().toISOString())
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();
        if (codeResult.error && codeResult.error.code !== 'PGRST116') return NextResponse.json({ error: codeResult.error.message }, { status: 500 });
        if (!codeResult.data?.id) return NextResponse.json({ error: 'Invalid or expired reset code.' }, { status: 400 });

        const patch = { password_hash: hashPassword(password), password_updated_at: new Date().toISOString() };
        const updated = await supabase.from('users').update(patch).eq('id', codeResult.data.user_id).select(FULL_MEMBER_FIELDS).maybeSingle();
        if (updated.error) return NextResponse.json({ error: updated.error.message }, { status: 500 });
        await supabase.from('password_reset_codes').update({ used_at: new Date().toISOString() }).eq('id', codeResult.data.id);
        try { await supabase.from('user_notifications').insert({ user_id: codeResult.data.user_id, type: 'security', title: 'Password changed', body: 'Your password was reset successfully.' }); } catch {}
        return NextResponse.json({ ok: true, member: normalizeMember(updated.data, { canViewPhone: true, includeEmail: true }) });
    }
    if (action === 'login_account') {
        const email = String(body.email || '').trim().toLowerCase();
        const password = String(body.password || '');
        if (!email || !email.includes('@')) return NextResponse.json({ error: 'A valid email is required.' }, { status: 400 });
        if (password.length < 6) return NextResponse.json({ error: 'Password is required.' }, { status: 400 });

        let result = await supabase
            .from('users')
            .select(FULL_MEMBER_FIELDS)
            .eq('email', email)
            .maybeSingle();

        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            return NextResponse.json({ error: 'Password login needs the latest SQL migration. Add password_hash to users first.' }, { status: 500 });
        }

        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        if (!result.data) return NextResponse.json({ error: 'No account found for this email. Create an account first.' }, { status: 404 });
        if (!result.data.password_hash) return NextResponse.json({ error: 'This account has no password yet. Create a new account password first.' }, { status: 401 });
        if (!verifyPassword(password, result.data.password_hash)) return NextResponse.json({ error: 'Incorrect email or password.' }, { status: 401 });

        await supabase.from('users').update({ last_seen_at: new Date().toISOString(), last_seen: new Date().toISOString() }).eq('id', result.data.id);
        return NextResponse.json({ ok: true, member: normalizeMember(result.data, { canViewPhone: true, includeEmail: true }) });
    }

    if (action === 'upsert_account') {
        const email = String(body.email || '').trim().toLowerCase();
        if (!email || !email.includes('@')) return NextResponse.json({ error: 'A valid email is required.' }, { status: 400 });
        if (body.password && !body.id) {
            const completionError = accountCompletionError(body);
            if (completionError) return NextResponse.json({ error: completionError }, { status: 400 });
        }

        let existingAccount = await supabase
            .from('users')
            .select('id, username, password_hash, avatar_url, photos, verified, verification_status, admin_approved, package_locked, subscription_tier, package_expires_at, verification_selfie_url, verification_document_url, verification_phone, verification_submitted_at, auth_user_id')
            .eq('email', email)
            .maybeSingle();
        if (existingAccount.error && ['42703', 'PGRST204'].includes(existingAccount.error.code)) {
            existingAccount = await supabase
                .from('users')
                .select('id, password_hash, avatar_url, photos, verified, verification_status, admin_approved, package_locked, subscription_tier, package_expires_at, verification_selfie_url, verification_document_url, verification_phone, verification_submitted_at')
                .eq('email', email)
                .maybeSingle();
        }
        if (existingAccount.error && existingAccount.error.code !== 'PGRST116') return NextResponse.json({ error: existingAccount.error.message }, { status: 500 });
        const isProfileUpdate = Boolean(existingAccount.data?.id && body.id === existingAccount.data.id && !body.password);
        if (!isProfileUpdate) {
            if (String(body.password || '').length < 6) return NextResponse.json({ error: 'Create a password with at least 6 characters.' }, { status: 400 });
            if (existingAccount.data?.password_hash) return NextResponse.json({ error: 'This email already has an account. Please sign in.' }, { status: 409 });
            const completionError = accountCompletionError(body);
            if (completionError) return NextResponse.json({ error: completionError }, { status: 400 });
        }
        let payload = accountPayload(body, { fullSchema: true });
        payload.username = await uniqueUsername(supabase, body.username || existingAccount.data?.username || payload.username || body.display_name || email, existingAccount.data?.id || null);
        const oldProfilePhoto = getPrimaryPhoto(existingAccount.data || {});
        const newProfilePhoto = getPrimaryPhoto(payload);
        const profilePhotoChanged = Boolean(isProfileUpdate && existingAccount.data?.verified && oldProfilePhoto && oldProfilePhoto !== newProfilePhoto);
        if (isProfileUpdate) {
            if (profilePhotoChanged) {
                payload.verified = false;
                payload.verification_status = 'reverify_required';
                payload.verification_selfie_url = '';
                payload.verification_document_url = '';
                payload.verification_document_type = '';
                payload.verification_phone = '';
                payload.verification_submitted_at = null;
                payload.verification_rejection_reason = 'Profile photo changed. User must resubmit verification.';
            } else {
                delete payload.verified;
                delete payload.verification_status;
                delete payload.verification_selfie_url;
                delete payload.verification_document_url;
                delete payload.verification_phone;
                delete payload.verification_submitted_at;
            }
            delete payload.admin_approved;
            delete payload.package_locked;
            delete payload.subscription_tier;
            delete payload.package_expires_at;
        } else if (existingAccount.data?.id) {
            payload.verified = existingAccount.data.verified;
            payload.verification_status = existingAccount.data.verification_status || payload.verification_status;
            payload.admin_approved = existingAccount.data.admin_approved;
            payload.package_locked = existingAccount.data.package_locked;
            payload.subscription_tier = existingAccount.data.subscription_tier || payload.subscription_tier;
            payload.package_expires_at = existingAccount.data.package_expires_at || null;
        }
        let result = await supabase
            .from('users')
            .upsert(payload, { onConflict: 'email' })
            .select(FULL_MEMBER_FIELDS)
            .maybeSingle();

        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            payload = accountPayload(body, { fullSchema: false });
            delete payload.username;
            if (isProfileUpdate) {
                delete payload.verified;
                delete payload.verification_status;
            }
            result = await supabase
                .from('users')
                .upsert(payload, { onConflict: 'email' })
                .select(BASIC_MEMBER_FIELDS)
                .maybeSingle();
        }

        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        if (profilePhotoChanged && result.data?.id) {
            try {
                await supabase.from('user_notifications').insert({
                    user_id: result.data.id,
                    type: 'verification',
                    title: 'Verification reset',
                    body: 'Your profile photo changed. Please submit a new selfie, ID/passport, and phone details for badge review.',
                });
            } catch {}
        }
        const createdAccount = !existingAccount.data?.id;
        if (createdAccount && result.data?.id) {
            const welcomeTitle = 'Welcome to Genuine Sugar Mummies';
            const welcomeBody = 'Your account has been created. Complete your profile, upload a profile picture, submit manual verification, and choose a package when you are ready to unlock premium features.';
            try { await supabase.from('user_notifications').insert({ user_id: result.data.id, type: 'welcome', title: welcomeTitle, body: welcomeBody }); } catch {}
            await sendAndLogEmail(supabase, { to: email, subject: welcomeTitle, text: welcomeBody, html: emailHtml(welcomeTitle, welcomeBody) });
        }
        return NextResponse.json({ ok: true, member: normalizeMember({ ...payload, ...(result.data || {}) }, { canViewPhone: true, includeEmail: true }), createdAccount });
    }

    if (action === 'oauth_account') {
        const email = String(body.email || '').trim().toLowerCase();
        if (!email || !email.includes('@')) return NextResponse.json({ error: 'A valid Google email is required.' }, { status: 400 });
        const displayName = cleanDisplayName(body.display_name || body.name, email);
        let existing = await supabase.from('users').select(FULL_MEMBER_FIELDS).eq('email', email).maybeSingle();
        if (existing.error && ['42703', 'PGRST204'].includes(existing.error.code)) {
            existing = await supabase.from('users').select(BASIC_MEMBER_FIELDS).eq('email', email).maybeSingle();
        }
        if (existing.error && existing.error.code !== 'PGRST116') return NextResponse.json({ error: existing.error.message }, { status: 500 });
        if (existing.data?.id) {
            const patch = {
                last_seen_at: new Date().toISOString(),
                last_seen: new Date().toISOString(),
                ...(body.auth_user_id && !existing.data.auth_user_id ? { auth_user_id: body.auth_user_id } : {}),
            };
            const seenUpdate = await supabase.from('users').update(patch).eq('id', existing.data.id);
            if (seenUpdate.error && ['42703', 'PGRST204'].includes(seenUpdate.error.code)) {
                await supabase.from('users').update({ last_seen_at: patch.last_seen_at, last_seen: patch.last_seen }).eq('id', existing.data.id);
            }
            return NextResponse.json({ ok: true, member: normalizeMember(existing.data, { canViewPhone: true, includeEmail: true }), createdAccount: false });
        }
        const payload = accountPayload({
            email,
            display_name: displayName,
            avatar_url: body.avatar_url || '',
            photos: body.avatar_url ? [body.avatar_url] : [],
            preference: body.preference || 'toyboy_looking_for_sugar_mummy',
        }, { fullSchema: true });
        payload.username = await uniqueUsername(supabase, body.username || displayName || email);
        let result = await supabase.from('users').insert(payload).select(FULL_MEMBER_FIELDS).maybeSingle();
        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            const fallbackPayload = { ...payload };
            delete fallbackPayload.auth_user_id;
            delete fallbackPayload.username;
            result = await supabase.from('users').insert(fallbackPayload).select(BASIC_MEMBER_FIELDS).maybeSingle();
        }
        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        const welcomeTitle = 'Welcome to Genuine Sugar Mummies';
        const welcomeBody = 'Your Google sign-in is ready. Complete your profile, upload a profile picture, and request manual verification when you want a blue badge.';
        try { await supabase.from('user_notifications').insert({ user_id: result.data.id, type: 'welcome', title: welcomeTitle, body: welcomeBody }); } catch {}
        await sendAndLogEmail(supabase, { to: email, subject: welcomeTitle, text: welcomeBody, html: emailHtml(welcomeTitle, welcomeBody) });
        return NextResponse.json({ ok: true, member: normalizeMember({ ...payload, ...(result.data || {}) }, { canViewPhone: true, includeEmail: true }), createdAccount: true });
    }

    if (action === 'submit_verification') {
        const email = String(body.email || '').trim().toLowerCase();
        const selfie = String(body.verification_selfie_url || '').trim();
        const documentUrl = String(body.verification_document_url || '').trim();
        const phone = String(body.verification_phone || body.phone_number || body.phone || '').trim();
        if (!email && !memberId) return NextResponse.json({ error: 'Sign in before submitting verification.' }, { status: 400 });
        if (!selfie || !documentUrl || !phone) return NextResponse.json({ error: 'Selfie, ID/passport, and phone number are required.' }, { status: 400 });

        const patch = {
            verification_status: 'pending_admin',
            verified: false,
            verification_selfie_url: selfie.slice(0, 2000000),
            verification_document_url: documentUrl.slice(0, 2000000),
            verification_document_type: String(body.verification_document_type || 'id').slice(0, 40),
            verification_phone: phone.slice(0, 40),
            phone_number: phone.slice(0, 40),
            phone: phone.slice(0, 40),
            verification_submitted_at: new Date().toISOString(),
            verification_rejection_reason: '',
        };

        let result;
        if (memberId) result = await supabase.from('users').update(patch).eq('id', memberId).select(FULL_MEMBER_FIELDS).maybeSingle();
        else result = await supabase.from('users').update(patch).eq('email', email).select(FULL_MEMBER_FIELDS).maybeSingle();

        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            const fallbackPatch = { verification_status: 'pending_admin', verified: false, phone_number: phone.slice(0, 40), phone: phone.slice(0, 40) };
            result = memberId
                ? await supabase.from('users').update(fallbackPatch).eq('id', memberId).select(BASIC_MEMBER_FIELDS).maybeSingle()
                : await supabase.from('users').update(fallbackPatch).eq('email', email).select(BASIC_MEMBER_FIELDS).maybeSingle();
        }

        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        try { await supabase.from('admin_logs').insert({ action: 'verification_submitted', details: { userId: memberId || result.data?.id || null, email } }); } catch {}
        return NextResponse.json({ ok: true, member: normalizeMember(result.data || patch, { canViewPhone: true, includeEmail: true }) });
    }

    if (action === 'support_ticket') {
        const service = String(body.service || 'general').slice(0, 80);
        const email = String(body.email || '').trim().toLowerCase();
        let account = null;
        if (memberId) {
            const { data } = await supabase
                .from('users')
                .select('id, email, display_name')
                .eq('id', memberId)
                .maybeSingle();
            account = data || null;
        }
        if (!account?.id && email) {
            const { data } = await supabase
                .from('users')
                .select('id, email, display_name')
                .eq('email', email)
                .maybeSingle();
            account = data || null;
        }
        const recipientId = account?.id || memberId || null;
        const recipientEmail = account?.email || email;
        const recipientName = String(account?.display_name || body.display_name || body.senderName || 'Member').slice(0, 80);
        const ticketPayload = {
            user_id: recipientId,
            subject: String(body.subject || 'Support request').slice(0, 160),
            body: String(body.message || body.body || '').slice(0, 1200),
            service,
            status: 'open',
            priority: String(body.priority || 'normal').slice(0, 40),
        };
        if (ticketPayload.body.length < 3) return NextResponse.json({ error: 'Support message is too short.' }, { status: 400 });
        let result = await supabase.from('support_tickets').insert(ticketPayload).select('id, subject, status, created_at').maybeSingle();
        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            const fallbackPayload = { ...ticketPayload };
            delete fallbackPayload.service;
            result = await supabase.from('support_tickets').insert(fallbackPayload).select('id, subject, status, created_at').maybeSingle();
        }
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        const autoResponse = buildSupportAutoResponse(service, { name: recipientName, subject: ticketPayload.subject });
        const ticketId = result.data?.id || null;
        if (ticketId) {
            try {
                await supabase.from('ticket_responses').insert({
                    ticket_id: ticketId,
                    responder: autoResponse.senderLabel,
                    body: autoResponse.body,
                });
            } catch {}
        }
        if (recipientId) {
            try {
                await supabase.from('user_notifications').insert({
                    user_id: recipientId,
                    type: 'ticket_auto_response',
                    title: autoResponse.title,
                    body: autoResponse.body,
                    metadata: {
                        ticketId,
                        service: autoResponse.service,
                        team: autoResponse.team,
                        senderLabel: autoResponse.senderLabel,
                    },
                });
            } catch {}
        }
        if (recipientEmail) {
            await sendAndLogEmail(supabase, {
                to: recipientEmail,
                subject: autoResponse.title,
                text: autoResponse.body,
                html: emailHtml(autoResponse.title, autoResponse.body, {
                    preview: autoResponse.shortStatus,
                    actionUrl: 'https://genuinesugarmummies.com/alerts',
                    actionLabel: 'Open GS Inbox',
                }),
            });
        }
        try { await supabase.from('admin_logs').insert({ action: 'support_ticket_submitted', details: ticketPayload }); } catch {}
        return NextResponse.json({ ok: true, ticket: result.data || ticketPayload, autoResponse, persisted: !result.error });
    }

    if (action === 'request_package') {
        const tier = String(body.tier || 'basic').toLowerCase();
        const amount = tier === 'gold' ? 3550 : tier === 'silver' ? 1200 : 650;
        const paymentReference = String(body.payment_reference || '').trim();
        if (paymentReference.length < 3) return NextResponse.json({ error: 'Payment transaction ID is required before admin can approve a package.' }, { status: 400 });
        const requestPayload = {
            user_id: memberId || null,
            email: String(body.email || '').trim().toLowerCase(),
            display_name: String(body.display_name || body.senderName || 'Member').slice(0, 120),
            tier,
            amount_ksh: amount,
            status: 'pending',
            payment_reference: paymentReference.slice(0, 120),
            note: String(body.note || '').slice(0, 500),
        };
        const result = await supabase.from('package_requests').insert(requestPayload).select('id, tier, status, amount_ksh').maybeSingle();
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        const requestTitle = 'Package request received';
        const requestBody = `Your ${tier.toUpperCase()} package request with transaction ID ${paymentReference} is waiting for admin approval.`;
        if (memberId) {
            try { await supabase.from('user_notifications').insert({ user_id: memberId, type: 'package', title: requestTitle, body: requestBody }); } catch {}
        }
        if (requestPayload.email) await sendAndLogEmail(supabase, { to: requestPayload.email, subject: requestTitle, text: requestBody, html: emailHtml(requestTitle, requestBody) });
        try { await supabase.from('admin_logs').insert({ action: 'package_requested', details: requestPayload }); } catch {}
        return NextResponse.json({ ok: true, request: result.data || requestPayload, persisted: !result.error });
    }

    if (action === 'record_interaction') {
        const actorUserId = body.actorUserId || body.userId || null;
        const profileKey = String(body.profileKey || body.savedKey || memberId || '').slice(0, 180);
        const kind = String(body.kind || body.interaction || 'view').slice(0, 40);
        const usageKind = kind === 'superlike' ? 'superlikes' : kind === 'like' ? 'likes' : kind === 'pass' || kind === 'swipe_pass' ? 'swipes' : kind === 'message' ? 'messages' : 'views';
        const quota = await enforceDailyLimit(supabase, actorUserId, usageKind);
        if (!quota.ok) return NextResponse.json({ error: quota.message || LIMIT_NOTICE, ...quota }, { status: 402 });
        await recordInteraction(supabase, actorUserId, profileKey, kind, {
            profileName: body.profileName,
            profileImage: body.profileImage,
            isSuperLike: kind === 'superlike',
            metadata: { source: body.source || '', score: body.score || null },
        });
        return NextResponse.json({ ok: true, quota });
    }

    if (!action || !memberId) {
        return NextResponse.json({ error: 'Missing action or memberId.' }, { status: 400 });
    }

    if (action === 'like' || action === 'superlike') {
        const actorUserId = body.actorUserId || body.likerId || null;
        if (!memberId || !actorUserId) return NextResponse.json({ error: 'Signed-in user and member are required.' }, { status: 400 });
        if (memberId === actorUserId) return NextResponse.json({ error: 'You cannot like your own profile.' }, { status: 400 });
        const quota = await enforceDailyLimit(supabase, actorUserId, action === 'superlike' ? 'superlikes' : 'likes');
        if (!quota.ok) return NextResponse.json({ error: quota.message || LIMIT_NOTICE, ...quota }, { status: 402 });
        const result = await supabase.from('member_likes').upsert({
            liker_id: actorUserId,
            liked_id: memberId,
            is_super_like: action === 'superlike',
        }, { onConflict: 'liker_id,liked_id' });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        await recordInteraction(supabase, actorUserId, `member:${memberId}`, action, {
            profileName: body.profileName,
            profileImage: body.profileImage,
            isSuperLike: action === 'superlike',
            metadata: { score: body.score || null, source: 'member' },
        });
        /*
          A like is only half of a match.

          member_likes rows were being written and nothing ever read them back
          the other way, so a mutual like produced two independent likes and no
          match. The matches table has existed since 20260703_120 and had never
          been written to by any code. The matches screen listed every member
          instead, which is why it never resembled a matches screen.

          So: having recorded this like, look for the reciprocal one.
        */
        const match = await recordMatchIfMutual(supabase, actorUserId, memberId, {
            superLike: action === 'superlike',
            actorName: body.senderName,
        });

        try {
            await supabase.from('user_notifications').insert({
                user_id: memberId,
                type: match.matched ? 'match' : action,
                title: match.matched
                    ? 'It is a match'
                    : (action === 'superlike' ? 'New super like' : 'New like'),
                body: match.matched
                    ? `You and ${String(body.senderName || 'someone').slice(0, 80)} liked each other. Say hello.`
                    : `${String(body.senderName || 'Someone').slice(0, 80)} ${action === 'superlike' ? 'super liked' : 'liked'} your profile.`,
                metadata: { actorUserId },
            });
        } catch {}

        return NextResponse.json({
            ok: true,
            quota,
            persisted: !result.error,
            matched: match.matched,
            match: match.peer,
        });
    }

    if (action === 'swipe_pass') {
        const actorUserId = body.actorUserId || null;
        if (!memberId || !actorUserId) return NextResponse.json({ error: 'Signed-in user and member are required.' }, { status: 400 });
        const quota = await enforceDailyLimit(supabase, actorUserId, 'swipes');
        if (!quota.ok) return NextResponse.json({ error: quota.message || LIMIT_NOTICE, ...quota }, { status: 402 });
        const result = await supabase.from('member_swipes').upsert({
            swiper_id: actorUserId,
            swiped_id: memberId,
            direction: 'pass',
        }, { onConflict: 'swiper_id,swiped_id' });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        await recordInteraction(supabase, actorUserId, `member:${memberId}`, 'pass', { metadata: { source: 'member' } });
        return NextResponse.json({ ok: true, quota, persisted: !result.error });
    }

    if (action === 'save_profile') {
        const saverId = body.actorUserId || body.userId || null;
        const savedKey = String(body.savedKey || memberId || '').slice(0, 160);
        if (!saverId || !savedKey) return NextResponse.json({ error: 'Signed-in user and saved profile are required.' }, { status: 400 });
        const result = await supabase.from('member_saves').upsert({
            user_id: saverId,
            saved_member_id: memberId || null,
            saved_key: savedKey,
            saved_name: String(body.savedName || '').slice(0, 120),
            saved_image: String(body.savedImage || '').slice(0, 500),
        }, { onConflict: 'user_id,saved_key' });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        await recordInteraction(supabase, saverId, savedKey, 'save', {
            profileName: body.savedName,
            profileImage: body.savedImage,
            metadata: { source: body.source || (memberId ? 'member' : 'wp') },
        });
        return NextResponse.json({ ok: true, persisted: !result.error });
    }

    if (action === 'unsave_profile') {
        const saverId = body.actorUserId || body.userId || null;
        const savedKey = String(body.savedKey || memberId || '').slice(0, 160);
        if (!saverId || !savedKey) return NextResponse.json({ error: 'Signed-in user and saved profile are required.' }, { status: 400 });
        const result = await supabase.from('member_saves').delete().eq('user_id', saverId).eq('saved_key', savedKey);
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        try { await supabase.from('user_interactions').delete().eq('user_id', saverId).eq('profile_key', savedKey).eq('action', 'save'); } catch {}
        return NextResponse.json({ ok: true, persisted: !result.error });
    }
    if (action === 'view') {
        const viewerId = body.actorUserId || body.viewerId || body.userId || null;
        if (viewerId) {
            const quota = await enforceDailyLimit(supabase, viewerId, 'views');
            if (!quota.ok) return NextResponse.json({ error: quota.message || LIMIT_NOTICE, ...quota }, { status: 402 });
            await recordInteraction(supabase, viewerId, `member:${memberId}`, 'view', { metadata: { source: 'member' } });
            try {
                await supabase.from('profile_views').insert({
                    viewed_id: memberId,
                    viewer_id: viewerId,
                    viewer_key: viewerId,
                    source: 'member',
                });
            } catch {}
        }
        const result = await incrementUserCounter(supabase, memberId, 'total_profile_views');
        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, totalProfileViews: result.data?.total_profile_views || 0 });
    }

    if (action === 'follow') {
        const existing = await supabase
            .from('member_follows')
            .select('id')
            .eq('follower_key', actorKey)
            .eq('followed_id', memberId)
            .maybeSingle();

        if (existing.data?.id) {
            await supabase.from('member_follows').delete().eq('id', existing.data.id);
            const { data: member } = await supabase.from('users').select('followers_count').eq('id', memberId).maybeSingle();
            const nextCount = Math.max(0, (member?.followers_count || 0) - 1);
            await supabase.from('users').update({ followers_count: nextCount }).eq('id', memberId);
            return NextResponse.json({ ok: true, following: false, followersCount: nextCount });
        }

        const inserted = await supabase.from('member_follows').insert({ follower_key: actorKey, followed_id: memberId });
        if (inserted.error && inserted.error.code !== 'PGRST205') return NextResponse.json({ error: inserted.error.message }, { status: 500 });
        const result = await incrementUserCounter(supabase, memberId, 'followers_count');
        return NextResponse.json({ ok: true, following: true, followersCount: result.data?.followers_count || 0, persisted: !inserted.error });
    }

    if (action === 'message') {
        const text = String(body.message || '').trim();
        let attachmentUrl = String(body.attachmentUrl || body.attachment_url || '').trim();
        const attachmentType = String(body.attachmentType || body.attachment_type || '').trim().slice(0, 40);
        const attachmentName = String(body.attachmentName || body.attachment_name || '').trim().slice(0, 120);
        let voiceUrl = String(body.voiceUrl || body.voice_url || '').trim();
        if (text.length < 2 && !attachmentUrl && !voiceUrl) return NextResponse.json({ error: 'Message is too short.' }, { status: 400 });
        const senderUserId = body.actorUserId || body.senderUserId || null;
        const senderName = String(body.senderName || 'Member').slice(0, 80);
        const quota = await enforceDailyLimit(supabase, senderUserId, 'messages');
        if (!quota.ok) return NextResponse.json({ error: quota.message || LIMIT_NOTICE, ...quota }, { status: 402 });
        attachmentUrl = await uploadMessageAsset(supabase, attachmentUrl, { ownerId: senderUserId || actorKey, type: attachmentType || 'attachment', name: attachmentName });
        voiceUrl = await uploadMessageAsset(supabase, voiceUrl, { ownerId: senderUserId || actorKey, type: 'voice_note', name: attachmentName || 'voice-note' });
        const messagePayload = {
            member_id: memberId,
            sender_key: actorKey,
            sender_name: senderName,
            body: (text || (voiceUrl ? 'Voice note' : attachmentType === 'image' ? 'Image message' : attachmentType === 'gif' ? `GIF: ${attachmentName || 'reaction'}` : 'Media message')).slice(0, 600),
            attachment_url: attachmentUrl.slice(0, 2000000),
            attachment_type: attachmentType,
            attachment_name: attachmentName,
            voice_url: voiceUrl.slice(0, 2000000),
        };
        let result = await supabase.from('member_messages').insert(messagePayload);
        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            const fallbackPayload = { ...messagePayload };
            delete fallbackPayload.attachment_url;
            delete fallbackPayload.attachment_type;
            delete fallbackPayload.attachment_name;
            delete fallbackPayload.voice_url;
            result = await supabase.from('member_messages').insert(fallbackPayload);
        }
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        try {
            await supabase.from('user_notifications').insert({
                user_id: memberId,
                type: 'member_message',
                title: voiceUrl ? `New voice note from ${senderName}` : attachmentUrl ? `New media message from ${senderName}` : `New message from ${senderName}`,
                body: messagePayload.body,
                metadata: { senderUserId, senderKey: actorKey, attachmentType, attachmentName, hasVoice: Boolean(voiceUrl) },
            });
        } catch {}
        await recordInteraction(supabase, senderUserId, `member:${memberId}`, 'message', { profileName: body.profileName, metadata: { source: 'member', attachmentType, hasVoice: Boolean(voiceUrl) } });
        return NextResponse.json({ ok: true, quota, persisted: !result.error });
    }

    if (action === 'call_request') {
        const callType = String(body.callType || 'voice').slice(0, 20);
        const requesterName = String(body.senderName || 'Member').slice(0, 80);
        const result = await supabase.from('call_requests').insert({
            member_id: memberId,
            requester_key: actorKey,
            requester_name: requesterName,
            call_type: callType,
            status: 'pending',
            note: String(body.note || '').slice(0, 240),
        });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        try {
            await supabase.from('user_notifications').insert({
                user_id: memberId,
                type: 'call_request',
                title: `${callType === 'video' ? 'Video' : 'Voice'} call request`,
                body: `${requesterName} requested a ${callType} call. Admin can review the request.`,
                metadata: { requesterKey: actorKey },
            });
        } catch {}
        return NextResponse.json({ ok: true, persisted: !result.error });
    }

    if (action === 'gift') {
        const giftName = String(body.giftName || 'Rose').slice(0, 80);
        const emoji = String(body.emoji || ':rose:').slice(0, 40);
        const senderName = String(body.senderName || 'Member').slice(0, 80);
        const result = await supabase.from('member_gifts').insert({
            member_id: memberId,
            sender_key: actorKey,
            gift_name: giftName,
            emoji,
            message: String(body.message || '').slice(0, 240),
        });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        try {
            await supabase.from('user_notifications').insert({
                user_id: memberId,
                type: 'gift',
                title: `${senderName} sent a ${giftName}`,
                body: `${emoji} ${String(body.message || 'You received a gift.').slice(0, 240)}`,
                metadata: { senderKey: actorKey, giftName },
            });
        } catch {}
        const counter = await incrementUserCounter(supabase, memberId, 'gifts_received_count');
        return NextResponse.json({ ok: true, giftsReceivedCount: counter.data?.gifts_received_count || 0, persisted: !result.error });
    }

    return NextResponse.json({ error: 'Unsupported action.' }, { status: 400 });
}












