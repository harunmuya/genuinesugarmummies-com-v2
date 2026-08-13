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
