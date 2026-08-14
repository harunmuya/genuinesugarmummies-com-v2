-- GS Global schema, part 1 of 3.
--
-- Paste into the Supabase SQL Editor and run. Do the parts in order and
-- wait for each to finish.
--
-- This is structure only: tables, policies, indexes and the package tiers.
-- The 181 demo profiles are separate, in seed-batch-*.sql, because they are
-- optional and were 273 KB of the original file on their own.
--
-- Safe to re-run: everything is IF NOT EXISTS / DROP POLICY IF EXISTS.


-- ==================================================================
-- 20260625_000_base_tables_for_new_project.sql
-- ==================================================================

-- Base schema for a fresh Supabase project.
-- Run before 20260625_foundation_social_rebuild.sql.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.direct_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant_one_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    participant_two_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT direct_conversations_distinct_participants
        CHECK (participant_one_id IS NULL OR participant_two_id IS NULL OR participant_one_id <> participant_two_id)
);

CREATE TABLE IF NOT EXISTS public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    body TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'general',
    title TEXT NOT NULL DEFAULT '',
    body TEXT DEFAULT '',
    data JSONB DEFAULT '{}',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at);
CREATE INDEX IF NOT EXISTS idx_direct_conversations_participant_one ON public.direct_conversations(participant_one_id);
CREATE INDEX IF NOT EXISTS idx_direct_conversations_participant_two ON public.direct_conversations(participant_two_id);
CREATE INDEX IF NOT EXISTS idx_direct_messages_conversation ON public.direct_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read users" ON public.users;
CREATE POLICY "Public can read users"
ON public.users
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can read own conversations" ON public.direct_conversations;
CREATE POLICY "Users can read own conversations"
ON public.direct_conversations
FOR SELECT
USING (auth.uid() = participant_one_id OR auth.uid() = participant_two_id);

DROP POLICY IF EXISTS "Users can read own direct messages" ON public.direct_messages;
CREATE POLICY "Users can read own direct messages"
ON public.direct_messages
FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can insert own direct messages" ON public.direct_messages;
CREATE POLICY "Users can insert own direct messages"
ON public.direct_messages
FOR INSERT
WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications"
ON public.notifications
FOR SELECT
USING (auth.uid() = user_id);

-- ==================================================================
-- 20260625_030_missing_member_features.sql
-- ==================================================================

﻿-- Run this in Supabase SQL Editor after the base users table exists.

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
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_seed_profile BOOLEAN DEFAULT false;

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
    wants = CASE
        WHEN COALESCE(wants, '') <> '' THEN wants
        WHEN profile_label = 'sugar_mummy' THEN 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.'
        WHEN profile_label = 'sugar_daddy' THEN 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.'
        WHEN profile_label = 'mistress' THEN 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.'
        ELSE ''
    END,
    needed_qualities = CASE
        WHEN COALESCE(needed_qualities, '') <> '' THEN needed_qualities
        ELSE 'respectful, discreet, honest, consistent, serious about meeting'
    END,
    age_range_preference = CASE
        WHEN COALESCE(age_range_preference, '') <> '' THEN age_range_preference
        WHEN profile_label = 'sugar_mummy' THEN '21-34'
        WHEN profile_label = 'sugar_daddy' THEN '21-35'
        WHEN profile_label = 'mistress' THEN '38-68'
        ELSE ''
    END,
    hobbies = CASE WHEN hobbies IS NULL OR array_length(hobbies, 1) IS NULL THEN ARRAY['travel','fine dining','music','weekend dates']::TEXT[] ELSE hobbies END,
    interests = CASE WHEN interests IS NULL OR array_length(interests, 1) IS NULL THEN ARRAY['meaningful conversations','discreet connection','premium experiences']::TEXT[] ELSE interests END,
    followers_count = COALESCE(followers_count, 0),
    gifts_received_count = COALESCE(gifts_received_count, 0),
    admin_approved = CASE WHEN email LIKE 'seed+%@genuinesugarmummies.com' THEN true ELSE COALESCE(admin_approved, false) END,
    is_seed_profile = CASE WHEN email LIKE 'seed+%@genuinesugarmummies.com' THEN true ELSE COALESCE(is_seed_profile, false) END;

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

CREATE INDEX IF NOT EXISTS idx_member_follows_followed ON public.member_follows(followed_id);
CREATE INDEX IF NOT EXISTS idx_member_messages_member ON public.member_messages(member_id);
CREATE INDEX IF NOT EXISTS idx_member_gifts_member ON public.member_gifts(member_id);
CREATE INDEX IF NOT EXISTS idx_users_member_category ON public.users(member_category);
CREATE INDEX IF NOT EXISTS idx_users_admin_approved ON public.users(admin_approved);

ALTER TABLE public.member_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_gifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can follow members" ON public.member_follows;
CREATE POLICY "Anyone can follow members" ON public.member_follows FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can send member messages" ON public.member_messages;
CREATE POLICY "Anyone can send member messages" ON public.member_messages FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can send member gifts" ON public.member_gifts;
CREATE POLICY "Anyone can send member gifts" ON public.member_gifts FOR ALL USING (true) WITH CHECK (true);

-- ==================================================================
-- 20260625_040_admin_control_packages_verification.sql
-- ==================================================================

﻿-- GenuineSugarMummies.com admin control, manual verification, packages, gifts, messages, analytics.
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
('silver', 'Silver Recommended', 1200, true, 0, 50, true, false, true, 2),
('gold', 'Gold International', 3500, true, 0, 100, true, true, true, 3)
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

-- ==================================================================
-- 20260625_060_auth_email_admin_packages.sql
-- ==================================================================

﻿-- Genuine Sugar Mummies auth, email, admin actions, and package unlock support
-- Run this in Supabase SQL Editor after the foundation migration.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Auth/password columns for real email + password login.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password_updated_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS package_locked BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS package_expires_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone_reveal_plan TEXT DEFAULT 'silver';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending_admin';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_selfie_url TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_document_url TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_document_type TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_phone TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_rejection_reason TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_in_public BOOLEAN DEFAULT true;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gifts_received_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_profile_views INTEGER DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique ON public.users (lower(email));
CREATE INDEX IF NOT EXISTS idx_users_password_hash ON public.users (password_hash) WHERE password_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_package_access ON public.users (subscription_tier, admin_approved, package_locked);
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users (verification_status);

CREATE TABLE IF NOT EXISTS public.user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'admin',
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    read BOOLEAN DEFAULT false,
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

CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT DEFAULT 'open',
    priority TEXT DEFAULT 'normal',
    created_at TIMESTAMPTZ DEFAULT now(),
    closed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.ticket_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    responder TEXT DEFAULT 'admin',
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.package_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    email TEXT,
    display_name TEXT,
    tier TEXT NOT NULL,
    amount_ksh INTEGER NOT NULL,
    status TEXT DEFAULT 'pending',
    payment_reference TEXT NOT NULL,
    note TEXT DEFAULT '',
    admin_note TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.broadcasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    target_segment TEXT DEFAULT 'all',
    status TEXT DEFAULT 'sent',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
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

CREATE TABLE IF NOT EXISTS public.member_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sender_key TEXT NOT NULL,
    sender_name TEXT DEFAULT 'Member',
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.member_gifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sender_key TEXT NOT NULL,
    gift_name TEXT NOT NULL,
    emoji TEXT DEFAULT '',
    message TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.member_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_key TEXT NOT NULL,
    followed_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (follower_key, followed_id)
);

CREATE TABLE IF NOT EXISTS public.call_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    requester_key TEXT NOT NULL,
    requester_name TEXT DEFAULT 'Member',
    call_type TEXT DEFAULT 'voice',
    status TEXT DEFAULT 'pending',
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO public.app_limits (id, daily_message_limit, daily_gift_limit, max_photos_per_user, require_manual_verification, ads_enabled)
VALUES ('global', 30, 20, 6, true, false)
ON CONFLICT (id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_user_notifications_user ON public.user_notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_outbox_status ON public.email_outbox(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ticket_responses_ticket ON public.ticket_responses(ticket_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_package_requests_status ON public.package_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_messages_member ON public.member_messages(member_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_gifts_member ON public.member_gifts(member_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_requests_status ON public.call_requests(status, created_at DESC);

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service role manages user_notifications" ON public.user_notifications;
CREATE POLICY "service role manages user_notifications" ON public.user_notifications FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages email_outbox" ON public.email_outbox;
CREATE POLICY "service role manages email_outbox" ON public.email_outbox FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages support_tickets" ON public.support_tickets;
CREATE POLICY "service role manages support_tickets" ON public.support_tickets FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages ticket_responses" ON public.ticket_responses;
CREATE POLICY "service role manages ticket_responses" ON public.ticket_responses FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages package_requests" ON public.package_requests;
CREATE POLICY "service role manages package_requests" ON public.package_requests FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages broadcasts" ON public.broadcasts;
CREATE POLICY "service role manages broadcasts" ON public.broadcasts FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages admin_logs" ON public.admin_logs;
CREATE POLICY "service role manages admin_logs" ON public.admin_logs FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages app_limits" ON public.app_limits;
CREATE POLICY "service role manages app_limits" ON public.app_limits FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages member_messages" ON public.member_messages;
CREATE POLICY "service role manages member_messages" ON public.member_messages FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages member_gifts" ON public.member_gifts;
CREATE POLICY "service role manages member_gifts" ON public.member_gifts FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages member_follows" ON public.member_follows;
CREATE POLICY "service role manages member_follows" ON public.member_follows FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service role manages call_requests" ON public.call_requests;
CREATE POLICY "service role manages call_requests" ON public.call_requests FOR ALL USING (true) WITH CHECK (true);

-- ==================================================================
-- 20260625_foundation_social_rebuild.sql
-- ==================================================================

-- Foundation migration for the GenuineSugarMummies social rebuild.
-- Run this in Supabase SQL editor or through the Supabase CLI before enabling the new Members UI.

-- ==========================================
-- Existing table extensions
-- ==========================================

ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS photos TEXT[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS location TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS country TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS city TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS profile_label TEXT DEFAULT 'member';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS relationship_status TEXT DEFAULT 'single';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS body_type TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS height TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS education TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS occupation TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS income_range TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS smoking TEXT DEFAULT 'no';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS drinking TEXT DEFAULT 'social';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS children TEXT DEFAULT 'none';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS languages TEXT[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS show_in_public BOOLEAN DEFAULT true;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMPTZ;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS ban_reason TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS total_profile_views INTEGER DEFAULT 0;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS tokens INTEGER DEFAULT 0;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES public.users(id);
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

ALTER TABLE IF EXISTS public.direct_messages ADD COLUMN IF NOT EXISTS reply_to UUID REFERENCES public.direct_messages(id);
ALTER TABLE IF EXISTS public.direct_messages ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS public.direct_messages ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS public.direct_messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS public.direct_messages ADD COLUMN IF NOT EXISTS reactions JSONB DEFAULT '[]';

-- ==========================================
-- New tables
-- ==========================================

CREATE TABLE IF NOT EXISTS public.profile_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    viewer_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    viewed_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    viewed_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(viewer_id, viewed_id)
);

CREATE TABLE IF NOT EXISTS public.member_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liker_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    liked_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    is_super_like BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(liker_id, liked_id)
);

CREATE TABLE IF NOT EXISTS public.gifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    description TEXT DEFAULT '',
    cost_tokens INTEGER NOT NULL,
    cost_ksh NUMERIC DEFAULT 0,
    category TEXT DEFAULT 'standard',
    image_url TEXT,
    is_animated BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    required_plan TEXT DEFAULT 'silver',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sent_gifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    gift_id UUID REFERENCES public.gifts(id) NOT NULL,
    message TEXT DEFAULT '',
    tokens_spent INTEGER NOT NULL,
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.token_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    amount INTEGER NOT NULL,
    type TEXT NOT NULL,
    description TEXT DEFAULT '',
    reference_id UUID,
    balance_after INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.token_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    tokens INTEGER NOT NULL,
    price_ksh NUMERIC NOT NULL,
    bonus_tokens INTEGER DEFAULT 0,
    is_popular BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.typing_indicators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    is_typing BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name TEXT DEFAULT 'Admin',
    role TEXT DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin', 'moderator', 'support')),
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.admin_users(id),
    admin_email TEXT NOT NULL,
    action TEXT NOT NULL,
    target_type TEXT,
    target_id TEXT,
    details JSONB DEFAULT '{}',
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.auto_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    trigger_after_hours INTEGER,
    target_plans TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.email_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    to_email TEXT NOT NULL,
    from_name TEXT DEFAULT 'GenuineSugarMummies',
    from_email TEXT DEFAULT 'noreply@genuinesugarmummies.com',
    subject TEXT NOT NULL,
    html_body TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'bounced')),
    provider TEXT DEFAULT 'resend',
    provider_id TEXT,
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    badge_type TEXT NOT NULL,
    badge_label TEXT,
    badge_color TEXT DEFAULT '#FFD700',
    granted_by UUID REFERENCES public.admin_users(id),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, badge_type)
);

-- ==========================================
-- Indexes
-- ==========================================

CREATE INDEX IF NOT EXISTS idx_profile_views_viewed ON public.profile_views(viewed_id);
CREATE INDEX IF NOT EXISTS idx_profile_views_viewer ON public.profile_views(viewer_id);
CREATE INDEX IF NOT EXISTS idx_member_likes_liked ON public.member_likes(liked_id);
CREATE INDEX IF NOT EXISTS idx_member_likes_liker ON public.member_likes(liker_id);
CREATE INDEX IF NOT EXISTS idx_sent_gifts_receiver ON public.sent_gifts(receiver_id);
CREATE INDEX IF NOT EXISTS idx_sent_gifts_sender ON public.sent_gifts(sender_id);
CREATE INDEX IF NOT EXISTS idx_token_transactions_user ON public.token_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_conv ON public.typing_indicators(conversation_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin ON public.admin_audit_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created ON public.admin_audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_email_queue_status ON public.email_queue(status);
CREATE INDEX IF NOT EXISTS idx_email_queue_user ON public.email_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_user ON public.user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_users_show_in_public ON public.users(show_in_public);
CREATE INDEX IF NOT EXISTS idx_users_is_banned ON public.users(is_banned);
CREATE INDEX IF NOT EXISTS idx_users_profile_label ON public.users(profile_label);
CREATE INDEX IF NOT EXISTS idx_users_last_seen_at ON public.users(last_seen_at);

-- ==========================================
-- Row level security and policies
-- ==========================================

ALTER TABLE public.profile_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sent_gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auto_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own views" ON public.profile_views;
CREATE POLICY "Users can insert own views" ON public.profile_views FOR INSERT WITH CHECK (auth.uid() = viewer_id);
DROP POLICY IF EXISTS "Users can see profile views" ON public.profile_views;
CREATE POLICY "Users can see profile views" ON public.profile_views FOR SELECT USING (auth.uid() = viewed_id OR auth.uid() = viewer_id);

DROP POLICY IF EXISTS "Users can manage own likes" ON public.member_likes;
CREATE POLICY "Users can manage own likes" ON public.member_likes FOR ALL USING (auth.uid() = liker_id) WITH CHECK (auth.uid() = liker_id);
DROP POLICY IF EXISTS "Users can see likes on them" ON public.member_likes;
CREATE POLICY "Users can see likes on them" ON public.member_likes FOR SELECT USING (auth.uid() = liked_id OR auth.uid() = liker_id);

DROP POLICY IF EXISTS "Anyone can view active gifts" ON public.gifts;
CREATE POLICY "Anyone can view active gifts" ON public.gifts FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Users can send gifts" ON public.sent_gifts;
CREATE POLICY "Users can send gifts" ON public.sent_gifts FOR INSERT WITH CHECK (auth.uid() = sender_id);
DROP POLICY IF EXISTS "Users can see own gifts" ON public.sent_gifts;
CREATE POLICY "Users can see own gifts" ON public.sent_gifts FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can see own token history" ON public.token_transactions;
CREATE POLICY "Users can see own token history" ON public.token_transactions FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view active token packages" ON public.token_packages;
CREATE POLICY "Anyone can view active token packages" ON public.token_packages FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Users can manage own typing" ON public.typing_indicators;
CREATE POLICY "Users can manage own typing" ON public.typing_indicators FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Authenticated users can read typing" ON public.typing_indicators;
CREATE POLICY "Authenticated users can read typing" ON public.typing_indicators FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Anyone can view badges" ON public.user_badges;
CREATE POLICY "Anyone can view badges" ON public.user_badges FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users view own emails" ON public.email_queue;
CREATE POLICY "Users view own emails" ON public.email_queue FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated users can read auto messages" ON public.auto_messages;
CREATE POLICY "Authenticated users can read auto messages" ON public.auto_messages FOR SELECT USING (auth.role() = 'authenticated');

-- Lock app_settings down if the table already exists.
DO $$
BEGIN
    IF to_regclass('public.app_settings') IS NOT NULL THEN
        ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Open app settings" ON public.app_settings;
        DROP POLICY IF EXISTS "Authenticated app settings read" ON public.app_settings;
        CREATE POLICY "Authenticated app settings read" ON public.app_settings FOR SELECT USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- Ensure users can insert payment transactions when the existing table is present.
DO $$
BEGIN
    IF to_regclass('public.transactions') IS NOT NULL THEN
        ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Users can create own transactions" ON public.transactions;
        CREATE POLICY "Users can create own transactions" ON public.transactions FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

-- ==========================================
-- Realtime publications
-- ==========================================

DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications; EXCEPTION WHEN duplicate_object OR undefined_table THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.typing_indicators; EXCEPTION WHEN duplicate_object OR undefined_table THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.member_likes; EXCEPTION WHEN duplicate_object OR undefined_table THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.profile_views; EXCEPTION WHEN duplicate_object OR undefined_table THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.sent_gifts; EXCEPTION WHEN duplicate_object OR undefined_table THEN NULL; END;
END $$;

-- ==========================================
-- Triggers
-- ==========================================

CREATE OR REPLACE FUNCTION public.increment_profile_view_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.users
    SET total_profile_views = COALESCE(total_profile_views, 0) + 1
    WHERE id = NEW.viewed_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_profile_view_insert ON public.profile_views;
CREATE TRIGGER on_profile_view_insert
AFTER INSERT ON public.profile_views
FOR EACH ROW EXECUTE FUNCTION public.increment_profile_view_count();

CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.referral_code IS NULL THEN
        NEW.referral_code := 'GS-' || upper(substr(md5(random()::text), 1, 8));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_user_referral_code ON public.users;
CREATE TRIGGER on_user_referral_code
BEFORE INSERT ON public.users
FOR EACH ROW EXECUTE FUNCTION public.generate_referral_code();

-- ==========================================
-- Seed data
-- ==========================================

INSERT INTO public.gifts (name, emoji, cost_tokens, cost_ksh, category, required_plan, sort_order) VALUES
    ('Rose', ':rose:', 10, 50, 'standard', 'silver', 1),
    ('Bouquet', ':bouquet:', 25, 125, 'standard', 'silver', 2),
    ('Teddy Bear', ':teddy_bear:', 30, 150, 'standard', 'silver', 3),
    ('Chocolate', ':chocolate_bar:', 15, 75, 'standard', 'silver', 4),
    ('Coffee Date', ':coffee:', 20, 100, 'standard', 'silver', 5),
    ('Diamond', ':gem:', 100, 500, 'premium', 'gold', 6),
    ('Crown', ':crown:', 150, 750, 'premium', 'gold', 7),
    ('Mystery Box', ':gift:', 80, 400, 'premium', 'gold', 8),
    ('Trophy', ':trophy:', 120, 600, 'premium', 'gold', 9),
    ('Spotlight', ':star:', 200, 1000, 'premium', 'gold', 10)
ON CONFLICT DO NOTHING;

INSERT INTO public.token_packages (name, tokens, price_ksh, bonus_tokens, is_popular, sort_order) VALUES
    ('Starter Pack', 50, 250, 0, false, 1),
    ('Popular Pack', 200, 800, 20, true, 2),
    ('Value Pack', 500, 1500, 75, false, 3),
    ('Premium Pack', 1000, 2500, 200, false, 4)
ON CONFLICT DO NOTHING;

-- ==================================================================
-- 20260626_070_mobile_auth_swipes_password_reset.sql
-- ==================================================================

﻿-- Genuine Sugar Mummies mobile-auth and swipe interaction support
-- Run this after the auth/package migration in Supabase SQL Editor.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.password_reset_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_codes_lookup
ON public.password_reset_codes (email, code_hash, expires_at DESC)
WHERE used_at IS NULL;

CREATE TABLE IF NOT EXISTS public.member_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liker_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    liked_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    is_super_like BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(liker_id, liked_id)
);

CREATE INDEX IF NOT EXISTS idx_member_likes_liker ON public.member_likes(liker_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_likes_liked ON public.member_likes(liked_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.member_swipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    swiper_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    swiped_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    direction TEXT NOT NULL DEFAULT 'pass',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(swiper_id, swiped_id)
);

CREATE INDEX IF NOT EXISTS idx_member_swipes_swiper ON public.member_swipes(swiper_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_swipes_swiped ON public.member_swipes(swiped_id, created_at DESC);

ALTER TABLE public.password_reset_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_swipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service role manages password_reset_codes" ON public.password_reset_codes;
CREATE POLICY "service role manages password_reset_codes" ON public.password_reset_codes FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service role manages member_likes" ON public.member_likes;
CREATE POLICY "service role manages member_likes" ON public.member_likes FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service role manages member_swipes" ON public.member_swipes;
CREATE POLICY "service role manages member_swipes" ON public.member_swipes FOR ALL USING (true) WITH CHECK (true);

DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.member_likes; EXCEPTION WHEN duplicate_object OR undefined_table THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.member_swipes; EXCEPTION WHEN duplicate_object OR undefined_table THEN NULL; END;
END $$;

-- ==================================================================
-- 20260626_080_user_alert_settings.sql
-- ==================================================================

-- Genuine Sugar Mummies notification/settings repair
-- Run this in Supabase SQL Editor if alerts switches or account preferences are not persisting.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    notifications BOOLEAN NOT NULL DEFAULT true,
    email_notifications BOOLEAN NOT NULL DEFAULT false,
    dark_mode BOOLEAN NOT NULL DEFAULT false,
    show_online BOOLEAN NOT NULL DEFAULT true,
    show_age BOOLEAN NOT NULL DEFAULT true,
    is_public BOOLEAN NOT NULL DEFAULT true,
    live_location BOOLEAN NOT NULL DEFAULT false,
    location_enabled BOOLEAN NOT NULL DEFAULT false,
    push_token TEXT DEFAULT '',
    push_platform TEXT DEFAULT '',
    notification_permission TEXT DEFAULT 'default',
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'admin',
    title TEXT NOT NULL DEFAULT 'Notification',
    body TEXT NOT NULL DEFAULT '',
    metadata JSONB DEFAULT '{}'::jsonb,
    read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_notifications ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.user_notifications ADD COLUMN IF NOT EXISTS read BOOLEAN DEFAULT false;
ALTER TABLE public.user_notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
ALTER TABLE public.user_notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_user_settings_updated ON public.user_settings(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notifications_user ON public.user_notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notifications_unread ON public.user_notifications(user_id, read, created_at DESC);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service role manages user_settings" ON public.user_settings;
CREATE POLICY "service role manages user_settings" ON public.user_settings FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service role manages user_notifications" ON public.user_notifications;
CREATE POLICY "service role manages user_notifications" ON public.user_notifications FOR ALL USING (true) WITH CHECK (true);

-- Backfill one settings row for every existing account.
INSERT INTO public.user_settings (user_id)
SELECT id FROM public.users
ON CONFLICT (user_id) DO NOTHING;

-- ==================================================================
-- 20260703_090_real_app_admin_cleanup.sql
-- ==================================================================

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
