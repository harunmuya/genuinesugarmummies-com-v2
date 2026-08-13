-- GenuineSugarMummies.com real-app cleanup for manual verification, lifetime packages,
-- working queues, Google-created accounts, and admin-controlled actions.
-- Run this whole file in Supabase SQL Editor after the foundation migrations.

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
    verification_status TEXT DEFAULT 'unsubmitted',
    show_in_public BOOLEAN DEFAULT false,
    is_banned BOOLEAN DEFAULT false,
    is_suspended BOOLEAN DEFAULT false,
    total_profile_views INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_seen_at TIMESTAMPTZ DEFAULT now(),
    last_seen TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.users
    ALTER COLUMN verification_status SET DEFAULT 'unsubmitted';

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS member_category TEXT DEFAULT 'member';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS looking_for TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS intent_summary TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS wants TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS needed_qualities TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS age_range_preference TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS hobbies TEXT[] DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS interests TEXT[] DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gifts_received_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone_reveal_plan TEXT DEFAULT 'silver';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS package_locked BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS package_expires_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_selfie_url TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_document_url TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_document_type TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_phone TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_rejection_reason TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS preference_locked BOOLEAN DEFAULT true;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password_updated_at TIMESTAMPTZ;

UPDATE public.users
SET verification_status = 'unsubmitted'
WHERE COALESCE(verification_status, '') IN ('', 'pending_admin')
  AND COALESCE(verification_selfie_url, '') = ''
  AND COALESCE(verification_document_url, '') = '';

-- Do not revoke or reset existing verified users during migrations.
-- Reverification requests should be created from the admin panel per-user so real approvals are preserved.

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
    features JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '[]'::jsonb;

INSERT INTO public.package_tiers (id, name, price_ksh, phone_reveal, daily_message_limit, daily_gift_limit, priority_visibility, international_access, voice_video_access, sort_order, features)
VALUES
('basic', 'Basic', 650, false, 10, 10, false, false, false, 1, '["Lifetime Basic membership after admin approval","10 daily messages, 10 likes, and 10 swipes","Browse member photos and details","Send gifts and emojis","One chosen direct connection request facilitated by Admin Mary G on Telegram","No random connection - user chooses who to request"]'::jsonb),
('silver', 'Silver', 1200, true, 0, 50, true, false, true, 2, '["Recommended package","Lifetime Silver membership","Phone number reveal for profiles","Unlimited messaging after approval","More likes, swipes, saved profiles, gifts, and emojis","Voice and video call requests","Priority Admin Mary G support"]'::jsonb),
('gold', 'Gold International', 3500, true, 0, 100, true, true, true, 3, '["Lifetime Gold International membership","International and prominent users","Phone contacts and unlimited messaging","Premium gifts priority","Top placement after approval","Fastest admin support and guided connection assistance"]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    price_ksh = EXCLUDED.price_ksh,
    phone_reveal = EXCLUDED.phone_reveal,
    daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit,
    priority_visibility = EXCLUDED.priority_visibility,
    international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    features = EXCLUDED.features,
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

CREATE TABLE IF NOT EXISTS public.member_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    sender_key TEXT NOT NULL,
    sender_name TEXT DEFAULT 'Member',
    body TEXT NOT NULL,
    attachment_url TEXT DEFAULT '',
    attachment_type TEXT DEFAULT '',
    attachment_name TEXT DEFAULT '',
    voice_url TEXT DEFAULT '',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS attachment_url TEXT DEFAULT '';
ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS attachment_type TEXT DEFAULT '';
ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS attachment_name TEXT DEFAULT '';
ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS voice_url TEXT DEFAULT '';

CREATE TABLE IF NOT EXISTS public.member_gifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    sender_key TEXT NOT NULL,
    gift_name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    message TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.member_saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    saved_member_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    saved_key TEXT DEFAULT '',
    saved_name TEXT DEFAULT '',
    saved_image TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, saved_key)
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
    service TEXT DEFAULT 'general',
    status TEXT DEFAULT 'open',
    priority TEXT DEFAULT 'normal',
    created_at TIMESTAMPTZ DEFAULT now(),
    closed_at TIMESTAMPTZ
);
ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS service TEXT DEFAULT 'general';

CREATE TABLE IF NOT EXISTS public.ticket_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    responder TEXT DEFAULT 'admin',
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
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

CREATE TABLE IF NOT EXISTS public.user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    profile_key TEXT NOT NULL,
    action TEXT NOT NULL,
    profile_name TEXT DEFAULT '',
    profile_image TEXT DEFAULT '',
    is_super_like BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, profile_key, action)
);

CREATE TABLE IF NOT EXISTS public.user_daily_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
    kind TEXT NOT NULL,
    count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, usage_date, kind)
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
ON CONFLICT (id) DO UPDATE SET
    require_manual_verification = true,
    updated_at = now();

CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    notifications BOOLEAN DEFAULT true,
    email_notifications BOOLEAN DEFAULT false,
    dark_mode BOOLEAN DEFAULT false,
    show_online BOOLEAN DEFAULT true,
    show_age BOOLEAN DEFAULT true,
    is_public BOOLEAN DEFAULT true,
    live_location BOOLEAN DEFAULT false,
    location_enabled BOOLEAN DEFAULT false,
    push_token TEXT DEFAULT '',
    push_platform TEXT DEFAULT '',
    notification_permission TEXT DEFAULT 'default',
    preferences JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    actor TEXT DEFAULT 'admin',
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_verification_action_queue ON public.users(verification_status, verification_submitted_at);
CREATE INDEX IF NOT EXISTS idx_package_requests_pending ON public.package_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_open ON public.support_tickets(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_created ON public.user_notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_interactions_user_action ON public.user_interactions(user_id, action, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_daily_usage_user_date ON public.user_daily_usage(user_id, usage_date DESC);
CREATE INDEX IF NOT EXISTS idx_member_messages_member_created ON public.member_messages(member_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_gifts_member_created ON public.member_gifts(member_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_saves_user_created ON public.member_saves(user_id, created_at DESC);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_daily_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can upsert users" ON public.users;
CREATE POLICY "Public can upsert users" ON public.users FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can view package tiers" ON public.package_tiers;
CREATE POLICY "Anyone can view package tiers" ON public.package_tiers FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "Anyone can request packages" ON public.package_requests;
CREATE POLICY "Anyone can request packages" ON public.package_requests FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can send member messages" ON public.member_messages;
CREATE POLICY "Anyone can send member messages" ON public.member_messages FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can send member gifts" ON public.member_gifts;
CREATE POLICY "Anyone can send member gifts" ON public.member_gifts FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Users can save members" ON public.member_saves;
CREATE POLICY "Users can save members" ON public.member_saves FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can request calls" ON public.call_requests;
CREATE POLICY "Anyone can request calls" ON public.call_requests FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can create tickets" ON public.support_tickets;
CREATE POLICY "Anyone can create tickets" ON public.support_tickets FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages ticket responses" ON public.ticket_responses;
CREATE POLICY "Service role manages ticket responses" ON public.ticket_responses FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages user notifications" ON public.user_notifications;
CREATE POLICY "Service role manages user notifications" ON public.user_notifications FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages user interactions" ON public.user_interactions;
CREATE POLICY "Service role manages user interactions" ON public.user_interactions FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages user daily usage" ON public.user_daily_usage;
CREATE POLICY "Service role manages user daily usage" ON public.user_daily_usage FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Users can manage settings" ON public.user_settings;
CREATE POLICY "Users can manage settings" ON public.user_settings FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages limits" ON public.app_limits;
CREATE POLICY "Service role manages limits" ON public.app_limits FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role manages logs" ON public.admin_logs;
CREATE POLICY "Service role manages logs" ON public.admin_logs FOR ALL USING (true) WITH CHECK (true);
