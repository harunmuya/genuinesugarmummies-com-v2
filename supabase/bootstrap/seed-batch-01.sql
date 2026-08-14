-- Seed profiles, batch 1 of 16.
--
-- The original migration inserts all 181 in one 273 KB statement, which
-- the SQL Editor will not always accept. Split on top-level row boundaries
-- with quote and depth tracking, because the bios contain commas, brackets
-- and escaped quotes and a naive split produces SQL that does not parse.
--
-- ON CONFLICT is preserved on every batch, so re-running is safe.

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
('seed+mistress-012@genuinesugarmummies.com', 'Linda Mugisha', '/seed/mistresses/photo_21_2026-06-24_14-00-45.jpg', ARRAY['/seed/mistresses/photo_21_2026-06-24_14-00-45.jpg']::TEXT[], 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, clean communication, serious about meeting. Preferred age range: 38-68.', 'Adult mistress with a polished, youthful style and a preference for respectful, established men. Interests: private dates, discreet connection. Wants: A generous sugar daddy for discreet dates, lifestyle support, and consistent communication. Needed qualities: honest, clean communication, serious about meeting. Preferred age range: 38-68.', 24, 'Nakuru', 'Kenya', 'Nakuru', '+254770676510', '+254770676510', 'mistress', 'mistress', 'Sugar Daddy', 'I am a mistress looking for Sugar Daddy.', 'A generous sugar daddy for discreet dates, lifestyle support, and consistent communication.', 'honest, clean communication, serious about meeting, consistent', '38-68', ARRAY['fine dining', 'live music', 'business events', 'travel']::TEXT[], ARRAY['private dates', 'discreet connection', 'serious matches', 'long-term arrangement']::TEXT[], 'Slim', 'silver', true, 'verified', true, false, false, 2251, 181, true, 'silver', true, '2026-06-25T11:00:59+00', '2026-06-25T11:00:59+00', '2026-06-13T00:24:59+00')

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
