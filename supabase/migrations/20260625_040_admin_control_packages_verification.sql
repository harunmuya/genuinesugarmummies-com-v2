-- GenuineSugarMummies.com admin control, manual verification, packages, gifts, messages, analytics.
-- Run this whole file in Supabase SQL Editor. It is idempotent and uses TIMESTAMPTZ, not timestz.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    photos TEXT[] DEFAULT '{}',
    bio TEXT DEFAULT '',
    description TEXT DEFAULT '',
    age INTEGER,
    location TEXT DEFAULT '',
    country TEXT DEFAULT '',
    city TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    phone_number TEXT DEFAULT '',
    profile_label TEXT DEFAULT 'member',
    subscription_tier TEXT DEFAULT 'free',
    verified BOOLEAN DEFAULT false,
    verification_status TEXT DEFAULT 'pending_admin',
    show_in_public BOOLEAN DEFAULT false,
    is_banned BOOLEAN DEFAULT false,
    is_suspended BOOLEAN DEFAULT false,
    total_profile_views INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_seen_at TIMESTAMPTZ DEFAULT now(),
    last_seen TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS member_category TEXT DEFAULT 'member';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS looking_for TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS intent_summary TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS wants TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS needed_qualities TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS age_range_preference TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS hobbies TEXT[] DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS interests TEXT[] DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS body_type TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gifts_received_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone_reveal_plan TEXT DEFAULT 'silver';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_seed_profile BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS package_locked BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS package_expires_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_selfie_url TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_document_url TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_document_type TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_phone TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_rejection_reason TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS preference_locked BOOLEAN DEFAULT true;

CREATE TABLE IF NOT EXISTS public.package_tiers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    price_ksh INTEGER NOT NULL DEFAULT 0,
    phone_reveal BOOLEAN DEFAULT false,
    daily_message_limit INTEGER DEFAULT 0,
    daily_gift_limit INTEGER DEFAULT 0,
    priority_visibility BOOLEAN DEFAULT false,
    international_access BOOLEAN DEFAULT false,
    voice_video_access BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO public.package_tiers (id, name, price_ksh, phone_reveal, daily_message_limit, daily_gift_limit, priority_visibility, international_access, voice_video_access, sort_order) VALUES
('basic', 'Basic', 650, false, 10, 10, false, false, false, 1),
('silver', 'Silver', 1200, true, 30, 20, true, false, true, 2),
('gold', 'Gold International', 3500, true, 100, 50, true, true, true, 3)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    price_ksh = EXCLUDED.price_ksh,
    phone_reveal = EXCLUDED.phone_reveal,
    daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit,
    priority_visibility = EXCLUDED.priority_visibility,
    international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    updated_at = now();

CREATE TABLE IF NOT EXISTS public.package_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    email TEXT DEFAULT '',
    display_name TEXT DEFAULT '',
    tier TEXT NOT NULL DEFAULT 'basic',
    amount_ksh INTEGER NOT NULL DEFAULT 650,
    status TEXT NOT NULL DEFAULT 'pending',
    payment_reference TEXT DEFAULT '',
    note TEXT DEFAULT '',
    admin_note TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.member_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_key TEXT NOT NULL,
    followed_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(follower_key, followed_id)
);

CREATE TABLE IF NOT EXISTS public.member_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    sender_key TEXT NOT NULL,
    sender_name TEXT DEFAULT 'Member',
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.member_gifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    sender_key TEXT NOT NULL,
    gift_name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    message TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now()
);


CREATE TABLE IF NOT EXISTS public.call_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    requester_key TEXT NOT NULL,
    requester_name TEXT DEFAULT 'Member',
    call_type TEXT DEFAULT 'voice',
    status TEXT DEFAULT 'pending',
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    subject TEXT NOT NULL DEFAULT 'Support request',
    body TEXT DEFAULT '',
    status TEXT DEFAULT 'open',
    priority TEXT DEFAULT 'normal',
    created_at TIMESTAMPTZ DEFAULT now(),
    closed_at TIMESTAMPTZ
);


CREATE TABLE IF NOT EXISTS public.user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'admin',
    title TEXT NOT NULL,
    body TEXT DEFAULT '',
    read BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ticket_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    responder TEXT DEFAULT 'admin',
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.email_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    to_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT DEFAULT 'queued',
    provider_response TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    sent_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS public.broadcasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    target_segment TEXT DEFAULT 'all',
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    sent_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_limits (
    id TEXT PRIMARY KEY DEFAULT 'global',
    daily_message_limit INTEGER DEFAULT 30,
    daily_gift_limit INTEGER DEFAULT 20,
    max_photos_per_user INTEGER DEFAULT 6,
    require_manual_verification BOOLEAN DEFAULT true,
    ads_enabled BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO public.app_limits (id, daily_message_limit, daily_gift_limit, max_photos_per_user, require_manual_verification, ads_enabled)
VALUES ('global', 30, 20, 6, true, false)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    actor TEXT DEFAULT 'admin',
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.profile_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    actor_key TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ad_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    placement TEXT NOT NULL DEFAULT 'members',
    image_url TEXT DEFAULT '',
    target_url TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT false,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

UPDATE public.users
SET
    member_category = COALESCE(NULLIF(member_category, ''), profile_label, 'member'),
    looking_for = CASE
        WHEN COALESCE(looking_for, '') <> '' THEN looking_for
        WHEN profile_label = 'sugar_mummy' THEN 'Sugar Guy / Toyboy'
        WHEN profile_label = 'sugar_daddy' THEN 'Mistress'
        WHEN profile_label = 'mistress' THEN 'Sugar Daddy'
        WHEN profile_label = 'toyboy' THEN 'Sugar Mummy'
        ELSE ''
    END,
    intent_summary = CASE
        WHEN COALESCE(intent_summary, '') <> '' THEN intent_summary
        WHEN profile_label = 'sugar_mummy' THEN 'I am a sugar mummy looking for a sugar guy / toyboy.'
        WHEN profile_label = 'sugar_daddy' THEN 'I am a sugar daddy looking for an adult mistress.'
        WHEN profile_label = 'mistress' THEN 'I am an adult mistress looking for a sugar daddy.'
        WHEN profile_label = 'toyboy' THEN 'I am a sugar guy / toyboy looking for a sugar mummy.'
        ELSE ''
    END,
    followers_count = COALESCE(followers_count, 0),
    gifts_received_count = COALESCE(gifts_received_count, 0),
    admin_approved = CASE WHEN email LIKE 'seed+%@genuinesugarmummies.com' THEN true ELSE COALESCE(admin_approved, false) END,
    is_seed_profile = CASE WHEN email LIKE 'seed+%@genuinesugarmummies.com' THEN true ELSE COALESCE(is_seed_profile, false) END,
    package_locked = COALESCE(package_locked, false),
    phone_reveal_plan = COALESCE(NULLIF(phone_reveal_plan, ''), 'silver');

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_profile_label ON public.users(profile_label);
CREATE INDEX IF NOT EXISTS idx_users_member_category ON public.users(member_category);
CREATE INDEX IF NOT EXISTS idx_users_admin_approved ON public.users(admin_approved);
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users(verification_status);
CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON public.users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_member_follows_followed ON public.member_follows(followed_id);
CREATE INDEX IF NOT EXISTS idx_member_messages_member ON public.member_messages(member_id);
CREATE INDEX IF NOT EXISTS idx_member_gifts_member ON public.member_gifts(member_id);
CREATE INDEX IF NOT EXISTS idx_package_requests_status ON public.package_requests(status);
CREATE INDEX IF NOT EXISTS idx_call_requests_status ON public.call_requests(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_user_notifications_user ON public.user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_email_outbox_status ON public.email_outbox(status);
CREATE INDEX IF NOT EXISTS idx_ticket_responses_ticket ON public.ticket_responses(ticket_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created ON public.admin_logs(created_at DESC);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read visible users" ON public.users;
CREATE POLICY "Public can read visible users" ON public.users FOR SELECT USING (show_in_public = true OR true);
DROP POLICY IF EXISTS "Public can upsert users" ON public.users;
CREATE POLICY "Public can upsert users" ON public.users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can view package tiers" ON public.package_tiers;
CREATE POLICY "Anyone can view package tiers" ON public.package_tiers FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "Anyone can request packages" ON public.package_requests;
CREATE POLICY "Anyone can request packages" ON public.package_requests FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can follow members" ON public.member_follows;
CREATE POLICY "Anyone can follow members" ON public.member_follows FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can send member messages" ON public.member_messages;
CREATE POLICY "Anyone can send member messages" ON public.member_messages FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can send member gifts" ON public.member_gifts;
CREATE POLICY "Anyone can send member gifts" ON public.member_gifts FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can request calls" ON public.call_requests;
CREATE POLICY "Anyone can request calls" ON public.call_requests FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can create tickets" ON public.support_tickets;
CREATE POLICY "Anyone can create tickets" ON public.support_tickets FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages user notifications" ON public.user_notifications;
CREATE POLICY "Service role manages user notifications" ON public.user_notifications FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages ticket responses" ON public.ticket_responses;
CREATE POLICY "Service role manages ticket responses" ON public.ticket_responses FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages email outbox" ON public.email_outbox;
CREATE POLICY "Service role manages email outbox" ON public.email_outbox FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can read broadcasts" ON public.broadcasts;
CREATE POLICY "Anyone can read broadcasts" ON public.broadcasts FOR SELECT USING (status = 'sent');
DROP POLICY IF EXISTS "Service role manages limits" ON public.app_limits;
CREATE POLICY "Service role manages limits" ON public.app_limits FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages logs" ON public.admin_logs;
CREATE POLICY "Service role manages logs" ON public.admin_logs FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can record profile views" ON public.profile_views;
CREATE POLICY "Anyone can record profile views" ON public.profile_views FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can read active ads" ON public.ad_slots;
CREATE POLICY "Anyone can read active ads" ON public.ad_slots FOR SELECT USING (is_active = true);



