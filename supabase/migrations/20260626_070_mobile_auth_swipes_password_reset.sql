-- Genuine Sugar Mummies mobile-auth and swipe interaction support
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
