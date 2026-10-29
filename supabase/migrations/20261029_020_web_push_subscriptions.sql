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
