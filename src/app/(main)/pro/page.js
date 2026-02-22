'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Crown, Star, Gem, Shield, Zap, Heart, Eye, MapPin,
    MessageCircle, Sparkles, Check, ExternalLink, Lock, Gift,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

const PACKAGES = [
    {
        id: 'basic',
        name: 'Basic Pro',
        price: 1000,
        color: '#7C3AED',
        gradient: 'linear-gradient(135deg, #7C3AED 0%, #A78BFA 100%)',
        icon: Star,
        popular: false,
        features: [
            { text: 'See who liked your profile', icon: Heart },
            { text: 'Priority profile visibility', icon: Eye },
            { text: 'Remove ads', icon: Zap },
            { text: '10 Super Likes per day', icon: Sparkles },
            { text: 'Read receipts on messages', icon: MessageCircle },
        ],
    },
    {
        id: 'premium',
        name: 'Premium Pro',
        price: 1500,
        color: '#EC4899',
        gradient: 'linear-gradient(135deg, #EC4899 0%, #F472B6 100%)',
        icon: Crown,
        popular: true,
        features: [
            { text: 'All Basic Pro features', icon: Check },
            { text: 'Verified badge boost', icon: Shield },
            { text: 'Unlimited Super Likes', icon: Sparkles },
            { text: 'Advanced match filters', icon: Zap },
            { text: 'Priority in search results', icon: Eye },
            { text: 'Direct connection requests', icon: ExternalLink },
            { text: 'See profile visitors', icon: MapPin },
        ],
    },
    {
        id: 'vip',
        name: 'VIP Pro',
        price: 2500,
        color: '#D97706',
        gradient: 'linear-gradient(135deg, #F59E0B 0%, #D97706 100%)',
        icon: Gem,
        popular: false,
        features: [
            { text: 'All Premium Pro features', icon: Check },
            { text: 'VIP gold badge on profile', icon: Crown },
            { text: 'Exclusive VIP matches only', icon: Heart },
            { text: 'Admin-assisted connections', icon: MessageCircle },
            { text: 'Live location matching', icon: MapPin },
            { text: 'Featured profile spotlight', icon: Sparkles },
            { text: 'Priority admin support 24/7', icon: Shield },
            { text: 'Gift profile boosts', icon: Gift },
        ],
    },
];

export default function ProPage() {
    const { user, logActivity, addMessage } = useAuth();
    const [selectedPkg, setSelectedPkg] = useState(null);
    const [showPayment, setShowPayment] = useState(false);

    const handleSelectPackage = (pkg) => {
        setSelectedPkg(pkg);
        setShowPayment(true);
    };

    const handlePayViaTelegram = () => {
        if (!selectedPkg) return;

        const displayName = user?.display_name || user?.email?.split('@')[0] || 'User';
        const msg = encodeURIComponent(
            `Hi Admin Mary G, I'd like to subscribe to the ${selectedPkg.name} package (KES ${selectedPkg.price.toLocaleString()}) on GenuineSugarMummies.com.\n\nMy name: ${displayName}\nMy email: ${user?.email || 'N/A'}\n\nPlease send payment details.`
        );
        window.open(`https://t.me/GSADMINMARYGAGENCY?text=${msg}`, '_blank');

        logActivity('pro_subscription', {
            title: `Requested ${selectedPkg.name}`,
            message: `KES ${selectedPkg.price.toLocaleString()} — Payment via Telegram`,
        });
        addMessage({
            type: 'pro_subscription',
            sender: 'GS Pro',
            senderImage: '',
            title: `${selectedPkg.name} Subscription Request`,
            body: `You've requested the ${selectedPkg.name} package for KES ${selectedPkg.price.toLocaleString()}. Admin Mary G will reach out on Telegram with payment instructions. Once payment is confirmed, your Pro features will be activated.`,
        });

        setShowPayment(false);
    };

    return (
        <div className="px-4 py-6 pb-28 space-y-6">
            {/* Header */}
            <div className="text-center space-y-2">
                <div className="w-16 h-16 mx-auto rounded-2xl flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #F59E0B 0%, #D97706 100%)' }}>
                    <Crown size={32} className="text-white" />
                </div>
                <h1 className="text-2xl font-black text-text-primary">Upgrade to Pro</h1>
                <p className="text-sm text-text-secondary max-w-sm mx-auto">
                    Unlock premium features and get priority access to genuine connections. Payment handled securely by Admin Mary G via Telegram.
                </p>
            </div>

            {/* Packages */}
            <div className="space-y-4">
                {PACKAGES.map((pkg, idx) => {
                    const Icon = pkg.icon;
                    return (
                        <motion.div
                            key={pkg.id}
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: idx * 0.1 }}
                            className="relative rounded-2xl overflow-hidden"
                            style={{
                                border: pkg.popular
                                    ? `2px solid ${pkg.color}`
                                    : '1px solid rgba(124,58,237,0.1)',
                                boxShadow: pkg.popular
                                    ? `0 8px 32px ${pkg.color}20`
                                    : '0 2px 12px rgba(0,0,0,0.05)',
                            }}
                        >
                            {/* Popular badge */}
                            {pkg.popular && (
                                <div
                                    className="text-center py-1.5 text-xs font-bold text-white"
                                    style={{ background: pkg.gradient }}
                                >
                                    <Star size={12} className="inline mr-1" /> MOST POPULAR
                                </div>
                            )}

                            <div className="p-5 space-y-4" style={{ background: 'var(--color-bg-card)' }}>
                                {/* Package header */}
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center gap-3">
                                        <div
                                            className="w-12 h-12 rounded-xl flex items-center justify-center"
                                            style={{ background: `${pkg.color}15` }}
                                        >
                                            <Icon size={24} style={{ color: pkg.color }} />
                                        </div>
                                        <div>
                                            <h3 className="font-bold text-text-primary text-lg">{pkg.name}</h3>
                                            <div className="flex items-baseline gap-1">
                                                <span className="text-2xl font-black" style={{ color: pkg.color }}>
                                                    KES {pkg.price.toLocaleString()}
                                                </span>
                                                <span className="text-xs text-text-muted">/month</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                {/* Features */}
                                <div className="space-y-2">
                                    {pkg.features.map((feature, fi) => {
                                        const FIcon = feature.icon;
                                        return (
                                            <div key={fi} className="flex items-center gap-2.5">
                                                <div
                                                    className="w-5 h-5 rounded-full flex items-center justify-center shrink-0"
                                                    style={{ background: `${pkg.color}12` }}
                                                >
                                                    <FIcon size={12} style={{ color: pkg.color }} />
                                                </div>
                                                <span className="text-sm text-text-secondary">{feature.text}</span>
                                            </div>
                                        );
                                    })}
                                </div>

                                {/* CTA Button */}
                                <button
                                    onClick={() => handleSelectPackage(pkg)}
                                    className="w-full py-3.5 rounded-xl font-bold text-white transition-all active:scale-[0.98] shadow-lg"
                                    style={{
                                        background: pkg.gradient,
                                        boxShadow: `0 4px 20px ${pkg.color}30`,
                                    }}
                                >
                                    {pkg.popular ? 'Get Premium' : `Subscribe — KES ${pkg.price.toLocaleString()}`}
                                </button>
                            </div>
                        </motion.div>
                    );
                })}
            </div>

            {/* Trust note */}
            <div className="rounded-xl p-4 text-center space-y-2" style={{ background: 'rgba(20,184,166,0.08)', border: '1px solid rgba(20,184,166,0.15)' }}>
                <Shield size={20} className="mx-auto text-accent" />
                <p className="text-xs text-text-secondary leading-relaxed">
                    All payments are handled personally by <strong>Admin Mary G</strong> via Telegram.
                    Your subscription is activated within 24 hours of payment confirmation.
                    Contact <strong>@GSADMINMARYGAGENCY</strong> for any questions.
                </p>
            </div>

            {/* Payment Modal */}
            <AnimatePresence>
                {showPayment && selectedPkg && (
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm"
                        onClick={() => setShowPayment(false)}
                    >
                        <motion.div
                            initial={{ y: 300 }}
                            animate={{ y: 0 }}
                            exit={{ y: 300 }}
                            className="w-full max-w-md rounded-t-3xl p-6 space-y-5"
                            style={{ background: 'var(--color-bg-card)' }}
                            onClick={(e) => e.stopPropagation()}
                        >
                            {/* Package summary */}
                            <div className="text-center space-y-2">
                                <div
                                    className="w-14 h-14 mx-auto rounded-xl flex items-center justify-center"
                                    style={{ background: `${selectedPkg.color}15` }}
                                >
                                    {(() => {
                                        const PkgIcon = selectedPkg.icon;
                                        return <PkgIcon size={28} style={{ color: selectedPkg.color }} />;
                                    })()}
                                </div>
                                <h3 className="text-xl font-black text-text-primary">{selectedPkg.name}</h3>
                                <p className="text-3xl font-black" style={{ color: selectedPkg.color }}>
                                    KES {selectedPkg.price.toLocaleString()}
                                    <span className="text-sm font-medium text-text-muted">/month</span>
                                </p>
                            </div>

                            {/* Payment instructions */}
                            <div className="rounded-xl p-4 space-y-2" style={{ background: 'var(--color-surface)' }}>
                                <p className="text-sm font-bold text-text-primary">How to pay:</p>
                                <ol className="text-xs text-text-secondary space-y-1.5 list-decimal list-inside">
                                    <li>Tap "Pay via Telegram" below</li>
                                    <li>You'll be connected to Admin Mary G</li>
                                    <li>She'll provide M-Pesa/payment details</li>
                                    <li>Send payment & share confirmation</li>
                                    <li>Your Pro features activate within 24 hrs</li>
                                </ol>
                            </div>

                            {/* Telegram CTA */}
                            <button
                                onClick={handlePayViaTelegram}
                                className="w-full flex items-center justify-center gap-2 py-4 rounded-xl font-bold text-white transition-all active:scale-[0.98] shadow-lg"
                                style={{
                                    background: selectedPkg.gradient,
                                    boxShadow: `0 4px 20px ${selectedPkg.color}30`,
                                }}
                            >
                                <ExternalLink size={20} />
                                Pay via Telegram
                            </button>

                            <button
                                onClick={() => setShowPayment(false)}
                                className="w-full py-3 text-sm font-medium text-text-muted"
                            >
                                Cancel
                            </button>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}
