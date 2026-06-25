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