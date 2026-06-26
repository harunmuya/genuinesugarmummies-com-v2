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