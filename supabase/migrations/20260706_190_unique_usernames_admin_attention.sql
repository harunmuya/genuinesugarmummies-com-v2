-- Adds durable usernames for every account. The application also derives a
-- temporary handle from id/display name until this migration is applied.

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS username TEXT;

WITH prepared AS (
    SELECT
        id,
        lower(
            regexp_replace(
                coalesce(nullif(username, ''), nullif(display_name, ''), split_part(email, '@', 1), 'member'),
                '[^a-zA-Z0-9_]+',
                '_',
                'g'
            )
        ) AS raw_username
    FROM public.users
),
cleaned AS (
    SELECT
        id,
        trim(both '_' from left(coalesce(nullif(raw_username, ''), 'member'), 24)) AS base_username
    FROM prepared
),
numbered AS (
    SELECT
        id,
        coalesce(nullif(base_username, ''), 'member') AS base_username,
        row_number() OVER (PARTITION BY coalesce(nullif(base_username, ''), 'member') ORDER BY id) AS duplicate_number
    FROM cleaned
)
UPDATE public.users u
SET username = CASE
    WHEN n.duplicate_number = 1 THEN left(n.base_username, 24)
    ELSE left(n.base_username, 17) || '_' || left(replace(u.id::text, '-', ''), 6)
END
FROM numbered n
WHERE u.id = n.id
  AND coalesce(u.username, '') = '';

CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique_idx
    ON public.users (lower(username))
    WHERE username IS NOT NULL AND username <> '';
