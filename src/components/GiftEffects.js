'use client';

const OVERLAY_ID = 'gs-gift-effects-overlay';

function tierForGift(gift) {
    const explicit = Number(gift?.tier || gift?.giftTier || 0);
    if (explicit) return Math.max(1, Math.min(4, explicit));
    const cost = Number(gift?.credit_cost || gift?.creditCost || gift?.gift_cost || 0);
    if (cost >= 1000) return 4;
    if (cost >= 100) return 3;
    if (cost >= 10) return 2;
    return 1;
}

function visualForGift(gift) {
    return gift?.icon_url || gift?.iconUrl || gift?.gif_url || gift?.gifUrl || gift?.imageUrl || gift?.gift_visual || gift?.emoji || '/gifts/rose_gift.png';
}

function getOverlay() {
    if (typeof document === 'undefined') return null;
    let overlay = document.getElementById(OVERLAY_ID);
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = OVERLAY_ID;
        overlay.className = 'gs-gift-fx-overlay';
        document.body.appendChild(overlay);
    }
    return overlay;
}

function spawnParticles(x, y, count, tier) {
    const overlay = getOverlay();
    if (!overlay) return;
    const colors = tier >= 4
        ? ['#f7a928', '#f04472', '#19a7ce', '#2fbf71', '#ffffff']
        : tier >= 3
            ? ['#f7a928', '#f6c453', '#ffffff']
            : ['#f7a928', '#ffffff'];
    for (let index = 0; index < count; index++) {
        const particle = document.createElement('span');
        particle.className = 'gs-gift-particle';
        const angle = (Math.PI * 2 * index) / count;
        const distance = 42 + Math.random() * (tier >= 3 ? 160 : 90);
        const color = colors[index % colors.length];
        particle.style.left = `${x}px`;
        particle.style.top = `${y}px`;
        particle.style.background = color;
        particle.style.boxShadow = `0 0 12px ${color}`;
        particle.style.setProperty('--gift-x', `${Math.cos(angle) * distance}px`);
        particle.style.setProperty('--gift-y', `${Math.sin(angle) * distance}px`);
        overlay.appendChild(particle);
        window.setTimeout(() => particle.remove(), 1200);
    }
}

function screenFlash(tier) {
    const overlay = getOverlay();
    if (!overlay || tier < 3) return;
    const flash = document.createElement('div');
    flash.className = tier >= 4 ? 'gs-gift-screen-flash gs-gift-screen-flash--epic' : 'gs-gift-screen-flash';
    overlay.appendChild(flash);
    window.setTimeout(() => flash.remove(), 900);
}

function screenShake() {
    if (typeof document === 'undefined') return;
    const body = document.body;
    const original = body.style.transform;
    const frames = ['translate(3px,2px)', 'translate(-3px,-2px)', 'translate(4px,-1px)', 'translate(-4px,1px)', 'translate(2px,3px)', 'translate(0,0)'];
    frames.forEach((frame, index) => {
        window.setTimeout(() => { body.style.transform = frame; }, index * 48);
    });
    window.setTimeout(() => { body.style.transform = original; }, frames.length * 48 + 40);
}

function spawnConfetti(count = 48) {
    const overlay = getOverlay();
    if (!overlay) return;
    const colors = ['#f7a928', '#f04472', '#19a7ce', '#2fbf71', '#8b5cf6', '#ffffff'];
    for (let index = 0; index < count; index++) {
        const item = document.createElement('span');
        const size = 6 + Math.random() * 9;
        item.style.position = 'absolute';
        item.style.left = `${Math.random() * window.innerWidth}px`;
        item.style.top = '-20px';
        item.style.width = `${size}px`;
        item.style.height = `${size * (Math.random() > 0.5 ? 1.8 : 1)}px`;
        item.style.borderRadius = Math.random() > 0.65 ? '50%' : '2px';
        item.style.background = colors[index % colors.length];
        item.style.opacity = '0.95';
        item.style.transform = 'translateY(0) rotate(0deg)';
        item.style.transition = `transform ${2200 + Math.random() * 1600}ms cubic-bezier(.22,1,.36,1), opacity 3200ms ease`;
        overlay.appendChild(item);
        item.offsetHeight;
        item.style.transform = `translate(${(Math.random() - 0.5) * 220}px, ${window.innerHeight + 80}px) rotate(${Math.random() * 900}deg)`;
        item.style.opacity = '0';
        window.setTimeout(() => item.remove(), 4200);
    }
}

function spawnTrail(item, tier) {
    if (tier < 2) return;
    let ticks = 0;
    const timer = window.setInterval(() => {
        const rect = item.getBoundingClientRect();
        if (rect.width) spawnParticles(rect.left + rect.width / 2, rect.top + rect.height / 2, tier >= 4 ? 7 : 3, tier);
        ticks += 1;
        if (ticks > 8) window.clearInterval(timer);
    }, 160);
}

export function triggerGiftEffect(gift, origin) {
    const overlay = getOverlay();
    if (!overlay) return;
    const tier = tierForGift(gift);
    const visual = visualForGift(gift);
    const rect = origin?.getBoundingClientRect?.();
    const startX = rect ? rect.left + rect.width / 2 : window.innerWidth / 2;
    const startY = rect ? rect.top + rect.height / 2 : window.innerHeight - 150;
    const item = document.createElement('div');
    item.className = `gs-flying-gift gs-flying-gift--tier-${tier}`;
    item.style.left = `${startX}px`;
    item.style.top = `${startY}px`;
    const isImage = String(visual || '').startsWith('/') || String(visual || '').startsWith('http');
    item.innerHTML = isImage
        ? `<img src="${visual}" alt="${gift?.name || 'Gift'}" />`
        : `<span>${visual || 'Gift'}</span>`;
    overlay.appendChild(item);
    const count = tier >= 4 ? 60 : tier >= 3 ? 30 : tier >= 2 ? 14 : 6;
    spawnParticles(startX, startY, count, tier);
    spawnTrail(item, tier);
    screenFlash(tier);
    if (tier >= 4) {
        screenShake();
        spawnConfetti(70);
    }
    window.setTimeout(() => item.remove(), tier >= 4 ? 3600 : tier >= 3 ? 2400 : 1700);
}

export default function GiftEffectsRoot() {
    return null;
}
