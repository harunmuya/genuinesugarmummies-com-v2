const DEFAULT_TIERS = {
    free: {
        id: 'free',
        name: 'Free',
        price_ksh: 0,
        phone_reveal: false,
        daily_message_limit: 5,
        daily_gift_limit: 0,
        daily_like_limit: 5,
        daily_super_like_limit: 0,
        daily_swipe_limit: 10,
        daily_profile_view_limit: 10,
        priority_visibility: false,
        international_access: false,
        voice_video_access: false,
        can_see_who_liked: false,
        can_see_who_viewed: false,
        can_send_voice_notes: false,
        can_send_images: false,
        can_go_live: false,
        can_send_gifts: false,
        can_use_nearby: false,
        max_gift_tier: 0,
        starting_credits: 0,
        features: [],
    },
    basic: {
        id: 'basic',
        name: 'Basic',
        price_ksh: 650,
        phone_reveal: false,
        daily_message_limit: 30,
        daily_gift_limit: 10,
        daily_like_limit: 10,
        daily_super_like_limit: 5,
        daily_swipe_limit: 30,
        daily_profile_view_limit: 30,
        priority_visibility: false,
        international_access: false,
        voice_video_access: false,
        can_see_who_liked: false,
        can_see_who_viewed: false,
        can_send_voice_notes: false,
        can_send_images: true,
        can_go_live: false,
        can_send_gifts: true,
        can_use_nearby: false,
        max_gift_tier: 1,
        starting_credits: 50,
        features: [],
    },
    silver: {
        id: 'silver',
        name: 'Silver Recommended',
        price_ksh: 1200,
        phone_reveal: true,
        daily_message_limit: 0,
        daily_gift_limit: 50,
        daily_like_limit: 50,
        daily_super_like_limit: 100,
        daily_swipe_limit: 0,
        daily_profile_view_limit: 0,
        priority_visibility: true,
        international_access: false,
        voice_video_access: true,
        can_see_who_liked: true,
        can_see_who_viewed: true,
        can_send_voice_notes: true,
        can_send_images: true,
        can_go_live: true,
        can_send_gifts: true,
        can_use_nearby: true,
        max_gift_tier: 3,
        starting_credits: 200,
        features: [],
    },
    gold: {
        id: 'gold',
        name: 'Gold International',
        price_ksh: 3550,
        phone_reveal: true,
        daily_message_limit: 0,
        daily_gift_limit: 0,
        daily_like_limit: 0,
        daily_super_like_limit: 0,
        daily_swipe_limit: 0,
        daily_profile_view_limit: 0,
        priority_visibility: true,
        international_access: true,
        voice_video_access: true,
        can_see_who_liked: true,
        can_see_who_viewed: true,
        can_send_voice_notes: true,
        can_send_images: true,
        can_go_live: true,
        can_send_gifts: true,
        can_use_nearby: true,
        max_gift_tier: 4,
        starting_credits: 500,
        features: [],
    },
};

export function normalizeTierId(value) {
    const tier = String(value || 'free').toLowerCase();
    if (tier === 'diamond') return 'gold';
    return DEFAULT_TIERS[tier] ? tier : 'free';
}

/**
 * The tier a member is actually entitled to right now.
 *
 * Everything else asks this: getUserPackageAccess reads it, canUseFeature acts
 * on what it returns, and every route gates on that. So an omission here is an
 * omission everywhere.
 *
 * It considered admin_approved and package_locked, and never the expiry date.
 * The admin screen writes package_expires_at when granting a package, and
 * nothing in the app had ever read it, so an expired Gold stayed Gold
 * indefinitely: calls, going live, gifts, voice notes, phone reveal, all of it,
 * forever, from a package that lapsed months ago.
 *
 * A tier past its expiry is free. That is the whole fix, and it belongs here
 * rather than in each route, because a second gate beside this one is how the
 * two drift apart.
 */
export function activeTierId(user) {
    const tier = normalizeTierId(user?.subscription_tier || user?.subscriptionTier);
    if (tier === 'free') return 'free';
    if (!user?.admin_approved || user?.package_locked) return 'free';

    /*
      Both spellings, because this is called with rows straight from the
      database and with the camelCase objects normalizeMember produces. Reading
      only one silently grants the paid tier wherever the other is passed, which
      is the failure this is meant to prevent.
    */
    const expiresAt = user?.package_expires_at ?? user?.packageExpiresAt ?? null;
    if (expiresAt) {
        const expiry = new Date(expiresAt).getTime();
        // An unparseable date is treated as no expiry rather than as expired,
        // so bad data cannot lock a paying member out of what they bought.
        if (Number.isFinite(expiry) && expiry < Date.now()) return 'free';
    }

    return tier;
}

function normalizePackageRow(row, tierId) {
    const fallback = DEFAULT_TIERS[tierId] || DEFAULT_TIERS.free;
    return {
        ...fallback,
        ...(row || {}),
        id: tierId,
        features: Array.isArray(row?.features) ? row.features : fallback.features,
        max_gift_tier: Number(row?.max_gift_tier ?? fallback.max_gift_tier ?? 0),
    };
}

export async function getPackageTier(supabase, tierId) {
    const normalized = normalizeTierId(tierId);
    if (!supabase) return normalizePackageRow(null, normalized);
    try {
        const { data, error } = await supabase
            .from('package_tiers')
            .select('*')
            .eq('id', normalized)
            .maybeSingle();
        if (error || !data) return normalizePackageRow(null, normalized);
        return normalizePackageRow(data, normalized);
    } catch {
        return normalizePackageRow(null, normalized);
    }
}

export async function getUserPackageAccess(supabase, user) {
    const tierId = activeTierId(user);
    const tier = await getPackageTier(supabase, tierId);
    return { tierId, tier, approved: tierId !== 'free' || normalizeTierId(user?.subscription_tier) === 'free' };
}

export function dailyLimitForFeature(tier, feature) {
    const map = {
        messages: 'daily_message_limit',
        gifts: 'daily_gift_limit',
        likes: 'daily_like_limit',
        superlikes: 'daily_super_like_limit',
        swipes: 'daily_swipe_limit',
        views: 'daily_profile_view_limit',
    };
    const column = map[feature];
    if (!column) return null;
    const value = tier?.[column];
    if (value === null || value === undefined) return null;
    const number = Number(value);
    if (!Number.isFinite(number)) return null;
    return number <= 0 ? null : number;
}

export function canUseFeature(tier, feature) {
    if (!tier) return false;
    if (feature === 'messages') return dailyLimitForFeature(tier, 'messages') !== 0;
    if (feature === 'phone') return Boolean(tier.phone_reveal);
    if (feature === 'calls') return Boolean(tier.voice_video_access);
    if (feature === 'voiceNotes') return Boolean(tier.can_send_voice_notes);
    if (feature === 'images') return Boolean(tier.can_send_images);
    if (feature === 'live') return Boolean(tier.can_go_live);
    if (feature === 'gifts') return Boolean(tier.can_send_gifts);
    if (feature === 'nearby') return Boolean(tier.can_use_nearby);
    return false;
}

export function defaultPackageTiers() {
    return [DEFAULT_TIERS.basic, DEFAULT_TIERS.silver, DEFAULT_TIERS.gold];
}
