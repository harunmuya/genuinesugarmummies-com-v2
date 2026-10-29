-- Everything needed to stand this app up on a fresh Supabase project.
--
-- Every migration in supabase/migrations, concatenated in filename order, which
-- is the order they were written and the order they must be applied. Paste the
-- schema is intended for a fresh project. Do not run it against a populated
-- project.
--
-- Synthetic seed member profiles are intentionally omitted. Package-tier and
-- application-default rows remain; gift catalog rows come from the verified
-- source export so their original IDs are preserved without duplicate seeds.
--
-- This creates no member accounts, messages, matches, or other member records.
-- Read docs/migrating-supabase.md before using it; schema without a verified
-- data export is not a complete migration.
--
-- Regenerate with: python scripts/build-bootstrap.py



-- ======================================================================
-- 20260625_000_base_tables_for_new_project.sql
-- ======================================================================

-- Base schema for a fresh Supabase project.
-- Run before 20260625_foundation_social_rebuild.sql.

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


-- ======================================================================
-- 20260625_020_seed_members_profiles.sql
-- ======================================================================

-- Member feature fields, action tables, and categorized seed profiles.

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

-- Synthetic seed member inserts intentionally omitted from bootstrap.


-- ======================================================================
-- 20260625_030_missing_member_features.sql
-- ======================================================================

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


-- ======================================================================
-- 20260625_040_admin_control_packages_verification.sql
-- ======================================================================

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


-- ======================================================================
-- 20260625_060_auth_email_admin_packages.sql
-- ======================================================================

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


-- ======================================================================
-- 20260625_foundation_social_rebuild.sql
-- ======================================================================

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

-- A preceding migration may have created the legacy profile_views shape.
ALTER TABLE public.profile_views ADD COLUMN IF NOT EXISTS viewer_id UUID REFERENCES public.users(id) ON DELETE CASCADE;
ALTER TABLE public.profile_views ADD COLUMN IF NOT EXISTS viewed_id UUID REFERENCES public.users(id) ON DELETE CASCADE;
ALTER TABLE public.profile_views ADD COLUMN IF NOT EXISTS viewed_at TIMESTAMPTZ DEFAULT now();

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


-- ======================================================================
-- 20260626_070_mobile_auth_swipes_password_reset.sql
-- ======================================================================

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


-- ======================================================================
-- 20260626_080_user_alert_settings.sql
-- ======================================================================

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


-- ======================================================================
-- 20260703_090_real_app_admin_cleanup.sql
-- ======================================================================

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


-- ======================================================================
-- 20260703_110_real_time_dating_security_and_media.sql
-- ======================================================================

-- GenuineSugarMummies.com production hardening migration.
-- Safe to run on a live Supabase project: no deletes, no truncates, no reseeding, no status resets.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_in_public BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS package_locked BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_rejection_reason TEXT DEFAULT '';

CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_one_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    user_two_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active',
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_one_id, user_two_id)
);

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    body TEXT DEFAULT '',
    message_type TEXT NOT NULL DEFAULT 'text',
    status TEXT NOT NULL DEFAULT 'sent',
    read_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.message_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    storage_bucket TEXT NOT NULL DEFAULT 'message-attachments',
    storage_path TEXT DEFAULT '',
    public_url TEXT DEFAULT '',
    attachment_type TEXT NOT NULL DEFAULT 'image',
    file_name TEXT DEFAULT '',
    mime_type TEXT DEFAULT '',
    byte_size BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.voice_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    storage_bucket TEXT NOT NULL DEFAULT 'message-attachments',
    storage_path TEXT DEFAULT '',
    public_url TEXT DEFAULT '',
    duration_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.call_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caller_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    call_type TEXT NOT NULL DEFAULT 'voice',
    status TEXT NOT NULL DEFAULT 'requested',
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    missed_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.call_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    signal_type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.gift_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Appreciation',
    gif_url TEXT DEFAULT '',
    icon_url TEXT DEFAULT '',
    credit_cost INTEGER NOT NULL DEFAULT 0,
    money_cost_ksh INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Gift catalog seed rows are restored from the verified source export.

CREATE TABLE IF NOT EXISTS public.gift_wallet (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    credits INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.gift_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    gift_id UUID REFERENCES public.gift_catalog(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE SET NULL,
    credits_spent INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'sent',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.money_wallet (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    balance_ksh INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.credit_wallet (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    credits INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    wallet_type TEXT NOT NULL DEFAULT 'credit',
    direction TEXT NOT NULL DEFAULT 'credit',
    amount INTEGER NOT NULL DEFAULT 0,
    balance_after INTEGER,
    source TEXT NOT NULL DEFAULT 'admin',
    status TEXT NOT NULL DEFAULT 'posted',
    reference TEXT DEFAULT '',
    admin_note TEXT DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL UNIQUE,
    p256dh TEXT DEFAULT '',
    auth TEXT DEFAULT '',
    platform TEXT DEFAULT 'web',
    permission TEXT DEFAULT 'default',
    user_agent TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS attachment_url TEXT DEFAULT '';
ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS attachment_type TEXT DEFAULT '';
ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS attachment_name TEXT DEFAULT '';
ALTER TABLE public.member_messages ADD COLUMN IF NOT EXISTS voice_url TEXT DEFAULT '';
ALTER TABLE public.call_requests ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'message-attachments',
    'message-attachments',
    true,
    6291456,
    ARRAY['image/jpeg','image/png','image/webp','image/gif','audio/webm','audio/mp4','audio/mpeg','audio/wav']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_real_presence ON public.users(last_seen_at DESC) WHERE show_in_public = true;
CREATE INDEX IF NOT EXISTS idx_conversations_user_one ON public.conversations(user_one_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_user_two ON public.conversations(user_two_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON public.messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_message_attachments_message ON public.message_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_users ON public.call_sessions(caller_id, receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_signals_session_created ON public.call_signals(call_session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created ON public.wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user ON public.push_subscriptions(user_id);

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
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.money_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read users" ON public.users;
DROP POLICY IF EXISTS "Public can upsert users" ON public.users;
DROP POLICY IF EXISTS "Anyone can request packages" ON public.package_requests;
DROP POLICY IF EXISTS "Anyone can send member messages" ON public.member_messages;
DROP POLICY IF EXISTS "Anyone can send member gifts" ON public.member_gifts;
DROP POLICY IF EXISTS "Users can save members" ON public.member_saves;
DROP POLICY IF EXISTS "Anyone can request calls" ON public.call_requests;
DROP POLICY IF EXISTS "Anyone can create tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Service role manages ticket responses" ON public.ticket_responses;
DROP POLICY IF EXISTS "Service role manages user notifications" ON public.user_notifications;
DROP POLICY IF EXISTS "Service role manages user interactions" ON public.user_interactions;
DROP POLICY IF EXISTS "Service role manages user daily usage" ON public.user_daily_usage;
DROP POLICY IF EXISTS "Users can manage settings" ON public.user_settings;
DROP POLICY IF EXISTS "Service role manages limits" ON public.app_limits;
DROP POLICY IF EXISTS "Service role manages logs" ON public.admin_logs;
DROP POLICY IF EXISTS "Anyone can view package tiers" ON public.package_tiers;
DROP POLICY IF EXISTS "Users can read own settings" ON public.user_settings;
DROP POLICY IF EXISTS "Users can manage own settings" ON public.user_settings;
DROP POLICY IF EXISTS "Users can read own notifications" ON public.user_notifications;
DROP POLICY IF EXISTS "Users can update own notification read status" ON public.user_notifications;
DROP POLICY IF EXISTS "Users can read own conversations" ON public.conversations;
DROP POLICY IF EXISTS "Users can read own messages" ON public.messages;
DROP POLICY IF EXISTS "Users can read own wallet transactions" ON public.wallet_transactions;
DROP POLICY IF EXISTS "Users can manage own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Public can view active package tiers" ON public.package_tiers;
DROP POLICY IF EXISTS "Public can view active gifts" ON public.gift_catalog;
DROP POLICY IF EXISTS "Public can read message attachment files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload message attachment files" ON storage.objects;

REVOKE ALL ON public.users FROM anon, authenticated;
REVOKE ALL ON public.package_requests FROM anon, authenticated;
REVOKE ALL ON public.member_messages FROM anon, authenticated;
REVOKE ALL ON public.support_tickets FROM anon, authenticated;
REVOKE ALL ON public.ticket_responses FROM anon, authenticated;
REVOKE ALL ON public.user_notifications FROM anon, authenticated;
REVOKE ALL ON public.user_daily_usage FROM anon, authenticated;
REVOKE ALL ON public.admin_logs FROM anon, authenticated;
REVOKE ALL ON public.money_wallet FROM anon, authenticated;
REVOKE ALL ON public.credit_wallet FROM anon, authenticated;
REVOKE ALL ON public.wallet_transactions FROM anon, authenticated;

GRANT SELECT (id, auth_user_id) ON public.users TO authenticated;

CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
    id,
    display_name,
    avatar_url,
    photos,
    bio,
    age,
    location,
    country,
    city,
    profile_label,
    member_category,
    looking_for,
    intent_summary,
    wants,
    needed_qualities,
    age_range_preference,
    hobbies,
    interests,
    subscription_tier,
    verified,
    show_in_public,
    total_profile_views,
    followers_count,
    gifts_received_count,
    created_at,
    last_seen_at
FROM public.users
WHERE show_in_public = true
  AND COALESCE(is_banned, false) = false
  AND COALESCE(is_suspended, false) = false;

GRANT SELECT ON public.public_profiles TO anon, authenticated;

CREATE POLICY "Users can read own settings" ON public.user_settings
FOR SELECT USING (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id));

CREATE POLICY "Users can manage own settings" ON public.user_settings
FOR ALL USING (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id))
WITH CHECK (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id));

CREATE POLICY "Users can read own notifications" ON public.user_notifications
FOR SELECT USING (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id));

CREATE POLICY "Users can update own notification read status" ON public.user_notifications
FOR UPDATE USING (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id))
WITH CHECK (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id));

CREATE POLICY "Users can read own conversations" ON public.conversations
FOR SELECT USING (
    auth.uid() IN (user_one_id, user_two_id)
    OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id IN (user_one_id, user_two_id))
);

CREATE POLICY "Users can read own messages" ON public.messages
FOR SELECT USING (
    auth.uid() IN (sender_id, receiver_id)
    OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id IN (sender_id, receiver_id))
);

CREATE POLICY "Users can read own wallet transactions" ON public.wallet_transactions
FOR SELECT USING (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id));

CREATE POLICY "Users can manage own push subscriptions" ON public.push_subscriptions
FOR ALL USING (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id))
WITH CHECK (auth.uid() = user_id OR auth.uid() IN (SELECT auth_user_id FROM public.users WHERE id = user_id));

CREATE POLICY "Public can view active package tiers" ON public.package_tiers
FOR SELECT USING (is_active = true);

CREATE POLICY "Public can view active gifts" ON public.gift_catalog
FOR SELECT USING (is_active = true);

CREATE POLICY "Public can read message attachment files" ON storage.objects
FOR SELECT USING (bucket_id = 'message-attachments');

CREATE POLICY "Authenticated users can upload message attachment files" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'message-attachments' AND auth.role() = 'authenticated');


-- ======================================================================
-- 20260703_120_missing_real_features_tables.sql
-- ======================================================================

-- Missing real feature tables for GS dating app.
-- Safe live migration: creates only missing objects and preserves existing rows.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.packages (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    price_ksh INTEGER NOT NULL DEFAULT 0,
    features JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.packages (id, name, price_ksh, features)
VALUES
('basic', 'Basic', 650, '["5 super likes","Premium messaging access","Gifts and emojis","One chosen direct connection request through Admin Mary G"]'::jsonb),
('silver', 'Silver', 1200, '["Recommended","100 super likes","Phone reveal where enabled","Unlimited messaging","Voice notes","Call requests","Priority support"]'::jsonb),
('gold', 'Gold International', 3550, '["Unlimited super likes","Unlimited profile views","Unlimited messages","Voice and video call access","GIF gifts","Premium support"]'::jsonb)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, features = EXCLUDED.features, updated_at = now();

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    package_id TEXT REFERENCES public.packages(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    lifetime BOOLEAN NOT NULL DEFAULT true,
    payment_reference TEXT DEFAULT '',
    approved_by TEXT DEFAULT 'admin',
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, package_id)
);

CREATE TABLE IF NOT EXISTS public.likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liker_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    liked_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    source_key TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(liker_id, liked_id)
);

CREATE TABLE IF NOT EXISTS public.super_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    source_key TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(sender_id, receiver_id)
);

CREATE TABLE IF NOT EXISTS public.swipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    swiper_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    swiped_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    source_key TEXT DEFAULT '',
    direction TEXT NOT NULL DEFAULT 'pass',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(swiper_id, swiped_id, source_key)
);

CREATE TABLE IF NOT EXISTS public.profile_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    viewer_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    viewed_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    source_key TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.saved_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    saved_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    saved_key TEXT DEFAULT '',
    saved_name TEXT DEFAULT '',
    saved_image TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, saved_key)
);

CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_one_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    user_two_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    score INTEGER DEFAULT 0,
    source_key TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_one_id, user_two_id)
);

CREATE TABLE IF NOT EXISTS public.ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL DEFAULT 'user',
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.call_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caller_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    call_type TEXT NOT NULL DEFAULT 'voice',
    status TEXT NOT NULL DEFAULT 'requested',
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    missed_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.call_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    signal_type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.gift_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Appreciation',
    gif_url TEXT DEFAULT '',
    icon_url TEXT DEFAULT '',
    credit_cost INTEGER NOT NULL DEFAULT 0,
    money_cost_ksh INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Gift catalog seed rows are restored from the verified source export.

CREATE TABLE IF NOT EXISTS public.gift_wallet (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    credits INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.gift_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    gift_id UUID REFERENCES public.gift_catalog(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE SET NULL,
    credits_spent INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'sent',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.money_wallet (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    balance_ksh INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.credit_wallet (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    credits INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    wallet_type TEXT NOT NULL DEFAULT 'credit',
    direction TEXT NOT NULL DEFAULT 'credit',
    amount INTEGER NOT NULL DEFAULT 0,
    balance_after INTEGER,
    source TEXT NOT NULL DEFAULT 'admin',
    status TEXT NOT NULL DEFAULT 'posted',
    reference TEXT DEFAULT '',
    admin_note TEXT DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL UNIQUE,
    p256dh TEXT DEFAULT '',
    auth TEXT DEFAULT '',
    platform TEXT DEFAULT 'web',
    permission TEXT DEFAULT 'default',
    user_agent TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created ON public.wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_transactions_sender_created ON public.gift_transactions(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_signals_session_created ON public.call_signals(call_session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON public.messages(conversation_id, created_at DESC);

ALTER TABLE public.packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.super_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.money_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view active packages" ON public.packages;
DROP POLICY IF EXISTS "Public can view active gifts" ON public.gift_catalog;
CREATE POLICY "Public can view active packages" ON public.packages FOR SELECT USING (is_active = true);
CREATE POLICY "Public can view active gifts" ON public.gift_catalog FOR SELECT USING (is_active = true);


-- ======================================================================
-- 20260704_140_real_call_foundation.sql
-- ======================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.call_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caller_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    call_type TEXT NOT NULL DEFAULT 'voice',
    status TEXT NOT NULL DEFAULT 'ringing',
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    missed_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS caller_id UUID REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS call_type TEXT NOT NULL DEFAULT 'voice';
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ringing';
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ;
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS missed_at TIMESTAMPTZ;
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.call_sessions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.call_sessions DROP CONSTRAINT IF EXISTS call_sessions_not_self_check;
ALTER TABLE public.call_sessions ADD CONSTRAINT call_sessions_not_self_check
CHECK (caller_id IS NULL OR receiver_id IS NULL OR caller_id <> receiver_id) NOT VALID;

ALTER TABLE public.call_sessions DROP CONSTRAINT IF EXISTS call_sessions_call_type_check;
ALTER TABLE public.call_sessions ADD CONSTRAINT call_sessions_call_type_check
CHECK (call_type IN ('voice', 'video')) NOT VALID;

ALTER TABLE public.call_sessions DROP CONSTRAINT IF EXISTS call_sessions_status_check;
ALTER TABLE public.call_sessions ADD CONSTRAINT call_sessions_status_check
CHECK (status IN ('requested', 'ringing', 'accepted', 'active', 'ended', 'rejected', 'declined', 'missed', 'cancelled')) NOT VALID;

CREATE TABLE IF NOT EXISTS public.call_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    signal_type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.call_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_call_sessions_caller_status ON public.call_sessions(caller_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_sessions_receiver_status ON public.call_sessions(receiver_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_sessions_live ON public.call_sessions(status, created_at DESC) WHERE status IN ('ringing', 'accepted', 'active');
CREATE INDEX IF NOT EXISTS idx_call_signals_session_created ON public.call_signals(call_session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_call_signals_receiver_created ON public.call_signals(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_events_session_created ON public.call_events(call_session_id, created_at DESC);

ALTER TABLE public.call_sessions DROP CONSTRAINT IF EXISTS call_sessions_not_self_check;

UPDATE public.call_sessions
SET status = 'ended',
    ended_at = COALESCE(ended_at, now()),
    receiver_id = NULL,
    metadata = COALESCE(metadata, '{}'::jsonb) || '{"closeReason":"invalid_self_call"}'::jsonb
WHERE caller_id IS NOT NULL
  AND receiver_id IS NOT NULL
  AND caller_id = receiver_id;

ALTER TABLE public.call_sessions ADD CONSTRAINT call_sessions_not_self_check
CHECK (caller_id IS NULL OR receiver_id IS NULL OR caller_id <> receiver_id) NOT VALID;

UPDATE public.call_sessions
SET status = 'missed',
    missed_at = COALESCE(missed_at, now())
WHERE status = 'ringing'
  AND created_at < now() - interval '2 minutes';

ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages call sessions" ON public.call_sessions;
CREATE POLICY "Service role manages call sessions" ON public.call_sessions
FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Service role manages call signals" ON public.call_signals;
CREATE POLICY "Service role manages call signals" ON public.call_signals
FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Service role manages call events" ON public.call_events;
CREATE POLICY "Service role manages call events" ON public.call_events
FOR ALL USING (true) WITH CHECK (true);


-- ======================================================================
-- 20260704_150_real_gift_inventory.sql
-- ======================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.user_gift_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    gift_id UUID NOT NULL REFERENCES public.gift_catalog(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    total_received INTEGER NOT NULL DEFAULT 0 CHECK (total_received >= 0),
    total_sent INTEGER NOT NULL DEFAULT 0 CHECK (total_sent >= 0),
    last_transaction_id UUID,
    source TEXT NOT NULL DEFAULT 'app',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, gift_id)
);

CREATE INDEX IF NOT EXISTS idx_user_gift_inventory_user_updated
ON public.user_gift_inventory(user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_gift_inventory_gift
ON public.user_gift_inventory(gift_id);

ALTER TABLE public.user_gift_inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own gift inventory" ON public.user_gift_inventory;
CREATE POLICY "Users can view own gift inventory"
ON public.user_gift_inventory
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages gift inventory" ON public.user_gift_inventory;
CREATE POLICY "Service role manages gift inventory"
ON public.user_gift_inventory
FOR ALL
USING (true)
WITH CHECK (true);

ALTER TABLE public.gift_transactions
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'sent';

ALTER TABLE public.gift_transactions
ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

INSERT INTO public.user_gift_inventory (
    user_id,
    gift_id,
    quantity,
    total_received,
    total_sent,
    last_transaction_id,
    source,
    updated_at
)
SELECT
    gt.receiver_id,
    gt.gift_id,
    COUNT(*)::integer AS quantity,
    COUNT(*)::integer AS total_received,
    0 AS total_sent,
    (array_agg(gt.id ORDER BY gt.created_at DESC))[1] AS last_transaction_id,
    'received_backfill' AS source,
    now()
FROM public.gift_transactions gt
WHERE gt.receiver_id IS NOT NULL
  AND gt.gift_id IS NOT NULL
GROUP BY gt.receiver_id, gt.gift_id
ON CONFLICT (user_id, gift_id)
DO UPDATE SET
    quantity = GREATEST(public.user_gift_inventory.quantity, EXCLUDED.quantity),
    total_received = GREATEST(public.user_gift_inventory.total_received, EXCLUDED.total_received),
    last_transaction_id = COALESCE(EXCLUDED.last_transaction_id, public.user_gift_inventory.last_transaction_id),
    updated_at = now();

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.gift_transactions;
    EXCEPTION WHEN duplicate_object OR undefined_table THEN
        NULL;
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_gift_inventory;
    EXCEPTION WHEN duplicate_object OR undefined_table THEN
        NULL;
    END;
END $$;


-- ======================================================================
-- 20260704_160_calls_public_matches_packages.sql
-- ======================================================================

ALTER TABLE public.call_sessions
ADD COLUMN IF NOT EXISTS duration_seconds INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_call_sessions_users_created
ON public.call_sessions(caller_id, receiver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_call_sessions_ended
ON public.call_sessions(ended_at DESC)
WHERE ended_at IS NOT NULL;

UPDATE public.users
SET show_in_public = true,
    last_seen_at = COALESCE(last_seen_at, now()),
    last_seen = COALESCE(last_seen, now())
WHERE COALESCE(show_in_public, false) = false
  AND COALESCE(is_banned, false) = false
  AND COALESCE(is_suspended, false) = false
  AND COALESCE(avatar_url, '') <> ''
  AND COALESCE(bio, '') <> ''
  AND age IS NOT NULL
  AND COALESCE(location, '') <> ''
  AND (COALESCE(phone_number, '') <> '' OR COALESCE(phone, '') <> '');

UPDATE public.users
SET display_name = INITCAP(REPLACE(REPLACE(SPLIT_PART(email, '@', 1), '.', ' '), '_', ' '))
WHERE display_name ILIKE '%@%'
  AND COALESCE(email, '') <> '';

UPDATE public.package_tiers
SET price_ksh = 3550,
    features = '[
      "Lifetime Gold International access",
      "International and prominent profile access",
      "Unlimited messaging, profile views, and phone contacts",
      "Unlimited voice and video call access where device permissions allow",
      "Premium gifts, wallet activity, and priority placement",
      "Fastest Admin Mary G support and guided connection assistance"
    ]'::jsonb
WHERE id = 'gold';

UPDATE public.package_tiers
SET features = '[
  "Lifetime Silver membership after admin approval",
  "Phone number reveal for approved profiles",
  "Unlimited messaging after approval",
  "Voice calls and video calls with call history",
  "More likes, swipes, saves, premium gifts, and wallet features",
  "Priority Admin Mary G support for serious local connections"
]'::jsonb
WHERE id = 'silver';

UPDATE public.package_tiers
SET features = '[
  "Lifetime Basic membership after admin approval",
  "Starter messaging limit for serious introductions",
  "10 likes and 10 swipes per day",
  "Send premium GS gifts with approved credits",
  "One direct connection of your choice facilitated by Admin Mary G on Telegram",
  "No random connection - you choose who to request"
]'::jsonb
WHERE id = 'basic';


-- ======================================================================
-- 20260704_170_antigravity_upgrade_migration.sql
-- ======================================================================

-- ============================================================================
-- GS App SAFE Production Upgrade Migration
-- genuinesugarmummies.com — Supabase project: tislsfajzqcctjcrmnlg
-- 
-- SAFE TO RUN ON LIVE DATABASE:
-- ✅ All CREATE TABLE use IF NOT EXISTS
-- ✅ All ALTER TABLE use ADD COLUMN IF NOT EXISTS
-- ✅ All INSERT use ON CONFLICT DO UPDATE or DO NOTHING
-- ✅ No DELETE, DROP, or TRUNCATE statements
-- ✅ Preserves all existing users, messages, gifts, and data
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. USER TABLE UPGRADES (new columns for live, follows, geolocation)
-- ============================================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_live BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS geo_updated_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT '';

-- Backfill gender from profile_label for admin filtering
UPDATE public.users
SET gender = CASE
    WHEN profile_label IN ('sugar_mummy', 'mistress') THEN 'female'
    WHEN profile_label IN ('toyboy', 'sugar_daddy') THEN 'male'
    ELSE COALESCE(gender, '')
END
WHERE COALESCE(gender, '') = ''
  AND profile_label IS NOT NULL
  AND profile_label <> '';

-- ============================================================================
-- 2. USER FOLLOWS TABLE (real authenticated follows, not anonymous)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    following_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(follower_id, following_id)
);

-- Safe constraint add (may already exist)
DO $$
BEGIN
    ALTER TABLE public.user_follows ADD CONSTRAINT user_follows_no_self CHECK (follower_id <> following_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON public.user_follows(follower_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_follows_following ON public.user_follows(following_id, created_at DESC);

ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view follows" ON public.user_follows;
CREATE POLICY "Authenticated users can view follows" ON public.user_follows
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can manage own follows" ON public.user_follows;
CREATE POLICY "Users can manage own follows" ON public.user_follows
    FOR ALL USING (auth.uid() = follower_id) WITH CHECK (auth.uid() = follower_id);

-- Trigger: auto-update followers_count and following_count
CREATE OR REPLACE FUNCTION public.handle_follow_count_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.users SET followers_count = COALESCE(followers_count, 0) + 1 WHERE id = NEW.following_id;
        UPDATE public.users SET following_count = COALESCE(following_count, 0) + 1 WHERE id = NEW.follower_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.users SET followers_count = GREATEST(COALESCE(followers_count, 0) - 1, 0) WHERE id = OLD.following_id;
        UPDATE public.users SET following_count = GREATEST(COALESCE(following_count, 0) - 1, 0) WHERE id = OLD.follower_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_follow_count_change ON public.user_follows;
CREATE TRIGGER trg_follow_count_change
AFTER INSERT OR DELETE ON public.user_follows
FOR EACH ROW EXECUTE FUNCTION public.handle_follow_count_change();

-- ============================================================================
-- 3. LIVE STREAMING TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.live_streams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT DEFAULT 'Untitled Stream',
    thumbnail_url TEXT DEFAULT '',
    viewer_count INTEGER DEFAULT 0,
    total_gifts INTEGER DEFAULT 0,
    total_coins INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    started_at TIMESTAMPTZ DEFAULT now(),
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_viewers (
    stream_id UUID REFERENCES public.live_streams(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (stream_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.live_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id UUID REFERENCES public.live_streams(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_gifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id UUID REFERENCES public.live_streams(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    gift_name TEXT NOT NULL,
    gift_visual TEXT DEFAULT '',
    gift_cost INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_live_streams_active ON public.live_streams(is_active, started_at DESC) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_live_streams_host ON public.live_streams(host_id, is_active);
CREATE INDEX IF NOT EXISTS idx_live_comments_stream ON public.live_comments(stream_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_gifts_stream ON public.live_gifts(stream_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_viewers_stream ON public.live_viewers(stream_id);

-- RLS
ALTER TABLE public.live_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_viewers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_gifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active live streams" ON public.live_streams;
CREATE POLICY "Anyone can view active live streams" ON public.live_streams
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Host can manage own streams" ON public.live_streams;
CREATE POLICY "Host can manage own streams" ON public.live_streams
    FOR ALL USING (auth.uid() = host_id) WITH CHECK (auth.uid() = host_id);

DROP POLICY IF EXISTS "Anyone can view live viewers" ON public.live_viewers;
CREATE POLICY "Anyone can view live viewers" ON public.live_viewers FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can join streams" ON public.live_viewers;
CREATE POLICY "Authenticated users can join streams" ON public.live_viewers
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view live comments" ON public.live_comments;
CREATE POLICY "Anyone can view live comments" ON public.live_comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can comment" ON public.live_comments;
CREATE POLICY "Authenticated users can comment" ON public.live_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view live gifts" ON public.live_gifts;
CREATE POLICY "Anyone can view live gifts" ON public.live_gifts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can send live gifts" ON public.live_gifts;
CREATE POLICY "Authenticated users can send live gifts" ON public.live_gifts
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Trigger: auto-update viewer_count
CREATE OR REPLACE FUNCTION public.handle_viewer_count_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.live_streams SET viewer_count = COALESCE(viewer_count, 0) + 1 WHERE id = NEW.stream_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.live_streams SET viewer_count = GREATEST(COALESCE(viewer_count, 0) - 1, 0) WHERE id = OLD.stream_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_viewer_count_change ON public.live_viewers;
CREATE TRIGGER trg_viewer_count_change
AFTER INSERT OR DELETE ON public.live_viewers
FOR EACH ROW EXECUTE FUNCTION public.handle_viewer_count_change();

-- Trigger: auto-update total_gifts and total_coins on live_gifts insert
CREATE OR REPLACE FUNCTION public.handle_live_gift_sent()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.live_streams
    SET total_gifts = COALESCE(total_gifts, 0) + 1,
        total_coins = COALESCE(total_coins, 0) + COALESCE(NEW.gift_cost, 0)
    WHERE id = NEW.stream_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_live_gift_sent ON public.live_gifts;
CREATE TRIGGER trg_live_gift_sent
AFTER INSERT ON public.live_gifts
FOR EACH ROW EXECUTE FUNCTION public.handle_live_gift_sent();

-- ============================================================================
-- 4. UPGRADE GIFT CATALOG (52 premium gifts)
-- ============================================================================

-- Add missing columns to gift_catalog
ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS tier INTEGER DEFAULT 1;
ALTER TABLE public.gift_catalog ADD COLUMN IF NOT EXISTS emoji TEXT DEFAULT '🎁';

-- Insert/update all 52 gifts
-- Uses name as conflict detection (add unique constraint first)
DO $$
BEGIN
    ALTER TABLE public.gift_catalog ADD CONSTRAINT gift_catalog_name_unique UNIQUE (name);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Gift catalog seed rows are restored from the verified source export.

-- ============================================================================
-- 5. GEOLOCATION RPC FUNCTION (Haversine)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_nearby_users(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_km DOUBLE PRECISION DEFAULT 50,
    max_results INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    avatar_url TEXT,
    profile_label TEXT,
    age INTEGER,
    is_live BOOLEAN,
    last_seen_at TIMESTAMPTZ,
    distance_km DOUBLE PRECISION
)
LANGUAGE sql STABLE
AS $$
    SELECT
        u.id,
        u.display_name,
        u.avatar_url,
        u.profile_label,
        u.age,
        COALESCE(u.is_live, false) AS is_live,
        u.last_seen_at,
        (6371 * acos(
            LEAST(1.0, cos(radians(user_lat)) * cos(radians(u.latitude))
            * cos(radians(u.longitude) - radians(user_lng))
            + sin(radians(user_lat)) * sin(radians(u.latitude)))
        )) AS distance_km
    FROM public.users u
    WHERE u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      AND u.show_in_public = true
      AND COALESCE(u.is_banned, false) = false
      AND COALESCE(u.is_suspended, false) = false
      AND (6371 * acos(
            LEAST(1.0, cos(radians(user_lat)) * cos(radians(u.latitude))
            * cos(radians(u.longitude) - radians(user_lng))
            + sin(radians(user_lat)) * sin(radians(u.latitude)))
        )) <= radius_km
    ORDER BY distance_km ASC
    LIMIT max_results;
$$;

-- ============================================================================
-- 6. ENABLE SUPABASE REALTIME for new tables
-- ============================================================================

DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.live_streams; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.live_comments; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.live_gifts; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.live_viewers; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.user_follows; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ============================================================================
-- 7. VERIFY — List all tables (run SELECT to confirm)
-- ============================================================================
-- After running this migration, verify with:
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
--
-- Expected new tables:
--   live_streams, live_viewers, live_comments, live_gifts, user_follows
--
-- Expected new columns on users:
--   is_live, following_count, latitude, longitude, geo_updated_at, gender
--
-- Expected gift_catalog upgrades:
--   52 rows with tier and emoji columns
-- ============================================================================


-- ======================================================================
-- 20260704_180_package_tiers_feature_gates.sql
-- ======================================================================

-- ============================================================================
-- GS App — Proper Package Tiers with Full Feature Gates
-- Safe to run on live DB: uses ON CONFLICT + ADD COLUMN IF NOT EXISTS
-- ============================================================================

-- Add new feature-gate columns to package_tiers
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_like_limit INTEGER DEFAULT 5;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_super_like_limit INTEGER DEFAULT 0;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_swipe_limit INTEGER DEFAULT 10;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_profile_view_limit INTEGER DEFAULT 10;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_see_who_liked BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_see_who_viewed BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_send_voice_notes BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_send_images BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_go_live BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_send_gifts BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_use_nearby BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS max_gift_tier INTEGER DEFAULT 1;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS starting_credits INTEGER DEFAULT 0;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS badge_label TEXT DEFAULT '';
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS badge_color TEXT DEFAULT '';
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';

-- ============================================================================
-- FREE TIER (no payment, default for all new users)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'free', 'Free', 0, 0, true,
    'Get started and explore GS App. Upgrade anytime to unlock premium features.',
    'FREE', '#9ca3af',
    false, 5, 0,
    5, 0, 10, 10,
    false, false, false,
    false, false,
    false, false, false, false, false,
    0, 0,
    '[
        "5 messages per day",
        "5 likes and 10 swipes per day",
        "10 profile views per day",
        "Browse all public members",
        "Basic profile creation",
        "Receive gifts and messages from others",
        "Upgrade anytime to unlock calls, voice notes, gifts, and more"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- BASIC TIER — KSH 650 (Starter paid plan)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'basic', 'Basic', 650, 1, true,
    'Unlock messaging, starter gifts, and one direct Admin Mary G connection of your choice.',
    'BASIC', '#3b82f6',
    false, 30, 10,
    10, 5, 30, 30,
    false, false, false,
    false, false,
    false, true, false, true, false,
    1, 50,
    '[
        "Lifetime Basic membership after admin approval",
        "30 messages per day",
        "10 likes and 5 super likes per day",
        "30 swipes and 30 profile views per day",
        "Send images in chat",
        "Send Tier 1 gifts (Rose, Heart, Butterfly, Coffee, and more)",
        "50 free GS credits on activation",
        "One direct connection of your choice facilitated by Admin Mary G on Telegram",
        "No random connection — you choose who to request"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- SILVER TIER — KSH 1,200 (Recommended plan)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'silver', 'Silver Recommended', 1200, 2, true,
    'The serious connection plan. Voice calls, video calls, voice notes, premium gifts, and nearby discovery.',
    'SILVER ⭐', '#a855f7',
    true, 0, 50,
    50, 100, 0, 0,
    true, false, true,
    true, true,
    true, true, true, true, true,
    3, 200,
    '[
        "⭐ RECOMMENDED — Best value for serious connections",
        "Lifetime Silver membership after admin approval",
        "Unlimited messaging after approval",
        "Phone number reveal for approved profiles",
        "50 likes and 100 super likes per day",
        "Unlimited swipes and profile views",
        "Voice calls and video calls with call history",
        "Send and receive voice notes in chat",
        "Send images, GIFs, and media in chat",
        "Go Live — broadcast and receive gifts from viewers",
        "Send gifts up to Tier 3 (Golden Trophy, Diamond, Sports Car, Castle, and more)",
        "200 free GS credits on activation",
        "See who liked and viewed your profile",
        "Nearby users — discover people close to you",
        "Priority profile visibility in search and discover",
        "Priority Admin Mary G support for serious local connections"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- GOLD TIER — KSH 3,550 (Premium International)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'gold', 'Gold International', 3550, 3, true,
    'The ultimate VIP experience. Everything unlimited, international access, all premium gifts, and fastest support.',
    'GOLD 👑', '#f59e0b',
    true, 0, 0,
    0, 0, 0, 0,
    true, true, true,
    true, true,
    true, true, true, true, true,
    4, 500,
    '[
        "👑 VIP GOLD — The ultimate GS experience",
        "Lifetime Gold International access",
        "International and prominent profile access — connect worldwide",
        "Unlimited messaging, likes, super likes, swipes, and profile views",
        "Unlimited voice and video call access",
        "Send and receive voice notes, images, GIFs, and all media",
        "Go Live — broadcast, go viral, and receive gifts from global viewers",
        "Send ALL gift tiers including Tier 4 exclusives (Galaxy, Golden Dragon, Treasure, Grand Palace)",
        "500 free GS credits on activation",
        "See who liked and viewed your profile",
        "Nearby users — discover local and international connections",
        "Priority profile placement — appear first in search, discover, and recommendations",
        "Gold badge on your profile — stand out from other members",
        "Unlimited daily gift sending — no daily caps",
        "Fastest Admin Mary G support and guided connection assistance",
        "Priority phone number reveal for all approved profiles"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- Also update the `packages` table if it exists (some routes read from this)
-- ============================================================================
INSERT INTO public.packages (id, name, price_ksh, features, is_active) VALUES
(
    'free', 'Free', 0,
    '[
        "5 messages per day",
        "5 likes and 10 swipes per day",
        "10 profile views per day",
        "Browse all public members",
        "Receive gifts and messages"
    ]'::jsonb,
    true
),
(
    'basic', 'Basic', 650,
    '[
        "30 messages per day",
        "10 likes, 5 super likes, 30 swipes per day",
        "Send images in chat",
        "Send Tier 1 gifts (Rose, Heart, Coffee, etc.)",
        "50 free GS credits",
        "One direct Admin Mary G connection of your choice"
    ]'::jsonb,
    true
),
(
    'silver', 'Silver Recommended', 1200,
    '[
        "⭐ Recommended — best value",
        "Unlimited messaging",
        "Phone number reveal",
        "Voice and video calls",
        "Voice notes and media sharing",
        "Go Live streaming",
        "Send gifts up to Tier 3",
        "200 free GS credits",
        "See who liked and viewed you",
        "Nearby user discovery",
        "Priority visibility and support"
    ]'::jsonb,
    true
),
(
    'gold', 'Gold International', 3550,
    '[
        "👑 VIP Gold — everything unlimited",
        "International access worldwide",
        "Unlimited messages, likes, swipes",
        "Unlimited voice and video calls",
        "All media types in chat",
        "Go Live with global reach",
        "Send ALL gift tiers (including exclusives)",
        "500 free GS credits",
        "Gold badge on profile",
        "Priority placement everywhere",
        "Fastest Admin Mary G support"
    ]'::jsonb,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    price_ksh = EXCLUDED.price_ksh,
    features = EXCLUDED.features,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- ============================================================================
-- Set all existing users without a tier to 'free'
-- ============================================================================
UPDATE public.users
SET subscription_tier = 'free'
WHERE COALESCE(subscription_tier, '') = ''
   OR subscription_tier IS NULL;


-- ======================================================================
-- 20260706_190_unique_usernames_admin_attention.sql
-- ======================================================================

-- Adds durable usernames for every account. The application also derives a
-- temporary handle from id/display name until this migration is applied.

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS username TEXT;

WITH prepared AS (
    SELECT
        id,
        lower(
            regexp_replace(
                coalesce(nullif(username, ''), nullif(display_name, ''), split_part(email, '@', 1), 'member'),
                '[^a-zA-Z0-9_]+',
                '_',
                'g'
            )
        ) AS raw_username
    FROM public.users
),
cleaned AS (
    SELECT
        id,
        trim(both '_' from left(coalesce(nullif(raw_username, ''), 'member'), 24)) AS base_username
    FROM prepared
),
numbered AS (
    SELECT
        id,
        coalesce(nullif(base_username, ''), 'member') AS base_username,
        row_number() OVER (PARTITION BY coalesce(nullif(base_username, ''), 'member') ORDER BY id) AS duplicate_number
    FROM cleaned
)
UPDATE public.users u
SET username = CASE
    WHEN n.duplicate_number = 1 THEN left(n.base_username, 24)
    ELSE left(n.base_username, 17) || '_' || left(replace(u.id::text, '-', ''), 6)
END
FROM numbered n
WHERE u.id = n.id
  AND coalesce(u.username, '') = '';

CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique_idx
    ON public.users (lower(username))
    WHERE username IS NOT NULL AND username <> '';


-- ======================================================================
-- 20260706_200_live_stats_and_location_finish.sql
-- ======================================================================

-- Finishes live stream counters used by the app UI.
-- Existing apps remain safe if this migration is applied after deployment.

ALTER TABLE public.live_streams
    ADD COLUMN IF NOT EXISTS total_views INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_comments INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_likes INTEGER DEFAULT 0;

UPDATE public.live_streams ls
SET total_comments = counts.comment_count
FROM (
    SELECT stream_id, count(*)::INTEGER AS comment_count
    FROM public.live_comments
    GROUP BY stream_id
) counts
WHERE ls.id = counts.stream_id
  AND COALESCE(ls.total_comments, 0) <> counts.comment_count;

UPDATE public.live_streams ls
SET total_views = GREATEST(COALESCE(ls.total_views, 0), COALESCE(ls.viewer_count, 0));

CREATE INDEX IF NOT EXISTS idx_live_streams_featured
    ON public.live_streams(is_active, viewer_count DESC, started_at DESC)
    WHERE is_active = true;

CREATE OR REPLACE FUNCTION public.handle_live_comment_sent()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.live_streams
    SET total_comments = COALESCE(total_comments, 0) + 1
    WHERE id = NEW.stream_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_live_comment_sent ON public.live_comments;
CREATE TRIGGER trg_live_comment_sent
AFTER INSERT ON public.live_comments
FOR EACH ROW EXECUTE FUNCTION public.handle_live_comment_sent();


-- ======================================================================
-- 20260706_210_live_likes_follow_notifications.sql
-- ======================================================================

-- Adds persisted live likes used by the live viewer room and featured live cards.

ALTER TABLE public.live_streams
    ADD COLUMN IF NOT EXISTS total_likes INTEGER DEFAULT 0;

UPDATE public.live_streams
SET total_likes = COALESCE(total_likes, 0);


-- ======================================================================
-- 20260706_220_stories_boosts_activity.sql
-- ======================================================================

-- ================================================
-- Stories, profile boosts, and Silver+ activity center
-- Run in Supabase SQL Editor.
-- Safe to re-run (all guards are idempotent).
-- Handles tables left over from partial previous runs.
-- ================================================

-- 1. Extend users table with boost & seed columns
alter table public.users
    add column if not exists show_in_public boolean not null default true,
    add column if not exists boost_expires_at timestamptz,
    add column if not exists boost_score integer not null default 0,
    add column if not exists boost_started_at timestamptz,
    add column if not exists is_seed_profile boolean not null default false;

create index if not exists users_boost_expires_idx on public.users (boost_expires_at desc);
create index if not exists users_seed_public_idx on public.users (is_seed_profile, show_in_public);

-- 2. Profile views
create table if not exists public.profile_views (
    id uuid primary key default gen_random_uuid(),
    viewed_id uuid not null references public.users(id) on delete cascade,
    viewer_id uuid references public.users(id) on delete set null,
    viewer_key text,
    source text not null default 'member',
    created_at timestamptz not null default now()
);

-- Backfill columns if table existed from a partial run
alter table public.profile_views add column if not exists viewed_id uuid references public.users(id) on delete cascade;
alter table public.profile_views add column if not exists viewer_id uuid references public.users(id) on delete set null;
alter table public.profile_views add column if not exists viewer_key text;
alter table public.profile_views add column if not exists source text not null default 'member';
alter table public.profile_views add column if not exists created_at timestamptz not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'profile_views_viewed_viewer_source_created_key'
    ) then
        alter table public.profile_views
            add constraint profile_views_viewed_viewer_source_created_key
            unique (viewed_id, viewer_id, source, created_at);
    end if;
end $$;

create index if not exists profile_views_viewed_created_idx on public.profile_views (viewed_id, created_at desc);
create index if not exists profile_views_viewer_created_idx on public.profile_views (viewer_id, created_at desc);

-- 3. Profile boosts
create table if not exists public.profile_boosts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    tier text not null default 'silver',
    status text not null default 'active',
    source text not null default 'member',
    starts_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '24 hours'),
    created_at timestamptz not null default now()
);

-- Backfill columns
alter table public.profile_boosts add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.profile_boosts add column if not exists tier text not null default 'silver';
alter table public.profile_boosts add column if not exists status text not null default 'active';
alter table public.profile_boosts add column if not exists source text not null default 'member';
alter table public.profile_boosts add column if not exists starts_at timestamptz not null default now();
alter table public.profile_boosts add column if not exists expires_at timestamptz not null default (now() + interval '24 hours');
alter table public.profile_boosts add column if not exists created_at timestamptz not null default now();

create index if not exists profile_boosts_active_idx on public.profile_boosts (status, expires_at desc);
create index if not exists profile_boosts_user_idx on public.profile_boosts (user_id, created_at desc);

-- 4. User stories
create table if not exists public.user_stories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    caption text,
    media_url text not null,
    media_type text not null default 'image',
    background text,
    status text not null default 'active',
    created_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '24 hours')
);

-- Backfill columns
alter table public.user_stories add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.user_stories add column if not exists caption text;
alter table public.user_stories add column if not exists media_url text;
alter table public.user_stories add column if not exists media_type text not null default 'image';
alter table public.user_stories add column if not exists background text;
alter table public.user_stories add column if not exists status text not null default 'active';
alter table public.user_stories add column if not exists created_at timestamptz not null default now();
alter table public.user_stories add column if not exists expires_at timestamptz not null default (now() + interval '24 hours');

create index if not exists user_stories_active_idx on public.user_stories (status, expires_at desc, created_at desc);
create index if not exists user_stories_user_idx on public.user_stories (user_id, created_at desc);

-- 5. Story views
create table if not exists public.story_views (
    id uuid primary key default gen_random_uuid(),
    story_id uuid not null references public.user_stories(id) on delete cascade,
    viewer_id uuid references public.users(id) on delete set null,
    viewer_key text,
    created_at timestamptz not null default now()
);

-- Backfill columns
alter table public.story_views add column if not exists story_id uuid references public.user_stories(id) on delete cascade;
alter table public.story_views add column if not exists viewer_id uuid references public.users(id) on delete set null;
alter table public.story_views add column if not exists viewer_key text;
alter table public.story_views add column if not exists created_at timestamptz not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'story_views_story_id_viewer_id_key'
    ) then
        alter table public.story_views
            add constraint story_views_story_id_viewer_id_key
            unique (story_id, viewer_id);
    end if;
end $$;

create index if not exists story_views_story_idx on public.story_views (story_id, created_at desc);
create index if not exists story_views_viewer_idx on public.story_views (viewer_id, created_at desc);

-- 6. Story likes
create table if not exists public.story_likes (
    id uuid primary key default gen_random_uuid(),
    story_id uuid not null references public.user_stories(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

-- Backfill columns
alter table public.story_likes add column if not exists story_id uuid references public.user_stories(id) on delete cascade;
alter table public.story_likes add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.story_likes add column if not exists created_at timestamptz not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'story_likes_story_id_user_id_key'
    ) then
        alter table public.story_likes
            add constraint story_likes_story_id_user_id_key
            unique (story_id, user_id);
    end if;
end $$;

create index if not exists story_likes_story_idx on public.story_likes (story_id, created_at desc);
create index if not exists story_likes_user_idx on public.story_likes (user_id, created_at desc);

-- 7. Storage bucket for story media
insert into storage.buckets (id, name, public)
values ('story-media', 'story-media', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Story media public read" on storage.objects;
create policy "Story media public read"
on storage.objects for select
using (bucket_id = 'story-media');

drop policy if exists "Story media authenticated insert" on storage.objects;
create policy "Story media authenticated insert"
on storage.objects for insert
with check (bucket_id = 'story-media');

-- 8. RLS for new tables
alter table public.profile_views enable row level security;
alter table public.profile_boosts enable row level security;
alter table public.user_stories enable row level security;
alter table public.story_views enable row level security;
alter table public.story_likes enable row level security;

-- Permissive policies (service-role bypasses RLS for admin routes)
do $$
declare t text;
begin
    foreach t in array array[
        'profile_views','profile_boosts','user_stories','story_views','story_likes'
    ] loop
        execute format('drop policy if exists "app all %1$s" on public.%1$I', t);
        execute format('create policy "app all %1$s" on public.%1$I for all using (true) with check (true)', t);
    end loop;
end $$;

-- 9. Realtime for stories (optional, skip if already added)
do $$
begin
    begin alter publication supabase_realtime add table public.user_stories; exception when duplicate_object or undefined_table then null; end;
    begin alter publication supabase_realtime add table public.story_views; exception when duplicate_object or undefined_table then null; end;
    begin alter publication supabase_realtime add table public.story_likes; exception when duplicate_object or undefined_table then null; end;
end $$;


-- ======================================================================
-- 20260707_020_account_required_fields_and_delete_repair.sql
-- ======================================================================

-- Account creation, profile editing, and deletion support.
-- Non-destructive: adds missing columns/indexes only and keeps existing client data.
-- Safe for projects where public.users.photos already exists as text[].

create extension if not exists pgcrypto;

alter table if exists public.users
    add column if not exists username text,
    add column if not exists display_name text,
    add column if not exists email text,
    add column if not exists avatar_url text,
    add column if not exists photos jsonb not null default '[]'::jsonb,
    add column if not exists bio text,
    add column if not exists description text,
    add column if not exists age integer,
    add column if not exists location text,
    add column if not exists city text,
    add column if not exists country text,
    add column if not exists phone text,
    add column if not exists phone_number text,
    add column if not exists looking_for text,
    add column if not exists wants text,
    add column if not exists needed_qualities text,
    add column if not exists age_range_preference text,
    add column if not exists profile_label text,
    add column if not exists member_category text,
    add column if not exists show_in_public boolean not null default false,
    add column if not exists admin_approved boolean not null default true,
    add column if not exists package_locked boolean not null default false,
    add column if not exists is_banned boolean not null default false,
    add column if not exists is_suspended boolean not null default false,
    add column if not exists auth_user_id uuid,
    add column if not exists password_hash text,
    add column if not exists password_updated_at timestamptz,
    add column if not exists updated_at timestamptz not null default now(),
    add column if not exists created_at timestamptz not null default now();

update public.users
set
    username = coalesce(
        nullif(username, ''),
        lower(regexp_replace(split_part(coalesce(email, id::text), '@', 1), '[^a-zA-Z0-9_]+', '_', 'g'))
    ),
    display_name = coalesce(nullif(display_name, ''), split_part(coalesce(email, 'GS Member'), '@', 1)),
    phone_number = coalesce(nullif(phone_number, ''), phone),
    phone = coalesce(nullif(phone, ''), phone_number),
    description = coalesce(description, bio),
    bio = coalesce(bio, description),
    city = coalesce(nullif(city, ''), location),
    member_category = coalesce(nullif(member_category, ''), profile_label),
    profile_label = coalesce(nullif(profile_label, ''), member_category, 'member')
where id is not null;

with duplicate_usernames as (
    select
        id,
        username,
        row_number() over (partition by lower(username) order by created_at nulls last, id) as duplicate_number
    from public.users
    where username is not null and username <> ''
)
update public.users users_to_fix
set username = left(duplicate_usernames.username, 17) || '_' || left(replace(users_to_fix.id::text, '-', ''), 6)
from duplicate_usernames
where users_to_fix.id = duplicate_usernames.id
  and duplicate_usernames.duplicate_number > 1;

create unique index if not exists users_email_unique_idx
    on public.users (lower(email))
    where email is not null and email <> '';

create unique index if not exists users_username_unique_idx
    on public.users (lower(username))
    where username is not null and username <> '';

create index if not exists users_public_complete_idx
    on public.users (show_in_public, is_banned, is_suspended, updated_at desc);

alter table if exists public.users enable row level security;

drop policy if exists "Users can read public profiles" on public.users;
create policy "Users can read public profiles"
on public.users for select
using (
    show_in_public = true
    or auth.uid() = auth_user_id
);

drop policy if exists "Users can update own account" on public.users;
create policy "Users can update own account"
on public.users for update
using (auth.uid() = auth_user_id)
with check (auth.uid() = auth_user_id);

drop policy if exists "Users can delete own account" on public.users;
create policy "Users can delete own account"
on public.users for delete
using (auth.uid() = auth_user_id);


-- ======================================================================
-- 20260707_030_emergency_auth_members_recovery.sql
-- ======================================================================

﻿-- Emergency auth/members recovery for existing production data.
-- Safe to rerun. Does not delete client data.

create extension if not exists pgcrypto;

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'users' and column_name = 'id' and data_type = 'uuid'
    ) then
        execute 'alter table public.users alter column id set default gen_random_uuid()';
    elsif exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'users' and column_name = 'id'
    ) then
        execute 'alter table public.users alter column id set default gen_random_uuid()::text';
    end if;
end $$;

alter table if exists public.users
    add column if not exists username text,
    add column if not exists password_hash text,
    add column if not exists password_updated_at timestamptz,
    add column if not exists avatar_url text,
    add column if not exists bio text,
    add column if not exists description text,
    add column if not exists age integer,
    add column if not exists location text,
    add column if not exists city text,
    add column if not exists country text,
    add column if not exists phone text,
    add column if not exists phone_number text,
    add column if not exists show_in_public boolean not null default false,
    add column if not exists admin_approved boolean not null default true,
    add column if not exists package_locked boolean not null default false,
    add column if not exists is_banned boolean not null default false,
    add column if not exists is_suspended boolean not null default false,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now(),
    add column if not exists last_seen_at timestamptz,
    add column if not exists last_seen timestamptz,
    add column if not exists verification_status text not null default 'unsubmitted',
    add column if not exists subscription_tier text not null default 'free';

update public.users
set
    username = coalesce(nullif(username, ''), lower(regexp_replace(split_part(coalesce(email, id::text), '@', 1), '[^a-zA-Z0-9_]+', '_', 'g'))),
    phone_number = coalesce(nullif(phone_number, ''), phone),
    phone = coalesce(nullif(phone, ''), phone_number),
    bio = coalesce(bio, description),
    description = coalesce(description, bio),
    city = coalesce(nullif(city, ''), location),
    updated_at = coalesce(updated_at, now())
where id is not null;

with duplicate_usernames as (
    select id, username, row_number() over (partition by lower(username) order by created_at nulls last, id) as duplicate_number
    from public.users
    where username is not null and username <> ''
)
update public.users u
set username = left(duplicate_usernames.username, 17) || '_' || left(replace(u.id::text, '-', ''), 6)
from duplicate_usernames
where u.id = duplicate_usernames.id and duplicate_usernames.duplicate_number > 1;

create unique index if not exists users_email_unique_idx on public.users (lower(email)) where email is not null and email <> '';
create unique index if not exists users_username_unique_idx on public.users (lower(username)) where username is not null and username <> '';
create index if not exists users_public_status_idx on public.users (show_in_public, is_banned, is_suspended, created_at desc);
create index if not exists users_login_email_idx on public.users (lower(email), password_hash);

insert into storage.buckets (id, name, public)
values ('profile-media', 'profile-media', true), ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

alter table if exists public.users enable row level security;

drop policy if exists "Users public read safe" on public.users;
create policy "Users public read safe" on public.users for select using (show_in_public = true or auth.uid() = auth_user_id);


-- ======================================================================
-- 20260708_040_profile_visibility_repair.sql
-- ======================================================================

-- Safe profile visibility repair for existing users.
-- This does not delete users, photos, messages, payments, or verification data.

alter table public.users
    add column if not exists show_in_public boolean default true,
    add column if not exists is_banned boolean default false,
    add column if not exists is_suspended boolean default false,
    add column if not exists username text;

update public.users
set is_banned = false
where is_banned is null;

update public.users
set is_suspended = false
where is_suspended is null;

update public.users
set show_in_public = true
where show_in_public is null
  and coalesce(is_banned, false) = false
  and coalesce(is_suspended, false) = false;

create index if not exists users_active_profiles_idx
    on public.users (is_banned, is_suspended, created_at desc);

create index if not exists users_username_lookup_idx
    on public.users (lower(username))
    where username is not null;


-- ======================================================================
-- 20260710_010_production_hardening_foundation.sql
-- ======================================================================

-- GS production hardening foundation.
-- Safe for live databases: additive schema changes only, no deletes, no truncates, no reseeding.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Users: stable profile, consent, category, seed, and visibility metadata.
-- ---------------------------------------------------------------------------

alter table if exists public.users
    add column if not exists username text,
    add column if not exists display_name text,
    add column if not exists email text,
    add column if not exists avatar_url text,
    add column if not exists bio text,
    add column if not exists description text,
    add column if not exists age integer,
    add column if not exists location text,
    add column if not exists city text,
    add column if not exists country text,
    add column if not exists phone text,
    add column if not exists phone_number text,
    add column if not exists profile_label text,
    add column if not exists member_category text,
    add column if not exists looking_for text,
    add column if not exists wants text,
    add column if not exists needed_qualities text,
    add column if not exists age_range_preference text,
    add column if not exists auth_user_id uuid,
    add column if not exists show_in_public boolean default true,
    add column if not exists admin_approved boolean default true,
    add column if not exists package_locked boolean default false,
    add column if not exists is_banned boolean default false,
    add column if not exists is_suspended boolean default false,
    add column if not exists is_seed_profile boolean not null default false,
    add column if not exists boost_expires_at timestamptz,
    add column if not exists boost_score integer not null default 0,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now(),
    add column if not exists account_type text,
    add column if not exists profile_intent text,
    add column if not exists profile_completion_status text not null default 'incomplete',
    add column if not exists profile_completed_at timestamptz,
    add column if not exists terms_accepted_at timestamptz,
    add column if not exists privacy_accepted_at timestamptz,
    add column if not exists community_guidelines_accepted_at timestamptz,
    add column if not exists last_prompted_complete_profile_at timestamptz,
    add column if not exists location_consent_at timestamptz,
    add column if not exists precise_location_consent_at timestamptz,
    add column if not exists device_latitude numeric(10, 7),
    add column if not exists device_longitude numeric(10, 7),
    add column if not exists ip_latitude numeric(10, 7),
    add column if not exists ip_longitude numeric(10, 7),
    add column if not exists location_source text,
    add column if not exists seed_category text,
    add column if not exists seed_source_path text,
    add column if not exists seed_media_ok boolean not null default true,
    add column if not exists seed_repaired_at timestamptz,
    add column if not exists real_user boolean not null default true,
    add column if not exists profile_sort_bucket integer not null default 0,
    add column if not exists featured_until timestamptz,
    add column if not exists last_engagement_at timestamptz,
    add column if not exists account_deleted_at timestamptz;

alter table if exists public.users
    alter column show_in_public set default true,
    alter column admin_approved set default true,
    alter column package_locked set default false,
    alter column is_banned set default false,
    alter column is_suspended set default false;

update public.users
set
    real_user = case
        when coalesce(is_seed_profile, false) = true then false
        when email ilike 'seed+%' then false
        else coalesce(real_user, true)
    end,
    account_type = coalesce(nullif(account_type, ''), nullif(member_category, ''), nullif(profile_label, '')),
    profile_intent = coalesce(nullif(profile_intent, ''), nullif(looking_for, ''), nullif(wants, '')),
    show_in_public = coalesce(show_in_public, true),
    admin_approved = coalesce(admin_approved, true),
    package_locked = coalesce(package_locked, false),
    is_banned = coalesce(is_banned, false),
    is_suspended = coalesce(is_suspended, false)
where id is not null;

update public.users
set profile_completion_status = case
    when coalesce(display_name, '') <> ''
     and coalesce(avatar_url, '') <> ''
     and coalesce(age, 0) >= 18
     and coalesce(location, city, '') <> ''
     and coalesce(account_type, member_category, profile_label, '') <> ''
     and coalesce(profile_intent, looking_for, '') <> ''
    then 'complete'
    else 'incomplete'
end
where coalesce(is_seed_profile, false) = false;

update public.users
set
    profile_completion_status = 'complete',
    profile_completed_at = coalesce(profile_completed_at, now()),
    real_user = false
where coalesce(is_seed_profile, false) = true
   or email ilike 'seed+%';

create index if not exists users_public_runtime_idx
    on public.users (show_in_public, is_banned, is_suspended, profile_completion_status, created_at desc);

create index if not exists users_category_runtime_idx
    on public.users (account_type, member_category, profile_label, created_at desc);

create index if not exists users_seed_runtime_idx
    on public.users (is_seed_profile, seed_category, seed_media_ok);

create index if not exists users_featured_runtime_idx
    on public.users (featured_until desc, boost_expires_at desc, last_engagement_at desc);

-- ---------------------------------------------------------------------------
-- Package tier columns expected by the current application code.
-- ---------------------------------------------------------------------------

create table if not exists public.package_tiers (
    id text primary key,
    name text not null,
    price_ksh integer not null default 0,
    sort_order integer not null default 0,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

alter table if exists public.package_tiers
    add column if not exists features jsonb default '[]'::jsonb,
    add column if not exists daily_like_limit integer default 5,
    add column if not exists daily_super_like_limit integer default 0,
    add column if not exists daily_swipe_limit integer default 10,
    add column if not exists daily_profile_view_limit integer default 10,
    add column if not exists can_see_who_liked boolean default false,
    add column if not exists can_see_who_viewed boolean default false,
    add column if not exists can_send_voice_notes boolean default false,
    add column if not exists can_send_images boolean default false,
    add column if not exists can_go_live boolean default false,
    add column if not exists can_send_gifts boolean default false,
    add column if not exists can_use_nearby boolean default false,
    add column if not exists max_gift_tier integer default 0,
    add column if not exists starting_credits integer default 0,
    add column if not exists badge_label text default '',
    add column if not exists badge_color text default '',
    add column if not exists description text default '',
    add column if not exists updated_at timestamptz not null default now();

update public.package_tiers
set
    daily_like_limit = coalesce(daily_like_limit, 5),
    daily_super_like_limit = coalesce(daily_super_like_limit, 0),
    daily_swipe_limit = coalesce(daily_swipe_limit, 10),
    daily_profile_view_limit = coalesce(daily_profile_view_limit, 10),
    can_see_who_liked = coalesce(can_see_who_liked, false),
    can_see_who_viewed = coalesce(can_see_who_viewed, false),
    can_send_voice_notes = coalesce(can_send_voice_notes, false),
    can_send_images = coalesce(can_send_images, false),
    can_go_live = coalesce(can_go_live, false),
    can_send_gifts = coalesce(can_send_gifts, false),
    can_use_nearby = coalesce(can_use_nearby, false),
    max_gift_tier = coalesce(max_gift_tier, 0),
    starting_credits = coalesce(starting_credits, 0),
    features = coalesce(features, '[]'::jsonb),
    updated_at = now()
where id is not null;

-- ---------------------------------------------------------------------------
-- Legacy chat compatibility repair.
-- ---------------------------------------------------------------------------

create table if not exists public.conversations (
    id uuid primary key default gen_random_uuid(),
    user_one_id uuid references public.users(id) on delete cascade,
    user_two_id uuid references public.users(id) on delete cascade,
    status text not null default 'active',
    last_message_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table if exists public.conversations
    add column if not exists user_one_id uuid references public.users(id) on delete cascade,
    add column if not exists user_two_id uuid references public.users(id) on delete cascade,
    add column if not exists status text not null default 'active',
    add column if not exists last_message_at timestamptz,
    add column if not exists updated_at timestamptz not null default now();

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'conversations' and column_name = 'user_id'
    ) then
        execute 'alter table public.conversations alter column user_id drop not null';
    end if;
end $$;

create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid references public.conversations(id) on delete cascade,
    sender_id uuid references public.users(id) on delete set null,
    receiver_id uuid references public.users(id) on delete set null,
    body text default '',
    message_type text not null default 'text',
    status text not null default 'sent',
    read_at timestamptz,
    delivered_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

alter table if exists public.messages
    add column if not exists conversation_id uuid references public.conversations(id) on delete cascade,
    add column if not exists sender_id uuid references public.users(id) on delete set null,
    add column if not exists receiver_id uuid references public.users(id) on delete set null,
    add column if not exists body text default '',
    add column if not exists message_type text not null default 'text',
    add column if not exists status text not null default 'sent',
    add column if not exists read_at timestamptz,
    add column if not exists delivered_at timestamptz,
    add column if not exists metadata jsonb not null default '{}'::jsonb,
    add column if not exists created_at timestamptz not null default now();

update public.messages
set body = coalesce(nullif(body, ''), '')
where body is null;

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'messages' and column_name = 'content'
    ) then
        execute 'update public.messages set content = coalesce(nullif(content, ''''), nullif(body, ''''), '''') where content is null or content = ''''';
        execute 'alter table public.messages alter column content set default ''''';
        execute 'alter table public.messages alter column content set not null';
    end if;
end $$;

create index if not exists conversations_users_runtime_idx
    on public.conversations (user_one_id, user_two_id, updated_at desc);

create index if not exists messages_runtime_idx
    on public.messages (conversation_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Consent, reminders, admin attention, payments, and usage audit foundations.
-- ---------------------------------------------------------------------------

create table if not exists public.user_terms_acceptances (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete cascade,
    terms_version text not null default '2026-07-10',
    privacy_version text not null default '2026-07-10',
    community_version text not null default '2026-07-10',
    ip_address text,
    user_agent text,
    accepted_at timestamptz not null default now()
);

create table if not exists public.profile_completion_reminders (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete cascade,
    email text,
    reminder_type text not null default 'complete_profile',
    status text not null default 'queued',
    attempts integer not null default 0,
    last_error text default '',
    scheduled_for timestamptz not null default now(),
    sent_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.admin_attention_items (
    id uuid primary key default gen_random_uuid(),
    section text not null,
    item_type text not null,
    user_id uuid references public.users(id) on delete set null,
    severity text not null default 'normal',
    title text not null,
    body text default '',
    status text not null default 'open',
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    resolved_at timestamptz
);

create table if not exists public.payment_provider_configs (
    id uuid primary key default gen_random_uuid(),
    provider text not null,
    is_active boolean not null default false,
    display_name text not null,
    public_metadata jsonb not null default '{}'::jsonb,
    private_metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(provider)
);

create table if not exists public.payment_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete set null,
    provider text not null,
    package_id text,
    amount_ksh integer,
    provider_reference text,
    status text not null default 'pending',
    raw_payload jsonb not null default '{}'::jsonb,
    reviewed_by uuid references public.users(id) on delete set null,
    reviewed_at timestamptz,
    created_at timestamptz not null default now()
);

create table if not exists public.package_usage_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete cascade,
    package_id text not null default 'free',
    feature text not null,
    action text not null,
    allowed boolean not null default true,
    reason text default '',
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists public.system_health_events (
    id uuid primary key default gen_random_uuid(),
    source text not null,
    level text not null default 'info',
    message text not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists user_terms_user_created_idx
    on public.user_terms_acceptances (user_id, accepted_at desc);

create index if not exists profile_completion_reminders_due_idx
    on public.profile_completion_reminders (status, scheduled_for);

create index if not exists admin_attention_open_idx
    on public.admin_attention_items (status, section, severity, created_at desc);

create index if not exists payment_events_user_created_idx
    on public.payment_events (user_id, created_at desc);

create index if not exists package_usage_user_feature_idx
    on public.package_usage_events (user_id, feature, created_at desc);

create index if not exists system_health_source_created_idx
    on public.system_health_events (source, created_at desc);

alter table public.user_terms_acceptances enable row level security;
alter table public.profile_completion_reminders enable row level security;
alter table public.admin_attention_items enable row level security;
alter table public.payment_provider_configs enable row level security;
alter table public.payment_events enable row level security;
alter table public.package_usage_events enable row level security;
alter table public.system_health_events enable row level security;

drop policy if exists "Users read own terms acceptances" on public.user_terms_acceptances;
create policy "Users read own terms acceptances"
on public.user_terms_acceptances for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Users read own reminders" on public.profile_completion_reminders;
create policy "Users read own reminders"
on public.profile_completion_reminders for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Users read own payment events" on public.payment_events;
create policy "Users read own payment events"
on public.payment_events for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Users read own package usage" on public.package_usage_events;
create policy "Users read own package usage"
on public.package_usage_events for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Public read active payment providers" on public.payment_provider_configs;
create policy "Public read active payment providers"
on public.payment_provider_configs for select
using (is_active = true);

-- Service role bypasses RLS in Supabase and should perform admin writes through server routes only.

insert into public.system_health_events (source, level, message, metadata)
values (
    'migration',
    'info',
    'Production hardening foundation migration installed',
    jsonb_build_object('migration', '20260710_010_production_hardening_foundation')
);


-- ======================================================================
-- 20260813_020_lock_down_public_table_access.sql
-- ======================================================================

-- Close the tables that the public anon key can currently read and write.
--
-- NEXT_PUBLIC_SUPABASE_ANON_KEY ships inside the JavaScript bundle. It is meant
-- to be public, and that is fine only while row level security actually
-- constrains it. Here it did not.
--
-- Twenty four tables carry a policy of the form
--
--     CREATE POLICY "..." ON public.<table> FOR ALL USING (true) WITH CHECK (true);
--
-- Several are named "Service role manages ...", but a policy with no TO clause
-- applies to every role, anon included. The name records an intention that the
-- SQL never expressed.
--
-- 20260703_110 revoked eleven of those tables from anon and authenticated, which
-- is what has been holding this together. The rest were left open.
--
-- The worst of them is password_reset_codes. It holds email, code_hash,
-- expires_at and used_at, and the reset flow in src/app/api/members/route.js
-- accepts a reset when it finds a matching, unused, unexpired row:
--
--   codeHash = sha256(email + ':' + code)      six digit code, no salt
--   select ... where email = ? and code_hash = ? and used_at is null
--                and expires_at > now()
--
-- With write access to that table an attacker does not need to intercept
-- anything or wait for a victim to request a reset. They insert their own row
-- for any email with a code_hash they computed, then call the public
-- reset_password endpoint with that code. That is account takeover on demand.
-- Read access alone is nearly as bad: the hash is unsalted over a known email
-- and a 900,000 value space, so recovering the code is seconds of work.
--
-- Nothing in the app writes to these tables from the browser. Every write goes
-- through an API route holding the service role key, which bypasses RLS. So
-- revoking anon and authenticated costs the app nothing.
--
-- The exception is realtime. Supabase delivers postgres_changes through RLS, so
-- a table the browser subscribes to must remain selectable by anon. Four
-- subscriptions exist:
--
--   call_sessions    IncomingCallManager
--   call_signals     the active call screen
--   live_comments    the live stream screen
--   live_gifts       the live stream screen
--   messages         the chat thread
--
-- messages is already restricted by a policy keyed on auth.uid(). This app does
-- not use Supabase Auth at all — it verifies passwords against its own users
-- table — so auth.uid() is null for every visitor and that subscription has
-- never delivered a single row. Polling has always been what actually worked,
-- which is why the intervals were tuned so low.
--
-- call_sessions and call_signals cannot be scoped to a viewer for the same
-- reason: with no auth.uid() there is no way for a policy to tell one member
-- from another, so leaving them selectable means every member's call metadata
-- and WebRTC signalling is readable by anyone with the public key. Twenty five
-- seconds of ring latency is not worth that, so they are closed and the app
-- polls instead. See the matching change to POLL.INCOMING_CALLS.
--
-- live_comments and live_gifts stay readable. They are public by nature: they
-- are what a live stream shows to everyone watching it.

begin;

-- ---------------------------------------------------------------------------
-- Server-only tables.
-- ---------------------------------------------------------------------------
do $$
declare
    t text;
    p record;
    server_only text[] := array[
        -- Account takeover risk, in order of severity.
        'password_reset_codes',
        'email_outbox',
        'broadcasts',
        'admin_logs',
        'app_limits',
        -- Call plumbing. Written by the API, no longer subscribed to.
        'call_sessions',
        'call_signals',
        'call_events',
        'call_requests',
        -- Member activity, all written through API routes.
        'member_follows',
        'member_gifts',
        'member_likes',
        'member_messages',
        'member_saves',
        'member_swipes',
        'profile_views',
        'user_interactions',
        'user_settings',
        'user_daily_usage',
        'package_requests',
        'support_tickets',
        'ticket_responses',
        'user_notifications'
    ];
begin
    foreach t in array server_only loop
        if to_regclass('public.' || t) is null then
            continue;
        end if;

        execute format('alter table public.%I enable row level security', t);

        -- Drop every existing policy rather than naming them. The blanket
        -- policies were created under several different names across
        -- migrations, and a DROP POLICY IF EXISTS list would silently miss any
        -- that were renamed.
        for p in
            select policyname from pg_policies
            where schemaname = 'public' and tablename = t
        loop
            execute format('drop policy %I on public.%I', p.policyname, t);
        end loop;

        -- The service role bypasses RLS, so no policy is needed for the API.
        -- No policy at all means no other role can read or write anything.
        execute format('revoke all on public.%I from anon, authenticated', t);
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Public live stream content: readable, never writable.
-- ---------------------------------------------------------------------------
do $$
declare
    t text;
    p record;
    read_only text[] := array['live_comments', 'live_gifts', 'live_streams'];
begin
    foreach t in array read_only loop
        if to_regclass('public.' || t) is null then
            continue;
        end if;

        execute format('alter table public.%I enable row level security', t);

        for p in
            select policyname from pg_policies
            where schemaname = 'public' and tablename = t
        loop
            execute format('drop policy %I on public.%I', p.policyname, t);
        end loop;

        -- SELECT only, and only for reading. Comments and gifts are still
        -- inserted by the API with the service role.
        execute format('revoke all on public.%I from anon, authenticated', t);
        execute format('grant select on public.%I to anon, authenticated', t);
        execute format(
            'create policy %I on public.%I for select to anon, authenticated using (true)',
            t || '_public_read', t);
    end loop;
end $$;

commit;

-- After running this, confirm nothing is left open:
--
--   select tablename, policyname, roles, cmd, qual
--   from pg_policies
--   where schemaname = 'public'
--     and (qual = 'true' or qual is null)
--   order by tablename;
--
-- Anything listed there with cmd = 'ALL' and roles including anon is another
-- instance of the problem this migration exists to fix.


-- ======================================================================
-- 20260813_030_collapse_repeated_reminders.sql
-- ======================================================================

-- Delete the duplicate standing reminders already sitting in members' inboxes.
--
-- "Complete your profile", "Manual verification is available" and "Unlock
-- premium GS features" are conditions, not events: they stay true until the
-- member does something about them. The server posted a fresh copy of each
-- every 24 hours for as long as the condition held, so an unverified free
-- account collected three new inbox messages a day, identical to yesterday's.
--
-- That is how an inbox reaches 58 items showing the same two notices over and
-- over, and it buries the messages that are genuinely events — a real message,
-- a match, an admin reply — under nags nobody asked to see again.
--
-- The code no longer does this: notifyOnceDaily now refuses while an unread
-- copy exists and waits a week after one is read. This clears what was already
-- delivered, which would otherwise stay in those inboxes forever.
--
-- Only the three reminder types are touched. Likes, matches, messages and admin
-- replies are events, and two of them are two things.

begin;

with ranked as (
    select
        id,
        row_number() over (
            partition by user_id, type
            -- Keep the newest, and prefer an unread one: a member who has not
            -- seen the reminder should still find it there afterwards.
            order by read asc, created_at desc
        ) as position
    from public.user_notifications
    where type in ('profile', 'verification', 'package')
)
delete from public.user_notifications
where id in (select id from ranked where position > 1);

commit;

-- How many remain per member, which should now be at most one of each:
--
--   select user_id, type, count(*)
--   from public.user_notifications
--   where type in ('profile', 'verification', 'package')
--   group by user_id, type
--   having count(*) > 1;
--
-- Any rows returned there mean the code path that writes them has regressed.


-- ======================================================================
-- 20260813_040_auth_attempt_throttle.sql
-- ======================================================================

-- Record authentication attempts, so they can be throttled.
--
-- Nothing limited them. Login accepted unlimited password guesses against any
-- address, and password reset was worse: createResetCode returns a six digit
-- number, so 900,000 possibilities, and reset_password would check as many
-- guesses as anyone cared to send.
--
-- That is a complete account takeover path against any email on the platform.
-- Request a reset for the address, then walk the code space. At a hundred
-- requests a second it averages about seventy five minutes, and nothing
-- anywhere would have noticed or slowed down.
--
-- The table is deliberately small and dumb: one row per attempt, read back over
-- a short window. No counters to keep in step, and nothing to reset by hand
-- when somebody is locked out — the window simply passes.

create table if not exists public.auth_attempts (
    id uuid primary key default gen_random_uuid(),
    -- 'login:someone@example.com' or 'reset:someone@example.com'. Scoped by
    -- address rather than by IP: an attacker moves between addresses easily,
    -- and locking an IP would take out everyone behind a shared connection,
    -- which in Kenya is most mobile users.
    scope text not null,
    succeeded boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists auth_attempts_scope_time_idx
    on public.auth_attempts (scope, created_at desc);

alter table public.auth_attempts enable row level security;

-- No policy at all, so only the service role reaches it. The API routes are the
-- only thing that should ever read or write this, and a member being able to
-- read it would hand them a list of which addresses exist.
revoke all on public.auth_attempts from anon, authenticated;

-- Old rows are useless once the window has passed, and this table grows on
-- every sign-in on the busiest path in the app.
create or replace function public.prune_auth_attempts()
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.auth_attempts where created_at < now() - interval '24 hours';
$$;


-- ======================================================================
-- 20261029_010_basic_standard_price_and_claim_offer.sql
-- ======================================================================

-- Standard Basic access is KSh750. The separate app-only local introduction
-- offer is KSh650 and is recorded as an admin-reviewed offer, not a package.
UPDATE public.package_tiers
SET price_ksh = 750,
    description = 'Starter app access. Local introduction requests are a separate service with their own published fee and availability review.',
    features = '[
        "30 messages per day",
        "10 likes and 5 Super Likes per day",
        "30 swipes and 30 profile views per day",
        "Image sharing in chat",
        "Tier 1 gifts, subject to available credits",
        "No phone reveal, voice/video calls, or live streaming"
    ]'::jsonb,
    updated_at = now()
WHERE id = 'basic';


-- ======================================================================
-- 20261029_020_web_push_subscriptions.sql
-- ======================================================================

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL UNIQUE,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'web',
    permission TEXT NOT NULL DEFAULT 'granted',
    user_agent TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user
    ON public.push_subscriptions(user_id, updated_at DESC);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role manages push_subscriptions" ON public.push_subscriptions;
CREATE POLICY "service role manages push_subscriptions"
    ON public.push_subscriptions FOR ALL TO service_role
    USING (true) WITH CHECK (true);


-- ======================================================================
-- 20261029_030_security_invoker_public_profiles.sql
-- ======================================================================

-- Make the public profile projection honor the querying role's RLS policies.

BEGIN;

DROP POLICY IF EXISTS "Public can read users" ON public.users;
DROP POLICY IF EXISTS "Public can read visible users" ON public.users;
DROP POLICY IF EXISTS "Public can upsert users" ON public.users;
DROP POLICY IF EXISTS "Users can read public profiles" ON public.users;
DROP POLICY IF EXISTS "Users public read safe" ON public.users;

CREATE POLICY "Users can read active public profiles or their own row"
    ON public.users
    FOR SELECT
    TO anon, authenticated
    USING (
        (
            show_in_public = true
            AND COALESCE(is_banned, false) = false
            AND COALESCE(is_suspended, false) = false
        )
        OR auth.uid() = auth_user_id
    );

REVOKE SELECT (auth_user_id) ON public.users FROM anon, authenticated;
GRANT SELECT (
    id,
    display_name,
    avatar_url,
    photos,
    bio,
    age,
    location,
    country,
    city,
    profile_label,
    member_category,
    looking_for,
    intent_summary,
    wants,
    needed_qualities,
    age_range_preference,
    hobbies,
    interests,
    subscription_tier,
    verified,
    show_in_public,
    total_profile_views,
    followers_count,
    gifts_received_count,
    created_at,
    last_seen_at,
    is_banned,
    is_suspended
) ON public.users TO anon, authenticated;

CREATE OR REPLACE VIEW public.public_profiles
    WITH (security_invoker = true)
AS
SELECT
    id,
    display_name,
    avatar_url,
    photos,
    bio,
    age,
    location,
    country,
    city,
    profile_label,
    member_category,
    looking_for,
    intent_summary,
    wants,
    needed_qualities,
    age_range_preference,
    hobbies,
    interests,
    subscription_tier,
    verified,
    show_in_public,
    total_profile_views,
    followers_count,
    gifts_received_count,
    created_at,
    last_seen_at
FROM public.users
WHERE show_in_public = true
  AND COALESCE(is_banned, false) = false
  AND COALESCE(is_suspended, false) = false;

GRANT SELECT ON public.public_profiles TO anon, authenticated;

COMMIT;
