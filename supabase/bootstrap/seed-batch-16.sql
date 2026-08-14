-- Seed profiles, batch 16 of 16.
--
-- The original migration inserts all 181 in one 273 KB statement, which
-- the SQL Editor will not always accept. Split on top-level row boundaries
-- with quote and depth tracking, because the bios contain commas, brackets
-- and escaped quotes and a naive split produces SQL that does not parse.
--
-- ON CONFLICT is preserved on every batch, so re-running is safe.

INSERT INTO public.users (email, display_name, avatar_url, photos, bio, description, age, location, country, city, phone, phone_number, profile_label, member_category, looking_for, intent_summary, wants, needed_qualities, age_range_preference, hobbies, interests, body_type, subscription_tier, verified, verification_status, show_in_public, is_banned, is_suspended, total_profile_views, followers_count, admin_approved, phone_reveal_plan, is_seed_profile, last_seen_at, last_seen, created_at) VALUES

('seed+sugar_mummy-088@genuinesugarmummies.com', 'Rosemary Hassan', '/seed/sugarmums/photo_9_2026-06-24_14-00-45.jpg', ARRAY['/seed/sugarmums/photo_9_2026-06-24_14-00-45.jpg']::TEXT[], 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, emotionally mature, well groomed. Preferred age range: 21-34.', 'Genuine sugar mummy seeking a warm, discreet connection with an attentive younger gentleman. Interests: serious matches, meaningful conversations. Wants: A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious. Needed qualities: serious about meeting, emotionally mature, well groomed. Preferred age range: 21-34.', 42, 'Entebbe', 'Uganda', 'Entebbe', '+256732517584', '+256732517584', 'sugar_mummy', 'sugar_mummy', 'Sugar Guy / Toyboy', 'I am a sugar mummy looking for Sugar Guy / Toyboy.', 'A confident sugar guy or toyboy who is respectful, attentive, energetic, and serious.', 'serious about meeting, emotionally mature, well groomed, clean communication', '21-34', ARRAY['art galleries', 'fashion', 'beach walks', 'spa days']::TEXT[], ARRAY['serious matches', 'meaningful conversations', 'mentorship', 'verified members']::TEXT[], 'Fit', 'silver', true, 'verified', true, false, false, 2467, 338, true, 'silver', true, '2026-06-25T02:08:59+00', '2026-06-25T02:08:59+00', '2026-03-28T20:24:59+00')

ON CONFLICT (email) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    avatar_url = EXCLUDED.avatar_url,
    photos = EXCLUDED.photos,
    bio = EXCLUDED.bio,
    description = EXCLUDED.description,
    age = EXCLUDED.age,
    location = EXCLUDED.location,
    country = EXCLUDED.country,
    city = EXCLUDED.city,
    phone = EXCLUDED.phone,
    phone_number = EXCLUDED.phone_number,
    profile_label = EXCLUDED.profile_label,
    member_category = EXCLUDED.member_category,
    looking_for = EXCLUDED.looking_for,
    intent_summary = EXCLUDED.intent_summary,
    wants = EXCLUDED.wants,
    needed_qualities = EXCLUDED.needed_qualities,
    age_range_preference = EXCLUDED.age_range_preference,
    hobbies = EXCLUDED.hobbies,
    interests = EXCLUDED.interests,
    body_type = EXCLUDED.body_type,
    subscription_tier = EXCLUDED.subscription_tier,
    verified = EXCLUDED.verified,
    verification_status = EXCLUDED.verification_status,
    show_in_public = EXCLUDED.show_in_public,
    is_banned = EXCLUDED.is_banned,
    is_suspended = EXCLUDED.is_suspended,
    total_profile_views = GREATEST(public.users.total_profile_views, EXCLUDED.total_profile_views),
    followers_count = GREATEST(public.users.followers_count, EXCLUDED.followers_count),
    admin_approved = EXCLUDED.admin_approved,
    phone_reveal_plan = EXCLUDED.phone_reveal_plan,
    is_seed_profile = EXCLUDED.is_seed_profile,
    last_seen_at = EXCLUDED.last_seen_at,
    last_seen = EXCLUDED.last_seen;
