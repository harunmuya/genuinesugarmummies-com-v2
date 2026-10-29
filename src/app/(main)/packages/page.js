'use client';

import { useEffect, useMemo, useState } from 'react';
import {
    BadgeCheck,
    Check,
    Crown,
    Eye,
    Gem,
    Gift,
    Headphones,
    HelpCircle,
    Lock,
    MessageCircle,
    Phone,
    PhoneCall,
    Rocket,
    Send,
    Shield,
    Star,
    Users,
    Wallet,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

const TIERS = [
    {
        id: 'basic',
        name: 'Basic',
        shortName: 'Basic',
        price: 750,
        label: 'Entry tier',
        icon: Shield,
        color: 'primary',
        summary: 'A lower-cost paid tier with daily limits for members who want to start conversations and request a local introduction.',
        bestFor: 'Limited daily use, with image sharing and Tier 1 gifts.',
        sectionTitle: "What's included",
        highlights: [
            { icon: MessageCircle, title: '30 messages', caption: 'Every day' },
            { icon: Heart, title: '10 likes', caption: 'Every day' },
            { icon: Gift, title: 'Tier 1 gifts', caption: 'With credits' },
        ],
        services: [
            'Up to 30 chat messages per day',
            '10 likes and 5 Super Likes per day',
            '30 swipes and 30 profile views per day',
            'Image sharing in chat',
            'Gift sending up to Tier 1, using credits already in your account',
            'Phone reveal, voice/video calls and live streaming are not included',
            'A local introduction is a separate service, normally KSh750; eligible app accounts can claim the KSh650 offer after payment verification',
        ],
        why: [
            'Pay KSh750 using one of the displayed mobile-money methods',
            'Submit the provider transaction ID for admin review',
            'Basic app features activate only after payment is confirmed',
        ],
    },
    {
        id: 'silver',
        name: 'Silver',
        shortName: 'Silver',
        price: 1200,
        label: 'Recommended Plan',
        icon: Gem,
        color: 'secondary',
        summary: 'More room to communicate, with phone reveal and selected live and call features.',
        bestFor: 'No daily message, swipe or profile-view cap; likes and gifts remain limited.',
        sectionTitle: 'What you get',
        highlights: [
            { icon: MessageCircle, title: 'Messages', caption: 'No daily cap' },
            { icon: PhoneCall, title: 'Voice/video', caption: 'Included' },
            { icon: Eye, title: '50 likes', caption: '100 Super Likes/day' },
        ],
        services: [
            'No daily message, swipe or profile-view cap',
            '50 likes and 100 Super Likes per day',
            'Phone reveal on profiles that allow it',
            'Voice/video calls and voice notes',
            'Images, live streaming and nearby discovery',
            'Gift sending up to Tier 3, within the daily gift limit',
            'See who liked and viewed your profile',
        ],
        why: [
            'One-time payment; no automatic recurring charge',
            'Paid access starts after admin verifies the transaction',
            'Availability and member choices are not guaranteed',
        ],
        recommended: true,
    },
    {
        id: 'gold',
        name: 'Gold International',
        shortName: 'Gold',
        price: 3550,
        label: 'Highest Access',
        icon: Crown,
        color: 'gold',
        summary: 'The broadest app feature set, including international profile access and higher gift tiers.',
        bestFor: 'For members who need the international tier and uncapped daily limits.',
        sectionTitle: 'What you get',
        highlights: [
            { icon: Crown, title: 'International', caption: 'Profile access' },
            { icon: Rocket, title: 'No daily caps', caption: 'Core activity' },
            { icon: Gift, title: 'Tier 4 gifts', caption: 'With credits' },
        ],
        services: [
            'No daily cap on messages, likes, Super Likes, swipes or profile views',
            'International profile access',
            'Phone reveal, calls, voice notes, images, live streaming and nearby discovery',
            'Gift sending up to Tier 4, within the active gift rules',
            'See who liked and viewed your profile',
            'International access does not guarantee a match, response or introduction',
        ],
        why: [
            'One-time payment; no automatic recurring charge',
            'Paid access starts after admin verifies the transaction',
            'Matches and introductions remain subject to member choice and availability',
        ],
    },
];

const PAYMENT_METHODS = [
    {
        id: 'airtel',
        name: 'Airtel Money',
        title: 'Pay with Airtel Money',
        number: '0739154302',
        steps: ['Open Airtel Money', 'Choose Send Money', 'Enter 0739154302', 'Confirm the recipient and amount before sending', 'Paste the transaction ID below'],
    },
    {
        id: 'mpesa',
        name: 'M Pesa',
        title: 'Pay with M-Pesa',
        number: '0713160195',
        steps: ['Open M-Pesa', 'Choose Send Money', 'Enter 0713160195', 'Confirm the recipient and amount before sending', 'Paste the transaction ID below'],
    },
];

function currentTier(user) {
    return String(user?.subscription_tier || user?.subscriptionTier || 'free').toLowerCase();
}

function toneClasses(color, active = false) {
    if (color === 'gold') {
        return {
            icon: 'text-gold bg-amber-100',
            pill: 'bg-amber-100 text-gold',
            border: active ? '2px solid rgba(201,130,9,0.65)' : '1px solid rgba(201,130,9,0.22)',
            glow: '0 20px 50px rgba(201,130,9,0.16)',
        };
    }
    if (color === 'secondary') {
        return {
            icon: 'text-secondary bg-secondary/10',
            pill: 'bg-secondary/10 text-secondary',
            border: active ? '2px solid var(--color-secondary)' : '1px solid rgba(240,68,114,0.18)',
            glow: '0 20px 50px rgba(240,68,114,0.16)',
        };
    }
    return {
        icon: 'text-primary bg-primary/10',
        pill: 'bg-primary/10 text-primary',
        border: active ? '2px solid var(--color-primary)' : 'var(--card-border)',
        glow: 'var(--shadow-glow)',
    };
}

export default function PackagesPage() {
    const { user, addMessage } = useAuth();
    const [selectedTier, setSelectedTier] = useState('silver');
    const [methodId, setMethodId] = useState('airtel');
    const [paymentRef, setPaymentRef] = useState('');
    const [note, setNote] = useState('');
    const [status, setStatus] = useState('');
    const [loading, setLoading] = useState(false);
    const [paymentConfirmed, setPaymentConfirmed] = useState(false);
    const [offerStatus, setOfferStatus] = useState('loading');
    const [claimLocalOffer, setClaimLocalOffer] = useState(false);
    const [packages, setPackages] = useState(TIERS);
    const activeTier = currentTier(user);
    const selected = useMemo(() => packages.find((item) => item.id === selectedTier) || packages[0] || TIERS[0], [packages, selectedTier]);
    const method = useMemo(() => PAYMENT_METHODS.find((item) => item.id === methodId) || PAYMENT_METHODS[0], [methodId]);
    const effectivePrice = selected.id === 'basic' && claimLocalOffer ? 650 : Number(selected.price || 0);
    const unlocked = Boolean(user?.admin_approved && !user?.package_locked && ['basic', 'silver', 'gold', 'diamond'].includes(activeTier));

    useEffect(() => {
        let alive = true;
        fetch('/api/packages')
            .then((res) => res.json())
            .then((data) => {
                if (!alive || !Array.isArray(data.packages)) return;
                setPackages(TIERS.map((fallback) => {
                    const remote = data.packages.find((pkg) => pkg.id === fallback.id);
                    return {
                        ...fallback,
                        price: fallback.id === 'basic' ? 750 : Number(remote?.price_ksh ?? fallback.price),
                        badgeLabel: remote?.badge_label || fallback.label,
                    };
                }));
            })
            .catch(() => {});
        return () => { alive = false; };
    }, []);

    useEffect(() => {
        if (!user?.id) return;
        let active = true;
        fetch('/api/members', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'local_offer_status' }),
        }).then(async (res) => {
            const data = await res.json().catch(() => ({}));
            if (active && res.ok) setOfferStatus(data.status || 'available');
            else if (active) setOfferStatus('available');
        }).catch(() => { if (active) setOfferStatus('available'); });
        return () => { active = false; };
    }, [user?.id]);

    useEffect(() => {
        if (!user?.id || offerStatus !== 'under_review') return undefined;
        let alive = true;
        const refreshOffer = async () => {
            try {
                const res = await fetch('/api/members', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: 'local_offer_status' }),
                });
                const data = await res.json().catch(() => ({}));
                if (alive && res.ok) setOfferStatus(data.status || 'under_review');
            } catch {}
        };
        const timer = window.setInterval(refreshOffer, 15000);
        return () => { alive = false; window.clearInterval(timer); };
    }, [offerStatus, user?.id]);

    async function requestPackage() {
        if (!user?.email) {
            window.location.href = '/auth/login';
            return;
        }
        const ref = paymentRef.trim();
        if (ref.replace(/[^a-z0-9]/gi, '').length < 6) {
            setStatus('Enter the full transaction ID from your payment receipt.');
            return;
        }
        if (!paymentConfirmed) {
            setStatus('Confirm that you completed the transfer to the displayed recipient and amount.');
            return;
        }
        setLoading(true);
        setStatus('');
        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'request_package',
                    memberId: user.id,
                    email: user.email,
                    display_name: user.display_name,
                    tier: selected.id,
                    payment_reference: ref,
                    payment_method: method.id,
                    offer_code: selected.id === 'basic' && claimLocalOffer ? 'LOCAL650' : '',
                    note: `${method.name}: ${note}`.slice(0, 500),
                }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(data.error || 'Package request failed.');
            setStatus(claimLocalOffer && selected.id === 'basic'
                ? `Local introduction offer request submitted with transaction ID ${ref}. It is not claimed until admin verifies the payment.`
                : `${selected.name} request sent. Admin will verify payment ${ref} before activating your account.`);
            setPaymentConfirmed(false);
            if (selected.id === 'basic' && claimLocalOffer) setOfferStatus('under_review');
            addMessage?.({
                type: 'package_request',
                sender: 'GS Finance',
                title: `${selected.name} request received`,
                body: claimLocalOffer && selected.id === 'basic'
                    ? `Your KSh650 local introduction offer payment is waiting for admin review. Payment ID: ${ref}`
                    : `Your KSh ${effectivePrice.toLocaleString()} ${selected.name} request is waiting for admin approval. Payment ID: ${ref}`,
            });
        } catch (error) {
            setStatus(error.message || 'Package request failed.');
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="px-4 py-4 pb-28 space-y-5">
            <section className="rounded-2xl overflow-hidden text-white shadow-lg" style={{ background: 'var(--gradient-primary)' }}>
                <div className="p-5 space-y-4">
                    <div className="flex items-start justify-between gap-3">
                        <div>
                            <p className="text-xs font-black uppercase text-white/75">GS Premium Access</p>
                            <h1 className="mt-1 text-3xl font-black leading-tight">Upgrade your account</h1>
                    <p className="mt-2 text-sm leading-relaxed text-white/85">Choose the features you need. Pay using the displayed mobile-money instructions and submit your transaction ID for manual review.</p>
                        </div>
                        <div className="h-12 w-12 rounded-2xl bg-white/18 flex items-center justify-center shrink-0"><Gem size={24} /></div>
                    </div>
                    <div className="grid grid-cols-3 gap-2">
                        <HeroMetric icon={MessageCircle} label="Chat" />
                        <HeroMetric icon={PhoneCall} label="Calls" />
                        <HeroMetric icon={Rocket} label="Boost" />
                    </div>
                </div>
            </section>

            {offerStatus !== 'claimed' && offerStatus !== 'under_review' && offerStatus !== 'loading' && (
                <section className="flex flex-col gap-3 rounded-2xl border p-4 sm:flex-row sm:items-center sm:justify-between" style={{ background: 'var(--color-bg-card)', borderColor: 'var(--color-primary)' }}>
                    <div className="flex items-start gap-3">
                        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary"><Crown size={19} /></span>
                        <div>
                            <p className="text-xs font-black uppercase text-primary">New app account offer</p>
                            <h2 className="mt-1 text-base font-black text-text-primary">Local introduction request</h2>
                            <p className="mt-1 text-sm text-text-secondary"><span className="mr-2 text-text-muted line-through">KSh 750</span><strong>KSh 650</strong> after payment verification</p>
                            <p className="mt-1 text-xs text-text-muted">One local introduction request, separate from app membership. Subject to availability and mutual consent; the desk reviews the payment ID before marking it claimed.</p>
                        </div>
                    </div>
                    <button onClick={() => { setSelectedTier('basic'); setClaimLocalOffer(true); setPaymentConfirmed(false); setStatus('Local introduction offer selected. Complete the KSh650 payment and submit its transaction ID for admin review.'); }} className="min-h-10 shrink-0 rounded-xl bg-primary px-4 text-sm font-black text-white">Claim KSh650 offer</button>
                </section>
            )}
            {offerStatus === 'under_review' && <p className="rounded-xl bg-amber-500/10 p-3 text-sm font-bold text-text-secondary">Your local introduction offer payment is waiting for admin verification.</p>}
            {offerStatus === 'claimed' && <p className="rounded-xl bg-success/10 p-3 text-sm font-bold text-text-secondary">Your local introduction offer has been claimed after payment verification. The desk will follow up about availability and next steps.</p>}

            <section className="rounded-2xl p-4 flex items-center gap-3" style={{ background: unlocked ? 'rgba(5,150,105,0.08)' : 'rgba(245,158,11,0.08)', border: unlocked ? '1px solid rgba(5,150,105,0.18)' : '1px solid rgba(245,158,11,0.2)' }}>
                {unlocked ? <BadgeCheck size={24} className="text-success" /> : <Lock size={24} className="text-gold" />}
                <div className="min-w-0">
                    <p className="text-sm font-black text-text-primary">Current account: {activeTier.toUpperCase()}</p>
                    <p className="text-xs text-text-muted">{unlocked ? 'Your approved package is active.' : 'Paid features open after admin verifies your payment.'}</p>
                </div>
            </section>

            <section className="grid gap-4">
                {packages.map((tier) => (
                    <TierCard
                        key={tier.id}
                        tier={tier}
                        active={selectedTier === tier.id}
                        selected={selected}
                        onSelect={() => { setSelectedTier(tier.id); setClaimLocalOffer(false); setPaymentConfirmed(false); }}
                    />
                ))}
            </section>
            <section className="rounded-[28px] p-4 space-y-4" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)', boxShadow: 'var(--shadow-card)' }}>
                <div className="flex items-center gap-2">
                    <Wallet size={18} className="text-primary" />
                    <h2 className="text-lg font-black text-text-primary">Payment</h2>
                </div>
                <div className="grid grid-cols-2 gap-2">
                    {PAYMENT_METHODS.map((item) => (
                    <button key={item.id} onClick={() => { setMethodId(item.id); setPaymentConfirmed(false); }} className={`min-h-11 rounded-2xl px-3 text-sm font-black ${methodId === item.id ? 'gradient-primary text-white' : 'bg-surface text-text-secondary'}`}>
                            {item.name}
                        </button>
                    ))}
                </div>
                <div className="rounded-2xl p-3 space-y-3" style={{ background: 'var(--color-primary-soft)', border: 'var(--card-border)' }}>
                    <div className="flex items-start justify-between gap-3">
                        <div>
                            <p className="text-sm font-black text-text-primary">{method.title}</p>
                    <p className="text-xs font-bold text-primary">Number: {method.number}</p>
                        </div>
                        <span className="rounded-full bg-white px-3 py-1 text-xs font-black text-primary">KSh {effectivePrice.toLocaleString()}</span>
                    </div>
                    <ol className="space-y-2">
                        {method.steps.map((step, index) => (
                            <li key={step} className="flex gap-2 text-sm font-bold text-text-secondary">
                                <span className="text-primary">{index + 1}.</span>
                                <span>{step}</span>
                            </li>
                        ))}
                    </ol>
                    <a href="https://t.me/GSADMINMARYGAGENCY" target="_blank" rel="noopener noreferrer" className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-white px-3 text-xs font-black text-primary"><HelpCircle size={14} /> Ask Admin Mary G</a>
                </div>
                <input value={paymentRef} onChange={(e) => setPaymentRef(e.target.value.toUpperCase())} placeholder="Payment transaction ID" className="w-full rounded-2xl py-3 px-3 text-base font-bold text-text-primary" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                <label className="flex items-start gap-2 rounded-xl p-3 text-sm text-text-secondary" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }}>
                    <input type="checkbox" checked={paymentConfirmed} onChange={(event) => setPaymentConfirmed(event.target.checked)} className="mt-1 accent-primary" />
                    <span>I completed the KSh {effectivePrice.toLocaleString()} transfer to <strong>{method.number}</strong> and confirmed the recipient in my wallet. I understand access stays pending until the admin verifies the transaction.</span>
                </label>
                <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Optional note for finance" rows={3} className="w-full rounded-2xl py-3 px-3 text-sm resize-none" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                {claimLocalOffer && <p className="rounded-xl bg-amber-500/10 p-3 text-xs leading-relaxed text-text-secondary">This payment is for the local introduction request only. It does not activate a Basic membership. The desk contacts you after the transaction is verified; availability and mutual consent still apply.</p>}
                <button disabled={loading || !paymentConfirmed} onClick={requestPackage} className="w-full min-h-13 rounded-2xl text-base font-black text-white gradient-primary flex items-center justify-center gap-2 disabled:opacity-60">
                    {loading ? <MessageCircle size={19} /> : <Send size={19} />} Submit for Approval
                </button>
                {status && <p className="rounded-2xl bg-primary/10 p-3 text-sm font-bold text-primary">{status}</p>}
            </section>

            <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <h2 className="text-sm font-black text-text-primary flex items-center gap-2"><Headphones size={16} className="text-secondary" /> Direct support</h2>
                <p className="text-sm text-text-secondary leading-relaxed">Need help choosing a package or confirming payment? Contact Admin Mary G and include your account email plus payment transaction ID.</p>
                <a href="https://t.me/GSADMINMARYGAGENCY" target="_blank" rel="noopener noreferrer" className="inline-flex min-h-11 items-center gap-2 rounded-2xl px-4 text-sm font-black text-white gradient-primary"><HelpCircle size={16} /> Open Telegram Support</a>
            </section>
        </div>
    );
}

function HeroMetric({ icon: Icon, label }) {
    return (
        <div className="rounded-2xl bg-white/14 p-3 text-center">
            <Icon size={18} className="mx-auto" />
            <p className="mt-1 text-xs font-black">{label}</p>
        </div>
    );
}

function TierCard({ tier, active, selected, onSelect }) {
    const Icon = tier.icon;
    const tone = toneClasses(tier.color, active);
    return (
        <article className="overflow-hidden rounded-[28px] transition-all" style={{ background: 'var(--color-bg-card)', border: tone.border, boxShadow: active ? tone.glow : 'var(--shadow-card)' }}>
            <button onClick={onSelect} className="relative w-full p-4 text-left transition-all active:scale-[0.99]">
                {tier.recommended && <span className="absolute right-3 top-3 inline-flex items-center gap-1 rounded-full px-3 py-1 text-[11px] font-black text-white gradient-primary"><Star size={11} fill="currentColor" /> Best Value</span>}
                <div className="flex items-start gap-3 pr-24">
                    <div className={`h-13 w-13 rounded-2xl flex items-center justify-center ${tone.icon}`}><Icon size={24} /></div>
                    <div className="min-w-0">
                        <p className={`mb-1 inline-flex rounded-full px-2.5 py-1 text-[11px] font-black ${tone.pill}`}>{tier.label}</p>
                        <h2 className="text-2xl font-black text-text-primary">{tier.name}</h2>
                        <p className="text-lg font-black text-primary">KSh {tier.price.toLocaleString()}</p>
                        <p className="text-[11px] font-black uppercase text-text-muted">One-time payment · no automatic renewal</p>
                        <p className="mt-1 text-xs font-bold text-text-muted">{tier.bestFor}</p>
                    </div>
                </div>
                <div className="mt-4 grid grid-cols-3 gap-2">
                    {tier.highlights.map((item) => {
                        const FeatureIcon = item.icon;
                        return (
                            <div key={item.title} className="rounded-2xl p-2 text-center" style={{ background: 'var(--color-surface)' }}>
                                <FeatureIcon size={17} className={`mx-auto mb-1 ${tier.color === 'gold' ? 'text-gold' : tier.color === 'secondary' ? 'text-secondary' : 'text-primary'}`} />
                                <p className="text-[11px] font-black text-text-primary">{item.title}</p>
                                <p className="text-[11px] font-bold text-text-muted">{item.caption}</p>
                            </div>
                        );
                    })}
                </div>
                <div className="mt-4 flex items-center justify-between gap-2">
                    <span className="inline-flex items-center gap-1 text-xs font-black text-success"><Check size={14} /> Active after review</span>
                    <span className={`rounded-full px-3 py-1.5 text-xs font-black ${active ? 'gradient-primary text-white' : 'bg-surface text-text-secondary'}`}>{active ? 'Selected' : 'Choose'}</span>
                </div>
            </button>
            {active && selected?.id === tier.id && (
                <div className="space-y-3 px-4 pb-4" style={{ borderTop: 'var(--card-border)' }}>
                    <p className="pt-3 text-sm leading-relaxed text-text-secondary">{selected.summary}</p>
                    <div className="rounded-2xl p-3" style={{ background: 'var(--color-surface)' }}>
                        <p className="mb-2 text-xs font-black text-text-primary">{selected.sectionTitle || 'Unlocked services'}</p>
                        <ol className="space-y-1.5">
                            {selected.services.map((service, index) => (
                                <li key={service} className="flex gap-2.5 rounded-xl bg-white/70 p-2">
                                    <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary text-[11px] font-black text-white">{index + 1}</span>
                                    <span className="text-[13px] font-bold leading-snug text-text-secondary">{service}</span>
                                </li>
                            ))}
                        </ol>
                    </div>
                    {Array.isArray(selected.why) && selected.why.length > 0 && (
                        <div className="rounded-2xl p-3" style={{ background: 'var(--color-primary-soft)', border: 'var(--card-border)' }}>
                            <p className="mb-2 text-xs font-black text-text-primary">{selected.id === 'basic' ? 'How it works' : `Why choose ${selected.name}?`}</p>
                            <ul className="space-y-1.5">
                                {selected.why.map((item) => (
                                    <li key={item} className="flex gap-2 text-[13px] font-bold text-text-secondary">
                                        <Check size={15} className="mt-0.5 shrink-0 text-success" />
                                        <span>{item}</span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                    )}
                </div>
            )}
        </article>
    );
}
