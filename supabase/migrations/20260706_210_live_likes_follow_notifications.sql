-- Adds persisted live likes used by the live viewer room and featured live cards.

ALTER TABLE public.live_streams
    ADD COLUMN IF NOT EXISTS total_likes INTEGER DEFAULT 0;

UPDATE public.live_streams
SET total_likes = COALESCE(total_likes, 0);
