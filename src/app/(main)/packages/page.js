'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { Check, Crown, Gem, HelpCircle, Lock, MessageCircle, Phone, Send, Shield, Sparkles, Wallet } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

const TIERS = [
    {
        id: 'basic',
        name: 'Basic',
        price: 650,
        icon: Shield,
        accent: 'text-primary',
        features: ['10 daily messages', '10 likes', '10 profile swipes', 'Send gifts and emojis', 'Browse member photos/details', 'Appear in active members'],
    },
    {
        id: 'silver',
        name: 'Silver',
        price: 1200,
        icon: Gem,
        accent: 'text-secondary',
        features: ['Lifetime phone number reveal', '30 daily messages', '50 likes and swipes', 'Voice call requests', 'Video call requests', 'Priority profile visibility'],
        popular: true,
    },
    {
        id: 'gold',
        name: 'Gold International',
        price: 3500,
        icon: Crown,
        accent: 'text-gold',
        features: ['International and prominent users', '100 daily messages', '200 likes and swipes', 'Premium gifts priority', 'Top placement after approval', 'Fast admin support'],
    },
];

const PAYMENT_METHODS = [
    {
        id: 'airtel',
        name: 'Airtel Money',
        title: 'Send to Airtel Money',
        steps: ['Open Airtel Money', 'Choose Send Money', 'Enter 0738871048', 'Enter the exact package amount', 'Paste the transaction ID below'],
    },
    {
        id: 'mpesa',
        name: 'M-Pesa',
        title: 'M-Pesa Assistance',
        steps: ['Tap Ask Admin below', 'Request the current M-Pesa number', 'Send the exact package amount', 'Paste the M-Pesa transaction ID below'],
    },
    {
        id: 'tkash',
        name: 'T-Kash',
        title: 'T-Kash to Airtel Number',
        steps: ['Use Send Money to other network', 'Select Airtel Money if asked', 'Enter 0738871048', 'Send the exact package amount', 'Paste the transaction ID below'],
    },
    {
        id: 'other',
        name: 'Other Network',
        title: 'Other Network Transfer',
        steps: ['Choose send money to Airtel Money or other network', 'Enter 0738871048', 'Send the exact package amount', 'Paste the transaction ID below', 'Ask admin if your network blocks the transfer'],
    },
];

function currentTier(user) {
    return String(user?.subscription_tier || user?.subscriptionTier || 'free').toLowerCase();
}

export default function PackagesPage() {
    const { user, addMessage } = useAuth();
    const [selectedTier, setSelectedTier] = useState('silver');
    const [methodId, setMethodId] = useState('airtel');
    const [paymentRef, setPaymentRef] = useState('');
    const [note, setNote] = useState('');
    const [status, setStatus] = useState('');
    const [loading, setLoading] = useState(false);
    const activeTier = currentTier(user);
    const selected = useMemo(() => TIERS.find((item) => item.id === selectedTier) || TIERS[0], [selectedTier]);
    const method = useMemo(() => PAYMENT_METHODS.find((item) => item.id === methodId) || PAYMENT_METHODS[0], [methodId]);
    const unlocked = Boolean(user?.admin_approved && !user?.package_locked && ['basic', 'silver', 'gold', 'diamond'].includes(activeTier));

    async function requestPackage() {
        if (!user?.email) {
            window.location.href = '/auth/login';
            return;
        }
        const ref = paymentRef.trim();
        if (ref.length < 3) {
            setStatus('Paste your payment transaction ID before sending the package request.');
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
                    note: `${method.name}: ${note}`.slice(0, 500),
                }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(data.error || 'Package request failed.');
            setStatus(`${selected.name} request sent. Admin will verify transaction ${ref} and unlock the package.`);
            addMessage?.({
                type: 'package_request',
                sender: 'GS Finance',
                title: `${selected.name} package requested`,
                body: `Your KSh ${selected.price} package request is waiting for admin approval. Transaction ID: ${ref}`,
            });
        } catch (error) {
            setStatus(error.message || 'Package request failed.');
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="px-4 py-4 pb-28 space-y-5">
            <section className="space-y-2">
                <div className="flex items-center justify-between gap-3">
                    <div>
                        <h1 className="text-xl font-black text-text-primary">Packages</h1>
                        <p className="text-xs text-text-muted">Pay, paste the transaction ID, then admin approves your package.</p>
                    </div>
                    <Link href="/members" className="w-10 h-10 rounded-full gradient-primary text-white flex items-center justify-center" aria-label="Members"><Phone size={18} /></Link>
                </div>
                <div className="rounded-2xl p-4 flex items-center gap-3" style={{ background: unlocked ? 'rgba(5,150,105,0.08)' : 'rgba(245,158,11,0.08)', border: unlocked ? '1px solid rgba(5,150,105,0.18)' : '1px solid rgba(245,158,11,0.2)' }}>
                    {unlocked ? <Check size={22} className="text-success" /> : <Lock size={22} className="text-gold" />}
                    <div>
                        <p className="text-sm font-black text-text-primary">Current: {activeTier.toUpperCase()}</p>
                        <p className="text-xs text-text-muted">{unlocked ? 'Your approved package is active.' : 'Premium features unlock after admin approves your payment.'}</p>
                    </div>
                </div>
            </section>

            <section className="grid gap-3">
                {TIERS.map((tier) => {
                    const Icon = tier.icon;
                    const active = selectedTier === tier.id;
                    return (
                        <button key={tier.id} onClick={() => setSelectedTier(tier.id)} className="text-left rounded-2xl p-4 space-y-3 transition-all" style={{ background: 'var(--color-bg-card)', border: active ? '2px solid var(--color-primary)' : 'var(--card-border)' }}>
                            <div className="flex items-start justify-between gap-3">
                                <div className="flex items-center gap-3">
                                    <div className="w-11 h-11 rounded-2xl bg-primary/10 flex items-center justify-center"><Icon size={20} className={tier.accent} /></div>
                                    <div>
                                        <div className="flex items-center gap-2"><h2 className="text-lg font-black text-text-primary">{tier.name}</h2>{tier.popular && <span className="px-2 py-0.5 rounded-full text-[10px] font-black text-white gradient-primary">Popular</span>}</div>
                                        <p className="text-sm font-black text-primary">KSh {tier.price.toLocaleString()}</p>
                                    </div>
                                </div>
                                {active && <Check size={20} className="text-primary" />}
                            </div>
                            <div className="grid gap-2">
                                {tier.features.map((feature) => <p key={feature} className="text-xs text-text-secondary flex items-center gap-2"><Check size={13} className="text-success" /> {feature}</p>)}
                            </div>
                        </button>
                    );
                })}
            </section>

            <section className="rounded-2xl p-4 space-y-4" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <h2 className="text-sm font-black text-text-primary flex items-center gap-2"><Wallet size={16} className="text-primary" /> Payment Instructions</h2>
                <div className="grid grid-cols-2 gap-2">
                    {PAYMENT_METHODS.map((item) => <button key={item.id} onClick={() => setMethodId(item.id)} className={`rounded-xl px-3 py-2 text-xs font-black ${methodId === item.id ? 'gradient-primary text-white' : 'bg-gray-100 text-text-secondary'}`}>{item.name}</button>)}
                </div>
                <div className="rounded-2xl p-3 bg-primary/10 space-y-2">
                    <p className="text-sm font-black text-text-primary">{method.title}</p>
                    <p className="text-xs font-bold text-primary">Amount: KSh {selected.price.toLocaleString()} for {selected.name}</p>
                    <ol className="space-y-1 text-xs text-text-secondary list-decimal list-inside">
                        {method.steps.map((step) => <li key={step}>{step}</li>)}
                    </ol>
                    <a href="https://t.me/GSADMINMARYGAGENCY" target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 rounded-xl px-3 py-2 text-xs font-black bg-white text-primary"><HelpCircle size={14} /> Ask Admin for Assistance</a>
                </div>
                <input value={paymentRef} onChange={(e) => setPaymentRef(e.target.value.toUpperCase())} placeholder="Paste payment transaction ID" className="w-full rounded-xl py-3 px-3 text-sm" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Optional note to finance/admin" rows={3} className="w-full rounded-xl py-3 px-3 text-sm resize-none" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                <button disabled={loading} onClick={requestPackage} className="w-full rounded-xl py-3 font-black text-white gradient-primary flex items-center justify-center gap-2 disabled:opacity-60">
                    {loading ? <MessageCircle size={18} /> : <Send size={18} />} Submit Payment for Approval
                </button>
                {status && <p className="text-xs font-bold text-primary bg-primary/10 rounded-xl p-3">{status}</p>}
            </section>
        </div>
    );
}