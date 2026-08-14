-- Everything needed to stand this app up on a fresh Supabase project.
--
-- Every migration in supabase/migrations, concatenated in filename order, which
-- is the order they were written and the order they must be applied. Paste the
-- whole file into the SQL Editor of the new project and run it once.
--
-- The migrations are written with IF NOT EXISTS and DROP POLICY IF EXISTS
-- throughout, so running this against a project that already has some of it is
-- safe.
--
-- This is schema only. It creates no members, no messages and no packages
-- beyond the seeded package tiers. Read docs/migrating-supabase.md before using
-- it: on a restricted project the data cannot be exported, and standing this up
-- without the data means every member loses their account.
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

INSERT INTO public.users (email, display_name, avatar_url, photos, bio, description, age, location, country, city, phone, phone_number, profile_label, member_category, looking_for, intent_summary, wants, needed_qualities, age_range_preference, hobbies, interests, body_type, subscription_tier, verified, verification_status, show_in_public, is_banned, is_suspended, total_profile_views, followers_count, admin_approved, phone_reveal_plan, is_seed_profile, last_seen_at, last_seen, created_at) VALUES
('seed+mistress-001@genuinesugarmummies.com', 'Aisha Kamau', '/seed/mistresses/photo_10_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_10_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, generous, kind. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, generous, kind. Preferred age range: 38-68.', 22, 'Mombasa', 'Kenya', 'Mombasa', '+254713198246', '+254713198246', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'honest, generous, kind, respectful', '38-68', ARRAY['fine dining', 'photography', 'fitness', 'live music']::TEXT[], ARRAY['lifestyle support', 'meaningful conversations', 'private dates', 'premium experiences']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 1985, 235, true, 'silver', true, '2026-06-25T12:17:59+00', '2026-06-25T12:17:59+00', '2026-06-24T11:24:59+00'),
('seed+mistress-002@genuinesugarmummies.com', 'Brenda Kariuki', '/seed/mistresses/photo_11_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_11_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: serious about meeting, discreet, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: serious about meeting, discreet, respectful. Preferred age range: 38-68.', 23, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254730832052', '+254730832052', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'serious about meeting, discreet, respectful, kind', '38-68', ARRAY['business events', 'fine dining', 'coffee dates', 'live music']::TEXT[], ARRAY['verified members', 'long-term arrangement', 'lifestyle support', 'discreet connection']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2867, 444, true, 'silver', true, '2026-06-25T12:10:59+00', '2026-06-25T12:10:59+00', '2026-06-23T10:24:59+00'),
('seed+mistress-003@genuinesugarmummies.com', 'Cynthia Nambooze', '/seed/mistresses/photo_12_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_12_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, serious matches. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, serious about meeting, discreet. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, serious matches. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, serious about meeting, discreet. Preferred age range: 38-68.', 24, 'Eldoret', 'Kenya', 'Eldoret', '+254715865179', '+254715865179', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'consistent, serious about meeting, discreet, kind', '38-68', ARRAY['weekend drives', 'live music', 'dancing', 'fashion']::TEXT[], ARRAY['private dates', 'serious matches', 'long-term arrangement', 'respectful companionship']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4472, 482, true, 'silver', true, '2026-06-25T12:03:59+00', '2026-06-25T12:03:59+00', '2026-06-22T09:24:59+00'),
('seed+mistress-004@genuinesugarmummies.com', 'Diana Nkurunziza', '/seed/mistresses/photo_13_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_13_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, premium experiences. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, respectful, emotionally mature. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, premium experiences. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, respectful, emotionally mature. Preferred age range: 38-68.', 25, 'Mombasa', 'Kenya', 'Mombasa', '+254747183667', '+254747183667', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'generous, respectful, emotionally mature, kind', '38-68', ARRAY['wine tasting', 'beach walks', 'travel', 'coffee dates']::TEXT[], ARRAY['mentorship', 'premium experiences', 'lifestyle support', 'verified members']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 1987, 887, true, 'silver', true, '2026-06-25T11:56:59+00', '2026-06-25T11:56:59+00', '2026-06-21T08:24:59+00'),
('seed+mistress-005@genuinesugarmummies.com', 'Evelyn Okello', '/seed/mistresses/photo_14_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_14_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, discreet, generous. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, discreet, generous. Preferred age range: 38-68.', 26, 'Mombasa', 'Kenya', 'Mombasa', '+254791279451', '+254791279451', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'emotionally mature, discreet, generous, honest', '38-68', ARRAY['beach walks', 'fitness', 'art galleries', 'spa days']::TEXT[], ARRAY['premium experiences', 'meaningful conversations', 'serious matches', 'verified members']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 6053, 558, true, 'silver', true, '2026-06-25T11:49:59+00', '2026-06-25T11:49:59+00', '2026-06-20T07:24:59+00'),
('seed+mistress-006@genuinesugarmummies.com', 'Faith Chebet', '/seed/mistresses/photo_15_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_15_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, emotionally mature, serious about meeting. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, emotionally mature, serious about meeting. Preferred age range: 38-68.', 27, 'Nakuru', 'Kenya', 'Nakuru', '+254750520651', '+254750520651', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'respectful, emotionally mature, serious about meeting, kind', '38-68', ARRAY['weekend drives', 'art galleries', 'beach walks', 'fitness']::TEXT[], ARRAY['verified members', 'lifestyle support', 'premium experiences', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 622, 286, true, 'silver', true, '2026-06-25T11:42:59+00', '2026-06-25T11:42:59+00', '2026-06-19T06:24:59+00'),
('seed+mistress-007@genuinesugarmummies.com', 'Grace Johnson', '/seed/mistresses/photo_16_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_16_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, clean communication, discreet. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, clean communication, discreet. Preferred age range: 38-68.', 28, 'Nakuru', 'Kenya', 'Nakuru', '+254741881177', '+254741881177', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'well groomed, clean communication, discreet, generous', '38-68', ARRAY['wine tasting', 'business events', 'photography', 'fashion']::TEXT[], ARRAY['lifestyle support', 'discreet connection', 'long-term arrangement', 'premium experiences']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4495, 586, true, 'silver', true, '2026-06-25T11:35:59+00', '2026-06-25T11:35:59+00', '2026-06-18T05:24:59+00'),
('seed+mistress-008@genuinesugarmummies.com', 'Halima Taylor', '/seed/mistresses/photo_17_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_17_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, premium experiences. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, well groomed, generous. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, premium experiences. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, well groomed, generous. Preferred age range: 38-68.', 29, 'Entebbe', 'Uganda', 'Entebbe', '+256716214975', '+256716214975', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'honest, well groomed, generous, kind', '38-68', ARRAY['photography', 'business events', 'beach walks', 'cooking']::TEXT[], ARRAY['long-term arrangement', 'premium experiences', 'lifestyle support', 'private dates']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5220, 168, true, 'silver', true, '2026-06-25T11:28:59+00', '2026-06-25T11:28:59+00', '2026-06-17T04:24:59+00'),
('seed+mistress-009@genuinesugarmummies.com', 'Ivy Wanjiku', '/seed/mistresses/photo_18_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_18_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, honest, discreet. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, honest, discreet. Preferred age range: 38-68.', 21, 'Dar es Salaam', 'Tanzania', 'Dar es Salaam', '+255711813328', '+255711813328', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'well groomed, honest, discreet, serious about meeting', '38-68', ARRAY['dancing', 'spa days', 'beach walks', 'business events']::TEXT[], ARRAY['private dates', 'long-term arrangement', 'verified members', 'mentorship']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 1018, 750, true, 'silver', true, '2026-06-25T11:21:59+00', '2026-06-25T11:21:59+00', '2026-06-16T03:24:59+00'),
('seed+mistress-010@genuinesugarmummies.com', 'Joy Achieng', '/seed/mistresses/photo_19_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_19_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, discreet, clean communication. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, discreet, clean communication. Preferred age range: 38-68.', 22, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250723755674', '+250723755674', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'respectful, discreet, clean communication, honest', '38-68', ARRAY['dancing', 'spa days', 'fashion', 'travel']::TEXT[], ARRAY['mentorship', 'long-term arrangement', 'meaningful conversations', 'lifestyle support']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 6974, 317, true, 'silver', true, '2026-06-25T11:14:59+00', '2026-06-25T11:14:59+00', '2026-06-15T02:24:59+00'),
('seed+mistress-011@genuinesugarmummies.com', 'Karen Nabwire', '/seed/mistresses/photo_20_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_20_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, well groomed, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, well groomed, respectful. Preferred age range: 38-68.', 23, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254756972064', '+254756972064', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'consistent, well groomed, respectful, honest', '38-68', ARRAY['business events', 'live music', 'weekend drives', 'fashion']::TEXT[], ARRAY['meaningful conversations', 'verified members', 'respectful companionship', 'mentorship']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2599, 838, true, 'silver', true, '2026-06-25T11:07:59+00', '2026-06-25T11:07:59+00', '2026-06-14T01:24:59+00'),
('seed+mistress-012@genuinesugarmummies.com', 'Linda Mugisha', '/seed/mistresses/photo_21_2026-06-24_14-00-45.jpg', ARRAY['/seed/mistresses/photo_21_2026-06-24_14-00-45.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, clean communication, serious about meeting. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, clean communication, serious about meeting. Preferred age range: 38-68.', 24, 'Nakuru', 'Kenya', 'Nakuru', '+254770676510', '+254770676510', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'honest, clean communication, serious about meeting, consistent', '38-68', ARRAY['fine dining', 'live music', 'business events', 'travel']::TEXT[], ARRAY['private dates', 'discreet connection', 'serious matches', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2251, 181, true, 'silver', true, '2026-06-25T11:00:59+00', '2026-06-25T11:00:59+00', '2026-06-13T00:24:59+00'),
('seed+mistress-013@genuinesugarmummies.com', 'Miriam Hassan', '/seed/mistresses/photo_21_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_21_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, well groomed, honest. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, well groomed, honest. Preferred age range: 38-68.', 25, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254741335612', '+254741335612', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'consistent, well groomed, honest, respectful', '38-68', ARRAY['cooking', 'business events', 'beach walks', 'live music']::TEXT[], ARRAY['verified members', 'lifestyle support', 'mentorship', 'serious matches']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2849, 77, true, 'silver', true, '2026-06-25T10:53:59+00', '2026-06-25T10:53:59+00', '2026-06-11T23:24:59+00'),
('seed+mistress-014@genuinesugarmummies.com', 'Nadia Wafula', '/seed/mistresses/photo_22_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_22_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, emotionally mature, generous. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, emotionally mature, generous. Preferred age range: 38-68.', 26, 'Nairobi', 'Kenya', 'Nairobi', '+254752174299', '+254752174299', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'respectful, emotionally mature, generous, serious about meeting', '38-68', ARRAY['business events', 'coffee dates', 'live music', 'wine tasting']::TEXT[], ARRAY['lifestyle support', 'respectful companionship', 'private dates', 'premium experiences']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2029, 538, true, 'silver', true, '2026-06-25T10:46:59+00', '2026-06-25T10:46:59+00', '2026-06-10T22:24:59+00'),
('seed+mistress-015@genuinesugarmummies.com', 'Olivia Smith', '/seed/mistresses/photo_23_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_23_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, kind, emotionally mature. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, kind, emotionally mature. Preferred age range: 38-68.', 27, 'Eldoret', 'Kenya', 'Eldoret', '+254722790993', '+254722790993', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'well groomed, kind, emotionally mature, respectful', '38-68', ARRAY['spa days', 'art galleries', 'live music', 'coffee dates']::TEXT[], ARRAY['meaningful conversations', 'discreet connection', 'lifestyle support', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2982, 453, true, 'silver', true, '2026-06-25T10:39:59+00', '2026-06-25T10:39:59+00', '2026-06-09T21:24:59+00'),
('seed+mistress-016@genuinesugarmummies.com', 'Patricia Brown', '/seed/mistresses/photo_24_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_24_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, generous, emotionally mature. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, generous, emotionally mature. Preferred age range: 38-68.', 28, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254734662336', '+254734662336', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'consistent, generous, emotionally mature, honest', '38-68', ARRAY['beach walks', 'art galleries', 'photography', 'fine dining']::TEXT[], ARRAY['private dates', 'respectful companionship', 'long-term arrangement', 'premium experiences']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 1228, 471, true, 'silver', true, '2026-06-25T10:32:59+00', '2026-06-25T10:32:59+00', '2026-06-08T20:24:59+00'),
('seed+mistress-017@genuinesugarmummies.com', 'Queen Otieno', '/seed/mistresses/photo_25_2026-06-24_14-00-45.jpg', ARRAY['/seed/mistresses/photo_25_2026-06-24_14-00-45.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, respectful, generous. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, respectful, generous. Preferred age range: 38-68.', 29, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254740274389', '+254740274389', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'honest, respectful, generous, kind', '38-68', ARRAY['weekend drives', 'fitness', 'art galleries', 'live music']::TEXT[], ARRAY['private dates', 'discreet connection', 'serious matches', 'respectful companionship']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4058, 428, true, 'silver', true, '2026-06-25T10:25:59+00', '2026-06-25T10:25:59+00', '2026-06-07T19:24:59+00'),
('seed+mistress-018@genuinesugarmummies.com', 'Ruth Njeri', '/seed/mistresses/photo_25_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_25_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: discreet, well groomed, serious about meeting. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: discreet, well groomed, serious about meeting. Preferred age range: 38-68.', 21, 'Entebbe', 'Uganda', 'Entebbe', '+256799865990', '+256799865990', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'discreet, well groomed, serious about meeting, emotionally mature', '38-68', ARRAY['live music', 'cooking', 'beach walks', 'fine dining']::TEXT[], ARRAY['meaningful conversations', 'long-term arrangement', 'respectful companionship', 'lifestyle support']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4632, 814, true, 'silver', true, '2026-06-25T10:18:59+00', '2026-06-25T10:18:59+00', '2026-06-06T18:24:59+00'),
('seed+mistress-019@genuinesugarmummies.com', 'Stella Mutiso', '/seed/mistresses/photo_26_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_26_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, respectful, consistent. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, respectful, consistent. Preferred age range: 38-68.', 22, 'Mwanza', 'Tanzania', 'Mwanza', '+255716712554', '+255716712554', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'honest, respectful, consistent, serious about meeting', '38-68', ARRAY['photography', 'art galleries', 'weekend drives', 'live music']::TEXT[], ARRAY['mentorship', 'lifestyle support', 'respectful companionship', 'serious matches']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4199, 500, true, 'silver', true, '2026-06-25T10:11:59+00', '2026-06-25T10:11:59+00', '2026-06-05T17:24:59+00'),
('seed+mistress-020@genuinesugarmummies.com', 'Talia Kato', '/seed/mistresses/photo_27_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_27_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, serious matches. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, emotionally mature, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, serious matches. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, emotionally mature, respectful. Preferred age range: 38-68.', 23, 'Kigali', 'Rwanda', 'Kigali', '+250720539589', '+250720539589', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'generous, emotionally mature, respectful, discreet', '38-68', ARRAY['fine dining', 'coffee dates', 'travel', 'weekend drives']::TEXT[], ARRAY['private dates', 'serious matches', 'lifestyle support', 'discreet connection']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4861, 685, true, 'silver', true, '2026-06-25T10:04:59+00', '2026-06-25T10:04:59+00', '2026-06-04T16:24:59+00'),
('seed+mistress-021@genuinesugarmummies.com', 'Uma Mutesi', '/seed/mistresses/photo_28_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_28_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, discreet, well groomed. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, discreet, well groomed. Preferred age range: 38-68.', 24, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254719109767', '+254719109767', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'clean communication, discreet, well groomed, serious about meeting', '38-68', ARRAY['coffee dates', 'fashion', 'fitness', 'live music']::TEXT[], ARRAY['premium experiences', 'lifestyle support', 'mentorship', 'verified members']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5168, 481, true, 'silver', true, '2026-06-25T09:57:59+00', '2026-06-25T09:57:59+00', '2026-06-03T15:24:59+00'),
('seed+mistress-022@genuinesugarmummies.com', 'Vanessa Kimani', '/seed/mistresses/photo_29_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_29_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, mentorship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, emotionally mature, consistent. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, mentorship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, emotionally mature, consistent. Preferred age range: 38-68.', 25, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254730559469', '+254730559469', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'generous, emotionally mature, consistent, clean communication', '38-68', ARRAY['travel', 'wine tasting', 'coffee dates', 'live music']::TEXT[], ARRAY['verified members', 'mentorship', 'meaningful conversations', 'discreet connection']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4530, 865, true, 'silver', true, '2026-06-25T09:50:59+00', '2026-06-25T09:50:59+00', '2026-06-02T14:24:59+00'),
('seed+mistress-023@genuinesugarmummies.com', 'Winnie Maina', '/seed/mistresses/photo_30_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_30_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: respectful companionship, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, clean communication, discreet. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: respectful companionship, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, clean communication, discreet. Preferred age range: 38-68.', 26, 'Eldoret', 'Kenya', 'Eldoret', '+254723878480', '+254723878480', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'generous, clean communication, discreet, respectful', '38-68', ARRAY['business events', 'dancing', 'spa days', 'coffee dates']::TEXT[], ARRAY['respectful companionship', 'verified members', 'mentorship', 'premium experiences']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 1353, 578, true, 'silver', true, '2026-06-25T09:43:59+00', '2026-06-25T09:43:59+00', '2026-06-01T13:24:59+00'),
('seed+mistress-024@genuinesugarmummies.com', 'Yvonne Williams', '/seed/mistresses/photo_36_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_36_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, discreet, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, discreet, respectful. Preferred age range: 38-68.', 27, 'Eldoret', 'Kenya', 'Eldoret', '+254791544151', '+254791544151', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'well groomed, discreet, respectful, serious about meeting', '38-68', ARRAY['fitness', 'business events', 'live music', 'photography']::TEXT[], ARRAY['premium experiences', 'lifestyle support', 'mentorship', 'discreet connection']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2346, 861, true, 'silver', true, '2026-06-25T09:36:59+00', '2026-06-25T09:36:59+00', '2026-06-01T12:24:59+00'),
('seed+mistress-025@genuinesugarmummies.com', 'Zara Mwangi', '/seed/mistresses/photo_37_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_37_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, honest, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, honest, respectful. Preferred age range: 38-68.', 28, 'Nairobi', 'Kenya', 'Nairobi', '+254719824586', '+254719824586', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'kind, honest, respectful, well groomed', '38-68', ARRAY['fine dining', 'fashion', 'dancing', 'weekend drives']::TEXT[], ARRAY['mentorship', 'meaningful conversations', 'discreet connection', 'serious matches']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4549, 164, true, 'silver', true, '2026-06-25T09:29:59+00', '2026-06-25T09:29:59+00', '2026-05-31T11:24:59+00'),
('seed+mistress-026@genuinesugarmummies.com', 'Amara Kamau', '/seed/mistresses/photo_38_2026-06-24_14-00-45.jpg', ARRAY['/seed/mistresses/photo_38_2026-06-24_14-00-45.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: discreet, consistent, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: discreet, consistent, respectful. Preferred age range: 38-68.', 29, 'Nairobi', 'Kenya', 'Nairobi', '+254736815198', '+254736815198', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'discreet, consistent, respectful, clean communication', '38-68', ARRAY['cooking', 'fashion', 'business events', 'coffee dates']::TEXT[], ARRAY['meaningful conversations', 'long-term arrangement', 'serious matches', 'respectful companionship']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5543, 267, true, 'silver', true, '2026-06-25T09:22:59+00', '2026-06-25T09:22:59+00', '2026-05-30T10:24:59+00'),
('seed+mistress-027@genuinesugarmummies.com', 'Bella Kariuki', '/seed/mistresses/photo_39_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_39_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, serious about meeting, kind. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, serious about meeting, kind. Preferred age range: 38-68.', 21, 'Mombasa', 'Kenya', 'Mombasa', '+254732872343', '+254732872343', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'clean communication, serious about meeting, kind, respectful', '38-68', ARRAY['fashion', 'dancing', 'coffee dates', 'beach walks']::TEXT[], ARRAY['serious matches', 'meaningful conversations', 'lifestyle support', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 6489, 352, true, 'silver', true, '2026-06-25T09:15:59+00', '2026-06-25T09:15:59+00', '2026-05-29T09:24:59+00'),
('seed+mistress-028@genuinesugarmummies.com', 'Chloe Nambooze', '/seed/mistresses/photo_3_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_3_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, well groomed, emotionally mature. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, well groomed, emotionally mature. Preferred age range: 38-68.', 22, 'Entebbe', 'Uganda', 'Entebbe', '+256768466643', '+256768466643', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'respectful, well groomed, emotionally mature, generous', '38-68', ARRAY['dancing', 'spa days', 'photography', 'live music']::TEXT[], ARRAY['mentorship', 'meaningful conversations', 'private dates', 'lifestyle support']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 6801, 324, true, 'silver', true, '2026-06-25T09:08:59+00', '2026-06-25T09:08:59+00', '2026-05-28T08:24:59+00'),
('seed+mistress-029@genuinesugarmummies.com', 'Deborah Nkurunziza', '/seed/mistresses/photo_40_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_40_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, premium experiences. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, discreet, consistent. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, premium experiences. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: generous, discreet, consistent. Preferred age range: 38-68.', 23, 'Dar es Salaam', 'Tanzania', 'Dar es Salaam', '+255775519093', '+255775519093', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'generous, discreet, consistent, well groomed', '38-68', ARRAY['live music', 'fine dining', 'spa days', 'wine tasting']::TEXT[], ARRAY['long-term arrangement', 'premium experiences', 'mentorship', 'serious matches']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 6991, 707, true, 'silver', true, '2026-06-25T09:01:59+00', '2026-06-25T09:01:59+00', '2026-05-27T07:24:59+00'),
('seed+mistress-030@genuinesugarmummies.com', 'Esther Okello', '/seed/mistresses/photo_45_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_45_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, mentorship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: serious about meeting, kind, consistent. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, mentorship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: serious about meeting, kind, consistent. Preferred age range: 38-68.', 24, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250750557592', '+250750557592', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'serious about meeting, kind, consistent, well groomed', '38-68', ARRAY['fine dining', 'travel', 'fitness', 'weekend drives']::TEXT[], ARRAY['serious matches', 'mentorship', 'respectful companionship', 'discreet connection']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4269, 632, true, 'silver', true, '2026-06-25T08:54:59+00', '2026-06-25T08:54:59+00', '2026-05-26T06:24:59+00'),
('seed+mistress-031@genuinesugarmummies.com', 'Fiona Chebet', '/seed/mistresses/photo_4_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_4_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: respectful companionship, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, emotionally mature, consistent. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: respectful companionship, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, emotionally mature, consistent. Preferred age range: 38-68.', 25, 'Mombasa', 'Kenya', 'Mombasa', '+254718796503', '+254718796503', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'honest, emotionally mature, consistent, serious about meeting', '38-68', ARRAY['beach walks', 'business events', 'live music', 'fitness']::TEXT[], ARRAY['respectful companionship', 'long-term arrangement', 'serious matches', 'mentorship']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5184, 350, true, 'silver', true, '2026-06-25T08:47:59+00', '2026-06-25T08:47:59+00', '2026-05-25T05:24:59+00'),
('seed+mistress-032@genuinesugarmummies.com', 'Gloria Johnson', '/seed/mistresses/photo_50_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_50_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, consistent, serious about meeting. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, consistent, serious about meeting. Preferred age range: 38-68.', 26, 'Thika', 'Kenya', 'Thika', '+254747681343', '+254747681343', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'kind, consistent, serious about meeting, honest', '38-68', ARRAY['spa days', 'cooking', 'travel', 'photography']::TEXT[], ARRAY['mentorship', 'verified members', 'serious matches', 'premium experiences']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 1651, 142, true, 'silver', true, '2026-06-25T08:40:59+00', '2026-06-25T08:40:59+00', '2026-05-24T04:24:59+00'),
('seed+mistress-033@genuinesugarmummies.com', 'Hilda Taylor', '/seed/mistresses/photo_5_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_5_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, mentorship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, discreet, honest. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, mentorship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, discreet, honest. Preferred age range: 38-68.', 27, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254765923927', '+254765923927', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'respectful, discreet, honest, generous', '38-68', ARRAY['spa days', 'beach walks', 'wine tasting', 'photography']::TEXT[], ARRAY['meaningful conversations', 'mentorship', 'long-term arrangement', 'verified members']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5049, 605, true, 'silver', true, '2026-06-25T08:33:59+00', '2026-06-25T08:33:59+00', '2026-05-23T03:24:59+00'),
('seed+mistress-034@genuinesugarmummies.com', 'Irene Wanjiku', '/seed/mistresses/photo_60_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_60_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, generous, discreet. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, generous, discreet. Preferred age range: 38-68.', 28, 'Thika', 'Kenya', 'Thika', '+254794763686', '+254794763686', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'clean communication, generous, discreet, well groomed', '38-68', ARRAY['art galleries', 'wine tasting', 'cooking', 'spa days']::TEXT[], ARRAY['lifestyle support', 'verified members', 'discreet connection', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2825, 646, true, 'silver', true, '2026-06-25T08:26:59+00', '2026-06-25T08:26:59+00', '2026-05-22T02:24:59+00'),
('seed+mistress-035@genuinesugarmummies.com', 'Jackie Achieng', '/seed/mistresses/photo_61_2026-06-24_14-00-45.jpg', ARRAY['/seed/mistresses/photo_61_2026-06-24_14-00-45.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, serious about meeting, emotionally mature. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: mentorship, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: respectful, serious about meeting, emotionally mature. Preferred age range: 38-68.', 29, 'Mombasa', 'Kenya', 'Mombasa', '+254788991014', '+254788991014', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'respectful, serious about meeting, emotionally mature, well groomed', '38-68', ARRAY['cooking', 'dancing', 'live music', 'spa days']::TEXT[], ARRAY['mentorship', 'lifestyle support', 'verified members', 'private dates']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 676, 798, true, 'silver', true, '2026-06-25T08:19:59+00', '2026-06-25T08:19:59+00', '2026-05-21T01:24:59+00'),
('seed+mistress-036@genuinesugarmummies.com', 'Kendra Nabwire', '/seed/mistresses/photo_62_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_62_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, respectful, generous. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, respectful, generous. Preferred age range: 38-68.', 21, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254764329471', '+254764329471', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'clean communication, respectful, generous, kind', '38-68', ARRAY['beach walks', 'spa days', 'business events', 'live music']::TEXT[], ARRAY['long-term arrangement', 'discreet connection', 'serious matches', 'private dates']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 6667, 192, true, 'silver', true, '2026-06-25T08:12:59+00', '2026-06-25T08:12:59+00', '2026-05-20T00:24:59+00'),
('seed+mistress-037@genuinesugarmummies.com', 'Lilian Mugisha', '/seed/mistresses/photo_65_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_65_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, honest, consistent. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: well groomed, honest, consistent. Preferred age range: 38-68.', 22, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254766742412', '+254766742412', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'well groomed, honest, consistent, kind', '38-68', ARRAY['art galleries', 'fine dining', 'coffee dates', 'live music']::TEXT[], ARRAY['private dates', 'discreet connection', 'meaningful conversations', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5972, 846, true, 'silver', true, '2026-06-25T08:05:59+00', '2026-06-25T08:05:59+00', '2026-05-18T23:24:59+00'),
('seed+mistress-038@genuinesugarmummies.com', 'Mercy Hassan', '/seed/mistresses/photo_6_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_6_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, discreet, well groomed. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: meaningful conversations, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, discreet, well groomed. Preferred age range: 38-68.', 23, 'Jinja', 'Uganda', 'Jinja', '+256740387936', '+256740387936', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'emotionally mature, discreet, well groomed, consistent', '38-68', ARRAY['beach walks', 'cooking', 'coffee dates', 'art galleries']::TEXT[], ARRAY['meaningful conversations', 'discreet connection', 'verified members', 'serious matches']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 714, 462, true, 'silver', true, '2026-06-25T07:58:59+00', '2026-06-25T07:58:59+00', '2026-05-17T22:24:59+00'),
('seed+mistress-039@genuinesugarmummies.com', 'Nelly Wafula', '/seed/mistresses/photo_75_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_75_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, emotionally mature, kind. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, emotionally mature, kind. Preferred age range: 38-68.', 24, 'Mwanza', 'Tanzania', 'Mwanza', '+255729840734', '+255729840734', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'clean communication, emotionally mature, kind, consistent', '38-68', ARRAY['fitness', 'live music', 'wine tasting', 'fashion']::TEXT[], ARRAY['premium experiences', 'verified members', 'private dates', 'discreet connection']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 606, 231, true, 'silver', true, '2026-06-25T07:51:59+00', '2026-06-25T07:51:59+00', '2026-05-16T21:24:59+00'),
('seed+mistress-040@genuinesugarmummies.com', 'Opal Smith', '/seed/mistresses/photo_7_2026-06-24_14-00-45.jpg', ARRAY['/seed/mistresses/photo_7_2026-06-24_14-00-45.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, serious about meeting, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, serious about meeting, respectful. Preferred age range: 38-68.', 25, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250783498858', '+250783498858', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'kind, serious about meeting, respectful, honest', '38-68', ARRAY['beach walks', 'fashion', 'coffee dates', 'art galleries']::TEXT[], ARRAY['long-term arrangement', 'respectful companionship', 'lifestyle support', 'serious matches']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 128, 500, true, 'silver', true, '2026-06-25T07:44:59+00', '2026-06-25T07:44:59+00', '2026-05-15T20:24:59+00'),
('seed+mistress-041@genuinesugarmummies.com', 'Pearl Brown', '/seed/mistresses/photo_7_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_7_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, serious matches. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, discreet, kind. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: verified members, serious matches. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, discreet, kind. Preferred age range: 38-68.', 26, 'Thika', 'Kenya', 'Thika', '+254713507746', '+254713507746', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'emotionally mature, discreet, kind, serious about meeting', '38-68', ARRAY['fitness', 'dancing', 'beach walks', 'cooking']::TEXT[], ARRAY['verified members', 'serious matches', 'lifestyle support', 'discreet connection']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5559, 356, true, 'silver', true, '2026-06-25T07:37:59+00', '2026-06-25T07:37:59+00', '2026-05-14T19:24:59+00'),
('seed+mistress-042@genuinesugarmummies.com', 'Rachel Otieno', '/seed/mistresses/photo_81_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_81_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: serious about meeting, respectful, generous. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, verified members. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: serious about meeting, respectful, generous. Preferred age range: 38-68.', 27, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254764242291', '+254764242291', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'serious about meeting, respectful, generous, consistent', '38-68', ARRAY['photography', 'weekend drives', 'art galleries', 'cooking']::TEXT[], ARRAY['serious matches', 'verified members', 'respectful companionship', 'lifestyle support']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 3862, 899, true, 'silver', true, '2026-06-25T07:30:59+00', '2026-06-25T07:30:59+00', '2026-05-13T18:24:59+00'),
('seed+mistress-043@genuinesugarmummies.com', 'Sandra Njeri', '/seed/mistresses/photo_84_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_84_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, discreet, serious about meeting. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: lifestyle support, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: kind, discreet, serious about meeting. Preferred age range: 38-68.', 28, 'Kisumu', 'Kenya', 'Kisumu', '+254720593152', '+254720593152', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'kind, discreet, serious about meeting, clean communication', '38-68', ARRAY['fine dining', 'fitness', 'beach walks', 'fashion']::TEXT[], ARRAY['lifestyle support', 'discreet connection', 'premium experiences', 'meaningful conversations']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 6216, 31, true, 'silver', true, '2026-06-25T07:23:59+00', '2026-06-25T07:23:59+00', '2026-05-12T17:24:59+00'),
('seed+mistress-044@genuinesugarmummies.com', 'Tracy Mutiso', '/seed/mistresses/photo_8_2026-06-24_14-00-45.jpg', ARRAY['/seed/mistresses/photo_8_2026-06-24_14-00-45.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, respectful, clean communication. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, respectful companionship. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, respectful, clean communication. Preferred age range: 38-68.', 29, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254726596564', '+254726596564', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'emotionally mature, respectful, clean communication, generous', '38-68', ARRAY['fine dining', 'fashion', 'live music', 'spa days']::TEXT[], ARRAY['private dates', 'respectful companionship', 'verified members', 'serious matches']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 1017, 697, true, 'silver', true, '2026-06-25T07:16:59+00', '2026-06-25T07:16:59+00', '2026-05-11T16:24:59+00'),
('seed+mistress-045@genuinesugarmummies.com', 'Vera Kato', '/seed/mistresses/photo_8_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_8_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, discreet, generous. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: premium experiences, meaningful conversations. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: clean communication, discreet, generous. Preferred age range: 38-68.', 21, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254713427110', '+254713427110', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'clean communication, discreet, generous, honest', '38-68', ARRAY['live music', 'art galleries', 'photography', 'fitness']::TEXT[], ARRAY['premium experiences', 'meaningful conversations', 'private dates', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5628, 601, true, 'silver', true, '2026-06-25T07:09:59+00', '2026-06-25T07:09:59+00', '2026-05-10T15:24:59+00'),
('seed+mistress-046@genuinesugarmummies.com', 'Wanja Mutesi', '/seed/mistresses/photo_92_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_92_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: discreet, generous, respectful. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: serious matches, lifestyle support. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: discreet, generous, respectful. Preferred age range: 38-68.', 22, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254778549186', '+254778549186', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'discreet, generous, respectful, clean communication', '38-68', ARRAY['beach walks', 'photography', 'live music', 'travel']::TEXT[], ARRAY['serious matches', 'lifestyle support', 'private dates', 'premium experiences']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 3115, 689, true, 'silver', true, '2026-06-25T07:02:59+00', '2026-06-25T07:02:59+00', '2026-05-09T14:24:59+00'),
('seed+mistress-047@genuinesugarmummies.com', 'Yasmin Kimani', '/seed/mistresses/photo_99_2026-06-25_14-21-42.jpg', ARRAY['/seed/mistresses/photo_99_2026-06-25_14-21-42.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, well groomed, clean communication. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: long-term arrangement, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: consistent, well groomed, clean communication. Preferred age range: 38-68.', 23, 'Mombasa', 'Kenya', 'Mombasa', '+254732869440', '+254732869440', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'consistent, well groomed, clean communication, emotionally mature', '38-68', ARRAY['coffee dates', 'spa days', 'fashion', 'fine dining']::TEXT[], ARRAY['long-term arrangement', 'discreet connection', 'private dates', 'lifestyle support']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 5408, 546, true, 'silver', true, '2026-06-25T06:55:59+00', '2026-06-25T06:55:59+00', '2026-05-08T13:24:59+00'),
('seed+mistress-048@genuinesugarmummies.com', 'Zuri Maina', '/seed/mistresses/photo_9_2026-06-25_14-21-41.jpg', ARRAY['/seed/mistresses/photo_9_2026-06-25_14-21-41.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: discreet connection, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, generous, discreet. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: discreet connection, long-term arrangement. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: emotionally mature, generous, discreet. Preferred age range: 38-68.', 24, 'Entebbe', 'Uganda', 'Entebbe', '+256741886931', '+256741886931', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'emotionally mature, generous, discreet, serious about meeting', '38-68', ARRAY['business events', 'dancing', 'coffee dates', 'art galleries']::TEXT[], ARRAY['discreet connection', 'long-term arrangement', 'mentorship', 'meaningful conversations']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 4748, 487, true, 'silver', true, '2026-06-25T06:48:59+00', '2026-06-25T06:48:59+00', '2026-05-08T12:24:59+00'),
('seed+sugar_daddy-001@genuinesugarmummies.com', 'James Kamau', '/seed/sugar-dads/photo_10_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_10_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: meaningful conversations, discreet connection. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, consistent, serious about meeting. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: meaningful conversations, discreet connection. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, consistent, serious about meeting. Preferred age range: 21-35.', 43, 'Manchester', 'United Kingdom', 'Manchester', '+447818389688', '+447818389688', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'discreet, consistent, serious about meeting, well groomed', '21-35', ARRAY['fashion', 'fine dining', 'art galleries', 'wine tasting']::TEXT[], ARRAY['meaningful conversations', 'discreet connection', 'lifestyle support', 'serious matches']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 163, 581, true, 'silver', true, '2026-06-25T12:17:59+00', '2026-06-25T12:17:59+00', '2026-06-24T11:24:59+00'),
('seed+sugar_daddy-002@genuinesugarmummies.com', 'Robert Kariuki', '/seed/sugar-dads/photo_11_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_11_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: discreet connection, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, serious about meeting, honest. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: discreet connection, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, serious about meeting, honest. Preferred age range: 21-35.', 44, 'New York', 'United States', 'New York', '+12022144646', '+12022144646', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, serious about meeting, honest, kind', '21-35', ARRAY['travel', 'live music', 'photography', 'beach walks']::TEXT[], ARRAY['discreet connection', 'verified members', 'lifestyle support', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 2490, 107, true, 'silver', true, '2026-06-25T12:10:59+00', '2026-06-25T12:10:59+00', '2026-06-23T10:24:59+00'),
('seed+sugar_daddy-003@genuinesugarmummies.com', 'William Nambooze', '/seed/sugar-dads/photo_13_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_13_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: serious matches, premium experiences. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, consistent, kind. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: serious matches, premium experiences. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, consistent, kind. Preferred age range: 21-35.', 45, 'London', 'United Kingdom', 'London', '+447663446859', '+447663446859', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'honest, consistent, kind, serious about meeting', '21-35', ARRAY['beach walks', 'photography', 'live music', 'fitness']::TEXT[], ARRAY['serious matches', 'premium experiences', 'discreet connection', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5837, 372, true, 'silver', true, '2026-06-25T12:03:59+00', '2026-06-25T12:03:59+00', '2026-06-22T09:24:59+00'),
('seed+sugar_daddy-004@genuinesugarmummies.com', 'Charles Nkurunziza', '/seed/sugar-dads/photo_14_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_14_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, lifestyle support. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, clean communication, emotionally mature. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, lifestyle support. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, clean communication, emotionally mature. Preferred age range: 21-35.', 46, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254771389930', '+254771389930', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'honest, clean communication, emotionally mature, generous', '21-35', ARRAY['fitness', 'wine tasting', 'cooking', 'live music']::TEXT[], ARRAY['private dates', 'lifestyle support', 'premium experiences', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4909, 753, true, 'silver', true, '2026-06-25T11:56:59+00', '2026-06-25T11:56:59+00', '2026-06-21T08:24:59+00'),
('seed+sugar_daddy-005@genuinesugarmummies.com', 'George Okello', '/seed/sugar-dads/photo_15_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_15_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, lifestyle support. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, respectful, clean communication. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, lifestyle support. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, respectful, clean communication. Preferred age range: 21-35.', 47, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254715157174', '+254715157174', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'discreet, respectful, clean communication, well groomed', '21-35', ARRAY['business events', 'fitness', 'travel', 'live music']::TEXT[], ARRAY['mentorship', 'lifestyle support', 'premium experiences', 'private dates']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 2473, 578, true, 'silver', true, '2026-06-25T11:49:59+00', '2026-06-25T11:49:59+00', '2026-06-20T07:24:59+00'),
('seed+sugar_daddy-006@genuinesugarmummies.com', 'Henry Chebet', '/seed/sugar-dads/photo_16_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_16_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, respectful companionship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, serious about meeting, consistent. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, respectful companionship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, serious about meeting, consistent. Preferred age range: 21-35.', 48, 'Kisumu', 'Kenya', 'Kisumu', '+254716364742', '+254716364742', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, serious about meeting, consistent, generous', '21-35', ARRAY['spa days', 'cooking', 'dancing', 'art galleries']::TEXT[], ARRAY['private dates', 'respectful companionship', 'mentorship', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3993, 894, true, 'silver', true, '2026-06-25T11:42:59+00', '2026-06-25T11:42:59+00', '2026-06-19T06:24:59+00'),
('seed+sugar_daddy-007@genuinesugarmummies.com', 'Edward Johnson', '/seed/sugar-dads/photo_17_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_17_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, respectful companionship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: serious about meeting, discreet, generous. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, respectful companionship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: serious about meeting, discreet, generous. Preferred age range: 21-35.', 49, 'Mombasa', 'Kenya', 'Mombasa', '+254725685181', '+254725685181', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'serious about meeting, discreet, generous, well groomed', '21-35', ARRAY['cooking', 'travel', 'beach walks', 'art galleries']::TEXT[], ARRAY['private dates', 'respectful companionship', 'meaningful conversations', 'serious matches']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3489, 794, true, 'silver', true, '2026-06-25T11:35:59+00', '2026-06-25T11:35:59+00', '2026-06-18T05:24:59+00'),
('seed+sugar_daddy-008@genuinesugarmummies.com', 'Michael Taylor', '/seed/sugar-dads/photo_18_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_18_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, kind, serious about meeting. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, kind, serious about meeting. Preferred age range: 21-35.', 50, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254789163156', '+254789163156', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'discreet, kind, serious about meeting, well groomed', '21-35', ARRAY['business events', 'dancing', 'wine tasting', 'live music']::TEXT[], ARRAY['verified members', 'long-term arrangement', 'discreet connection', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6142, 636, true, 'silver', true, '2026-06-25T11:28:59+00', '2026-06-25T11:28:59+00', '2026-06-17T04:24:59+00'),
('seed+sugar_daddy-009@genuinesugarmummies.com', 'Daniel Wanjiku', '/seed/sugar-dads/photo_19_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_19_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: clean communication, honest, generous. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: clean communication, honest, generous. Preferred age range: 21-35.', 51, 'Mombasa', 'Kenya', 'Mombasa', '+254710528361', '+254710528361', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'clean communication, honest, generous, well groomed', '21-35', ARRAY['dancing', 'live music', 'spa days', 'cooking']::TEXT[], ARRAY['mentorship', 'private dates', 'meaningful conversations', 'verified members']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5727, 473, true, 'silver', true, '2026-06-25T11:21:59+00', '2026-06-25T11:21:59+00', '2026-06-16T03:24:59+00'),
('seed+sugar_daddy-010@genuinesugarmummies.com', 'Richard Achieng', '/seed/sugar-dads/photo_20_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_20_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: emotionally mature, discreet, serious about meeting. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: emotionally mature, discreet, serious about meeting. Preferred age range: 21-35.', 52, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254724671015', '+254724671015', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'emotionally mature, discreet, serious about meeting, well groomed', '21-35', ARRAY['art galleries', 'fitness', 'fine dining', 'live music']::TEXT[], ARRAY['mentorship', 'serious matches', 'discreet connection', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5385, 242, true, 'silver', true, '2026-06-25T11:14:59+00', '2026-06-25T11:14:59+00', '2026-06-15T02:24:59+00'),
('seed+sugar_daddy-011@genuinesugarmummies.com', 'David Nabwire', '/seed/sugar-dads/photo_21_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_21_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: serious about meeting, discreet, well groomed. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: serious about meeting, discreet, well groomed. Preferred age range: 21-35.', 53, 'Kampala', 'Uganda', 'Kampala', '+256769822131', '+256769822131', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'serious about meeting, discreet, well groomed, respectful', '21-35', ARRAY['wine tasting', 'fitness', 'weekend drives', 'travel']::TEXT[], ARRAY['respectful companionship', 'meaningful conversations', 'mentorship', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5812, 323, true, 'silver', true, '2026-06-25T11:07:59+00', '2026-06-25T11:07:59+00', '2026-06-14T01:24:59+00'),
('seed+sugar_daddy-012@genuinesugarmummies.com', 'Anthony Mugisha', '/seed/sugar-dads/photo_22_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_22_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: discreet connection, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: consistent, discreet, respectful. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: discreet connection, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: consistent, discreet, respectful. Preferred age range: 21-35.', 54, 'Arusha', 'Tanzania', 'Arusha', '+255739807053', '+255739807053', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'consistent, discreet, respectful, well groomed', '21-35', ARRAY['fitness', 'coffee dates', 'cooking', 'art galleries']::TEXT[], ARRAY['discreet connection', 'private dates', 'respectful companionship', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 7129, 868, true, 'silver', true, '2026-06-25T11:00:59+00', '2026-06-25T11:00:59+00', '2026-06-13T00:24:59+00'),
('seed+sugar_daddy-013@genuinesugarmummies.com', 'Victor Hassan', '/seed/sugar-dads/photo_23_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_23_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, discreet, clean communication. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, discreet, clean communication. Preferred age range: 21-35.', 55, 'Kigali', 'Rwanda', 'Kigali', '+250765765620', '+250765765620', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, discreet, clean communication, honest', '21-35', ARRAY['dancing', 'spa days', 'fitness', 'business events']::TEXT[], ARRAY['respectful companionship', 'meaningful conversations', 'discreet connection', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4108, 845, true, 'silver', true, '2026-06-25T10:53:59+00', '2026-06-25T10:53:59+00', '2026-06-11T23:24:59+00'),
('seed+sugar_daddy-014@genuinesugarmummies.com', 'Samuel Wafula', '/seed/sugar-dads/photo_24_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_24_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, well groomed, discreet. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, well groomed, discreet. Preferred age range: 21-35.', 56, 'Mombasa', 'Kenya', 'Mombasa', '+254761953085', '+254761953085', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'kind, well groomed, discreet, consistent', '21-35', ARRAY['art galleries', 'fashion', 'beach walks', 'cooking']::TEXT[], ARRAY['premium experiences', 'private dates', 'meaningful conversations', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4586, 790, true, 'silver', true, '2026-06-25T10:46:59+00', '2026-06-25T10:46:59+00', '2026-06-10T22:24:59+00'),
('seed+sugar_daddy-015@genuinesugarmummies.com', 'Patrick Smith', '/seed/sugar-dads/photo_25_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_25_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, respectful, well groomed. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, respectful, well groomed. Preferred age range: 21-35.', 57, 'Nairobi', 'Kenya', 'Nairobi', '+254716296694', '+254716296694', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'honest, respectful, well groomed, emotionally mature', '21-35', ARRAY['art galleries', 'travel', 'fashion', 'fitness']::TEXT[], ARRAY['premium experiences', 'private dates', 'long-term arrangement', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3043, 542, true, 'silver', true, '2026-06-25T10:39:59+00', '2026-06-25T10:39:59+00', '2026-06-09T21:24:59+00'),
('seed+sugar_daddy-016@genuinesugarmummies.com', 'Joseph Brown', '/seed/sugar-dads/photo_26_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_26_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, lifestyle support. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: clean communication, discreet, well groomed. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, lifestyle support. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: clean communication, discreet, well groomed. Preferred age range: 21-35.', 58, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254772227324', '+254772227324', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'clean communication, discreet, well groomed, consistent', '21-35', ARRAY['dancing', 'art galleries', 'spa days', 'cooking']::TEXT[], ARRAY['respectful companionship', 'lifestyle support', 'mentorship', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5241, 41, true, 'silver', true, '2026-06-25T10:32:59+00', '2026-06-25T10:32:59+00', '2026-06-08T20:24:59+00'),
('seed+sugar_daddy-017@genuinesugarmummies.com', 'Brian Otieno', '/seed/sugar-dads/photo_27_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_27_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, generous, emotionally mature. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, generous, emotionally mature. Preferred age range: 21-35.', 59, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254724583863', '+254724583863', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'kind, generous, emotionally mature, serious about meeting', '21-35', ARRAY['dancing', 'live music', 'photography', 'weekend drives']::TEXT[], ARRAY['mentorship', 'verified members', 'respectful companionship', 'serious matches']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5386, 132, true, 'silver', true, '2026-06-25T10:25:59+00', '2026-06-25T10:25:59+00', '2026-06-07T19:24:59+00'),
('seed+sugar_daddy-018@genuinesugarmummies.com', 'Martin Njeri', '/seed/sugar-dads/photo_28_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_28_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: emotionally mature, well groomed, clean communication. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: emotionally mature, well groomed, clean communication. Preferred age range: 21-35.', 60, 'Kisumu', 'Kenya', 'Kisumu', '+254734728492', '+254734728492', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'emotionally mature, well groomed, clean communication, serious about meeting', '21-35', ARRAY['art galleries', 'photography', 'fitness', 'coffee dates']::TEXT[], ARRAY['mentorship', 'long-term arrangement', 'discreet connection', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6193, 532, true, 'silver', true, '2026-06-25T10:18:59+00', '2026-06-25T10:18:59+00', '2026-06-06T18:24:59+00'),
('seed+sugar_daddy-019@genuinesugarmummies.com', 'Stephen Mutiso', '/seed/sugar-dads/photo_39_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_39_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, discreet, honest. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, discreet, honest. Preferred age range: 21-35.', 61, 'Kisumu', 'Kenya', 'Kisumu', '+254785708093', '+254785708093', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'respectful, discreet, honest, kind', '21-35', ARRAY['cooking', 'travel', 'fitness', 'beach walks']::TEXT[], ARRAY['premium experiences', 'verified members', 'mentorship', 'long-term arrangement']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4091, 687, true, 'silver', true, '2026-06-25T10:11:59+00', '2026-06-25T10:11:59+00', '2026-06-05T17:24:59+00'),
('seed+sugar_daddy-020@genuinesugarmummies.com', 'Peter Kato', '/seed/sugar-dads/photo_40_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_40_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: consistent, emotionally mature, honest. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: consistent, emotionally mature, honest. Preferred age range: 21-35.', 62, 'Kisumu', 'Kenya', 'Kisumu', '+254759344907', '+254759344907', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'consistent, emotionally mature, honest, discreet', '21-35', ARRAY['art galleries', 'coffee dates', 'wine tasting', 'fashion']::TEXT[], ARRAY['premium experiences', 'verified members', 'long-term arrangement', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6433, 888, true, 'silver', true, '2026-06-25T10:04:59+00', '2026-06-25T10:04:59+00', '2026-06-04T16:24:59+00'),
('seed+sugar_daddy-021@genuinesugarmummies.com', 'Andrew Mutesi', '/seed/sugar-dads/photo_41_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_41_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, clean communication, consistent. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, clean communication, consistent. Preferred age range: 21-35.', 63, 'Entebbe', 'Uganda', 'Entebbe', '+256722986088', '+256722986088', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'respectful, clean communication, consistent, kind', '21-35', ARRAY['fine dining', 'fashion', 'photography', 'art galleries']::TEXT[], ARRAY['long-term arrangement', 'serious matches', 'meaningful conversations', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 896, 462, true, 'silver', true, '2026-06-25T09:57:59+00', '2026-06-25T09:57:59+00', '2026-06-03T15:24:59+00'),
('seed+sugar_daddy-022@genuinesugarmummies.com', 'Nicholas Kimani', '/seed/sugar-dads/photo_42_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_42_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: meaningful conversations, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, discreet, consistent. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: meaningful conversations, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, discreet, consistent. Preferred age range: 21-35.', 64, 'Mwanza', 'Tanzania', 'Mwanza', '+255798516791', '+255798516791', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, discreet, consistent, honest', '21-35', ARRAY['wine tasting', 'art galleries', 'fine dining', 'photography']::TEXT[], ARRAY['meaningful conversations', 'long-term arrangement', 'serious matches', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 737, 677, true, 'silver', true, '2026-06-25T09:50:59+00', '2026-06-25T09:50:59+00', '2026-06-02T14:24:59+00'),
('seed+sugar_daddy-023@genuinesugarmummies.com', 'Thomas Maina', '/seed/sugar-dads/photo_43_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_43_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, discreet connection. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, emotionally mature, discreet. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, discreet connection. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, emotionally mature, discreet. Preferred age range: 21-35.', 65, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250721555052', '+250721555052', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'generous, emotionally mature, discreet, serious about meeting', '21-35', ARRAY['cooking', 'spa days', 'coffee dates', 'beach walks']::TEXT[], ARRAY['premium experiences', 'discreet connection', 'respectful companionship', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6308, 112, true, 'silver', true, '2026-06-25T09:43:59+00', '2026-06-25T09:43:59+00', '2026-06-01T13:24:59+00'),
('seed+sugar_daddy-024@genuinesugarmummies.com', 'Simon Williams', '/seed/sugar-dads/photo_44_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_44_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, discreet, consistent. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, discreet, consistent. Preferred age range: 21-35.', 42, 'Mombasa', 'Kenya', 'Mombasa', '+254765252640', '+254765252640', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'respectful, discreet, consistent, clean communication', '21-35', ARRAY['art galleries', 'weekend drives', 'photography', 'fitness']::TEXT[], ARRAY['respectful companionship', 'serious matches', 'premium experiences', 'long-term arrangement']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4431, 262, true, 'silver', true, '2026-06-25T09:36:59+00', '2026-06-25T09:36:59+00', '2026-06-01T12:24:59+00'),
('seed+sugar_daddy-025@genuinesugarmummies.com', 'Kevin Mwangi', '/seed/sugar-dads/photo_45_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_45_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: meaningful conversations, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, emotionally mature, well groomed. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: meaningful conversations, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, emotionally mature, well groomed. Preferred age range: 21-35.', 43, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254728343467', '+254728343467', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'kind, emotionally mature, well groomed, discreet', '21-35', ARRAY['business events', 'spa days', 'dancing', 'weekend drives']::TEXT[], ARRAY['meaningful conversations', 'serious matches', 'private dates', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5305, 484, true, 'silver', true, '2026-06-25T09:29:59+00', '2026-06-25T09:29:59+00', '2026-05-31T11:24:59+00'),
('seed+sugar_daddy-026@genuinesugarmummies.com', 'Francis Kamau', '/seed/sugar-dads/photo_46_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_46_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: discreet connection, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, consistent, discreet. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: discreet connection, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, consistent, discreet. Preferred age range: 21-35.', 44, 'Eldoret', 'Kenya', 'Eldoret', '+254764823846', '+254764823846', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, consistent, discreet, honest', '21-35', ARRAY['art galleries', 'fitness', 'spa days', 'fine dining']::TEXT[], ARRAY['discreet connection', 'mentorship', 'meaningful conversations', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3822, 268, true, 'silver', true, '2026-06-25T09:22:59+00', '2026-06-25T09:22:59+00', '2026-05-30T10:24:59+00'),
('seed+sugar_daddy-027@genuinesugarmummies.com', 'Kenneth Kariuki', '/seed/sugar-dads/photo_47_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_47_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: lifestyle support, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, serious about meeting, respectful. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: lifestyle support, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, serious about meeting, respectful. Preferred age range: 21-35.', 45, 'Eldoret', 'Kenya', 'Eldoret', '+254794515032', '+254794515032', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'discreet, serious about meeting, respectful, kind', '21-35', ARRAY['live music', 'beach walks', 'art galleries', 'travel']::TEXT[], ARRAY['lifestyle support', 'long-term arrangement', 'premium experiences', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 146, 293, true, 'silver', true, '2026-06-25T09:15:59+00', '2026-06-25T09:15:59+00', '2026-05-29T09:24:59+00'),
('seed+sugar_daddy-028@genuinesugarmummies.com', 'Collins Nambooze', '/seed/sugar-dads/photo_48_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_48_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, discreet connection. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: emotionally mature, consistent, serious about meeting. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, discreet connection. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: emotionally mature, consistent, serious about meeting. Preferred age range: 21-35.', 46, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254734751051', '+254734751051', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'emotionally mature, consistent, serious about meeting, honest', '21-35', ARRAY['cooking', 'spa days', 'dancing', 'photography']::TEXT[], ARRAY['respectful companionship', 'discreet connection', 'mentorship', 'long-term arrangement']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5632, 268, true, 'silver', true, '2026-06-25T09:08:59+00', '2026-06-25T09:08:59+00', '2026-05-28T08:24:59+00'),
('seed+sugar_daddy-029@genuinesugarmummies.com', 'Allan Nkurunziza', '/seed/sugar-dads/photo_49_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_49_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: serious about meeting, consistent, clean communication. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: respectful companionship, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: serious about meeting, consistent, clean communication. Preferred age range: 21-35.', 47, 'Kisumu', 'Kenya', 'Kisumu', '+254747442589', '+254747442589', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'serious about meeting, consistent, clean communication, respectful', '21-35', ARRAY['spa days', 'travel', 'wine tasting', 'dancing']::TEXT[], ARRAY['respectful companionship', 'mentorship', 'discreet connection', 'serious matches']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3483, 777, true, 'silver', true, '2026-06-25T09:01:59+00', '2026-06-25T09:01:59+00', '2026-05-27T07:24:59+00'),
('seed+sugar_daddy-030@genuinesugarmummies.com', 'Eric Okello', '/seed/sugar-dads/photo_50_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_50_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: clean communication, discreet, well groomed. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: clean communication, discreet, well groomed. Preferred age range: 21-35.', 48, 'Kisumu', 'Kenya', 'Kisumu', '+254747882824', '+254747882824', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'clean communication, discreet, well groomed, kind', '21-35', ARRAY['live music', 'weekend drives', 'dancing', 'coffee dates']::TEXT[], ARRAY['premium experiences', 'verified members', 'mentorship', 'long-term arrangement']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 2854, 903, true, 'silver', true, '2026-06-25T08:54:59+00', '2026-06-25T08:54:59+00', '2026-05-26T06:24:59+00'),
('seed+sugar_daddy-031@genuinesugarmummies.com', 'Mark Chebet', '/seed/sugar-dads/photo_51_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_51_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, respectful, discreet. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, respectful, discreet. Preferred age range: 21-35.', 49, 'Kampala', 'Uganda', 'Kampala', '+256725576877', '+256725576877', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'kind, respectful, discreet, well groomed', '21-35', ARRAY['art galleries', 'travel', 'weekend drives', 'live music']::TEXT[], ARRAY['long-term arrangement', 'verified members', 'premium experiences', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5591, 389, true, 'silver', true, '2026-06-25T08:47:59+00', '2026-06-25T08:47:59+00', '2026-05-25T05:24:59+00'),
('seed+sugar_daddy-032@genuinesugarmummies.com', 'Philip Johnson', '/seed/sugar-dads/photo_52_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_52_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, honest, consistent. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, honest, consistent. Preferred age range: 21-35.', 50, 'Mwanza', 'Tanzania', 'Mwanza', '+255738779112', '+255738779112', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'respectful, honest, consistent, discreet', '21-35', ARRAY['spa days', 'fitness', 'business events', 'beach walks']::TEXT[], ARRAY['premium experiences', 'private dates', 'lifestyle support', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5285, 76, true, 'silver', true, '2026-06-25T08:40:59+00', '2026-06-25T08:40:59+00', '2026-05-24T04:24:59+00'),
('seed+sugar_daddy-033@genuinesugarmummies.com', 'Dennis Taylor', '/seed/sugar-dads/photo_53_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_53_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, discreet, well groomed. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, private dates. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, discreet, well groomed. Preferred age range: 21-35.', 51, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250722346205', '+250722346205', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'respectful, discreet, well groomed, serious about meeting', '21-35', ARRAY['wine tasting', 'photography', 'fitness', 'spa days']::TEXT[], ARRAY['long-term arrangement', 'private dates', 'meaningful conversations', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4483, 920, true, 'silver', true, '2026-06-25T08:33:59+00', '2026-06-25T08:33:59+00', '2026-05-23T03:24:59+00'),
('seed+sugar_daddy-034@genuinesugarmummies.com', 'Oscar Wanjiku', '/seed/sugar-dads/photo_54_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_54_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, well groomed, kind. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, long-term arrangement. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, well groomed, kind. Preferred age range: 21-35.', 52, 'Kisumu', 'Kenya', 'Kisumu', '+254714823811', '+254714823811', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'generous, well groomed, kind, clean communication', '21-35', ARRAY['beach walks', 'art galleries', 'fashion', 'spa days']::TEXT[], ARRAY['verified members', 'long-term arrangement', 'meaningful conversations', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1859, 391, true, 'silver', true, '2026-06-25T08:26:59+00', '2026-06-25T08:26:59+00', '2026-05-22T02:24:59+00'),
('seed+sugar_daddy-035@genuinesugarmummies.com', 'Alex Achieng', '/seed/sugar-dads/photo_55_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_55_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, discreet, emotionally mature. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: kind, discreet, emotionally mature. Preferred age range: 21-35.', 53, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254768196126', '+254768196126', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'kind, discreet, emotionally mature, respectful', '21-35', ARRAY['art galleries', 'live music', 'fashion', 'travel']::TEXT[], ARRAY['premium experiences', 'verified members', 'serious matches', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1817, 690, true, 'silver', true, '2026-06-25T08:19:59+00', '2026-06-25T08:19:59+00', '2026-05-21T01:24:59+00'),
('seed+sugar_daddy-036@genuinesugarmummies.com', 'Lawrence Nabwire', '/seed/sugar-dads/photo_56_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_56_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: lifestyle support, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, emotionally mature, serious about meeting. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: lifestyle support, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: honest, emotionally mature, serious about meeting. Preferred age range: 21-35.', 54, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254739444519', '+254739444519', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'honest, emotionally mature, serious about meeting, kind', '21-35', ARRAY['fine dining', 'wine tasting', 'dancing', 'fashion']::TEXT[], ARRAY['lifestyle support', 'meaningful conversations', 'serious matches', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1288, 804, true, 'silver', true, '2026-06-25T08:12:59+00', '2026-06-25T08:12:59+00', '2026-05-20T00:24:59+00'),
('seed+sugar_daddy-037@genuinesugarmummies.com', 'Ronald Mugisha', '/seed/sugar-dads/photo_57_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_57_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, clean communication, serious about meeting. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, clean communication, serious about meeting. Preferred age range: 21-35.', 55, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254740717457', '+254740717457', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'respectful, clean communication, serious about meeting, honest', '21-35', ARRAY['fine dining', 'fitness', 'weekend drives', 'dancing']::TEXT[], ARRAY['verified members', 'mentorship', 'meaningful conversations', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 209, 343, true, 'silver', true, '2026-06-25T08:05:59+00', '2026-06-25T08:05:59+00', '2026-05-18T23:24:59+00'),
('seed+sugar_daddy-038@genuinesugarmummies.com', 'Raymond Hassan', '/seed/sugar-dads/photo_58_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_58_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, well groomed, honest. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: long-term arrangement, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, well groomed, honest. Preferred age range: 21-35.', 56, 'Kisumu', 'Kenya', 'Kisumu', '+254756638169', '+254756638169', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'generous, well groomed, honest, kind', '21-35', ARRAY['fitness', 'fine dining', 'weekend drives', 'photography']::TEXT[], ARRAY['long-term arrangement', 'verified members', 'private dates', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 973, 619, true, 'silver', true, '2026-06-25T07:58:59+00', '2026-06-25T07:58:59+00', '2026-05-17T22:24:59+00'),
('seed+sugar_daddy-039@genuinesugarmummies.com', 'Walter Wafula', '/seed/sugar-dads/photo_59_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_59_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, serious about meeting, well groomed. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, mentorship. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: respectful, serious about meeting, well groomed. Preferred age range: 21-35.', 57, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254761546980', '+254761546980', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'respectful, serious about meeting, well groomed, kind', '21-35', ARRAY['coffee dates', 'live music', 'business events', 'fine dining']::TEXT[], ARRAY['verified members', 'mentorship', 'discreet connection', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 964, 714, true, 'silver', true, '2026-06-25T07:51:59+00', '2026-06-25T07:51:59+00', '2026-05-16T21:24:59+00'),
('seed+sugar_daddy-040@genuinesugarmummies.com', 'Graham Smith', '/seed/sugar-dads/photo_5_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_5_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, honest, consistent. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: premium experiences, meaningful conversations. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, honest, consistent. Preferred age range: 21-35.', 58, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254786656329', '+254786656329', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'discreet, honest, consistent, emotionally mature', '21-35', ARRAY['photography', 'art galleries', 'travel', 'dancing']::TEXT[], ARRAY['premium experiences', 'meaningful conversations', 'private dates', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3796, 313, true, 'silver', true, '2026-06-25T07:44:59+00', '2026-06-25T07:44:59+00', '2026-05-15T20:24:59+00'),
('seed+sugar_daddy-041@genuinesugarmummies.com', 'Arthur Brown', '/seed/sugar-dads/photo_60_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugar-dads/photo_60_2026-06-24_14-00-45.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, emotionally mature, kind. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, emotionally mature, kind. Preferred age range: 21-35.', 59, 'Jinja', 'Uganda', 'Jinja', '+256768518098', '+256768518098', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, emotionally mature, kind, clean communication', '21-35', ARRAY['business events', 'beach walks', 'travel', 'photography']::TEXT[], ARRAY['private dates', 'verified members', 'lifestyle support', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6056, 437, true, 'silver', true, '2026-06-25T07:37:59+00', '2026-06-25T07:37:59+00', '2026-05-14T19:24:59+00'),
('seed+sugar_daddy-042@genuinesugarmummies.com', 'Leonard Otieno', '/seed/sugar-dads/photo_6_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_6_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, premium experiences. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, generous, honest. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: mentorship, premium experiences. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, generous, honest. Preferred age range: 21-35.', 60, 'Dar es Salaam', 'Tanzania', 'Dar es Salaam', '+255720197758', '+255720197758', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, generous, honest, kind', '21-35', ARRAY['fashion', 'beach walks', 'wine tasting', 'spa days']::TEXT[], ARRAY['mentorship', 'premium experiences', 'meaningful conversations', 'verified members']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 871, 454, true, 'silver', true, '2026-06-25T07:30:59+00', '2026-06-25T07:30:59+00', '2026-05-13T18:24:59+00'),
('seed+sugar_daddy-043@genuinesugarmummies.com', 'Bruce Njeri', '/seed/sugar-dads/photo_7_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_7_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: serious matches, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, kind, consistent. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: serious matches, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: generous, kind, consistent. Preferred age range: 21-35.', 61, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250795886730', '+250795886730', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'generous, kind, consistent, honest', '21-35', ARRAY['dancing', 'weekend drives', 'coffee dates', 'fine dining']::TEXT[], ARRAY['serious matches', 'verified members', 'premium experiences', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 7191, 445, true, 'silver', true, '2026-06-25T07:23:59+00', '2026-06-25T07:23:59+00', '2026-05-12T17:24:59+00'),
('seed+sugar_daddy-044@genuinesugarmummies.com', 'Harold Mutiso', '/seed/sugar-dads/photo_8_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_8_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, emotionally mature, generous. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: private dates, verified members. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: well groomed, emotionally mature, generous. Preferred age range: 21-35.', 62, 'Nairobi', 'Kenya', 'Nairobi', '+254781485415', '+254781485415', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'well groomed, emotionally mature, generous, clean communication', '21-35', ARRAY['fitness', 'business events', 'wine tasting', 'fashion']::TEXT[], ARRAY['private dates', 'verified members', 'lifestyle support', 'serious matches']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6327, 129, true, 'silver', true, '2026-06-25T07:16:59+00', '2026-06-25T07:16:59+00', '2026-05-11T16:24:59+00'),
('seed+sugar_daddy-045@genuinesugarmummies.com', 'Vincent Kato', '/seed/sugar-dads/photo_9_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugar-dads/photo_9_2026-06-25_14-22-09.jpg']::TEXT[], 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, respectful, clean communication. Preferred age range: 21-35.', 'Established sugar daddy who values discretion, good conversation, and dependable connection. Interests: verified members, serious matches. Wants: A classy adult mistress who values privacy, honesty, and relaxed premium companionship. Needed qualities: discreet, respectful, clean communication. Preferred age range: 21-35.', 63, 'Eldoret', 'Kenya', 'Eldoret', '+254799899444', '+254799899444', 'sugar_daddy', 'sugar_daddy', 'Mistress', 'I am a sugar daddy looking for Mistress.', 'A classy adult mistress who values privacy, honesty, and relaxed premium companionship.', 'discreet, respectful, clean communication, well groomed', '21-35', ARRAY['business events', 'live music', 'dancing', 'beach walks']::TEXT[], ARRAY['verified members', 'serious matches', 'respectful companionship', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 2863, 328, true, 'silver', true, '2026-06-25T07:09:59+00', '2026-06-25T07:09:59+00', '2026-05-10T15:24:59+00'),
('seed+sugar_mummy-001@genuinesugarmummies.com', 'Margaret Kamau', '/seed/sugarmums/photo_100_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_100_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, generous, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, generous, emotionally mature. Preferred age range: 21-34.', 39, 'Nairobi', 'Kenya', 'Nairobi', '+254763575682', '+254763575682', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, generous, emotionally mature, well groomed', '21-34', ARRAY['weekend drives', 'cooking', 'wine tasting', 'business events']::TEXT[], ARRAY['long-term arrangement', 'private dates', 'meaningful conversations', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1369, 361, true, 'silver', true, '2026-06-25T12:17:59+00', '2026-06-25T12:17:59+00', '2026-06-24T11:24:59+00'),
('seed+sugar_mummy-002@genuinesugarmummies.com', 'Catherine Kariuki', '/seed/sugarmums/photo_10_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_10_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, respectful, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, respectful, generous. Preferred age range: 21-34.', 40, 'Eldoret', 'Kenya', 'Eldoret', '+254766794093', '+254766794093', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, respectful, generous, serious about meeting', '21-34', ARRAY['photography', 'fashion', 'dancing', 'business events']::TEXT[], ARRAY['serious matches', 'private dates', 'respectful companionship', 'verified members']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4058, 446, true, 'silver', true, '2026-06-25T12:10:59+00', '2026-06-25T12:10:59+00', '2026-06-23T10:24:59+00'),
('seed+sugar_mummy-003@genuinesugarmummies.com', 'Janet Nambooze', '/seed/sugarmums/photo_11_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_11_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, serious about meeting. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, serious about meeting. Preferred age range: 21-34.', 41, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254738514463', '+254738514463', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, well groomed, serious about meeting, respectful', '21-34', ARRAY['fitness', 'live music', 'dancing', 'coffee dates']::TEXT[], ARRAY['private dates', 'premium experiences', 'long-term arrangement', 'respectful companionship']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 528, 625, true, 'silver', true, '2026-06-25T12:03:59+00', '2026-06-25T12:03:59+00', '2026-06-22T09:24:59+00'),
('seed+sugar_mummy-004@genuinesugarmummies.com', 'Rosemary Nkurunziza', '/seed/sugarmums/photo_12_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_12_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, well groomed, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, well groomed, kind. Preferred age range: 21-34.', 42, 'Nakuru', 'Kenya', 'Nakuru', '+254726498676', '+254726498676', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, well groomed, kind, generous', '21-34', ARRAY['fitness', 'live music', 'dancing', 'weekend drives']::TEXT[], ARRAY['mentorship', 'serious matches', 'premium experiences', 'respectful companionship']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 5844, 557, true, 'silver', true, '2026-06-25T11:56:59+00', '2026-06-25T11:56:59+00', '2026-06-21T08:24:59+00'),
('seed+sugar_mummy-005@genuinesugarmummies.com', 'Monica Okello', '/seed/sugarmums/photo_12_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugarmums/photo_12_2026-06-25_14-22-09.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, well groomed, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, well groomed, generous. Preferred age range: 21-34.', 43, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254750703727', '+254750703727', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, well groomed, generous, kind', '21-34', ARRAY['coffee dates', 'cooking', 'spa days', 'fashion']::TEXT[], ARRAY['private dates', 'long-term arrangement', 'respectful companionship', 'lifestyle support']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 4777, 451, true, 'silver', true, '2026-06-25T11:49:59+00', '2026-06-25T11:49:59+00', '2026-06-20T07:24:59+00'),
('seed+sugar_mummy-006@genuinesugarmummies.com', 'Beatrice Chebet', '/seed/sugarmums/photo_13_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_13_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, generous, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, generous, kind. Preferred age range: 21-34.', 44, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254723355135', '+254723355135', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, generous, kind, well groomed', '21-34', ARRAY['fitness', 'travel', 'beach walks', 'fine dining']::TEXT[], ARRAY['premium experiences', 'meaningful conversations', 'discreet connection', 'long-term arrangement']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 4904, 458, true, 'silver', true, '2026-06-25T11:42:59+00', '2026-06-25T11:42:59+00', '2026-06-19T06:24:59+00'),
('seed+sugar_mummy-007@genuinesugarmummies.com', 'Caroline Johnson', '/seed/sugarmums/photo_14_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_14_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, honest. Preferred age range: 21-34.', 45, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254775303322', '+254775303322', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, generous, honest, discreet', '21-34', ARRAY['travel', 'beach walks', 'fitness', 'photography']::TEXT[], ARRAY['premium experiences', 'lifestyle support', 'serious matches', 'long-term arrangement']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 2942, 806, true, 'silver', true, '2026-06-25T11:35:59+00', '2026-06-25T11:35:59+00', '2026-06-18T05:24:59+00'),
('seed+sugar_mummy-008@genuinesugarmummies.com', 'Angela Taylor', '/seed/sugarmums/photo_15_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_15_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, serious about meeting, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, serious about meeting, generous. Preferred age range: 21-34.', 46, 'Jinja', 'Uganda', 'Jinja', '+256790618119', '+256790618119', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, serious about meeting, generous, well groomed', '21-34', ARRAY['cooking', 'spa days', 'weekend drives', 'live music']::TEXT[], ARRAY['private dates', 'meaningful conversations', 'mentorship', 'serious matches']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6260, 487, true, 'silver', true, '2026-06-25T11:28:59+00', '2026-06-25T11:28:59+00', '2026-06-17T04:24:59+00'),
('seed+sugar_mummy-009@genuinesugarmummies.com', 'Florence Wanjiku', '/seed/sugarmums/photo_16_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_16_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, generous, serious about meeting. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, generous, serious about meeting. Preferred age range: 21-34.', 47, 'Mwanza', 'Tanzania', 'Mwanza', '+255790417530', '+255790417530', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, generous, serious about meeting, emotionally mature', '21-34', ARRAY['wine tasting', 'business events', 'spa days', 'dancing']::TEXT[], ARRAY['serious matches', 'premium experiences', 'verified members', 'private dates']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 2330, 827, true, 'silver', true, '2026-06-25T11:21:59+00', '2026-06-25T11:21:59+00', '2026-06-16T03:24:59+00'),
('seed+sugar_mummy-010@genuinesugarmummies.com', 'Jane Achieng', '/seed/sugarmums/photo_17_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_17_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, generous, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, generous, honest. Preferred age range: 21-34.', 48, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250786631699', '+250786631699', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, generous, honest, serious about meeting', '21-34', ARRAY['coffee dates', 'travel', 'fitness', 'art galleries']::TEXT[], ARRAY['discreet connection', 'respectful companionship', 'verified members', 'meaningful conversations']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 3870, 405, true, 'silver', true, '2026-06-25T11:14:59+00', '2026-06-25T11:14:59+00', '2026-06-15T02:24:59+00'),
('seed+sugar_mummy-011@genuinesugarmummies.com', 'Lucy Nabwire', '/seed/sugarmums/photo_18_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_18_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, respectful, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, respectful, well groomed. Preferred age range: 21-34.', 49, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254753849014', '+254753849014', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, respectful, well groomed, honest', '21-34', ARRAY['wine tasting', 'dancing', 'business events', 'spa days']::TEXT[], ARRAY['lifestyle support', 'premium experiences', 'discreet connection', 'mentorship']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 4213, 98, true, 'silver', true, '2026-06-25T11:07:59+00', '2026-06-25T11:07:59+00', '2026-06-14T01:24:59+00'),
('seed+sugar_mummy-012@genuinesugarmummies.com', 'Maryanne Mugisha', '/seed/sugarmums/photo_19_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_19_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, discreet, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, discreet, kind. Preferred age range: 21-34.', 50, 'Nairobi', 'Kenya', 'Nairobi', '+254753811875', '+254753811875', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, discreet, kind, emotionally mature', '21-34', ARRAY['live music', 'photography', 'art galleries', 'dancing']::TEXT[], ARRAY['verified members', 'serious matches', 'meaningful conversations', 'discreet connection']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 508, 624, true, 'silver', true, '2026-06-25T11:00:59+00', '2026-06-25T11:00:59+00', '2026-06-13T00:24:59+00'),
('seed+sugar_mummy-013@genuinesugarmummies.com', 'Rebecca Hassan', '/seed/sugarmums/photo_20_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_20_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, clean communication, consistent. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, clean communication, consistent. Preferred age range: 21-34.', 51, 'Mombasa', 'Kenya', 'Mombasa', '+254784795847', '+254784795847', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'serious about meeting, clean communication, consistent, respectful', '21-34', ARRAY['fashion', 'travel', 'coffee dates', 'spa days']::TEXT[], ARRAY['long-term arrangement', 'mentorship', 'verified members', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 2945, 156, true, 'silver', true, '2026-06-25T10:53:59+00', '2026-06-25T10:53:59+00', '2026-06-11T23:24:59+00'),
('seed+sugar_mummy-014@genuinesugarmummies.com', 'Susan Wafula', '/seed/sugarmums/photo_22_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_22_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, clean communication, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, clean communication, generous. Preferred age range: 21-34.', 52, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254795543973', '+254795543973', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, clean communication, generous, serious about meeting', '21-34', ARRAY['weekend drives', 'business events', 'photography', 'travel']::TEXT[], ARRAY['mentorship', 'verified members', 'long-term arrangement', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3044, 532, true, 'silver', true, '2026-06-25T10:46:59+00', '2026-06-25T10:46:59+00', '2026-06-10T22:24:59+00'),
('seed+sugar_mummy-015@genuinesugarmummies.com', 'Teresa Smith', '/seed/sugarmums/photo_23_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_23_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, discreet. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, discreet. Preferred age range: 21-34.', 53, 'Thika', 'Kenya', 'Thika', '+254722632351', '+254722632351', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, generous, discreet, kind', '21-34', ARRAY['fitness', 'weekend drives', 'live music', 'fashion']::TEXT[], ARRAY['discreet connection', 'lifestyle support', 'verified members', 'private dates']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 4501, 801, true, 'silver', true, '2026-06-25T10:39:59+00', '2026-06-25T10:39:59+00', '2026-06-09T21:24:59+00'),
('seed+sugar_mummy-016@genuinesugarmummies.com', 'Victoria Brown', '/seed/sugarmums/photo_24_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_24_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, serious about meeting, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, serious about meeting, well groomed. Preferred age range: 21-34.', 54, 'Thika', 'Kenya', 'Thika', '+254762481995', '+254762481995', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, serious about meeting, well groomed, respectful', '21-34', ARRAY['wine tasting', 'dancing', 'business events', 'weekend drives']::TEXT[], ARRAY['serious matches', 'long-term arrangement', 'meaningful conversations', 'private dates']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 5974, 704, true, 'silver', true, '2026-06-25T10:32:59+00', '2026-06-25T10:32:59+00', '2026-06-08T20:24:59+00'),
('seed+sugar_mummy-017@genuinesugarmummies.com', 'Agnes Otieno', '/seed/sugarmums/photo_26_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_26_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, emotionally mature, consistent. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, emotionally mature, consistent. Preferred age range: 21-34.', 55, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254783561999', '+254783561999', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, emotionally mature, consistent, serious about meeting', '21-34', ARRAY['business events', 'fitness', 'dancing', 'photography']::TEXT[], ARRAY['discreet connection', 'lifestyle support', 'verified members', 'meaningful conversations']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 6383, 484, true, 'silver', true, '2026-06-25T10:25:59+00', '2026-06-25T10:25:59+00', '2026-06-07T19:24:59+00'),
('seed+sugar_mummy-018@genuinesugarmummies.com', 'Dorothy Njeri', '/seed/sugarmums/photo_27_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_27_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, consistent, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, consistent, generous. Preferred age range: 21-34.', 56, 'Entebbe', 'Uganda', 'Entebbe', '+256776992512', '+256776992512', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, consistent, generous, honest', '21-34', ARRAY['coffee dates', 'wine tasting', 'beach walks', 'weekend drives']::TEXT[], ARRAY['lifestyle support', 'meaningful conversations', 'mentorship', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 2415, 139, true, 'silver', true, '2026-06-25T10:18:59+00', '2026-06-25T10:18:59+00', '2026-06-06T18:24:59+00'),
('seed+sugar_mummy-019@genuinesugarmummies.com', 'Elizabeth Mutiso', '/seed/sugarmums/photo_28_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_28_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, consistent, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, consistent, respectful. Preferred age range: 21-34.', 57, 'Dar es Salaam', 'Tanzania', 'Dar es Salaam', '+255716515712', '+255716515712', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, consistent, respectful, emotionally mature', '21-34', ARRAY['fitness', 'art galleries', 'coffee dates', 'weekend drives']::TEXT[], ARRAY['long-term arrangement', 'private dates', 'lifestyle support', 'serious matches']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 3143, 526, true, 'silver', true, '2026-06-25T10:11:59+00', '2026-06-25T10:11:59+00', '2026-06-05T17:24:59+00'),
('seed+sugar_mummy-020@genuinesugarmummies.com', 'Hellen Kato', '/seed/sugarmums/photo_29_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_29_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, serious about meeting, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, serious about meeting, respectful. Preferred age range: 21-34.', 58, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250770829884', '+250770829884', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, serious about meeting, respectful, honest', '21-34', ARRAY['travel', 'fashion', 'live music', 'fine dining']::TEXT[], ARRAY['premium experiences', 'private dates', 'serious matches', 'long-term arrangement']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 1216, 863, true, 'silver', true, '2026-06-25T10:04:59+00', '2026-06-25T10:04:59+00', '2026-06-04T16:24:59+00'),
('seed+sugar_mummy-021@genuinesugarmummies.com', 'Judith Mutesi', '/seed/sugarmums/photo_30_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_30_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, honest, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, honest, kind. Preferred age range: 21-34.', 38, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254746349183', '+254746349183', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'serious about meeting, honest, kind, respectful', '21-34', ARRAY['business events', 'fine dining', 'travel', 'cooking']::TEXT[], ARRAY['mentorship', 'lifestyle support', 'meaningful conversations', 'serious matches']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 1078, 320, true, 'silver', true, '2026-06-25T09:57:59+00', '2026-06-25T09:57:59+00', '2026-06-03T15:24:59+00'),
('seed+sugar_mummy-022@genuinesugarmummies.com', 'Pauline Kimani', '/seed/sugarmums/photo_31_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_31_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, honest, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, honest, respectful. Preferred age range: 21-34.', 39, 'Nakuru', 'Kenya', 'Nakuru', '+254775702980', '+254775702980', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, honest, respectful, consistent', '21-34', ARRAY['beach walks', 'spa days', 'dancing', 'business events']::TEXT[], ARRAY['discreet connection', 'private dates', 'verified members', 'long-term arrangement']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 5966, 259, true, 'silver', true, '2026-06-25T09:50:59+00', '2026-06-25T09:50:59+00', '2026-06-02T14:24:59+00'),
('seed+sugar_mummy-023@genuinesugarmummies.com', 'Regina Maina', '/seed/sugarmums/photo_31_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_31_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, honest, consistent. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, honest, consistent. Preferred age range: 21-34.', 40, 'Eldoret', 'Kenya', 'Eldoret', '+254777670511', '+254777670511', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'generous, honest, consistent, respectful', '21-34', ARRAY['beach walks', 'fine dining', 'business events', 'fashion']::TEXT[], ARRAY['lifestyle support', 'long-term arrangement', 'meaningful conversations', 'premium experiences']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 6522, 531, true, 'silver', true, '2026-06-25T09:43:59+00', '2026-06-25T09:43:59+00', '2026-06-01T13:24:59+00'),
('seed+sugar_mummy-024@genuinesugarmummies.com', 'Sophia Williams', '/seed/sugarmums/photo_32_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_32_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, consistent, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, consistent, generous. Preferred age range: 21-34.', 41, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254740868544', '+254740868544', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, consistent, generous, clean communication', '21-34', ARRAY['cooking', 'art galleries', 'fine dining', 'spa days']::TEXT[], ARRAY['long-term arrangement', 'premium experiences', 'mentorship', 'verified members']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 5226, 684, true, 'silver', true, '2026-06-25T09:36:59+00', '2026-06-25T09:36:59+00', '2026-06-01T12:24:59+00'),
('seed+sugar_mummy-025@genuinesugarmummies.com', 'Anne Mwangi', '/seed/sugarmums/photo_32_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_32_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, well groomed, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, well groomed, honest. Preferred age range: 21-34.', 42, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254733950916', '+254733950916', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, well groomed, honest, consistent', '21-34', ARRAY['photography', 'dancing', 'fashion', 'weekend drives']::TEXT[], ARRAY['respectful companionship', 'premium experiences', 'verified members', 'long-term arrangement']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 596, 150, true, 'silver', true, '2026-06-25T09:29:59+00', '2026-06-25T09:29:59+00', '2026-05-31T11:24:59+00'),
('seed+sugar_mummy-026@genuinesugarmummies.com', 'Christine Kamau', '/seed/sugarmums/photo_33_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_33_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, honest, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, honest, well groomed. Preferred age range: 21-34.', 43, 'Nairobi', 'Kenya', 'Nairobi', '+254714889882', '+254714889882', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, honest, well groomed, clean communication', '21-34', ARRAY['fitness', 'live music', 'fine dining', 'cooking']::TEXT[], ARRAY['respectful companionship', 'premium experiences', 'mentorship', 'discreet connection']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 1645, 674, true, 'silver', true, '2026-06-25T09:22:59+00', '2026-06-25T09:22:59+00', '2026-05-30T10:24:59+00'),
('seed+sugar_mummy-027@genuinesugarmummies.com', 'Doreen Kariuki', '/seed/sugarmums/photo_33_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_33_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, kind, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, kind, honest. Preferred age range: 21-34.', 44, 'Thika', 'Kenya', 'Thika', '+254766505426', '+254766505426', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, kind, honest, serious about meeting', '21-34', ARRAY['cooking', 'dancing', 'fine dining', 'spa days']::TEXT[], ARRAY['premium experiences', 'mentorship', 'private dates', 'long-term arrangement']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1610, 359, true, 'silver', true, '2026-06-25T09:15:59+00', '2026-06-25T09:15:59+00', '2026-05-29T09:24:59+00'),
('seed+sugar_mummy-028@genuinesugarmummies.com', 'Esther Nambooze', '/seed/sugarmums/photo_34_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_34_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, clean communication, discreet. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, clean communication, discreet. Preferred age range: 21-34.', 45, 'Jinja', 'Uganda', 'Jinja', '+256723183958', '+256723183958', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, clean communication, discreet, honest', '21-34', ARRAY['art galleries', 'fashion', 'dancing', 'coffee dates']::TEXT[], ARRAY['mentorship', 'private dates', 'long-term arrangement', 'respectful companionship']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 5494, 347, true, 'silver', true, '2026-06-25T09:08:59+00', '2026-06-25T09:08:59+00', '2026-05-28T08:24:59+00'),
('seed+sugar_mummy-029@genuinesugarmummies.com', 'Fridah Nkurunziza', '/seed/sugarmums/photo_34_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_34_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, consistent, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, consistent, kind. Preferred age range: 21-34.', 46, 'Arusha', 'Tanzania', 'Arusha', '+255791929924', '+255791929924', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, consistent, kind, clean communication', '21-34', ARRAY['art galleries', 'business events', 'photography', 'beach walks']::TEXT[], ARRAY['meaningful conversations', 'discreet connection', 'premium experiences', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 694, 70, true, 'silver', true, '2026-06-25T09:01:59+00', '2026-06-25T09:01:59+00', '2026-05-27T07:24:59+00'),
('seed+sugar_mummy-030@genuinesugarmummies.com', 'Gladys Okello', '/seed/sugarmums/photo_35_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_35_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, well groomed, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, well groomed, respectful. Preferred age range: 21-34.', 47, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250718347459', '+250718347459', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'serious about meeting, well groomed, respectful, generous', '21-34', ARRAY['coffee dates', 'dancing', 'photography', 'spa days']::TEXT[], ARRAY['meaningful conversations', 'respectful companionship', 'serious matches', 'long-term arrangement']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 5365, 809, true, 'silver', true, '2026-06-25T08:54:59+00', '2026-06-25T08:54:59+00', '2026-05-26T06:24:59+00'),
('seed+sugar_mummy-031@genuinesugarmummies.com', 'Harriet Chebet', '/seed/sugarmums/photo_35_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_35_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, generous, clean communication. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, generous, clean communication. Preferred age range: 21-34.', 48, 'Thika', 'Kenya', 'Thika', '+254756517368', '+254756517368', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, generous, clean communication, discreet', '21-34', ARRAY['beach walks', 'business events', 'fine dining', 'cooking']::TEXT[], ARRAY['meaningful conversations', 'discreet connection', 'premium experiences', 'serious matches']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5401, 333, true, 'silver', true, '2026-06-25T08:47:59+00', '2026-06-25T08:47:59+00', '2026-05-25T05:24:59+00'),
('seed+sugar_mummy-032@genuinesugarmummies.com', 'Irene Johnson', '/seed/sugarmums/photo_36_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_36_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, discreet, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, discreet, honest. Preferred age range: 21-34.', 49, 'Nakuru', 'Kenya', 'Nakuru', '+254767324993', '+254767324993', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'generous, discreet, honest, consistent', '21-34', ARRAY['travel', 'fine dining', 'photography', 'weekend drives']::TEXT[], ARRAY['discreet connection', 'verified members', 'long-term arrangement', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 2419, 638, true, 'silver', true, '2026-06-25T08:40:59+00', '2026-06-25T08:40:59+00', '2026-05-24T04:24:59+00'),
('seed+sugar_mummy-033@genuinesugarmummies.com', 'Josephine Taylor', '/seed/sugarmums/photo_37_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_37_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, serious about meeting, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, serious about meeting, generous. Preferred age range: 21-34.', 50, 'Nakuru', 'Kenya', 'Nakuru', '+254779404466', '+254779404466', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, serious about meeting, generous, discreet', '21-34', ARRAY['travel', 'weekend drives', 'wine tasting', 'art galleries']::TEXT[], ARRAY['meaningful conversations', 'discreet connection', 'private dates', 'long-term arrangement']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 7054, 319, true, 'silver', true, '2026-06-25T08:33:59+00', '2026-06-25T08:33:59+00', '2026-05-23T03:24:59+00'),
('seed+sugar_mummy-034@genuinesugarmummies.com', 'Lydia Wanjiku', '/seed/sugarmums/photo_38_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_38_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, respectful, consistent. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, respectful, consistent. Preferred age range: 21-34.', 51, 'Kisumu', 'Kenya', 'Kisumu', '+254783486831', '+254783486831', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, respectful, consistent, discreet', '21-34', ARRAY['dancing', 'fashion', 'coffee dates', 'live music']::TEXT[], ARRAY['private dates', 'lifestyle support', 'meaningful conversations', 'serious matches']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 6663, 490, true, 'silver', true, '2026-06-25T08:26:59+00', '2026-06-25T08:26:59+00', '2026-05-22T02:24:59+00'),
('seed+sugar_mummy-035@genuinesugarmummies.com', 'Martha Achieng', '/seed/sugarmums/photo_3_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_3_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, generous, clean communication. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, generous, clean communication. Preferred age range: 21-34.', 52, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254792177767', '+254792177767', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, generous, clean communication, well groomed', '21-34', ARRAY['wine tasting', 'travel', 'cooking', 'fitness']::TEXT[], ARRAY['long-term arrangement', 'discreet connection', 'serious matches', 'verified members']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3896, 472, true, 'silver', true, '2026-06-25T08:19:59+00', '2026-06-25T08:19:59+00', '2026-05-21T01:24:59+00'),
('seed+sugar_mummy-036@genuinesugarmummies.com', 'Naomi Nabwire', '/seed/sugarmums/photo_3_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugarmums/photo_3_2026-06-25_14-22-09.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, respectful, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, respectful, generous. Preferred age range: 21-34.', 53, 'Kisumu', 'Kenya', 'Kisumu', '+254729418897', '+254729418897', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'honest, respectful, generous, discreet', '21-34', ARRAY['wine tasting', 'cooking', 'dancing', 'coffee dates']::TEXT[], ARRAY['serious matches', 'meaningful conversations', 'verified members', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1406, 180, true, 'silver', true, '2026-06-25T08:12:59+00', '2026-06-25T08:12:59+00', '2026-05-20T00:24:59+00'),
('seed+sugar_mummy-037@genuinesugarmummies.com', 'Priscilla Mugisha', '/seed/sugarmums/photo_41_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_41_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, honest, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, honest, generous. Preferred age range: 21-34.', 54, 'Nakuru', 'Kenya', 'Nakuru', '+254792276827', '+254792276827', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, honest, generous, serious about meeting', '21-34', ARRAY['fashion', 'coffee dates', 'fitness', 'travel']::TEXT[], ARRAY['mentorship', 'lifestyle support', 'serious matches', 'private dates']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4836, 618, true, 'silver', true, '2026-06-25T08:05:59+00', '2026-06-25T08:05:59+00', '2026-05-18T23:24:59+00'),
('seed+sugar_mummy-038@genuinesugarmummies.com', 'Sarah Hassan', '/seed/sugarmums/photo_42_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_42_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, discreet, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, discreet, emotionally mature. Preferred age range: 21-34.', 55, 'Kampala', 'Uganda', 'Kampala', '+256783536822', '+256783536822', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, discreet, emotionally mature, kind', '21-34', ARRAY['spa days', 'business events', 'photography', 'cooking']::TEXT[], ARRAY['premium experiences', 'respectful companionship', 'verified members', 'discreet connection']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 5314, 644, true, 'silver', true, '2026-06-25T07:58:59+00', '2026-06-25T07:58:59+00', '2026-05-17T22:24:59+00'),
('seed+sugar_mummy-039@genuinesugarmummies.com', 'Tabitha Wafula', '/seed/sugarmums/photo_43_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_43_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, discreet, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, discreet, well groomed. Preferred age range: 21-34.', 56, 'Arusha', 'Tanzania', 'Arusha', '+255798162823', '+255798162823', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, discreet, well groomed, respectful', '21-34', ARRAY['wine tasting', 'spa days', 'coffee dates', 'fitness']::TEXT[], ARRAY['mentorship', 'discreet connection', 'lifestyle support', 'long-term arrangement']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 3681, 173, true, 'silver', true, '2026-06-25T07:51:59+00', '2026-06-25T07:51:59+00', '2026-05-16T21:24:59+00'),
('seed+sugar_mummy-040@genuinesugarmummies.com', 'Wairimu Smith', '/seed/sugarmums/photo_44_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_44_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, kind, clean communication. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, kind, clean communication. Preferred age range: 21-34.', 57, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250757639995', '+250757639995', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, kind, clean communication, honest', '21-34', ARRAY['art galleries', 'live music', 'fashion', 'business events']::TEXT[], ARRAY['meaningful conversations', 'premium experiences', 'verified members', 'discreet connection']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 949, 587, true, 'silver', true, '2026-06-25T07:44:59+00', '2026-06-25T07:44:59+00', '2026-05-15T20:24:59+00'),
('seed+sugar_mummy-041@genuinesugarmummies.com', 'Yolanda Brown', '/seed/sugarmums/photo_46_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_46_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, kind, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, kind, honest. Preferred age range: 21-34.', 58, 'Nakuru', 'Kenya', 'Nakuru', '+254730952993', '+254730952993', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, kind, honest, generous', '21-34', ARRAY['art galleries', 'travel', 'fitness', 'wine tasting']::TEXT[], ARRAY['lifestyle support', 'meaningful conversations', 'private dates', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4812, 347, true, 'silver', true, '2026-06-25T07:37:59+00', '2026-06-25T07:37:59+00', '2026-05-14T19:24:59+00'),
('seed+sugar_mummy-042@genuinesugarmummies.com', 'Zipporah Otieno', '/seed/sugarmums/photo_47_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_47_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, generous, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, generous, kind. Preferred age range: 21-34.', 38, 'Nakuru', 'Kenya', 'Nakuru', '+254768352422', '+254768352422', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, generous, kind, discreet', '21-34', ARRAY['dancing', 'weekend drives', 'art galleries', 'coffee dates']::TEXT[], ARRAY['discreet connection', 'serious matches', 'mentorship', 'lifestyle support']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4858, 232, true, 'silver', true, '2026-06-25T07:30:59+00', '2026-06-25T07:30:59+00', '2026-05-13T18:24:59+00'),
('seed+sugar_mummy-043@genuinesugarmummies.com', 'Margaret Njeri', '/seed/sugarmums/photo_48_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_48_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, kind, clean communication. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, kind, clean communication. Preferred age range: 21-34.', 39, 'Nairobi', 'Kenya', 'Nairobi', '+254756900961', '+254756900961', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'generous, kind, clean communication, well groomed', '21-34', ARRAY['fine dining', 'fitness', 'art galleries', 'business events']::TEXT[], ARRAY['discreet connection', 'mentorship', 'respectful companionship', 'long-term arrangement']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 3077, 424, true, 'silver', true, '2026-06-25T07:23:59+00', '2026-06-25T07:23:59+00', '2026-05-12T17:24:59+00'),
('seed+sugar_mummy-044@genuinesugarmummies.com', 'Catherine Mutiso', '/seed/sugarmums/photo_49_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_49_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, honest, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, honest, well groomed. Preferred age range: 21-34.', 40, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254780393308', '+254780393308', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, honest, well groomed, serious about meeting', '21-34', ARRAY['fine dining', 'business events', 'coffee dates', 'live music']::TEXT[], ARRAY['premium experiences', 'verified members', 'mentorship', 'respectful companionship']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 5185, 857, true, 'silver', true, '2026-06-25T07:16:59+00', '2026-06-25T07:16:59+00', '2026-05-11T16:24:59+00'),
('seed+sugar_mummy-045@genuinesugarmummies.com', 'Janet Kato', '/seed/sugarmums/photo_4_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_4_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, honest, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, honest, kind. Preferred age range: 21-34.', 41, 'Kisumu', 'Kenya', 'Kisumu', '+254715147504', '+254715147504', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'serious about meeting, honest, kind, discreet', '21-34', ARRAY['travel', 'beach walks', 'fashion', 'dancing']::TEXT[], ARRAY['verified members', 'premium experiences', 'meaningful conversations', 'private dates']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 1202, 51, true, 'silver', true, '2026-06-25T07:09:59+00', '2026-06-25T07:09:59+00', '2026-05-10T15:24:59+00'),
('seed+sugar_mummy-046@genuinesugarmummies.com', 'Rosemary Mutesi', '/seed/sugarmums/photo_4_2026-06-25_14-22-09.jpg', ARRAY['/seed/sugarmums/photo_4_2026-06-25_14-22-09.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, clean communication, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, clean communication, kind. Preferred age range: 21-34.', 42, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254748722565', '+254748722565', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, clean communication, kind, discreet', '21-34', ARRAY['coffee dates', 'art galleries', 'weekend drives', 'business events']::TEXT[], ARRAY['verified members', 'meaningful conversations', 'premium experiences', 'mentorship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4235, 356, true, 'silver', true, '2026-06-25T07:02:59+00', '2026-06-25T07:02:59+00', '2026-05-09T14:24:59+00'),
('seed+sugar_mummy-047@genuinesugarmummies.com', 'Monica Kimani', '/seed/sugarmums/photo_51_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_51_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, respectful, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, private dates. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, respectful, well groomed. Preferred age range: 21-34.', 43, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254793920934', '+254793920934', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, respectful, well groomed, clean communication', '21-34', ARRAY['fitness', 'art galleries', 'fine dining', 'fashion']::TEXT[], ARRAY['premium experiences', 'private dates', 'long-term arrangement', 'mentorship']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 4818, 806, true, 'silver', true, '2026-06-25T06:55:59+00', '2026-06-25T06:55:59+00', '2026-05-08T13:24:59+00'),
('seed+sugar_mummy-048@genuinesugarmummies.com', 'Beatrice Maina', '/seed/sugarmums/photo_52_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_52_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, respectful, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, respectful, generous. Preferred age range: 21-34.', 44, 'Jinja', 'Uganda', 'Jinja', '+256712562462', '+256712562462', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'emotionally mature, respectful, generous, well groomed', '21-34', ARRAY['fine dining', 'business events', 'art galleries', 'weekend drives']::TEXT[], ARRAY['verified members', 'long-term arrangement', 'meaningful conversations', 'serious matches']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3510, 333, true, 'silver', true, '2026-06-25T06:48:59+00', '2026-06-25T06:48:59+00', '2026-05-08T12:24:59+00'),
('seed+sugar_mummy-049@genuinesugarmummies.com', 'Caroline Williams', '/seed/sugarmums/photo_53_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_53_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, honest, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, honest, emotionally mature. Preferred age range: 21-34.', 45, 'Arusha', 'Tanzania', 'Arusha', '+255751794395', '+255751794395', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, honest, emotionally mature, discreet', '21-34', ARRAY['photography', 'live music', 'beach walks', 'coffee dates']::TEXT[], ARRAY['serious matches', 'discreet connection', 'respectful companionship', 'premium experiences']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 4384, 501, true, 'silver', true, '2026-06-25T06:41:59+00', '2026-06-25T06:41:59+00', '2026-05-07T11:24:59+00'),
('seed+sugar_mummy-050@genuinesugarmummies.com', 'Angela Mwangi', '/seed/sugarmums/photo_54_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_54_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, emotionally mature, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, emotionally mature, honest. Preferred age range: 21-34.', 46, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250781412999', '+250781412999', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, emotionally mature, honest, clean communication', '21-34', ARRAY['weekend drives', 'art galleries', 'coffee dates', 'fashion']::TEXT[], ARRAY['verified members', 'premium experiences', 'mentorship', 'discreet connection']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 2518, 242, true, 'silver', true, '2026-06-25T06:34:59+00', '2026-06-25T06:34:59+00', '2026-05-06T10:24:59+00'),
('seed+sugar_mummy-051@genuinesugarmummies.com', 'Florence Kamau', '/seed/sugarmums/photo_55_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_55_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, honest, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, honest, kind. Preferred age range: 21-34.', 47, 'Nakuru', 'Kenya', 'Nakuru', '+254754910616', '+254754910616', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'generous, honest, kind, emotionally mature', '21-34', ARRAY['photography', 'wine tasting', 'art galleries', 'fashion']::TEXT[], ARRAY['discreet connection', 'premium experiences', 'mentorship', 'meaningful conversations']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1279, 835, true, 'silver', true, '2026-06-25T06:27:59+00', '2026-06-25T06:27:59+00', '2026-05-05T09:24:59+00'),
('seed+sugar_mummy-052@genuinesugarmummies.com', 'Jane Kariuki', '/seed/sugarmums/photo_56_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_56_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, honest, discreet. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, honest, discreet. Preferred age range: 21-34.', 48, 'Nairobi', 'Kenya', 'Nairobi', '+254799384815', '+254799384815', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'emotionally mature, honest, discreet, well groomed', '21-34', ARRAY['fitness', 'photography', 'travel', 'fashion']::TEXT[], ARRAY['discreet connection', 'mentorship', 'serious matches', 'private dates']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 974, 152, true, 'silver', true, '2026-06-25T06:20:59+00', '2026-06-25T06:20:59+00', '2026-05-04T08:24:59+00'),
('seed+sugar_mummy-053@genuinesugarmummies.com', 'Lucy Nambooze', '/seed/sugarmums/photo_57_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_57_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, well groomed, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, well groomed, generous. Preferred age range: 21-34.', 49, 'Nakuru', 'Kenya', 'Nakuru', '+254727105433', '+254727105433', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, well groomed, generous, serious about meeting', '21-34', ARRAY['fine dining', 'spa days', 'coffee dates', 'live music']::TEXT[], ARRAY['lifestyle support', 'respectful companionship', 'private dates', 'serious matches']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 1373, 575, true, 'silver', true, '2026-06-25T06:13:59+00', '2026-06-25T06:13:59+00', '2026-05-03T07:24:59+00'),
('seed+sugar_mummy-054@genuinesugarmummies.com', 'Maryanne Nkurunziza', '/seed/sugarmums/photo_58_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_58_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, emotionally mature, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, emotionally mature, respectful. Preferred age range: 21-34.', 50, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254763978292', '+254763978292', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'generous, emotionally mature, respectful, serious about meeting', '21-34', ARRAY['art galleries', 'spa days', 'live music', 'fitness']::TEXT[], ARRAY['premium experiences', 'mentorship', 'respectful companionship', 'long-term arrangement']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 377, 192, true, 'silver', true, '2026-06-25T06:06:59+00', '2026-06-25T06:06:59+00', '2026-05-02T06:24:59+00'),
('seed+sugar_mummy-055@genuinesugarmummies.com', 'Rebecca Okello', '/seed/sugarmums/photo_59_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_59_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, honest. Preferred age range: 21-34.', 51, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254774590755', '+254774590755', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, well groomed, honest, generous', '21-34', ARRAY['weekend drives', 'photography', 'fitness', 'fine dining']::TEXT[], ARRAY['respectful companionship', 'mentorship', 'private dates', 'meaningful conversations']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 1659, 291, true, 'silver', true, '2026-06-25T05:59:59+00', '2026-06-25T05:59:59+00', '2026-05-01T05:24:59+00'),
('seed+sugar_mummy-056@genuinesugarmummies.com', 'Susan Chebet', '/seed/sugarmums/photo_5_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_5_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, discreet, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, discreet, emotionally mature. Preferred age range: 21-34.', 52, 'Thika', 'Kenya', 'Thika', '+254788997734', '+254788997734', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, discreet, emotionally mature, generous', '21-34', ARRAY['weekend drives', 'photography', 'art galleries', 'spa days']::TEXT[], ARRAY['mentorship', 'meaningful conversations', 'respectful companionship', 'premium experiences']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 7428, 666, true, 'silver', true, '2026-06-25T05:52:59+00', '2026-06-25T05:52:59+00', '2026-04-30T04:24:59+00'),
('seed+sugar_mummy-057@genuinesugarmummies.com', 'Teresa Johnson', '/seed/sugarmums/photo_61_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_61_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, emotionally mature, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, emotionally mature, respectful. Preferred age range: 21-34.', 53, 'Karen, Nairobi', 'Kenya', 'Karen, Nairobi', '+254759346961', '+254759346961', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, emotionally mature, respectful, clean communication', '21-34', ARRAY['coffee dates', 'fashion', 'travel', 'beach walks']::TEXT[], ARRAY['private dates', 'meaningful conversations', 'verified members', 'lifestyle support']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 6254, 469, true, 'silver', true, '2026-06-25T05:45:59+00', '2026-06-25T05:45:59+00', '2026-04-29T03:24:59+00'),
('seed+sugar_mummy-058@genuinesugarmummies.com', 'Victoria Taylor', '/seed/sugarmums/photo_63_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_63_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, respectful, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, respectful, generous. Preferred age range: 21-34.', 54, 'Entebbe', 'Uganda', 'Entebbe', '+256749267475', '+256749267475', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'emotionally mature, respectful, generous, serious about meeting', '21-34', ARRAY['fitness', 'business events', 'photography', 'cooking']::TEXT[], ARRAY['respectful companionship', 'mentorship', 'premium experiences', 'discreet connection']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5700, 427, true, 'silver', true, '2026-06-25T05:38:59+00', '2026-06-25T05:38:59+00', '2026-04-28T02:24:59+00'),
('seed+sugar_mummy-059@genuinesugarmummies.com', 'Agnes Wanjiku', '/seed/sugarmums/photo_64_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_64_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, clean communication, serious about meeting. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, clean communication, serious about meeting. Preferred age range: 21-34.', 55, 'Mwanza', 'Tanzania', 'Mwanza', '+255787491774', '+255787491774', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, clean communication, serious about meeting, consistent', '21-34', ARRAY['travel', 'spa days', 'fitness', 'fashion']::TEXT[], ARRAY['serious matches', 'lifestyle support', 'verified members', 'private dates']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5830, 437, true, 'silver', true, '2026-06-25T05:31:59+00', '2026-06-25T05:31:59+00', '2026-04-27T01:24:59+00'),
('seed+sugar_mummy-060@genuinesugarmummies.com', 'Dorothy Achieng', '/seed/sugarmums/photo_66_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_66_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, generous, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, generous, honest. Preferred age range: 21-34.', 56, 'Kigali', 'Rwanda', 'Kigali', '+250780630041', '+250780630041', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, generous, honest, respectful', '21-34', ARRAY['dancing', 'live music', 'spa days', 'business events']::TEXT[], ARRAY['private dates', 'verified members', 'discreet connection', 'mentorship']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 4771, 219, true, 'silver', true, '2026-06-25T05:24:59+00', '2026-06-25T05:24:59+00', '2026-04-26T00:24:59+00'),
('seed+sugar_mummy-061@genuinesugarmummies.com', 'Elizabeth Nabwire', '/seed/sugarmums/photo_68_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_68_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, well groomed, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, well groomed, respectful. Preferred age range: 21-34.', 57, 'Kisumu', 'Kenya', 'Kisumu', '+254726638179', '+254726638179', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'honest, well groomed, respectful, emotionally mature', '21-34', ARRAY['fashion', 'cooking', 'coffee dates', 'art galleries']::TEXT[], ARRAY['private dates', 'lifestyle support', 'discreet connection', 'respectful companionship']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3822, 437, true, 'silver', true, '2026-06-25T05:17:59+00', '2026-06-25T05:17:59+00', '2026-04-24T23:24:59+00'),
('seed+sugar_mummy-062@genuinesugarmummies.com', 'Hellen Mugisha', '/seed/sugarmums/photo_69_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_69_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, emotionally mature, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, emotionally mature, generous. Preferred age range: 21-34.', 58, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254764461264', '+254764461264', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, emotionally mature, generous, serious about meeting', '21-34', ARRAY['art galleries', 'spa days', 'dancing', 'fitness']::TEXT[], ARRAY['respectful companionship', 'long-term arrangement', 'mentorship', 'verified members']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 602, 729, true, 'silver', true, '2026-06-25T05:10:59+00', '2026-06-25T05:10:59+00', '2026-04-23T22:24:59+00'),
('seed+sugar_mummy-063@genuinesugarmummies.com', 'Judith Hassan', '/seed/sugarmums/photo_70_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_70_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, consistent, serious about meeting. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, consistent, serious about meeting. Preferred age range: 21-34.', 38, 'Mombasa', 'Kenya', 'Mombasa', '+254758493892', '+254758493892', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, consistent, serious about meeting, emotionally mature', '21-34', ARRAY['wine tasting', 'art galleries', 'fine dining', 'fitness']::TEXT[], ARRAY['long-term arrangement', 'meaningful conversations', 'verified members', 'serious matches']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 5672, 94, true, 'silver', true, '2026-06-25T05:03:59+00', '2026-06-25T05:03:59+00', '2026-04-22T21:24:59+00'),
('seed+sugar_mummy-064@genuinesugarmummies.com', 'Pauline Wafula', '/seed/sugarmums/photo_71_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_71_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, serious about meeting, discreet. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, serious about meeting, discreet. Preferred age range: 21-34.', 39, 'Thika', 'Kenya', 'Thika', '+254796854024', '+254796854024', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, serious about meeting, discreet, emotionally mature', '21-34', ARRAY['travel', 'weekend drives', 'coffee dates', 'beach walks']::TEXT[], ARRAY['verified members', 'meaningful conversations', 'lifestyle support', 'long-term arrangement']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3554, 569, true, 'silver', true, '2026-06-25T04:56:59+00', '2026-06-25T04:56:59+00', '2026-04-21T20:24:59+00'),
('seed+sugar_mummy-065@genuinesugarmummies.com', 'Regina Smith', '/seed/sugarmums/photo_72_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_72_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, respectful, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, respectful, emotionally mature. Preferred age range: 21-34.', 40, 'Nakuru', 'Kenya', 'Nakuru', '+254718205797', '+254718205797', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, respectful, emotionally mature, generous', '21-34', ARRAY['live music', 'art galleries', 'fashion', 'weekend drives']::TEXT[], ARRAY['mentorship', 'lifestyle support', 'private dates', 'respectful companionship']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 355, 620, true, 'silver', true, '2026-06-25T04:49:59+00', '2026-06-25T04:49:59+00', '2026-04-20T19:24:59+00'),
('seed+sugar_mummy-066@genuinesugarmummies.com', 'Sophia Brown', '/seed/sugarmums/photo_73_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_73_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, emotionally mature, respectful. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, emotionally mature, respectful. Preferred age range: 21-34.', 41, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254774403314', '+254774403314', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'honest, emotionally mature, respectful, generous', '21-34', ARRAY['spa days', 'photography', 'fine dining', 'live music']::TEXT[], ARRAY['respectful companionship', 'long-term arrangement', 'discreet connection', 'private dates']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 6762, 251, true, 'silver', true, '2026-06-25T04:42:59+00', '2026-06-25T04:42:59+00', '2026-04-19T18:24:59+00'),
('seed+sugar_mummy-067@genuinesugarmummies.com', 'Anne Otieno', '/seed/sugarmums/photo_74_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_74_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, emotionally mature, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, emotionally mature, kind. Preferred age range: 21-34.', 42, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254745163918', '+254745163918', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'honest, emotionally mature, kind, clean communication', '21-34', ARRAY['business events', 'dancing', 'spa days', 'fashion']::TEXT[], ARRAY['lifestyle support', 'mentorship', 'meaningful conversations', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4926, 582, true, 'silver', true, '2026-06-25T04:35:59+00', '2026-06-25T04:35:59+00', '2026-04-18T17:24:59+00'),
('seed+sugar_mummy-068@genuinesugarmummies.com', 'Christine Njeri', '/seed/sugarmums/photo_76_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_76_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, consistent, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, consistent, kind. Preferred age range: 21-34.', 43, 'Jinja', 'Uganda', 'Jinja', '+256729414455', '+256729414455', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'honest, consistent, kind, emotionally mature', '21-34', ARRAY['spa days', 'beach walks', 'coffee dates', 'art galleries']::TEXT[], ARRAY['respectful companionship', 'premium experiences', 'long-term arrangement', 'discreet connection']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 1586, 397, true, 'silver', true, '2026-06-25T04:28:59+00', '2026-06-25T04:28:59+00', '2026-04-17T16:24:59+00'),
('seed+sugar_mummy-069@genuinesugarmummies.com', 'Doreen Mutiso', '/seed/sugarmums/photo_77_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_77_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, serious about meeting, clean communication. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, serious about meeting, clean communication. Preferred age range: 21-34.', 44, 'Dar es Salaam', 'Tanzania', 'Dar es Salaam', '+255741367382', '+255741367382', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, serious about meeting, clean communication, emotionally mature', '21-34', ARRAY['cooking', 'live music', 'fitness', 'photography']::TEXT[], ARRAY['meaningful conversations', 'discreet connection', 'respectful companionship', 'mentorship']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 2785, 220, true, 'silver', true, '2026-06-25T04:21:59+00', '2026-06-25T04:21:59+00', '2026-04-16T15:24:59+00'),
('seed+sugar_mummy-070@genuinesugarmummies.com', 'Esther Kato', '/seed/sugarmums/photo_78_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_78_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, respectful, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, respectful, generous. Preferred age range: 21-34.', 45, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250785859489', '+250785859489', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'serious about meeting, respectful, generous, well groomed', '21-34', ARRAY['cooking', 'fashion', 'travel', 'coffee dates']::TEXT[], ARRAY['lifestyle support', 'respectful companionship', 'mentorship', 'serious matches']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 4658, 699, true, 'silver', true, '2026-06-25T04:14:59+00', '2026-06-25T04:14:59+00', '2026-04-15T14:24:59+00'),
('seed+sugar_mummy-071@genuinesugarmummies.com', 'Fridah Mutesi', '/seed/sugarmums/photo_79_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_79_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, well groomed, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, well groomed, emotionally mature. Preferred age range: 21-34.', 46, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254787837954', '+254787837954', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'generous, well groomed, emotionally mature, consistent', '21-34', ARRAY['live music', 'cooking', 'fashion', 'fitness']::TEXT[], ARRAY['respectful companionship', 'lifestyle support', 'verified members', 'premium experiences']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3329, 221, true, 'silver', true, '2026-06-25T04:07:59+00', '2026-06-25T04:07:59+00', '2026-04-14T13:24:59+00'),
('seed+sugar_mummy-072@genuinesugarmummies.com', 'Gladys Kimani', '/seed/sugarmums/photo_80_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_80_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, consistent, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, verified members. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, consistent, well groomed. Preferred age range: 21-34.', 47, 'Kilimani, Nairobi', 'Kenya', 'Kilimani, Nairobi', '+254722941814', '+254722941814', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, consistent, well groomed, emotionally mature', '21-34', ARRAY['fashion', 'dancing', 'fitness', 'beach walks']::TEXT[], ARRAY['discreet connection', 'verified members', 'premium experiences', 'meaningful conversations']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3926, 751, true, 'silver', true, '2026-06-25T04:00:59+00', '2026-06-25T04:00:59+00', '2026-04-14T12:24:59+00'),
('seed+sugar_mummy-073@genuinesugarmummies.com', 'Harriet Maina', '/seed/sugarmums/photo_82_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_82_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, honest, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, honest, kind. Preferred age range: 21-34.', 48, 'Nakuru', 'Kenya', 'Nakuru', '+254729305721', '+254729305721', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, honest, kind, clean communication', '21-34', ARRAY['fashion', 'wine tasting', 'beach walks', 'fine dining']::TEXT[], ARRAY['serious matches', 'lifestyle support', 'meaningful conversations', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 1964, 349, true, 'silver', true, '2026-06-25T03:53:59+00', '2026-06-25T03:53:59+00', '2026-04-13T11:24:59+00'),
('seed+sugar_mummy-074@genuinesugarmummies.com', 'Irene Williams', '/seed/sugarmums/photo_83_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_83_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, serious about meeting, clean communication. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: premium experiences, mentorship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: well groomed, serious about meeting, clean communication. Preferred age range: 21-34.', 49, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254755277487', '+254755277487', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'well groomed, serious about meeting, clean communication, consistent', '21-34', ARRAY['cooking', 'live music', 'art galleries', 'coffee dates']::TEXT[], ARRAY['premium experiences', 'mentorship', 'discreet connection', 'serious matches']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 5980, 155, true, 'silver', true, '2026-06-25T03:46:59+00', '2026-06-25T03:46:59+00', '2026-04-12T10:24:59+00'),
('seed+sugar_mummy-075@genuinesugarmummies.com', 'Josephine Mwangi', '/seed/sugarmums/photo_85_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_85_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, serious about meeting, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, serious about meeting, kind. Preferred age range: 21-34.', 50, 'Kisumu', 'Kenya', 'Kisumu', '+254790342675', '+254790342675', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, serious about meeting, kind, generous', '21-34', ARRAY['wine tasting', 'coffee dates', 'spa days', 'fine dining']::TEXT[], ARRAY['verified members', 'respectful companionship', 'private dates', 'long-term arrangement']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 5873, 81, true, 'silver', true, '2026-06-25T03:39:59+00', '2026-06-25T03:39:59+00', '2026-04-11T09:24:59+00'),
('seed+sugar_mummy-076@genuinesugarmummies.com', 'Lydia Kamau', '/seed/sugarmums/photo_86_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_86_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, honest, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: respectful, honest, kind. Preferred age range: 21-34.', 51, 'Nairobi', 'Kenya', 'Nairobi', '+254712655134', '+254712655134', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'respectful, honest, kind, serious about meeting', '21-34', ARRAY['live music', 'coffee dates', 'art galleries', 'fashion']::TEXT[], ARRAY['respectful companionship', 'discreet connection', 'verified members', 'serious matches']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 2330, 751, true, 'silver', true, '2026-06-25T03:32:59+00', '2026-06-25T03:32:59+00', '2026-04-10T08:24:59+00'),
('seed+sugar_mummy-077@genuinesugarmummies.com', 'Martha Kariuki', '/seed/sugarmums/photo_87_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_87_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, clean communication, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: honest, clean communication, emotionally mature. Preferred age range: 21-34.', 52, 'Nairobi', 'Kenya', 'Nairobi', '+254789652029', '+254789652029', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'honest, clean communication, emotionally mature, generous', '21-34', ARRAY['coffee dates', 'cooking', 'photography', 'spa days']::TEXT[], ARRAY['long-term arrangement', 'meaningful conversations', 'private dates', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 6758, 270, true, 'silver', true, '2026-06-25T03:25:59+00', '2026-06-25T03:25:59+00', '2026-04-09T07:24:59+00'),
('seed+sugar_mummy-078@genuinesugarmummies.com', 'Naomi Nambooze', '/seed/sugarmums/photo_88_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_88_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, discreet, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: emotionally mature, discreet, generous. Preferred age range: 21-34.', 53, 'Entebbe', 'Uganda', 'Entebbe', '+256793896483', '+256793896483', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'emotionally mature, discreet, generous, consistent', '21-34', ARRAY['dancing', 'beach walks', 'travel', 'fashion']::TEXT[], ARRAY['long-term arrangement', 'discreet connection', 'lifestyle support', 'premium experiences']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 845, 44, true, 'silver', true, '2026-06-25T03:18:59+00', '2026-06-25T03:18:59+00', '2026-04-08T06:24:59+00'),
('seed+sugar_mummy-079@genuinesugarmummies.com', 'Priscilla Nkurunziza', '/seed/sugarmums/photo_89_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_89_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, consistent, generous. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: respectful companionship, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: kind, consistent, generous. Preferred age range: 21-34.', 54, 'Arusha', 'Tanzania', 'Arusha', '+255715340927', '+255715340927', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'kind, consistent, generous, discreet', '21-34', ARRAY['beach walks', 'coffee dates', 'art galleries', 'fine dining']::TEXT[], ARRAY['respectful companionship', 'meaningful conversations', 'private dates', 'lifestyle support']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 7463, 228, true, 'silver', true, '2026-06-25T03:11:59+00', '2026-06-25T03:11:59+00', '2026-04-07T05:24:59+00'),
('seed+sugar_mummy-080@genuinesugarmummies.com', 'Sarah Okello', '/seed/sugarmums/photo_90_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_90_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, respectful, emotionally mature. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: verified members, respectful companionship. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: consistent, respectful, emotionally mature. Preferred age range: 21-34.', 55, 'Gisenyi', 'Rwanda', 'Gisenyi', '+250728888795', '+250728888795', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'consistent, respectful, emotionally mature, discreet', '21-34', ARRAY['fine dining', 'travel', 'spa days', 'fitness']::TEXT[], ARRAY['verified members', 'respectful companionship', 'meaningful conversations', 'long-term arrangement']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 5918, 852, true, 'silver', true, '2026-06-25T03:04:59+00', '2026-06-25T03:04:59+00', '2026-04-06T04:24:59+00'),
('seed+sugar_mummy-081@genuinesugarmummies.com', 'Tabitha Chebet', '/seed/sugarmums/photo_91_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_91_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, consistent. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, long-term arrangement. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, consistent. Preferred age range: 21-34.', 56, 'Mombasa', 'Kenya', 'Mombasa', '+254722558320', '+254722558320', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, generous, consistent, respectful', '21-34', ARRAY['fitness', 'weekend drives', 'business events', 'live music']::TEXT[], ARRAY['serious matches', 'long-term arrangement', 'premium experiences', 'lifestyle support']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 6950, 249, true, 'silver', true, '2026-06-25T02:57:59+00', '2026-06-25T02:57:59+00', '2026-04-05T03:24:59+00'),
('seed+sugar_mummy-082@genuinesugarmummies.com', 'Wairimu Johnson', '/seed/sugarmums/photo_93_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_93_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: long-term arrangement, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, honest. Preferred age range: 21-34.', 57, 'Thika', 'Kenya', 'Thika', '+254755679902', '+254755679902', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, well groomed, honest, generous', '21-34', ARRAY['business events', 'dancing', 'wine tasting', 'cooking']::TEXT[], ARRAY['long-term arrangement', 'premium experiences', 'respectful companionship', 'verified members']::TEXT[], 'Curvy', 'silver', true, 'verified', true, false, false, 3617, 396, true, 'silver', true, '2026-06-25T02:50:59+00', '2026-06-25T02:50:59+00', '2026-04-04T02:24:59+00'),
('seed+sugar_mummy-083@genuinesugarmummies.com', 'Yolanda Taylor', '/seed/sugarmums/photo_94_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_94_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, clean communication, kind. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: mentorship, lifestyle support. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, clean communication, kind. Preferred age range: 21-34.', 58, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254791261771', '+254791261771', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, clean communication, kind, consistent', '21-34', ARRAY['spa days', 'beach walks', 'travel', 'business events']::TEXT[], ARRAY['mentorship', 'lifestyle support', 'private dates', 'respectful companionship']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3271, 769, true, 'silver', true, '2026-06-25T02:43:59+00', '2026-06-25T02:43:59+00', '2026-04-03T01:24:59+00'),
('seed+sugar_mummy-084@genuinesugarmummies.com', 'Zipporah Wanjiku', '/seed/sugarmums/photo_95_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_95_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, serious about meeting. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: discreet connection, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: clean communication, generous, serious about meeting. Preferred age range: 21-34.', 38, 'Thika', 'Kenya', 'Thika', '+254767684041', '+254767684041', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'clean communication, generous, serious about meeting, emotionally mature', '21-34', ARRAY['travel', 'wine tasting', 'fine dining', 'fitness']::TEXT[], ARRAY['discreet connection', 'premium experiences', 'mentorship', 'respectful companionship']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 4277, 580, true, 'silver', true, '2026-06-25T02:36:59+00', '2026-06-25T02:36:59+00', '2026-04-02T00:24:59+00'),
('seed+sugar_mummy-085@genuinesugarmummies.com', 'Margaret Achieng', '/seed/sugarmums/photo_96_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_96_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, kind, honest. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: private dates, premium experiences. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, kind, honest. Preferred age range: 21-34.', 39, 'Mombasa', 'Kenya', 'Mombasa', '+254720860053', '+254720860053', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, kind, honest, well groomed', '21-34', ARRAY['fine dining', 'travel', 'fashion', 'coffee dates']::TEXT[], ARRAY['private dates', 'premium experiences', 'long-term arrangement', 'respectful companionship']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 7495, 584, true, 'silver', true, '2026-06-25T02:29:59+00', '2026-06-25T02:29:59+00', '2026-03-31T23:24:59+00'),
('seed+sugar_mummy-086@genuinesugarmummies.com', 'Catherine Nabwire', '/seed/sugarmums/photo_97_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_97_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, clean communication. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: meaningful conversations, serious matches. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: discreet, well groomed, clean communication. Preferred age range: 21-34.', 40, 'Nyali, Mombasa', 'Kenya', 'Nyali, Mombasa', '+254731555791', '+254731555791', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'discreet, well groomed, clean communication, respectful', '21-34', ARRAY['coffee dates', 'weekend drives', 'spa days', 'beach walks']::TEXT[], ARRAY['meaningful conversations', 'serious matches', 'mentorship', 'verified members']::TEXT[], 'Elegant', 'silver', true, 'verified', true, false, false, 3529, 294, true, 'silver', true, '2026-06-25T02:22:59+00', '2026-06-25T02:22:59+00', '2026-03-30T22:24:59+00'),
('seed+sugar_mummy-087@genuinesugarmummies.com', 'Janet Mugisha', '/seed/sugarmums/photo_98_2026-06-25_14-21-42.jpg', ARRAY['/seed/sugarmums/photo_98_2026-06-25_14-21-42.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, clean communication, discreet. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: lifestyle support, discreet connection. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: generous, clean communication, discreet. Preferred age range: 21-34.', 41, 'Westlands, Nairobi', 'Kenya', 'Westlands, Nairobi', '+254760448354', '+254760448354', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'generous, clean communication, discreet, respectful', '21-34', ARRAY['dancing', 'travel', 'fashion', 'fitness']::TEXT[], ARRAY['lifestyle support', 'discreet connection', 'serious matches', 'verified members']::TEXT[], 'Average', 'silver', true, 'verified', true, false, false, 5160, 873, true, 'silver', true, '2026-06-25T02:15:59+00', '2026-06-25T02:15:59+00', '2026-03-29T21:24:59+00'),
('seed+sugar_mummy-088@genuinesugarmummies.com', 'Rosemary Hassan', '/seed/sugarmums/photo_9_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_9_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, emotionally mature, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, emotionally mature, well groomed. Preferred age range: 21-34.', 42, 'Entebbe', 'Uganda', 'Entebbe', '+256732517584', '+256732517584', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'serious about meeting, emotionally mature, well groomed, clean communication', '21-34', ARRAY['art galleries', 'fashion', 'beach walks', 'spa days']::TEXT[], ARRAY['serious matches', 'meaningful conversations', 'mentorship', 'verified members']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 2467, 338, true, 'silver', true, '2026-06-25T02:08:59+00', '2026-06-25T02:08:59+00', '2026-03-28T20:24:59+00')
ON CONFLICT (email) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    avatar_url = EXCLUDED.avatar_url,
    photos = EXCLUDED.photos,
    bio = EXCLUDED.bio,
    description = EXCLUDED.description,
    age = EXCLUDED.age,
    location = EXCLUDED.location,
    country = EXCLUDED.country,
    city = EXCLUDED.city,
    phone = EXCLUDED.phone,
    phone_number = EXCLUDED.phone_number,
    profile_label = EXCLUDED.profile_label,
    member_category = EXCLUDED.member_category,
    looking_for = EXCLUDED.looking_for,
    intent_summary = EXCLUDED.intent_summary,
    wants = EXCLUDED.wants,
    needed_qualities = EXCLUDED.needed_qualities,
    age_range_preference = EXCLUDED.age_range_preference,
    hobbies = EXCLUDED.hobbies,
    interests = EXCLUDED.interests,
    body_type = EXCLUDED.body_type,
    subscription_tier = EXCLUDED.subscription_tier,
    verified = EXCLUDED.verified,
    verification_status = EXCLUDED.verification_status,
    show_in_public = EXCLUDED.show_in_public,
    is_banned = EXCLUDED.is_banned,
    is_suspended = EXCLUDED.is_suspended,
    total_profile_views = GREATEST(public.users.total_profile_views, EXCLUDED.total_profile_views),
    followers_count = GREATEST(public.users.followers_count, EXCLUDED.followers_count),
    admin_approved = EXCLUDED.admin_approved,
    phone_reveal_plan = EXCLUDED.phone_reveal_plan,
    is_seed_profile = EXCLUDED.is_seed_profile,
    last_seen_at = EXCLUDED.last_seen_at,
    last_seen = EXCLUDED.last_seen;


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
