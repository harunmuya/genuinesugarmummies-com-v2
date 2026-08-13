-- ============================================================================
-- GS App — Proper Package Tiers with Full Feature Gates
-- Safe to run on live DB: uses ON CONFLICT + ADD COLUMN IF NOT EXISTS
-- ============================================================================

-- Add new feature-gate columns to package_tiers
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_like_limit INTEGER DEFAULT 5;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_super_like_limit INTEGER DEFAULT 0;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_swipe_limit INTEGER DEFAULT 10;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS daily_profile_view_limit INTEGER DEFAULT 10;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_see_who_liked BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_see_who_viewed BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_send_voice_notes BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_send_images BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_go_live BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_send_gifts BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS can_use_nearby BOOLEAN DEFAULT false;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS max_gift_tier INTEGER DEFAULT 1;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS starting_credits INTEGER DEFAULT 0;
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS badge_label TEXT DEFAULT '';
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS badge_color TEXT DEFAULT '';
ALTER TABLE public.package_tiers ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';

-- ============================================================================
-- FREE TIER (no payment, default for all new users)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'free', 'Free', 0, 0, true,
    'Get started and explore GS App. Upgrade anytime to unlock premium features.',
    'FREE', '#9ca3af',
    false, 5, 0,
    5, 0, 10, 10,
    false, false, false,
    false, false,
    false, false, false, false, false,
    0, 0,
    '[
        "5 messages per day",
        "5 likes and 10 swipes per day",
        "10 profile views per day",
        "Browse all public members",
        "Basic profile creation",
        "Receive gifts and messages from others",
        "Upgrade anytime to unlock calls, voice notes, gifts, and more"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- BASIC TIER — KSH 650 (Starter paid plan)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'basic', 'Basic', 650, 1, true,
    'Unlock messaging, starter gifts, and one direct Admin Mary G connection of your choice.',
    'BASIC', '#3b82f6',
    false, 30, 10,
    10, 5, 30, 30,
    false, false, false,
    false, false,
    false, true, false, true, false,
    1, 50,
    '[
        "Lifetime Basic membership after admin approval",
        "30 messages per day",
        "10 likes and 5 super likes per day",
        "30 swipes and 30 profile views per day",
        "Send images in chat",
        "Send Tier 1 gifts (Rose, Heart, Butterfly, Coffee, and more)",
        "50 free GS credits on activation",
        "One direct connection of your choice facilitated by Admin Mary G on Telegram",
        "No random connection — you choose who to request"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- SILVER TIER — KSH 1,200 (Recommended plan)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'silver', 'Silver Recommended', 1200, 2, true,
    'The serious connection plan. Voice calls, video calls, voice notes, premium gifts, and nearby discovery.',
    'SILVER ⭐', '#a855f7',
    true, 0, 50,
    50, 100, 0, 0,
    true, false, true,
    true, true,
    true, true, true, true, true,
    3, 200,
    '[
        "⭐ RECOMMENDED — Best value for serious connections",
        "Lifetime Silver membership after admin approval",
        "Unlimited messaging after approval",
        "Phone number reveal for approved profiles",
        "50 likes and 100 super likes per day",
        "Unlimited swipes and profile views",
        "Voice calls and video calls with call history",
        "Send and receive voice notes in chat",
        "Send images, GIFs, and media in chat",
        "Go Live — broadcast and receive gifts from viewers",
        "Send gifts up to Tier 3 (Golden Trophy, Diamond, Sports Car, Castle, and more)",
        "200 free GS credits on activation",
        "See who liked and viewed your profile",
        "Nearby users — discover people close to you",
        "Priority profile visibility in search and discover",
        "Priority Admin Mary G support for serious local connections"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- GOLD TIER — KSH 3,550 (Premium International)
-- ============================================================================
INSERT INTO public.package_tiers (
    id, name, price_ksh, sort_order, is_active, description,
    badge_label, badge_color,
    phone_reveal, daily_message_limit, daily_gift_limit,
    daily_like_limit, daily_super_like_limit, daily_swipe_limit, daily_profile_view_limit,
    priority_visibility, international_access, voice_video_access,
    can_see_who_liked, can_see_who_viewed,
    can_send_voice_notes, can_send_images, can_go_live, can_send_gifts, can_use_nearby,
    max_gift_tier, starting_credits,
    features
) VALUES (
    'gold', 'Gold International', 3550, 3, true,
    'The ultimate VIP experience. Everything unlimited, international access, all premium gifts, and fastest support.',
    'GOLD 👑', '#f59e0b',
    true, 0, 0,
    0, 0, 0, 0,
    true, true, true,
    true, true,
    true, true, true, true, true,
    4, 500,
    '[
        "👑 VIP GOLD — The ultimate GS experience",
        "Lifetime Gold International access",
        "International and prominent profile access — connect worldwide",
        "Unlimited messaging, likes, super likes, swipes, and profile views",
        "Unlimited voice and video call access",
        "Send and receive voice notes, images, GIFs, and all media",
        "Go Live — broadcast, go viral, and receive gifts from global viewers",
        "Send ALL gift tiers including Tier 4 exclusives (Galaxy, Golden Dragon, Treasure, Grand Palace)",
        "500 free GS credits on activation",
        "See who liked and viewed your profile",
        "Nearby users — discover local and international connections",
        "Priority profile placement — appear first in search, discover, and recommendations",
        "Gold badge on your profile — stand out from other members",
        "Unlimited daily gift sending — no daily caps",
        "Fastest Admin Mary G support and guided connection assistance",
        "Priority phone number reveal for all approved profiles"
    ]'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, price_ksh = EXCLUDED.price_ksh, sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description, badge_label = EXCLUDED.badge_label, badge_color = EXCLUDED.badge_color,
    phone_reveal = EXCLUDED.phone_reveal, daily_message_limit = EXCLUDED.daily_message_limit,
    daily_gift_limit = EXCLUDED.daily_gift_limit, daily_like_limit = EXCLUDED.daily_like_limit,
    daily_super_like_limit = EXCLUDED.daily_super_like_limit, daily_swipe_limit = EXCLUDED.daily_swipe_limit,
    daily_profile_view_limit = EXCLUDED.daily_profile_view_limit,
    priority_visibility = EXCLUDED.priority_visibility, international_access = EXCLUDED.international_access,
    voice_video_access = EXCLUDED.voice_video_access,
    can_see_who_liked = EXCLUDED.can_see_who_liked, can_see_who_viewed = EXCLUDED.can_see_who_viewed,
    can_send_voice_notes = EXCLUDED.can_send_voice_notes, can_send_images = EXCLUDED.can_send_images,
    can_go_live = EXCLUDED.can_go_live, can_send_gifts = EXCLUDED.can_send_gifts,
    can_use_nearby = EXCLUDED.can_use_nearby, max_gift_tier = EXCLUDED.max_gift_tier,
    starting_credits = EXCLUDED.starting_credits, features = EXCLUDED.features,
    updated_at = now();

-- ============================================================================
-- Also update the `packages` table if it exists (some routes read from this)
-- ============================================================================
INSERT INTO public.packages (id, name, price_ksh, features, is_active) VALUES
(
    'free', 'Free', 0,
    '[
        "5 messages per day",
        "5 likes and 10 swipes per day",
        "10 profile views per day",
        "Browse all public members",
        "Receive gifts and messages"
    ]'::jsonb,
    true
),
(
    'basic', 'Basic', 650,
    '[
        "30 messages per day",
        "10 likes, 5 super likes, 30 swipes per day",
        "Send images in chat",
        "Send Tier 1 gifts (Rose, Heart, Coffee, etc.)",
        "50 free GS credits",
        "One direct Admin Mary G connection of your choice"
    ]'::jsonb,
    true
),
(
    'silver', 'Silver Recommended', 1200,
    '[
        "⭐ Recommended — best value",
        "Unlimited messaging",
        "Phone number reveal",
        "Voice and video calls",
        "Voice notes and media sharing",
        "Go Live streaming",
        "Send gifts up to Tier 3",
        "200 free GS credits",
        "See who liked and viewed you",
        "Nearby user discovery",
        "Priority visibility and support"
    ]'::jsonb,
    true
),
(
    'gold', 'Gold International', 3550,
    '[
        "👑 VIP Gold — everything unlimited",
        "International access worldwide",
        "Unlimited messages, likes, swipes",
        "Unlimited voice and video calls",
        "All media types in chat",
        "Go Live with global reach",
        "Send ALL gift tiers (including exclusives)",
        "500 free GS credits",
        "Gold badge on profile",
        "Priority placement everywhere",
        "Fastest Admin Mary G support"
    ]'::jsonb,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    price_ksh = EXCLUDED.price_ksh,
    features = EXCLUDED.features,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- ============================================================================
-- Set all existing users without a tier to 'free'
-- ============================================================================
UPDATE public.users
SET subscription_tier = 'free'
WHERE COALESCE(subscription_tier, '') = ''
   OR subscription_tier IS NULL;