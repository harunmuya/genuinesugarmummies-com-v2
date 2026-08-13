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
