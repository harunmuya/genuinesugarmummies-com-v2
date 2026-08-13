'use client';

import { useMemo, useState } from 'react';

const PALETTES = {
    rose: ['#fb7185', '#f43f5e', '#0f766e'],
    bouquet: ['#f472b6', '#fb7185', '#22c55e'],
    heart: ['#fb7185', '#ef4444', '#f59e0b'],
    coffee: ['#b45309', '#f59e0b', '#14b8a6'],
    dinner: ['#ef4444', '#f97316', '#facc15'],
    perfume: ['#a78bfa', '#ec4899', '#22d3ee'],
    spa: ['#2dd4bf', '#22c55e', '#fbbf24'],
    champagne: ['#facc15', '#f97316', '#f43f5e'],
    diamond: ['#38bdf8', '#06b6d4', '#8b5cf6'],
    necklace: ['#fbbf24', '#f59e0b', '#ef4444'],
    shopping: ['#f97316', '#ec4899', '#14b8a6'],
    movie: ['#6366f1', '#ec4899', '#f59e0b'],
    music: ['#14b8a6', '#6366f1', '#f97316'],
    ride: ['#0f766e', '#14b8a6', '#f59e0b'],
    trip: ['#38bdf8', '#0f766e', '#f59e0b'],
    crown: ['#f59e0b', '#eab308', '#ef4444'],
    intro: ['#22c55e', '#14b8a6', '#f97316'],
    spotlight: ['#facc15', '#fb7185', '#8b5cf6'],
    default: ['#f97316', '#ec4899', '#14b8a6'],
};

const REAL_GIFT_IMAGES = {
    rose: '/gifts/rose.webp',
    star: '/gifts/star_gift.png',
    lucky: '/gifts/star_gift.png',
    sparkle: '/gifts/star_gift.png',
    bouquet: '/gifts/bouquet.webp',
    heart: '/gifts/heart.webp',
    coffee: '/gifts/coffee.webp',
    dinner: '/gifts/balloon-gift-box.webp',
    perfume: '/gifts/perfume.webp',
    teddy: '/gifts/teddy_gift.png',
    unicorn: '/gifts/unicorn_gift.png',
    spa: '/gifts/flower-garland.webp',
    champagne: '/gifts/confetti.webp',
    diamond: '/gifts/diamond-ring.webp',
    trophy: '/gifts/trophy_gift.png',
    castle: '/gifts/castle_gift.png',
    dragon: '/gifts/dragon_gift.png',
    fireworks: '/gifts/fireworks_gift.png',
    rocket: '/gifts/rocket_gift.png',
    galaxy: '/gifts/galaxy_gift.png',
    yacht: '/gifts/yacht_gift.png',
    car: '/gifts/sports_car_gift.png',
    necklace: '/gifts/gold-necklace.webp',
    shopping: '/gifts/money-gun.webp',
    movie: '/gifts/love-letter-premium.webp',
    music: '/gifts/go-galaxy.webp',
    ride: '/gifts/silver-sports-car.webp',
    trip: '/gifts/travel-with-you.webp',
    crown: '/gifts/crown.webp',
    intro: '/gifts/balloon-gift-box.webp',
    spotlight: '/gifts/hand-heart.webp',
    default: '/gifts/balloon-gift-box.webp',
};

function giftKind(gift) {
    const marker = String(gift?.icon_url || gift?.imageUrl || '').toLowerCase();
    if (marker.startsWith('gs-gift:')) return marker.replace('gs-gift:', '').trim() || 'default';
    const name = String(gift?.name || gift?.label || '').toLowerCase();
    if (name.includes('rose')) return 'rose';
    if (name.includes('star') || name.includes('sparkle') || name.includes('lucky') || name.includes('sunshine') || name.includes('lightning')) return 'star';
    if (name.includes('bouquet') || name.includes('flower') || name.includes('blossom') || name.includes('hibiscus') || name.includes('butterfly')) return 'bouquet';
    if (name.includes('heart')) return 'heart';
    if (name.includes('coffee')) return 'coffee';
    if (name.includes('dinner') || name.includes('meal') || name.includes('candy') || name.includes('ice cream') || name.includes('cupcake')) return 'dinner';
    if (name.includes('perfume') || name.includes('ribbon') || name.includes('designer bag')) return 'perfume';
    if (name.includes('teddy')) return 'teddy';
    if (name.includes('unicorn') || name.includes('peacock')) return 'unicorn';
    if (name.includes('spa')) return 'spa';
    if (name.includes('champagne') || name.includes('toast') || name.includes('rainbow')) return 'champagne';
    if (name.includes('diamond') || name.includes('crystal')) return 'diamond';
    if (name.includes('trophy') || name.includes('bullseye') || name.includes('dice')) return 'trophy';
    if (name.includes('castle') || name.includes('palace')) return 'castle';
    if (name.includes('dragon')) return 'dragon';
    if (name.includes('firework') || name.includes('meteor')) return 'fireworks';
    if (name.includes('rocket') || name.includes('space')) return 'rocket';
    if (name.includes('galaxy') || name.includes('planet')) return 'galaxy';
    if (name.includes('yacht')) return 'yacht';
    if (name.includes('car')) return 'car';
    if (name.includes('necklace') || name.includes('gold') || name.includes('treasure')) return 'necklace';
    if (name.includes('shopping')) return 'shopping';
    if (name.includes('movie') || name.includes('drama') || name.includes('mask') || name.includes('carousel') || name.includes('ferris')) return 'movie';
    if (name.includes('music') || name.includes('guitar') || name.includes('microphone')) return 'music';
    if (name.includes('ride')) return 'ride';
    if (name.includes('trip') || name.includes('weekend') || name.includes('travel')) return 'trip';
    if (name.includes('crown') || name.includes('queen') || name.includes('top hat') || name.includes('vip')) return 'crown';
    if (name.includes('intro') || name.includes('connect')) return 'intro';
    if (name.includes('spotlight') || name.includes('priority')) return 'spotlight';
    return 'default';
}

function GiftShape({ kind }) {
    const common = { stroke: 'currentColor', strokeWidth: 5, strokeLinecap: 'round', strokeLinejoin: 'round', fill: 'none' };
    switch (kind) {
        case 'rose':
            return (
                <>
                    <path {...common} d="M55 92V52" />
                    <path {...common} d="M55 70c-15-7-23-5-30 4 13 2 22-1 30-4Z" />
                    <path {...common} d="M55 63c15-7 24-5 31 5-13 2-22-1-31-5Z" />
                    <path d="M55 19c-18 0-31 12-31 27 0 16 14 29 31 29s31-13 31-29c0-15-13-27-31-27Z" fill="currentColor" opacity=".16" />
                    <path {...common} d="M35 45c8-20 33-27 46-9-9-4-18-2-27 7 11-1 20 2 26 11-13 8-31 7-45-9Z" />
                </>
            );
        case 'bouquet':
            return (
                <>
                    <path {...common} d="M42 94 55 54l13 40" />
                    <path {...common} d="M28 50c8 16 19 24 27 24s19-8 27-24" />
                    <circle cx="32" cy="36" r="13" fill="currentColor" opacity=".2" />
                    <circle cx="55" cy="30" r="15" fill="currentColor" opacity=".28" />
                    <circle cx="78" cy="36" r="13" fill="currentColor" opacity=".2" />
                    <path {...common} d="M32 36h.1M55 30h.1M78 36h.1M35 85h40" />
                </>
            );
        case 'heart':
            return <path d="M55 88C30 70 18 56 18 39c0-12 9-21 21-21 7 0 13 3 16 9 3-6 9-9 16-9 12 0 21 9 21 21 0 17-12 31-37 49Z" fill="currentColor" opacity=".84" />;
        case 'coffee':
            return (
                <>
                    <path {...common} d="M32 45h45v23c0 12-10 22-22 22h-1c-12 0-22-10-22-22V45Z" />
                    <path {...common} d="M77 52h5c8 0 13 5 13 12s-5 12-13 12h-5" />
                    <path {...common} d="M43 25c-4 7 4 10 0 17M58 25c-4 7 4 10 0 17M73 25c-4 7 4 10 0 17" />
                </>
            );
        case 'dinner':
            return (
                <>
                    <circle cx="55" cy="58" r="29" fill="currentColor" opacity=".14" />
                    <circle {...common} cx="55" cy="58" r="22" />
                    <path {...common} d="M22 24v68M29 24v68M22 45h14M88 24v68M88 24c11 12 10 27 0 37" />
                </>
            );
        case 'perfume':
            return (
                <>
                    <path {...common} d="M43 37h24M49 24h12v13H49zM38 51c0-8 7-14 17-14s17 6 17 14v33c0 7-5 12-12 12H50c-7 0-12-5-12-12V51Z" />
                    <path d="M47 62h16v20H47z" fill="currentColor" opacity=".22" />
                    <path {...common} d="M70 31h16M78 23v16" />
                </>
            );
        case 'spa':
            return (
                <>
                    <path d="M55 87c-22-19-23-42 0-64 23 22 22 45 0 64Z" fill="currentColor" opacity=".2" />
                    <path {...common} d="M55 87c-22-19-23-42 0-64 23 22 22 45 0 64Z" />
                    <path {...common} d="M55 87c-12-25-7-42 0-64M55 73c-15-9-28-8-40 3M55 73c15-9 28-8 40 3" />
                </>
            );
        case 'champagne':
            return (
                <>
                    <path {...common} d="M33 21h28c0 22-7 34-14 34S33 43 33 21ZM47 55v32M34 88h26" />
                    <path {...common} d="M65 21h28c0 22-7 34-14 34S65 43 65 21ZM79 55v32M66 88h26" />
                    <path {...common} d="M58 61 68 50" />
                </>
            );
        case 'diamond':
            return (
                <>
                    <path d="M22 43 39 22h32l17 21-33 47-33-47Z" fill="currentColor" opacity=".18" />
                    <path {...common} d="M22 43 39 22h32l17 21-33 47-33-47ZM22 43h66M39 22l16 21 16-21M39 22l-3 21 19 47 19-47-3-21" />
                </>
            );
        case 'necklace':
            return (
                <>
                    <path {...common} d="M25 27c3 36 17 56 30 56s27-20 30-56" />
                    <circle cx="55" cy="84" r="12" fill="currentColor" opacity=".24" />
                    <path {...common} d="M55 74v20M45 84h20M34 48h.1M76 48h.1" />
                </>
            );
        case 'shopping':
            return (
                <>
                    <path {...common} d="M29 38h52l-5 55H34L29 38Z" />
                    <path {...common} d="M42 38c0-14 7-22 13-22s13 8 13 22" />
                    <path d="M42 58h26v19H42z" fill="currentColor" opacity=".2" />
                </>
            );
        case 'movie':
            return (
                <>
                    <path {...common} d="M24 38h62v41H24zM24 38l11-18h62L86 38" />
                    <path {...common} d="M39 20 28 38M57 20 46 38M75 20 64 38M35 59h40" />
                </>
            );
        case 'music':
            return (
                <>
                    <path {...common} d="M68 22v50c0 9-8 16-18 16s-18-7-18-16 8-16 18-16c7 0 13 3 16 8" />
                    <path {...common} d="M68 22h22v17H68" />
                    <path d="M28 29c8 0 14-4 18-12 4 8 10 12 18 12-8 5-14 11-18 20-4-9-10-15-18-20Z" fill="currentColor" opacity=".2" />
                </>
            );
        case 'ride':
            return (
                <>
                    <path {...common} d="M24 62h62l-7-23H31l-7 23ZM28 62v18h12M70 80h12V62M40 80h30" />
                    <circle cx="38" cy="62" r="5" fill="currentColor" opacity=".5" />
                    <circle cx="72" cy="62" r="5" fill="currentColor" opacity=".5" />
                    <path {...common} d="M34 39 42 24h26l8 15" />
                </>
            );
        case 'trip':
            return (
                <>
                    <path {...common} d="M35 37h40v52H35zM45 37v-8c0-6 4-10 10-10s10 4 10 10v8M48 47v32M62 47v32" />
                    <path {...common} d="M77 24 96 14M84 33l12-19-22 3" />
                </>
            );
        case 'crown':
            return (
                <>
                    <path d="M20 37 39 57l16-31 16 31 19-20-8 50H28l-8-50Z" fill="currentColor" opacity=".22" />
                    <path {...common} d="M20 37 39 57l16-31 16 31 19-20-8 50H28l-8-50ZM31 74h48" />
                </>
            );
        case 'intro':
            return (
                <>
                    <path {...common} d="M36 62 24 50c-8-8-8-20 0-28s20-8 28 0l10 10M74 48l12 12c8 8 8 20 0 28s-20 8-28 0L48 78M42 68l26-26" />
                    <path d="M43 25c6-6 17-6 23 0 7 7 7 17 0 24" fill="currentColor" opacity=".14" />
                </>
            );
        case 'spotlight':
            return (
                <>
                    <path d="M55 19 66 43l26 3-19 18 5 26-23-13-23 13 5-26-19-18 26-3 11-24Z" fill="currentColor" opacity=".24" />
                    <path {...common} d="M55 19 66 43l26 3-19 18 5 26-23-13-23 13 5-26-19-18 26-3 11-24Z" />
                </>
            );
        default:
            return (
                <>
                    <path {...common} d="M28 45h54v47H28zM22 33h66v12H22zM55 33v59M36 33c-10-11-5-22 7-19 8 2 12 10 12 19M74 33c10-11 5-22-7-19-8 2-12 10-12 19" />
                    <path {...common} d="M44 58h22M44 72h22" />
                </>
            );
    }
}

export default function GiftVisual({ gift, className = 'h-14 w-full rounded-xl' }) {
    const [failed, setFailed] = useState(false);
    const rawUrl = gift?.icon_url || gift?.gif_url || gift?.imageUrl || gift?.gifUrl || '';
    const kind = useMemo(() => giftKind(gift), [gift]);
    const palette = PALETTES[kind] || PALETTES.default;
    const realFallbackUrl = REAL_GIFT_IMAGES[kind] || REAL_GIFT_IMAGES.default;
    const raw = String(rawUrl || '');
    const useRawUrl = raw.startsWith('/gifts/');
    const imageUrl = useRawUrl ? raw : realFallbackUrl;

    if (imageUrl && !failed) {
        return (
            <div
                className={`${className} relative flex items-center justify-center overflow-hidden bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.9),rgba(255,247,237,0.95)_42%,rgba(254,215,170,0.45))] ring-1 ring-amber-200/70`}
                aria-label={gift?.name || 'Gift'}
            >
                <div className="absolute inset-x-2 bottom-1 h-5 rounded-full bg-black/10 blur-md" />
                <img src={imageUrl} alt={gift?.name || 'Gift'} className="relative z-10 h-[88%] w-[88%] object-contain drop-shadow-md" loading="lazy" onError={() => setFailed(true)} />
            </div>
        );
    }

    return (
        <div
            className={`${className} relative flex items-center justify-center overflow-hidden text-white shadow-sm ring-1 ring-white/40`}
            style={{ background: `linear-gradient(135deg, ${palette[0]}, ${palette[1]} 58%, ${palette[2]})` }}
            aria-label={gift?.name || 'Gift'}
        >
            <div className="absolute -right-5 -top-5 h-16 w-16 rounded-full bg-white/24" />
            <div className="absolute -bottom-8 -left-6 h-20 w-20 rounded-full bg-black/10" />
            <svg viewBox="0 0 110 110" className="relative z-10 h-[78%] w-[78%] drop-shadow-sm" role="img" aria-hidden="true">
                <GiftShape kind={kind} />
            </svg>
        </div>
    );
}
