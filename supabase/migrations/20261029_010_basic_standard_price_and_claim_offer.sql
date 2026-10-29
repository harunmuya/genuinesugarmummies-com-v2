-- Standard Basic access is KSh750. The separate app-only local introduction
-- offer is KSh650 and is recorded as an admin-reviewed offer, not a package.
UPDATE public.package_tiers
SET price_ksh = 750,
    description = 'Starter app access. Local introduction requests are a separate service with their own published fee and availability review.',
    features = '[
        "30 messages per day",
        "10 likes and 5 Super Likes per day",
        "30 swipes and 30 profile views per day",
        "Image sharing in chat",
        "Tier 1 gifts, subject to available credits",
        "No phone reveal, voice/video calls, or live streaming"
    ]'::jsonb,
    updated_at = now()
WHERE id = 'basic';
