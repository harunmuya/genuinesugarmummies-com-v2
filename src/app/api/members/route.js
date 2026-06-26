import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { emailHtml, sendAndLogEmail } from '@/lib/email';
import { hashPassword, verifyPassword, createResetCode, hashResetCode } from '@/lib/security';

const FULL_MEMBER_FIELDS = `
    id,
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
    password_hash,
    created_at,
    last_seen_at,
    last_seen
`;

const BASIC_MEMBER_FIELDS = `
    id,
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

function maskPhone(phone) {
    if (!phone) return null;
    const digits = String(phone).replace(/\D/g, '');
    if (digits.length < 7) return 'Hidden';

    const prefix = phone.trim().startsWith('+') ? '+' : '';
    const visibleStart = digits.slice(0, Math.min(5, digits.length - 4));
    const visibleEnd = digits.slice(-2);
    return `${prefix}${visibleStart} ** *** ${visibleEnd}`;
}

function getDisplayName(member) {
    return member.display_name || member.email?.split('@')[0] || 'Member';
}

function getPrimaryPhoto(member) {
    if (member.avatar_url) return member.avatar_url;
    if (Array.isArray(member.photos) && member.photos[0]) return member.photos[0];
    return '';
}

function isUnlockedViewer(viewer) {
    if (!viewer) return false;
    const tier = String(viewer.subscription_tier || '').toLowerCase();
    return Boolean(viewer.admin_approved && !viewer.package_locked && UNLOCKED_PLANS.has(tier));
}

function normalizeMember(member, { canViewPhone = false } = {}) {
    const phone = member.phone_number || member.phone || '';
    const verified = Boolean(member.verified || member.verification_status === 'verified');

    return {
        id: member.id,
        name: getDisplayName(member),
        email: member.email || '',
        avatarUrl: getPrimaryPhoto(member),
        photos: Array.isArray(member.photos) ? member.photos : [],
        bio: member.description || member.bio || '',
        age: member.age || null,
        location: member.location || member.city || member.country || '',
        country: member.country || '',
        city: member.city || '',
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
        createdAt: member.created_at || null,
        lastSeenAt: member.last_seen_at || member.last_seen || null,
        isOnline: member.last_seen_at
            ? Date.now() - new Date(member.last_seen_at).getTime() < 5 * 60 * 1000
            : false,
    };
}

function applyFilters(query, searchParams, { fullSchema }) {
    const search = searchParams.get('search')?.trim();
    const country = searchParams.get('country')?.trim();
    const label = searchParams.get('label')?.trim();
    const online = searchParams.get('mode') === 'online';

    if (fullSchema) {
        query = query.eq('show_in_public', true)
            .eq('is_banned', false)
            .eq('is_suspended', false);

        if (label && label !== 'all') query = query.eq('profile_label', label);
        if (country && country !== 'all') query = query.ilike('country', `%${country}%`);
        if (online) {
            const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
            query = query.gte('last_seen_at', fiveMinutesAgo);
        }
    }

    if (search) {
        query = query.or(`display_name.ilike.%${search}%,email.ilike.%${search}%,location.ilike.%${search}%,country.ilike.%${search}%,looking_for.ilike.%${search}%`);
    }

    return query;
}

async function fetchMembers(supabase, searchParams, { fullSchema }) {
    const id = searchParams.get('id');
    const page = Math.max(parseInt(searchParams.get('page') || '1', 10), 1);
    const perPage = Math.min(Math.max(parseInt(searchParams.get('per_page') || '240', 10), 1), 240);
    const from = (page - 1) * perPage;
    const to = from + perPage - 1;

    let query = supabase
        .from('users')
        .select(fullSchema ? FULL_MEMBER_FIELDS : BASIC_MEMBER_FIELDS, { count: 'exact' });

    if (id) query = query.eq('id', id);
    query = applyFilters(query, searchParams, { fullSchema });
    query = query.order('created_at', { ascending: false }).range(from, to);

    return query;
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
    const canViewPhone = await getViewerUnlock(supabase, searchParams);

    let fullSchema = true;
    let result = await fetchMembers(supabase, searchParams, { fullSchema });

    if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
        fullSchema = false;
        result = await fetchMembers(supabase, searchParams, { fullSchema });
    }

    if (result.error) {
        console.error('Members API error:', result.error);
        return NextResponse.json({
            members: [],
            count: 0,
            setupRequired: true,
            error: result.error.message || 'Unable to load members.',
        }, { status: 500 });
    }

    return NextResponse.json({
        members: (result.data || []).map((member) => normalizeMember(member, { canViewPhone })),
        count: result.count || 0,
        schemaReady: fullSchema || (result.count || 0) > 0,
    }, {
        headers: { 'Cache-Control': 'private, max-age=20' },
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
    if (value.includes('sugar_daddy')) return 'Mistress';
    if (value.includes('mistress')) return 'Sugar Daddy';
    if (value.includes('toyboy')) return 'Sugar Mummy';
    return 'Sugar Guy / Toyboy';
}

function accountPayload(body, { fullSchema = true } = {}) {
    const email = String(body.email || '').trim().toLowerCase();
    const profileLabel = body.profile_label || profileLabelFromPreference(body.preference);
    const lookingFor = body.looking_for || lookingForFromPreference(body.preference);
    const photos = Array.isArray(body.photos) ? body.photos.filter(Boolean).slice(0, 6) : [];
    const avatar = body.avatar_url || photos[0] || '';
    const base = {
        email,
        display_name: String(body.display_name || email.split('@')[0] || 'Member').slice(0, 120),
        avatar_url: avatar,
        photos,
        bio: String(body.bio || '').slice(0, 1200),
        description: String(body.description || body.bio || '').slice(0, 1200),
        age: body.age ? Number(body.age) : null,
        location: String(body.location || '').slice(0, 120),
        country: String(body.country || '').slice(0, 80),
        city: String(body.city || body.location || '').slice(0, 120),
        phone: String(body.phone || body.phone_number || '').slice(0, 40),
        phone_number: String(body.phone_number || body.phone || '').slice(0, 40),
        profile_label: profileLabel,
        subscription_tier: String(body.subscription_tier || 'free').slice(0, 40),
        verified: false,
        verification_status: body.verification_submitted_at ? 'pending_admin' : 'unsubmitted',
        show_in_public: body.show_in_public === false ? false : Boolean(avatar && body.bio && body.age && body.location),
        is_banned: false,
        is_suspended: false,
        last_seen_at: new Date().toISOString(),
        last_seen: new Date().toISOString(),
    };

    if (!fullSchema) return base;

    return {
        ...base,
        member_category: profileLabel,
        looking_for: lookingFor,
        intent_summary: body.intent_summary || `I am a ${profileLabel.replace(/_/g, ' ')} looking for ${lookingFor}.`,
        wants: String(body.wants || '').slice(0, 500),
        needed_qualities: String(body.needed_qualities || '').slice(0, 500),
        age_range_preference: String(body.age_range_preference || '').slice(0, 80),
        hobbies: Array.isArray(body.hobbies) ? body.hobbies.slice(0, 12) : [],
        interests: Array.isArray(body.interests) ? body.interests.slice(0, 12) : [],
        admin_approved: false,
        phone_reveal_plan: 'silver',
        package_locked: false,
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

    if (action === 'account_inbox') {
        const email = String(body.email || '').trim().toLowerCase();
        let userId = body.memberId || body.userId || null;
        if (!userId && email) {
            const { data: found } = await supabase.from('users').select('id').eq('email', email).maybeSingle();
            userId = found?.id || null;
        }
        if (!userId) return NextResponse.json({ notifications: [] });
        const result = await supabase
            .from('user_notifications')
            .select('id, type, title, body, read, created_at')
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .limit(100);
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, notifications: result.data || [] });
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
        return NextResponse.json({ ok: true, member: normalizeMember(result.data, { canViewPhone: false }) });
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
        return NextResponse.json({ ok: true, member: normalizeMember(updated.data, { canViewPhone: true }) });
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
        return NextResponse.json({ ok: true, member: normalizeMember(result.data, { canViewPhone: true }) });
    }

    if (action === 'upsert_account') {
        const email = String(body.email || '').trim().toLowerCase();
        if (!email || !email.includes('@')) return NextResponse.json({ error: 'A valid email is required.' }, { status: 400 });

        const existingAccount = await supabase.from('users').select('id, password_hash').eq('email', email).maybeSingle();
        const isProfileUpdate = Boolean(existingAccount.data?.id && body.id === existingAccount.data.id && !body.password);
        if (!isProfileUpdate) {
            if (String(body.password || '').length < 6) return NextResponse.json({ error: 'Create a password with at least 6 characters.' }, { status: 400 });
            if (existingAccount.data?.password_hash) return NextResponse.json({ error: 'This email already has an account. Please sign in.' }, { status: 409 });
        }
        let payload = accountPayload(body, { fullSchema: true });
        let result = await supabase
            .from('users')
            .upsert(payload, { onConflict: 'email' })
            .select(FULL_MEMBER_FIELDS)
            .maybeSingle();

        if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
            payload = accountPayload(body, { fullSchema: false });
            result = await supabase
                .from('users')
                .upsert(payload, { onConflict: 'email' })
                .select(BASIC_MEMBER_FIELDS)
                .maybeSingle();
        }

        if (result.error) return NextResponse.json({ error: result.error.message }, { status: 500 });
        const createdAccount = !existingAccount.data?.id;
        if (createdAccount && result.data?.id) {
            const welcomeTitle = 'Welcome to Genuine Sugar Mummies';
            const welcomeBody = 'Your account has been created. Complete your profile, upload a profile picture, submit manual verification, and choose a package when you are ready to unlock premium features.';
            try { await supabase.from('user_notifications').insert({ user_id: result.data.id, type: 'welcome', title: welcomeTitle, body: welcomeBody }); } catch {}
            await sendAndLogEmail(supabase, { to: email, subject: welcomeTitle, text: welcomeBody, html: emailHtml(welcomeTitle, welcomeBody) });
        }
        return NextResponse.json({ ok: true, member: normalizeMember(result.data || payload, { canViewPhone: true }), createdAccount });
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
            admin_approved: false,
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
        return NextResponse.json({ ok: true, member: normalizeMember(result.data || patch, { canViewPhone: true }) });
    }

    if (action === 'support_ticket') {
        const ticketPayload = {
            user_id: memberId || null,
            subject: String(body.subject || 'Support request').slice(0, 160),
            body: String(body.message || body.body || '').slice(0, 1200),
            status: 'open',
            priority: String(body.priority || 'normal').slice(0, 40),
        };
        if (ticketPayload.body.length < 3) return NextResponse.json({ error: 'Support message is too short.' }, { status: 400 });
        const result = await supabase.from('support_tickets').insert(ticketPayload).select('id, subject, status, created_at').maybeSingle();
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        try { await supabase.from('admin_logs').insert({ action: 'support_ticket_submitted', details: ticketPayload }); } catch {}
        return NextResponse.json({ ok: true, ticket: result.data || ticketPayload, persisted: !result.error });
    }

    if (action === 'request_package') {
        const tier = String(body.tier || 'basic').toLowerCase();
        const amount = tier === 'gold' ? 3500 : tier === 'silver' ? 1200 : 650;
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

    if (!action || !memberId) {
        return NextResponse.json({ error: 'Missing action or memberId.' }, { status: 400 });
    }

    if (action === 'like' || action === 'superlike') {
        const actorUserId = body.actorUserId || body.likerId || null;
        if (!memberId || !actorUserId) return NextResponse.json({ error: 'Signed-in user and member are required.' }, { status: 400 });
        if (memberId === actorUserId) return NextResponse.json({ error: 'You cannot like your own profile.' }, { status: 400 });
        const result = await supabase.from('member_likes').upsert({
            liker_id: actorUserId,
            liked_id: memberId,
            is_super_like: action === 'superlike',
        }, { onConflict: 'liker_id,liked_id' });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        try {
            await supabase.from('user_notifications').insert({
                user_id: memberId,
                type: action,
                title: action === 'superlike' ? 'New super like' : 'New like',
                body: `${String(body.senderName || 'Someone').slice(0, 80)} ${action === 'superlike' ? 'super liked' : 'liked'} your profile.`,
                metadata: { actorUserId },
            });
        } catch {}
        return NextResponse.json({ ok: true, persisted: !result.error });
    }

    if (action === 'swipe_pass') {
        const actorUserId = body.actorUserId || null;
        if (!memberId || !actorUserId) return NextResponse.json({ error: 'Signed-in user and member are required.' }, { status: 400 });
        const result = await supabase.from('member_swipes').upsert({
            swiper_id: actorUserId,
            swiped_id: memberId,
            direction: 'pass',
        }, { onConflict: 'swiper_id,swiped_id' });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, persisted: !result.error });
    }
    if (action === 'view') {
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
        if (text.length < 2) return NextResponse.json({ error: 'Message is too short.' }, { status: 400 });
        const result = await supabase.from('member_messages').insert({
            member_id: memberId,
            sender_key: actorKey,
            sender_name: String(body.senderName || 'Member').slice(0, 80),
            body: text.slice(0, 600),
        });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, persisted: !result.error });
    }

    if (action === 'call_request') {
        const callType = String(body.callType || 'voice').slice(0, 20);
        const result = await supabase.from('call_requests').insert({
            member_id: memberId,
            requester_key: actorKey,
            requester_name: String(body.senderName || 'Member').slice(0, 80),
            call_type: callType,
            status: 'pending',
            note: String(body.note || '').slice(0, 240),
        });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        return NextResponse.json({ ok: true, persisted: !result.error });
    }

    if (action === 'gift') {
        const giftName = String(body.giftName || 'Rose').slice(0, 80);
        const emoji = String(body.emoji || ':rose:').slice(0, 40);
        const result = await supabase.from('member_gifts').insert({
            member_id: memberId,
            sender_key: actorKey,
            gift_name: giftName,
            emoji,
            message: String(body.message || '').slice(0, 240),
        });
        if (result.error && result.error.code !== 'PGRST205') return NextResponse.json({ error: result.error.message }, { status: 500 });
        const counter = await incrementUserCounter(supabase, memberId, 'gifts_received_count');
        return NextResponse.json({ ok: true, giftsReceivedCount: counter.data?.gifts_received_count || 0, persisted: !result.error });
    }

    return NextResponse.json({ error: 'Unsupported action.' }, { status: 400 });
}












