import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { canUseFeature, dailyLimitForFeature, getUserPackageAccess } from '@/lib/packageAccess';

function jsonError(message, status = 500) {
    return NextResponse.json({ error: message }, { status });
}

const DEFAULT_GIFT_CATALOG = [
    { name: 'Rose', category: 'Romance', icon_url: '/gifts/rose.webp', credit_cost: 1, sort_order: 10 },
    { name: 'White Rose', category: 'Romance', icon_url: '/gifts/white-rose.webp', credit_cost: 1, sort_order: 20 },
    { name: 'Tulip', category: 'Romance', icon_url: '/gifts/tulip.webp', credit_cost: 1, sort_order: 30 },
    { name: 'Community Heart', category: 'Romance', icon_url: '/gifts/heart.webp', credit_cost: 1, sort_order: 40 },
    { name: 'Heart Puff', category: 'Romance', icon_url: '/gifts/heart-puff.webp', credit_cost: 1, sort_order: 50 },
    { name: 'Love Letter', category: 'Romance', icon_url: '/gifts/love-letter.webp', credit_cost: 1, sort_order: 60 },
    { name: 'Blow a Kiss', category: 'Romance', icon_url: '/gifts/blow-kiss.webp', credit_cost: 1, sort_order: 70 },
    { name: 'Coffee', category: 'Date Treats', icon_url: '/gifts/coffee.webp', credit_cost: 1, sort_order: 80 },
    { name: 'Chocolate', category: 'Date Treats', icon_url: '/gifts/chocolate.webp', credit_cost: 5, sort_order: 90 },
    { name: 'Turkish Coffee', category: 'Date Treats', icon_url: '/gifts/turkish-coffee.webp', credit_cost: 5, sort_order: 100 },
    { name: 'Friendship Necklace', category: 'Luxury', icon_url: '/gifts/friendship-necklace.webp', credit_cost: 10, sort_order: 110 },
    { name: 'Flower Garland', category: 'Luxury', icon_url: '/gifts/flower-garland.webp', credit_cost: 15, sort_order: 120 },
    { name: 'Perfume', category: 'Luxury', icon_url: '/gifts/perfume.webp', credit_cost: 20, sort_order: 130 },
    { name: 'Bouquet', category: 'Luxury', icon_url: '/gifts/bouquet.webp', credit_cost: 20, sort_order: 140 },
    { name: 'Doughnut', category: 'Date Treats', icon_url: '/gifts/doughnut.webp', credit_cost: 30, sort_order: 150 },
    { name: 'Bouquet Flower', category: 'Luxury', icon_url: '/gifts/bouquet-flower.webp', credit_cost: 30, sort_order: 160 },
    { name: 'Love Letter Premium', category: 'Premium', icon_url: '/gifts/love-letter-premium.webp', credit_cost: 88, sort_order: 170 },
    { name: 'Little Crown', category: 'Premium', icon_url: '/gifts/little-crown.webp', credit_cost: 99, sort_order: 180 },
    { name: 'Love Painting', category: 'Premium', icon_url: '/gifts/love-painting.webp', credit_cost: 99, sort_order: 190 },
    { name: 'Confetti', category: 'Premium', icon_url: '/gifts/confetti.webp', credit_cost: 100, sort_order: 200 },
    { name: 'Hand Heart', category: 'Premium', icon_url: '/gifts/hand-heart.webp', credit_cost: 100, sort_order: 210 },
    { name: 'Balloon Gift Box', category: 'Premium', icon_url: '/gifts/balloon-gift-box.webp', credit_cost: 100, sort_order: 220 },
    { name: 'Kiss', category: 'Premium', icon_url: '/gifts/kiss.webp', credit_cost: 150, sort_order: 230 },
    { name: 'Sunglasses', category: 'Premium', icon_url: '/gifts/sunglasses.webp', credit_cost: 199, sort_order: 240 },
    { name: 'The Crown', category: 'Premium', icon_url: '/gifts/crown.webp', credit_cost: 199, sort_order: 250 },
    { name: 'Gold Necklace', category: 'Luxury', icon_url: '/gifts/gold-necklace.webp', credit_cost: 200, sort_order: 260 },
    { name: 'Diamond Heart Necklace', category: 'Luxury', icon_url: '/gifts/diamond-heart-necklace.webp', credit_cost: 200, sort_order: 270 },
    { name: 'Golden Crown', category: 'Premium', icon_url: '/gifts/golden-crown.webp', credit_cost: 299, sort_order: 280 },
    { name: 'Diamond Ring of Love', category: 'Luxury', icon_url: '/gifts/diamond-ring.webp', credit_cost: 300, sort_order: 290 },
    { name: 'Money Gun', category: 'Luxury', icon_url: '/gifts/money-gun.webp', credit_cost: 500, sort_order: 300 },
    { name: 'Go Galaxy', category: 'Elite', icon_url: '/gifts/go-galaxy.webp', credit_cost: 500, sort_order: 310 },
    { name: 'Travel with You', category: 'Elite', icon_url: '/gifts/travel-with-you.webp', credit_cost: 999, sort_order: 320 },
    { name: 'Galaxy', category: 'Elite', icon_url: '/gifts/galaxy.webp', credit_cost: 1000, sort_order: 330 },
    { name: 'Silver Sports Car', category: 'Elite', icon_url: '/gifts/silver-sports-car.webp', credit_cost: 1000, sort_order: 340 },
    { name: 'Rose Classic', category: 'Romance', icon_url: '/gifts/rose.webp', credit_cost: 5, sort_order: 350 },
    { name: 'Luxury Bouquet', category: 'Romance', icon_url: '/gifts/bouquet.webp', credit_cost: 12, sort_order: 360 },
    { name: 'Sweet Heart', category: 'Romance', icon_url: '/gifts/heart.webp', credit_cost: 8, sort_order: 370 },
];

const PREMIUM_GIFT_CATALOG = [
    { name: 'Rose', category: 'Flowers', icon_url: '/gifts/rose_gift.png', credit_cost: 1, tier: 1, sort_order: 1, emoji: 'Rose' },
    { name: 'Sweet Heart', category: 'Hearts', icon_url: '/gifts/heart_gift.png', credit_cost: 1, tier: 1, sort_order: 2, emoji: 'Heart' },
    { name: 'Lucky Star', category: 'Lucky', icon_url: '/gifts/star_gift.png', credit_cost: 1, tier: 1, sort_order: 3, emoji: 'Star' },
    { name: 'Butterfly', category: 'Nature', icon_url: '/gifts/flower-garland.webp', credit_cost: 1, tier: 1, sort_order: 4, emoji: 'Butterfly' },
    { name: 'Cherry Blossom', category: 'Flowers', icon_url: '/gifts/bouquet-flower.webp', credit_cost: 1, tier: 1, sort_order: 5, emoji: 'Blossom' },
    { name: 'Lucky Clover', category: 'Lucky', icon_url: '/gifts/hand-heart.webp', credit_cost: 1, tier: 1, sort_order: 6, emoji: 'Clover' },
    { name: 'Sparkle', category: 'Effects', icon_url: '/gifts/star_gift.png', credit_cost: 1, tier: 1, sort_order: 7, emoji: 'Sparkle' },
    { name: 'Music Note', category: 'Entertainment', icon_url: '/gifts/go-galaxy.webp', credit_cost: 1, tier: 1, sort_order: 8, emoji: 'Music' },
    { name: 'Flame', category: 'Effects', icon_url: '/gifts/fireworks_gift.png', credit_cost: 1, tier: 1, sort_order: 9, emoji: 'Flame' },
    { name: 'Sunshine', category: 'Nature', icon_url: '/gifts/star_gift.png', credit_cost: 1, tier: 1, sort_order: 10, emoji: 'Sun' },
    { name: 'Rainbow', category: 'Nature', icon_url: '/gifts/confetti.webp', credit_cost: 1, tier: 1, sort_order: 11, emoji: 'Rainbow' },
    { name: 'Crystal', category: 'Luxury', icon_url: '/gifts/diamond_gift.png', credit_cost: 1, tier: 1, sort_order: 12, emoji: 'Crystal' },
    { name: 'Pink Ribbon', category: 'Fashion', icon_url: '/gifts/love-letter-premium.webp', credit_cost: 1, tier: 1, sort_order: 13, emoji: 'Ribbon' },
    { name: 'Sweet Candy', category: 'Food', icon_url: '/gifts/chocolate.webp', credit_cost: 1, tier: 1, sort_order: 14, emoji: 'Candy' },
    { name: 'Ice Cream', category: 'Food', icon_url: '/gifts/doughnut.webp', credit_cost: 5, tier: 1, sort_order: 15, emoji: 'Ice Cream' },
    { name: 'Cupcake', category: 'Food', icon_url: '/gifts/doughnut.webp', credit_cost: 5, tier: 1, sort_order: 16, emoji: 'Cupcake' },
    { name: 'Bullseye', category: 'Games', icon_url: '/gifts/trophy_gift.png', credit_cost: 5, tier: 1, sort_order: 17, emoji: 'Target' },
    { name: 'Lucky Dice', category: 'Games', icon_url: '/gifts/star_gift.png', credit_cost: 5, tier: 1, sort_order: 18, emoji: 'Dice' },
    { name: 'Shooting Star', category: 'Effects', icon_url: '/gifts/star_gift.png', credit_cost: 5, tier: 1, sort_order: 19, emoji: 'Shooting Star' },
    { name: 'Lightning Bolt', category: 'Effects', icon_url: '/gifts/rocket_gift.png', credit_cost: 5, tier: 1, sort_order: 20, emoji: 'Lightning' },
    { name: 'Hibiscus', category: 'Flowers', icon_url: '/gifts/bouquet-flower.webp', credit_cost: 5, tier: 1, sort_order: 21, emoji: 'Hibiscus' },
    { name: 'Coffee', category: 'Food', icon_url: '/gifts/coffee.webp', credit_cost: 5, tier: 1, sort_order: 22, emoji: 'Coffee' },
    { name: 'Royal Crown', category: 'Premium', icon_url: '/gifts/crown_gift.png', credit_cost: 10, tier: 2, sort_order: 23, emoji: 'Crown' },
    { name: 'Perfume', category: 'Fashion', icon_url: '/gifts/perfume_gift.png', credit_cost: 15, tier: 2, sort_order: 24, emoji: 'Perfume' },
    { name: 'Drama Mask', category: 'Entertainment', icon_url: '/gifts/love-painting.webp', credit_cost: 15, tier: 2, sort_order: 25, emoji: 'Drama' },
    { name: 'Flower Bouquet', category: 'Flowers', icon_url: '/gifts/bouquet_gift.png', credit_cost: 20, tier: 2, sort_order: 26, emoji: 'Bouquet' },
    { name: 'Teddy Bear', category: 'Cute', icon_url: '/gifts/teddy_gift.png', credit_cost: 25, tier: 2, sort_order: 27, emoji: 'Teddy' },
    { name: 'Rock Guitar', category: 'Entertainment', icon_url: '/gifts/go-galaxy.webp', credit_cost: 30, tier: 2, sort_order: 28, emoji: 'Guitar' },
    { name: 'Microphone', category: 'Entertainment', icon_url: '/gifts/go-galaxy.webp', credit_cost: 30, tier: 2, sort_order: 29, emoji: 'Mic' },
    { name: 'Unicorn', category: 'Fantasy', icon_url: '/gifts/unicorn_gift.png', credit_cost: 50, tier: 2, sort_order: 30, emoji: 'Unicorn' },
    { name: 'Diamond Ring', category: 'Luxury', icon_url: '/gifts/diamond_gift.png', credit_cost: 50, tier: 2, sort_order: 31, emoji: 'Ring' },
    { name: 'Carousel', category: 'Entertainment', icon_url: '/gifts/balloon-gift-box.webp', credit_cost: 75, tier: 2, sort_order: 32, emoji: 'Carousel' },
    { name: 'Ferris Wheel', category: 'Entertainment', icon_url: '/gifts/fireworks_gift.png', credit_cost: 99, tier: 2, sort_order: 33, emoji: 'Wheel' },
    { name: 'Designer Bag', category: 'Fashion', icon_url: '/gifts/money-gun.webp', credit_cost: 99, tier: 2, sort_order: 34, emoji: 'Bag' },
    { name: 'Champagne', category: 'Luxury', icon_url: '/gifts/confetti.webp', credit_cost: 99, tier: 2, sort_order: 35, emoji: 'Champagne' },
    { name: 'Golden Trophy', category: 'Premium', icon_url: '/gifts/trophy_gift.png', credit_cost: 100, tier: 3, sort_order: 36, emoji: 'Trophy' },
    { name: 'Diamond', category: 'Luxury', icon_url: '/gifts/diamond_gift.png', credit_cost: 200, tier: 3, sort_order: 37, emoji: 'Diamond' },
    { name: 'Top Hat', category: 'Fashion', icon_url: '/gifts/crown_gift.png', credit_cost: 300, tier: 3, sort_order: 38, emoji: 'Hat' },
    { name: 'Sports Car', category: 'Luxury', icon_url: '/gifts/sports_car_gift.png', credit_cost: 300, tier: 3, sort_order: 39, emoji: 'Car' },
    { name: 'Peacock', category: 'Nature', icon_url: '/gifts/unicorn_gift.png', credit_cost: 400, tier: 3, sort_order: 40, emoji: 'Peacock' },
    { name: 'Castle', category: 'Premium', icon_url: '/gifts/castle_gift.png', credit_cost: 500, tier: 3, sort_order: 41, emoji: 'Castle' },
    { name: 'Luxury Yacht', category: 'Luxury', icon_url: '/gifts/yacht_gift.png', credit_cost: 699, tier: 3, sort_order: 42, emoji: 'Yacht' },
    { name: 'Dragon', category: 'Fantasy', icon_url: '/gifts/dragon_gift.png', credit_cost: 799, tier: 3, sort_order: 43, emoji: 'Dragon' },
    { name: 'Fireworks', category: 'Effects', icon_url: '/gifts/fireworks_gift.png', credit_cost: 999, tier: 3, sort_order: 44, emoji: 'Fireworks' },
    { name: 'Space Rocket', category: 'Premium', icon_url: '/gifts/rocket_gift.png', credit_cost: 1000, tier: 4, sort_order: 45, emoji: 'Rocket' },
    { name: 'Galaxy', category: 'Premium', icon_url: '/gifts/galaxy_gift.png', credit_cost: 2000, tier: 4, sort_order: 46, emoji: 'Galaxy' },
    { name: 'Meteor Shower', category: 'Premium', icon_url: '/gifts/fireworks_gift.png', credit_cost: 3000, tier: 4, sort_order: 47, emoji: 'Meteor' },
    { name: 'Planet', category: 'Premium', icon_url: '/gifts/galaxy_gift.png', credit_cost: 5000, tier: 4, sort_order: 48, emoji: 'Planet' },
    { name: 'Crystal Ball', category: 'Fantasy', icon_url: '/gifts/diamond_gift.png', credit_cost: 10000, tier: 4, sort_order: 49, emoji: 'Crystal Ball' },
    { name: 'Queens Crown', category: 'Premium', icon_url: '/gifts/crown_gift.png', credit_cost: 15000, tier: 4, sort_order: 50, emoji: 'Queen Crown' },
    { name: 'Grand Palace', category: 'Premium', icon_url: '/gifts/castle_gift.png', credit_cost: 20000, tier: 4, sort_order: 51, emoji: 'Palace' },
    { name: 'Treasure', category: 'Premium', icon_url: '/gifts/money-gun.webp', credit_cost: 34999, tier: 4, sort_order: 52, emoji: 'Treasure' },
    { name: 'Golden Dragon', category: 'Premium', icon_url: '/gifts/dragon_gift.png', credit_cost: 44999, tier: 4, sort_order: 53, emoji: 'Golden Dragon' },
];

async function ensureDefaultGiftCatalog(supabase) {
    const existing = await supabase.from('gift_catalog').select('id, name, icon_url, gif_url, credit_cost, sort_order');
    if (existing.error) return;
    const rows = existing.data || [];
    const byName = new Map(rows.map((gift) => [String(gift.name || '').trim().toLowerCase(), gift]));
    const names = new Set(byName.keys());
    const catalogByName = new Map();
    [...DEFAULT_GIFT_CATALOG, ...PREMIUM_GIFT_CATALOG].forEach((gift) => catalogByName.set(gift.name.toLowerCase(), gift));
    const seedCatalog = Array.from(catalogByName.values());
    const missing = seedCatalog
        .filter((gift) => !names.has(gift.name.toLowerCase()))
        .map((gift) => ({ ...gift, gif_url: '', money_cost_ksh: 0, is_active: true }));
    if (missing.length) await supabase.from('gift_catalog').insert(missing);

    const updates = seedCatalog
        .map((gift) => ({ gift, current: byName.get(gift.name.toLowerCase()) }))
        .filter(({ gift, current }) => {
            if (!current?.id) return false;
            const currentIcon = String(current.icon_url || '');
            return !currentIcon || currentIcon.startsWith('gs-gift:') || currentIcon !== gift.icon_url || current.credit_cost !== gift.credit_cost;
        });
    await Promise.all(updates.map(({ gift, current }) => supabase
        .from('gift_catalog')
        .update({ icon_url: gift.icon_url, gif_url: '', category: gift.category, credit_cost: gift.credit_cost, tier: gift.tier || 1, sort_order: gift.sort_order, is_active: true, updated_at: new Date().toISOString() })
        .eq('id', current.id)));
}

async function ensureWallets(supabase, userId) {
    await supabase.from('credit_wallet').upsert({ user_id: userId }, { onConflict: 'user_id' });
    await supabase.from('money_wallet').upsert({ user_id: userId }, { onConflict: 'user_id' });
    await supabase.from('gift_wallet').upsert({ user_id: userId }, { onConflict: 'user_id' });
}

function pairIds(a, b) {
    return [a, b].sort();
}

async function getUser(supabase, userId) {
    if (!userId) return null;
    const { data } = await supabase
        .from('users')
        .select('id, display_name, email, subscription_tier, admin_approved, package_locked')
        .eq('id', userId)
        .maybeSingle();
    return data || null;
}

function canUseGifts(user) {
    const tier = String(user?.subscription_tier || 'free').toLowerCase();
    return Boolean(user?.admin_approved && !user?.package_locked && ['basic', 'silver', 'gold', 'diamond'].includes(tier));
}

async function enforceGiftLimit(supabase, userId, tier) {
    const limit = dailyLimitForFeature(tier, 'gifts');
    if (limit === null || limit === undefined) return { ok: true, limit: null, remaining: null };
    if (limit <= 0) return { ok: false, limit, remaining: 0, message: 'Gift sending requires a paid package with gift access.', redirectTo: '/packages' };
    const usageDate = new Date().toISOString().slice(0, 10);
    const result = await supabase
        .from('user_daily_usage')
        .select('id, count')
        .eq('user_id', userId)
        .eq('usage_date', usageDate)
        .eq('kind', 'gifts')
        .maybeSingle();
    if (result.error && result.error.code !== 'PGRST116') return { ok: true, limit, remaining: Math.max(0, limit - 1), skipped: true };
    const current = result.data?.count || 0;
    if (current >= limit) return { ok: false, limit, used: current, remaining: 0, message: 'Your daily gift limit is exhausted. Upgrade your package for more gift access.', redirectTo: '/packages' };
    if (result.data?.id) {
        await supabase.from('user_daily_usage').update({ count: current + 1, updated_at: new Date().toISOString() }).eq('id', result.data.id);
    } else {
        await supabase.from('user_daily_usage').insert({ user_id: userId, usage_date: usageDate, kind: 'gifts', count: 1 });
    }
    return { ok: true, limit, used: current + 1, remaining: Math.max(0, limit - current - 1) };
}

async function ensureConversation(supabase, userId, peerId) {
    const [userOne, userTwo] = pairIds(userId, peerId);
    let result = await supabase
        .from('conversations')
        .select('id, user_one_id, user_two_id, status, last_message_at, created_at, updated_at')
        .eq('user_one_id', userOne)
        .eq('user_two_id', userTwo)
        .maybeSingle();
    if (result.error && result.error.code !== 'PGRST116') return { error: result.error };
    if (result.data?.id) return { data: result.data };
    result = await supabase
        .from('conversations')
        .insert({ user_one_id: userOne, user_two_id: userTwo, status: 'active' })
        .select('id, user_one_id, user_two_id, status, last_message_at, created_at, updated_at')
        .maybeSingle();
    return result;
}

async function findGift(supabase, body) {
    if (body.giftId) {
        const { data } = await supabase.from('gift_catalog').select('*').eq('id', body.giftId).eq('is_active', true).maybeSingle();
        if (data?.id) return data;
    }
    const name = String(body.giftName || body.name || '').trim();
    if (name) {
        const { data } = await supabase.from('gift_catalog').select('*').ilike('name', name).eq('is_active', true).limit(1).maybeSingle();
        if (data?.id) return data;
    }
    const { data } = await supabase.from('gift_catalog').select('*').eq('is_active', true).order('sort_order', { ascending: true }).limit(1).maybeSingle();
    return data || null;
}

async function updateGiftCounter(supabase, receiverId) {
    const { data } = await supabase.from('users').select('gifts_received_count').eq('id', receiverId).maybeSingle();
    const next = (data?.gifts_received_count || 0) + 1;
    await supabase.from('users').update({ gifts_received_count: next }).eq('id', receiverId);
    return next;
}

async function ensureGiftInventory(supabase, userId, giftId) {
    if (!userId || !giftId) return null;
    const { data } = await supabase
        .from('user_gift_inventory')
        .select('id, user_id, gift_id, quantity, total_received, total_sent, updated_at')
        .eq('user_id', userId)
        .eq('gift_id', giftId)
        .maybeSingle();
    if (data?.id) return data;
    const inserted = await supabase
        .from('user_gift_inventory')
        .insert({ user_id: userId, gift_id: giftId, quantity: 0, total_received: 0, total_sent: 0 })
        .select('id, user_id, gift_id, quantity, total_received, total_sent, updated_at')
        .maybeSingle();
    return inserted.data || null;
}

async function adjustGiftInventory(supabase, { userId, giftId, quantityDelta = 0, receivedDelta = 0, sentDelta = 0, transactionId = null, source = '' }) {
    const row = await ensureGiftInventory(supabase, userId, giftId);
    if (!row?.id) return null;
    const nextQuantity = Math.max(0, (row.quantity || 0) + quantityDelta);
    const payload = {
        quantity: nextQuantity,
        total_received: Math.max(0, (row.total_received || 0) + receivedDelta),
        total_sent: Math.max(0, (row.total_sent || 0) + sentDelta),
        last_transaction_id: transactionId,
        source: source || row.source || 'app',
        updated_at: new Date().toISOString(),
    };
    const { data } = await supabase
        .from('user_gift_inventory')
        .update(payload)
        .eq('id', row.id)
        .select('id, user_id, gift_id, quantity, total_received, total_sent, updated_at')
        .maybeSingle();
    return data || { ...row, ...payload };
}

async function safeGiftInventory(supabase, userId) {
    try {
        const { data, error } = await supabase
            .from('user_gift_inventory')
            .select('id, user_id, gift_id, quantity, total_received, total_sent, source, updated_at, gift_catalog(id, name, category, gif_url, icon_url, credit_cost)')
            .eq('user_id', userId)
            .gt('quantity', 0)
            .order('updated_at', { ascending: false })
            .limit(80);
        if (error) return [];
        return data || [];
    } catch {
        return [];
    }
}

function uniqueGiftCatalog(rows = []) {
    const seen = new Set();
    return rows.filter((gift) => {
        const key = `${String(gift.name || '').trim().toLowerCase()}-${gift.credit_cost || 0}`;
        if (!gift.name || seen.has(key)) return false;
        seen.add(key);
        return true;
    });
}

export async function GET(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    if (!userId) return jsonError('User id is required.', 400);
    await ensureWallets(supabase, userId);
    await ensureDefaultGiftCatalog(supabase);

    const [credit, money, gift, transactions, catalog, sent, received, inventory] = await Promise.all([
        supabase.from('credit_wallet').select('*').eq('user_id', userId).maybeSingle(),
        supabase.from('money_wallet').select('*').eq('user_id', userId).maybeSingle(),
        supabase.from('gift_wallet').select('*').eq('user_id', userId).maybeSingle(),
        supabase.from('wallet_transactions').select('*').eq('user_id', userId).order('created_at', { ascending: false }).limit(80),
        supabase.from('gift_catalog').select('*').eq('is_active', true).order('sort_order', { ascending: true }).limit(80),
        supabase.from('gift_transactions').select('*, gift_catalog(name, category, gif_url, icon_url, credit_cost)').eq('sender_id', userId).order('created_at', { ascending: false }).limit(60),
        supabase.from('gift_transactions').select('*, gift_catalog(name, category, gif_url, icon_url, credit_cost)').eq('receiver_id', userId).order('created_at', { ascending: false }).limit(60),
        safeGiftInventory(supabase, userId),
    ]);

    return NextResponse.json({
        ok: true,
        creditWallet: credit.data || { user_id: userId, credits: 0 },
        moneyWallet: money.data || { user_id: userId, balance_ksh: 0 },
        giftWallet: gift.data || { user_id: userId, credits: 0 },
        transactions: transactions.data || [],
        giftCatalog: uniqueGiftCatalog(catalog.data || []),
        giftInventory: inventory || [],
        giftsSent: sent.data || [],
        giftsReceived: received.data || [],
    });
}

export async function POST(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const body = await request.json().catch(() => ({}));
    const action = body.action;
    const userId = body.userId;
    if (!userId) return jsonError('User id is required.', 400);
    await ensureWallets(supabase, userId);
    await ensureDefaultGiftCatalog(supabase);

    if (action === 'request_topup') {
        const amount = Math.max(0, Number(body.amount || 0));
        const walletType = String(body.walletType || 'credit').slice(0, 40);
        const reference = String(body.reference || '').trim().slice(0, 120);
        if (!amount || !reference) return jsonError('Amount and payment reference are required.', 400);
        const { data, error } = await supabase.from('wallet_transactions').insert({
            user_id: userId,
            wallet_type: walletType,
            direction: 'credit',
            amount,
            source: 'user_topup_request',
            status: 'pending',
            reference,
            admin_note: String(body.note || '').slice(0, 300),
        }).select('*').maybeSingle();
        if (error) return jsonError(error.message);
        await supabase.from('user_notifications').insert({
            user_id: userId,
            type: 'wallet',
            title: 'Wallet top-up request received',
            body: `Your ${walletType} wallet top-up request is waiting for admin approval. Reference: ${reference}`,
            metadata: { walletTransactionId: data?.id || null },
        });
        await supabase.from('admin_logs').insert({ action: 'wallet_topup_requested', details: { userId, walletType, amount, reference } });
        return NextResponse.json({ ok: true, transaction: data });
    }

    if (action === 'send_gift') {
        const receiverId = body.receiverId;
        if (!receiverId) return jsonError('Gift receiver is required.', 400);
        if (receiverId === userId) return jsonError('Choose another member before sending a gift.', 400);
        const sender = await getUser(supabase, userId);
        const access = await getUserPackageAccess(supabase, sender);
        if (!canUseFeature(access.tier, 'gifts')) return NextResponse.json({ error: 'Gifts require an approved Basic, Silver, or Gold package.', redirectTo: '/packages' }, { status: 402 });
        const gift = await findGift(supabase, body);
        if (!gift?.id) return jsonError('Gift not found.', 404);
        if (Number(gift.tier || 1) > Number(access.tier.max_gift_tier || 0)) {
            return NextResponse.json({ error: `${gift.name} requires a higher package tier.`, redirectTo: '/packages' }, { status: 402 });
        }
        const quota = await enforceGiftLimit(supabase, userId, access.tier);
        if (!quota.ok) return NextResponse.json({ error: quota.message, ...quota }, { status: 402 });
        const senderInventory = await ensureGiftInventory(supabase, userId, gift.id);
        const useInventory = (senderInventory?.quantity || 0) > 0;
        const [{ data: creditWallet }, { data: giftWallet }] = await Promise.all([
            supabase.from('credit_wallet').select('*').eq('user_id', userId).maybeSingle(),
            supabase.from('gift_wallet').select('*').eq('user_id', userId).maybeSingle(),
        ]);
        const creditCredits = creditWallet?.credits || 0;
        const giftCredits = giftWallet?.credits || 0;
        const currentCredits = creditCredits + giftCredits;
        const cost = useInventory ? 0 : (gift.credit_cost || 0);
        if (!useInventory && currentCredits < cost) return NextResponse.json({ error: 'Not enough credits. Top up your credit wallet or ask admin for help.', redirectTo: '/wallet' }, { status: 402 });
        const giftDebit = useInventory ? 0 : Math.min(giftCredits, cost);
        const creditDebit = useInventory ? 0 : cost - giftDebit;
        const nextGiftCredits = giftCredits - giftDebit;
        const nextCreditCredits = creditCredits - creditDebit;
        if (useInventory) {
            await adjustGiftInventory(supabase, { userId, giftId: gift.id, quantityDelta: -1, sentDelta: 1, source: 'sent_from_wallet' });
        } else {
            if (giftDebit) await supabase.from('gift_wallet').update({ credits: nextGiftCredits, updated_at: new Date().toISOString() }).eq('user_id', userId);
            if (creditDebit || !giftDebit) await supabase.from('credit_wallet').update({ credits: nextCreditCredits, updated_at: new Date().toISOString() }).eq('user_id', userId);
        }
        const conversation = body.conversationId ? { data: { id: body.conversationId } } : await ensureConversation(supabase, userId, receiverId);
        if (conversation.error) return jsonError(conversation.error.message);
        const { data: tx, error } = await supabase.from('gift_transactions').insert({
            sender_id: userId,
            receiver_id: receiverId,
            gift_id: gift.id,
            conversation_id: conversation.data?.id || null,
            credits_spent: cost,
            status: 'sent',
            metadata: { message: String(body.message || '').slice(0, 200), source: useInventory ? 'gift_wallet' : 'credits', senderInventoryId: senderInventory?.id || null },
        }).select('*').maybeSingle();
        if (error) return jsonError(error.message);
        if (!useInventory) {
            await supabase.from('wallet_transactions').insert({
                user_id: userId,
                wallet_type: 'credit',
                direction: 'debit',
                amount: cost,
                balance_after: nextCreditCredits + nextGiftCredits,
                source: 'gift_sent',
                status: 'posted',
                reference: tx?.id || '',
                metadata: { giftId: gift.id, receiverId },
            });
        }
        await adjustGiftInventory(supabase, { userId: receiverId, giftId: gift.id, quantityDelta: 1, receivedDelta: 1, transactionId: tx?.id || null, source: 'received_gift' });
        const messageBody = String(body.message || '').trim().slice(0, 400) || `Sent a ${gift.name} gift`;
        let chatMessage = null;
        if (conversation.data?.id) {
            const now = new Date().toISOString();
            const inserted = await supabase.from('messages').insert({
                conversation_id: conversation.data.id,
                sender_id: userId,
                receiver_id: receiverId,
                body: messageBody,
                message_type: 'gift',
                status: 'sent',
                delivered_at: now,
                metadata: {
                    gift: { id: gift.id, transactionId: tx?.id || null, name: gift.name, category: gift.category, gifUrl: gift.gif_url, iconUrl: gift.icon_url, creditCost: gift.credit_cost, creditsSpent: cost, source: useInventory ? 'gift_wallet' : 'credits' },
                    attachment: gift.gif_url
                        ? { url: gift.gif_url, type: 'gif', name: gift.name }
                        : gift.icon_url
                            ? { url: gift.icon_url, type: 'image', name: gift.name }
                            : null,
                },
            }).select('id, conversation_id, sender_id, receiver_id, body, message_type, status, read_at, delivered_at, metadata, created_at').maybeSingle();
            chatMessage = inserted.data || null;
            await supabase.from('conversations').update({ last_message_at: now, updated_at: now }).eq('id', conversation.data.id);
        }
        const giftsReceivedCount = await updateGiftCounter(supabase, receiverId);
        await supabase.from('user_notifications').insert({
            user_id: receiverId,
            type: 'gift',
            title: `${gift.name} received`,
            body: `${sender?.display_name || 'A member'} sent you a ${gift.name} gift.`,
            metadata: { giftId: gift.id, senderId: userId, gifUrl: gift.gif_url, iconUrl: gift.icon_url, conversationId: conversation.data?.id || null, actionLink: `/messages/${userId}` },
        });
        await supabase.from('admin_logs').insert({ action: 'gift_sent', details: { senderId: userId, receiverId, giftId: gift.id, credits: cost } });
        return NextResponse.json({ ok: true, gift: tx, catalogGift: gift, message: chatMessage, credits: nextCreditCredits + nextGiftCredits, usedInventory: useInventory, giftsReceivedCount, conversation: conversation.data });
    }

    if (action === 'purchase_gift') {
        const buyer = await getUser(supabase, userId);
        const access = await getUserPackageAccess(supabase, buyer);
        if (!canUseFeature(access.tier, 'gifts')) return NextResponse.json({ error: 'Gift purchases require an approved Basic, Silver, or Gold package.', redirectTo: '/packages' }, { status: 402 });
        const gift = await findGift(supabase, body);
        if (!gift?.id) return jsonError('Gift not found.', 404);
        if (Number(gift.tier || 1) > Number(access.tier.max_gift_tier || 0)) {
            return NextResponse.json({ error: `${gift.name} requires a higher package tier.`, redirectTo: '/packages' }, { status: 402 });
        }
        const [{ data: creditWallet }, { data: giftWallet }] = await Promise.all([
            supabase.from('credit_wallet').select('*').eq('user_id', userId).maybeSingle(),
            supabase.from('gift_wallet').select('*').eq('user_id', userId).maybeSingle(),
        ]);
        const creditCredits = creditWallet?.credits || 0;
        const giftCredits = giftWallet?.credits || 0;
        const cost = gift.credit_cost || 0;
        if ((creditCredits + giftCredits) < cost) return NextResponse.json({ error: 'Not enough credits. Top up your credit wallet or ask admin for help.', redirectTo: '/wallet' }, { status: 402 });
        const giftDebit = Math.min(giftCredits, cost);
        const creditDebit = cost - giftDebit;
        const nextGiftCredits = giftCredits - giftDebit;
        const nextCreditCredits = creditCredits - creditDebit;
        if (giftDebit) await supabase.from('gift_wallet').update({ credits: nextGiftCredits, updated_at: new Date().toISOString() }).eq('user_id', userId);
        if (creditDebit || !giftDebit) await supabase.from('credit_wallet').update({ credits: nextCreditCredits, updated_at: new Date().toISOString() }).eq('user_id', userId);
        const inventory = await adjustGiftInventory(supabase, { userId, giftId: gift.id, quantityDelta: 1, receivedDelta: 1, source: 'purchased' });
        await supabase.from('wallet_transactions').insert({
            user_id: userId,
            wallet_type: 'credit',
            direction: 'debit',
            amount: cost,
            balance_after: nextCreditCredits + nextGiftCredits,
            source: 'gift_purchase',
            status: 'posted',
            reference: gift.id,
            metadata: { giftId: gift.id, giftName: gift.name },
        });
        await supabase.from('user_notifications').insert({
            user_id: userId,
            type: 'gift',
            title: `${gift.name} added to your gift wallet`,
            body: `You can now send ${gift.name} from your gift wallet to a member.`,
            metadata: { giftId: gift.id, iconUrl: gift.icon_url, actionLink: '/wallet' },
        });
        return NextResponse.json({ ok: true, catalogGift: gift, inventory, credits: nextCreditCredits + nextGiftCredits });
    }

    return jsonError('Unsupported wallet action.', 400);
}
