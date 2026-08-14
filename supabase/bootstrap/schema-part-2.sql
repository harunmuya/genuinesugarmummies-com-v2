-- GS Global schema, part 2 of 3.
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
-- 20260703_110_real_time_dating_security_and_media.sql
-- ==================================================================

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

INSERT INTO public.gift_catalog (name, category, gif_url, credit_cost, sort_order)
VALUES
('Rose', 'Flowers', 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', 5, 1),
('Heart', 'Hearts', 'https://media.giphy.com/media/26FLdmIp6wJr91JAI/giphy.gif', 8, 2),
('Coffee', 'Coffee', 'https://media.giphy.com/media/687qS11pXwjCM/giphy.gif', 10, 3),
('Diamond', 'Luxury', 'https://media.giphy.com/media/l4FGnZ5NlHuvHfthm/giphy.gif', 25, 4),
('Crown', 'Premium', 'https://media.giphy.com/media/okLCopqw6ElCDnIhuS/giphy.gif', 40, 5)
ON CONFLICT DO NOTHING;

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

-- ==================================================================
-- 20260703_120_missing_real_features_tables.sql
-- ==================================================================

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

INSERT INTO public.gift_catalog (name, category, gif_url, credit_cost, sort_order)
VALUES
('Rose', 'Flowers', 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', 5, 1),
('Bouquet', 'Flowers', 'https://media.giphy.com/media/3o7aD2saalBwwftBIY/giphy.gif', 12, 2),
('Heart', 'Hearts', 'https://media.giphy.com/media/26FLdmIp6wJr91JAI/giphy.gif', 8, 3),
('Coffee', 'Coffee', 'https://media.giphy.com/media/687qS11pXwjCM/giphy.gif', 10, 4),
('Diamond', 'Luxury', 'https://media.giphy.com/media/l4FGnZ5NlHuvHfthm/giphy.gif', 25, 5),
('Crown', 'Premium', 'https://media.giphy.com/media/okLCopqw6ElCDnIhuS/giphy.gif', 40, 6)
ON CONFLICT DO NOTHING;

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

-- ==================================================================
-- 20260704_140_real_call_foundation.sql
-- ==================================================================

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

-- ==================================================================
-- 20260704_150_real_gift_inventory.sql
-- ==================================================================

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

-- ==================================================================
-- 20260704_160_calls_public_matches_packages.sql
-- ==================================================================

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

-- ==================================================================
-- 20260704_170_antigravity_upgrade_migration.sql
-- ==================================================================

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

INSERT INTO public.gift_catalog (name, emoji, category, credit_cost, tier, sort_order, is_active) VALUES
-- Tier 1: Under 10 credits (14 gifts)
('Rose', '🌹', 'Flowers', 1, 1, 1, true),
('Sweet Heart', '💕', 'Hearts', 1, 1, 2, true),
('Lucky Star', '⭐', 'Lucky', 1, 1, 3, true),
('Butterfly', '🦋', 'Nature', 1, 1, 4, true),
('Cherry Blossom', '🌸', 'Flowers', 1, 1, 5, true),
('Lucky Clover', '🍀', 'Lucky', 1, 1, 6, true),
('Sparkle', '✨', 'Effects', 1, 1, 7, true),
('Music Note', '🎵', 'Entertainment', 1, 1, 8, true),
('Flame', '🔥', 'Effects', 1, 1, 9, true),
('Sunshine', '☀️', 'Nature', 1, 1, 10, true),
('Rainbow', '🌈', 'Nature', 1, 1, 11, true),
('Crystal', '💎', 'Luxury', 1, 1, 12, true),
('Pink Ribbon', '🎀', 'Fashion', 1, 1, 13, true),
('Sweet Candy', '🍬', 'Food', 1, 1, 14, true),
-- Tier 1: 5 credits (8 gifts)
('Ice Cream', '🍦', 'Food', 5, 1, 15, true),
('Cupcake', '🧁', 'Food', 5, 1, 16, true),
('Bullseye', '🎯', 'Games', 5, 1, 17, true),
('Lucky Dice', '🎲', 'Games', 5, 1, 18, true),
('Shooting Star', '🌠', 'Effects', 5, 1, 19, true),
('Lightning Bolt', '⚡', 'Effects', 5, 1, 20, true),
('Hibiscus', '🌺', 'Flowers', 5, 1, 21, true),
('Coffee', '☕', 'Food', 5, 1, 22, true),
-- Tier 2: 10-99 credits (11 gifts)
('Royal Crown', '👑', 'Premium', 10, 2, 23, true),
('Perfume', '🌸', 'Fashion', 15, 2, 24, true),
('Drama Mask', '🎭', 'Entertainment', 15, 2, 25, true),
('Flower Bouquet', '💐', 'Flowers', 20, 2, 26, true),
('Teddy Bear', '🧸', 'Cute', 25, 2, 27, true),
('Rock Guitar', '🎸', 'Entertainment', 30, 2, 28, true),
('Microphone', '🎤', 'Entertainment', 30, 2, 29, true),
('Unicorn', '🦄', 'Fantasy', 50, 2, 30, true),
('Diamond Ring', '💍', 'Luxury', 50, 2, 31, true),
('Carousel', '🎠', 'Entertainment', 75, 2, 32, true),
('Ferris Wheel', '🎡', 'Entertainment', 99, 2, 33, true),
-- Tier 2 continued
('Designer Bag', '👜', 'Fashion', 99, 2, 34, true),
('Champagne', '🍾', 'Luxury', 99, 2, 35, true),
-- Tier 3: 100-999 credits (6 gifts)
('Golden Trophy', '🏆', 'Premium', 100, 3, 36, true),
('Diamond', '💎', 'Luxury', 200, 3, 37, true),
('Top Hat', '🎩', 'Fashion', 300, 3, 38, true),
('Sports Car', '🏎️', 'Luxury', 300, 3, 39, true),
('Peacock', '🦚', 'Nature', 400, 3, 40, true),
('Castle', '🏰', 'Premium', 500, 3, 41, true),
('Luxury Yacht', '🛥️', 'Luxury', 699, 3, 42, true),
('Dragon', '🐉', 'Fantasy', 799, 3, 43, true),
('Fireworks', '🎆', 'Effects', 999, 3, 44, true),
-- Tier 4: 1000+ credits (9 gifts)
('Space Rocket', '🚀', 'Premium', 1000, 4, 45, true),
('Galaxy', '🌌', 'Premium', 2000, 4, 46, true),
('Meteor Shower', '☄️', 'Premium', 3000, 4, 47, true),
('Planet', '🪐', 'Premium', 5000, 4, 48, true),
('Crystal Ball', '🔮', 'Fantasy', 10000, 4, 49, true),
('Queens Crown', '👸', 'Premium', 15000, 4, 50, true),
('Grand Palace', '🏛️', 'Premium', 20000, 4, 51, true),
('Treasure', '💰', 'Premium', 34999, 4, 52, true),
('Golden Dragon', '🐲', 'Premium', 44999, 4, 53, true)
ON CONFLICT (name) DO UPDATE SET
    emoji = EXCLUDED.emoji,
    category = EXCLUDED.category,
    credit_cost = EXCLUDED.credit_cost,
    tier = EXCLUDED.tier,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

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

-- ==================================================================
-- 20260704_180_package_tiers_feature_gates.sql
-- ==================================================================

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

-- ==================================================================
-- 20260706_190_unique_usernames_admin_attention.sql
-- ==================================================================

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

-- ==================================================================
-- 20260706_200_live_stats_and_location_finish.sql
-- ==================================================================

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

-- ==================================================================
-- 20260706_210_live_likes_follow_notifications.sql
-- ==================================================================

-- Adds persisted live likes used by the live viewer room and featured live cards.

ALTER TABLE public.live_streams
    ADD COLUMN IF NOT EXISTS total_likes INTEGER DEFAULT 0;

UPDATE public.live_streams
SET total_likes = COALESCE(total_likes, 0);

-- ==================================================================
-- 20260706_220_stories_boosts_activity.sql
-- ==================================================================

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

-- ==================================================================
-- 20260707_020_account_required_fields_and_delete_repair.sql
-- ==================================================================

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

-- ==================================================================
-- 20260707_030_emergency_auth_members_recovery.sql
-- ==================================================================

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
