-- Make the public profile projection honor the querying role's RLS policies.

BEGIN;

DROP POLICY IF EXISTS "Public can read users" ON public.users;
DROP POLICY IF EXISTS "Public can read visible users" ON public.users;
DROP POLICY IF EXISTS "Public can upsert users" ON public.users;
DROP POLICY IF EXISTS "Users can read public profiles" ON public.users;
DROP POLICY IF EXISTS "Users public read safe" ON public.users;

CREATE POLICY "Users can read active public profiles or their own row"
    ON public.users
    FOR SELECT
    TO anon, authenticated
    USING (
        (
            show_in_public = true
            AND COALESCE(is_banned, false) = false
            AND COALESCE(is_suspended, false) = false
        )
        OR auth.uid() = auth_user_id
    );

REVOKE SELECT (auth_user_id) ON public.users FROM anon, authenticated;
GRANT SELECT (
    id,
    display_name,
    avatar_url,
    photos,
    bio,
    age,
    location,
    country,
    city,
    profile_label,
    member_category,
    looking_for,
    intent_summary,
    wants,
    needed_qualities,
    age_range_preference,
    hobbies,
    interests,
    subscription_tier,
    verified,
    show_in_public,
    total_profile_views,
    followers_count,
    gifts_received_count,
    created_at,
    last_seen_at,
    is_banned,
    is_suspended
) ON public.users TO anon, authenticated;

CREATE OR REPLACE VIEW public.public_profiles
    WITH (security_invoker = true)
AS
SELECT
    id,
    display_name,
    avatar_url,
    photos,
    bio,
    age,
    location,
    country,
    city,
    profile_label,
    member_category,
    looking_for,
    intent_summary,
    wants,
    needed_qualities,
    age_range_preference,
    hobbies,
    interests,
    subscription_tier,
    verified,
    show_in_public,
    total_profile_views,
    followers_count,
    gifts_received_count,
    created_at,
    last_seen_at
FROM public.users
WHERE show_in_public = true
  AND COALESCE(is_banned, false) = false
  AND COALESCE(is_suspended, false) = false;

GRANT SELECT ON public.public_profiles TO anon, authenticated;

COMMIT;
