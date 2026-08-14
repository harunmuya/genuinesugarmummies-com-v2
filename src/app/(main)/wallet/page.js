'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { CheckCircle, CreditCard, Gift, History, PackageOpen, Send, ShoppingBag, Wallet } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import GiftVisual from '@/components/GiftVisual';

function dateText(date) {
    try { return new Date(date).toLocaleString(); } catch { return ''; }
}

export default function WalletPage() {
    const { user } = useAuth();
    const [data, setData] = useState({ giftCatalog: [], giftInventory: [], transactions: [], giftsSent: [], giftsReceived: [] });
    const [amount, setAmount] = useState('100');
    const [reference, setReference] = useState('');
    const [walletType, setWalletType] = useState('credit');
    const [status, setStatus] = useState('');
    const [busyGiftId, setBusyGiftId] = useState('');
    const [loading, setLoading] = useState(true);

    async function loadWallet() {
        if (!user?.id) return;
        setLoading(true);
        try {
            const res = await fetch(`/api/wallet?userId=${encodeURIComponent(user.id)}`);
            const body = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(body.error || 'Wallet unavailable.');
            setData(body);
        } catch (err) {
            setStatus(err.message || 'Wallet unavailable.');
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => { loadWallet(); }, [user?.id]);

    async function requestTopup() {
        setStatus('');
        try {
            const res = await fetch('/api/wallet', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'request_topup', userId: user.id, walletType, amount: Number(amount), reference }),
            });
            const body = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(body.error || 'Top-up request failed.');
            setStatus('Top-up request sent to Finance for approval.');
            setReference('');
            await loadWallet();
        } catch (err) {
            setStatus(err.message || 'Top-up request failed.');
        }
    }

    async function purchaseGift(gift) {
        if (!gift?.id || !user?.id) return;
        setStatus('');
        setBusyGiftId(gift.id);
        try {
            const res = await fetch('/api/wallet', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'purchase_gift', userId: user.id, giftId: gift.id }),
            });
            const body = await res.json().catch(() => ({}));
            if (!res.ok) throw new Error(body.error || 'Gift purchase failed.');
            setStatus(`${gift.name} added to your gift wallet. Open a member chat to send it.`);
            await loadWallet();
        } catch (err) {
            setStatus(err.message || 'Gift purchase failed.');
        } finally {
            setBusyGiftId('');
        }
    }

    const inventoryByGift = new Map((data.giftInventory || []).map((item) => [item.gift_id, item]));

    return (
        <div className="px-4 py-4 pb-28 space-y-4">
            <div className="flex items-center justify-between gap-3">
                <div>
                    <h1 className="text-xl font-black text-text-primary">Wallet</h1>
                    <p className="text-xs text-text-muted">Buy credits with real money, wait for Finance approval, then send premium gifts in profiles and chat.</p>
                </div>
                <div className="w-11 h-11 rounded-full gradient-primary text-white flex items-center justify-center"><Wallet size={20} /></div>
            </div>

            {status && <div className="rounded-2xl p-3 text-xs font-bold text-primary bg-primary/10">{status}</div>}

            <section className="grid grid-cols-3 gap-2">
                <BalanceCard label="Credits" value={data.creditWallet?.credits || 0} icon={CreditCard} />
                <BalanceCard label="Gift Credits" value={data.giftWallet?.credits || 0} icon={Gift} />
                <BalanceCard label="Money KSh" value={data.moneyWallet?.balance_ksh || 0} icon={Wallet} />
            </section>

            <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <h2 className="text-sm font-black text-text-primary">Request Wallet Top-up</h2>
                <div className="grid grid-cols-3 gap-2">
                    {[100, 250, 500].map((value) => <button key={value} onClick={() => setAmount(String(value))} className={`rounded-xl py-2 text-xs font-black ${amount === String(value) ? 'gradient-primary text-white' : 'bg-primary/10 text-primary'}`}>{value} cr</button>)}
                </div>
                <div className="grid grid-cols-2 gap-2">
                    <select value={walletType} onChange={(e) => setWalletType(e.target.value)} className="rounded-xl p-3 text-sm" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }}>
                        <option value="credit">Credit wallet</option>
                        <option value="money">Money wallet</option>
                    </select>
                    <input value={amount} onChange={(e) => setAmount(e.target.value.replace(/\D/g, ''))} placeholder="Amount" className="rounded-xl p-3 text-sm" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                </div>
                <input value={reference} onChange={(e) => setReference(e.target.value.toUpperCase())} placeholder="Payment reference / transaction ID" className="w-full rounded-xl p-3 text-sm" style={{ background: 'var(--color-surface)', border: 'var(--card-border)' }} />
                <button onClick={requestTopup} className="w-full rounded-xl py-3 text-sm font-black text-white gradient-primary flex items-center justify-center gap-2"><Send size={16} /> Send to Finance</button>
                <div className="rounded-2xl p-3 text-xs text-text-secondary space-y-1" style={{ background: 'var(--color-surface)' }}>
                    <p className="font-black text-text-primary">How purchase approval works</p>
                    <p>Send the amount, paste the transaction ID, then Finance approves the wallet top-up from the admin panel. Approved credits are real paid credits used for premium gifts inside member profiles and chat.</p>
                    <Link href="/packages" className="inline-flex items-center gap-1 font-black text-primary"><CheckCircle size={13} /> Package unlocks are separate from gift credits</Link>
                </div>
            </section>

            <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <div className="flex items-center justify-between gap-2">
                    <h2 className="text-sm font-black text-text-primary">Gift Catalog</h2>
                    <Link href="/members" className="text-[11px] font-black text-primary">Choose member</Link>
                </div>
                <div className="grid grid-cols-2 gap-2">
                    {(data.giftCatalog || []).length === 0 ? <p className="col-span-2 text-xs text-text-muted">No gifts are active yet. Admin can activate gifts from the control panel.</p> : (data.giftCatalog || []).map((gift) => (
                        <div key={gift.id} className="rounded-2xl p-3 space-y-2 shadow-sm ring-1 ring-black/5" style={{ background: 'var(--color-surface)' }}>
                            <GiftVisual gift={gift} className="w-full h-24 rounded-xl" iconSize={28} />
                            <div className="flex items-center justify-between gap-2">
                                <div>
                                    <p className="text-sm font-black text-text-primary">{gift.name}</p>
                                    <p className="text-[11px] text-text-muted">{gift.category} gift · Owned {inventoryByGift.get(gift.id)?.quantity || 0}</p>
                                </div>
                                <span className="rounded-full bg-primary/10 px-2 py-1 text-xs font-black text-primary">{gift.credit_cost} credits</span>
                            </div>
                            <button onClick={() => purchaseGift(gift)} disabled={busyGiftId === gift.id} className="w-full rounded-xl py-2 text-xs font-black text-white gradient-primary inline-flex items-center justify-center gap-1 disabled:opacity-60"><ShoppingBag size={13} /> {busyGiftId === gift.id ? 'Adding...' : 'Add to Gift Wallet'}</button>
                        </div>
                    ))}
                </div>
                <p className="text-xs text-text-muted">Buy gifts into your gift wallet, then send them from member profiles or chat. If you send a gift you already own, no credits are charged again.</p>
            </section>

            <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <div className="flex items-center justify-between gap-2">
                    <h2 className="text-sm font-black text-text-primary flex items-center gap-2"><PackageOpen size={16} className="text-primary" /> My Gift Wallet</h2>
                    <span className="text-[11px] font-black text-primary">{(data.giftInventory || []).reduce((sum, item) => sum + (item.quantity || 0), 0)} ready</span>
                </div>
                {(data.giftInventory || []).length === 0 ? <p className="text-xs text-text-muted">Gifts you buy or receive will appear here. You can keep them or send them to another member later.</p> : (
                    <div className="grid grid-cols-3 gap-2">
                        {(data.giftInventory || []).map((item) => {
                            const gift = item.gift_catalog || {};
                            return (
                                <div key={item.id} className="rounded-2xl p-2 text-center" style={{ background: 'var(--color-surface)' }}>
                                    <GiftVisual gift={gift} className="mx-auto mb-1 h-16 w-full rounded-xl" />
                                    <p className="truncate text-[11px] font-black text-text-primary">{gift.name || 'Gift'}</p>
                                    <p className="text-[11px] font-black text-primary">x{item.quantity}</p>
                                </div>
                            );
                        })}
                    </div>
                )}
                <Link href="/messages" className="inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2 text-xs font-black text-white gradient-secondary"><Send size={13} /> Send from Chat</Link>
            </section>

            <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <h2 className="text-sm font-black text-text-primary">Gift Activity</h2>
                <div className="grid gap-2">
                    {[...(data.giftsReceived || []).map((gift) => ({ ...gift, directionLabel: 'Received' })), ...(data.giftsSent || []).map((gift) => ({ ...gift, directionLabel: 'Sent' }))].slice(0, 12).map((gift) => (
                        <div key={`${gift.directionLabel}-${gift.id}`} className="rounded-xl p-3 flex items-center gap-3" style={{ background: 'var(--color-surface)' }}>
                            <GiftVisual gift={gift.gift_catalog || gift} className="w-12 h-12 rounded-xl shrink-0" />
                            <div className="min-w-0 flex-1">
                                <p className="text-sm font-black text-text-primary truncate">{gift.directionLabel} {gift.gift_catalog?.name || 'gift'}</p>
                                <p className="text-xs text-text-muted">{gift.credits_spent || gift.gift_catalog?.credit_cost || 0} credits · {dateText(gift.created_at)}</p>
                            </div>
                        </div>
                    ))}
                    {(data.giftsReceived || []).length + (data.giftsSent || []).length === 0 && <p className="text-xs text-text-muted">Sent and received gifts will appear here.</p>}
                </div>
            </section>

            <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <h2 className="text-sm font-black text-text-primary flex items-center gap-2"><History size={16} className="text-primary" /> Wallet History</h2>
                {loading ? <p className="text-xs text-text-muted">Loading...</p> : (data.transactions || []).length === 0 ? <p className="text-xs text-text-muted">No wallet transactions yet.</p> : (
                    <div className="space-y-2">
                        {data.transactions.map((tx) => (
                            <div key={tx.id} className="rounded-xl p-3" style={{ background: 'var(--color-surface)' }}>
                                <div className="flex items-center justify-between gap-2">
                                    <p className="text-sm font-black text-text-primary">{tx.wallet_type} {tx.direction}</p>
                                    <span className={`text-xs font-black ${tx.status === 'posted' ? 'text-success' : 'text-gold'}`}>{tx.status}</span>
                                </div>
                                <p className="text-xs text-text-secondary">Amount: {tx.amount} · Ref: {tx.reference || 'N/A'}</p>
                                <p className="text-[11px] text-text-muted">{dateText(tx.created_at)}</p>
                            </div>
                        ))}
                    </div>
                )}
            </section>
        </div>
    );
}

function BalanceCard({ icon: Icon, label, value }) {
    return <div className="rounded-2xl p-3 min-h-[92px] flex flex-col justify-between" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><Icon size={18} className="text-primary" /><div><p className="text-[11px] text-text-muted">{label}</p><p className="text-lg font-black text-text-primary">{value}</p></div></div>;
}
