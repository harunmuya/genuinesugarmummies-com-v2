ALTER TABLE public.call_sessions
ADD COLUMN IF NOT EXISTS duration_seconds INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_call_sessions_users_created
ON public.call_sessions(caller_id, receiver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_call_sessions_ended
ON public.call_sessions(ended_at DESC)
WHERE ended_at IS NOT NULL;

UPDATE public.users
SET show_in_public = true,
    last_seen_at = COALESCE(last_seen_at, now()),
    last_seen = COALESCE(last_seen, now())
WHERE COALESCE(show_in_public, false) = false
  AND COALESCE(is_banned, false) = false
  AND COALESCE(is_suspended, false) = false
  AND COALESCE(avatar_url, '') <> ''
  AND COALESCE(bio, '') <> ''
  AND age IS NOT NULL
  AND COALESCE(location, '') <> ''
  AND (COALESCE(phone_number, '') <> '' OR COALESCE(phone, '') <> '');

UPDATE public.users
SET display_name = INITCAP(REPLACE(REPLACE(SPLIT_PART(email, '@', 1), '.', ' '), '_', ' '))
WHERE display_name ILIKE '%@%'
  AND COALESCE(email, '') <> '';

UPDATE public.package_tiers
SET price_ksh = 3550,
    features = '[
      "Lifetime Gold International access",
      "International and prominent profile access",
      "Unlimited messaging, profile views, and phone contacts",
      "Unlimited voice and video call access where device permissions allow",
      "Premium gifts, wallet activity, and priority placement",
      "Fastest Admin Mary G support and guided connection assistance"
    ]'::jsonb
WHERE id = 'gold';

UPDATE public.package_tiers
SET features = '[
  "Lifetime Silver membership after admin approval",
  "Phone number reveal for approved profiles",
  "Unlimited messaging after approval",
  "Voice calls and video calls with call history",
  "More likes, swipes, saves, premium gifts, and wallet features",
  "Priority Admin Mary G support for serious local connections"
]'::jsonb
WHERE id = 'silver';

UPDATE public.package_tiers
SET features = '[
  "Lifetime Basic membership after admin approval",
  "Starter messaging limit for serious introductions",
  "10 likes and 10 swipes per day",
  "Send premium GS gifts with approved credits",
  "One direct connection of your choice facilitated by Admin Mary G on Telegram",
  "No random connection - you choose who to request"
]'::jsonb
WHERE id = 'basic';
