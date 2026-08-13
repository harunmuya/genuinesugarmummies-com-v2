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
