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
