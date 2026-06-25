-- Run this in Supabase SQL Editor after the base users table exists.

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