'use client';

import { useEffect, useRef, useState } from 'react';
import { ArrowUpRight, MessageCircle, Shield, X } from 'lucide-react';

/**
 * Contact buttons for connecting with profiles via admin Mary G.
 */
export default function ContactButtons({ profileName }) {
    const [showWhatsappNotice, setShowWhatsappNotice] = useState(false);
    const closeNoticeRef = useRef(null);
    const name = profileName || 'this person';
    const messageText = `Hi, I read ${name}'s profile and would like to ask about the next step.`;
    const connectionMsg = encodeURIComponent(messageText);
    const helpMsg = encodeURIComponent(`Hi, I need help from Genuine Sugarmummies about ${name}.`);
    const phone = '+254739154302';

    useEffect(() => {
        if (!showWhatsappNotice) return undefined;
        const previousFocus = document.activeElement;
        closeNoticeRef.current?.focus();
        const closeOnEscape = (event) => {
            if (event.key === 'Escape') setShowWhatsappNotice(false);
        };
        document.addEventListener('keydown', closeOnEscape);
        return () => {
            document.removeEventListener('keydown', closeOnEscape);
            previousFocus?.focus?.();
        };
    }, [showWhatsappNotice]);

    return (
        <div className="w-full rounded-2xl bg-bg-card overflow-hidden" style={{ border: 'var(--card-border)' }}>
            {/* Title */}
            <div className="px-4 py-3" style={{ borderBottom: 'var(--card-border)' }}>
                <p className="text-sm font-semibold text-text-primary leading-snug">
                    To Hookup or Connect with <span className="text-gradient">{name}</span>,
                    request connection from admin <span className="text-text-primary font-bold">Mary G</span>
                </p>
            </div>

            {/* Buttons grid */}
            <div className="grid grid-cols-2 gap-2 p-3">
                {/* Telegram - Recommended */}
                <a
                    href={`https://t.me/GSADMINMARYGAGENCY?text=${connectionMsg}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="group flex items-center gap-2.5 px-3.5 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02] active:scale-[0.98]"
                    style={{ backgroundColor: '#168ACD', color: 'white' }}
                >
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" className="shrink-0">
                        <path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z" />
                    </svg>
                    <div className="min-w-0">
                        <span className="block text-sm font-bold leading-tight">Telegram</span>
                        <span className="block text-[11px] opacity-80 font-medium flex items-center gap-0.5">
                            Private contact
                        </span>
                    </div>
                </a>

                {/* SMS */}
                <a
                    href={`sms:${phone}?body=${connectionMsg}`}
                    className="group flex items-center gap-2.5 px-3.5 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02] active:scale-[0.98]"
                    style={{ backgroundColor: 'var(--color-surface-light)', color: 'var(--color-text-primary)', border: 'var(--card-border)' }}
                >
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="shrink-0">
                        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
                    </svg>
                    <div className="min-w-0">
                        <span className="block text-sm font-bold leading-tight">SMS</span>
                        <span className="block text-[11px] opacity-80 font-medium flex items-center gap-0.5">
                            <Star size={8} /> Recommended
                        </span>
                    </div>
                </a>

                {/* Phone Call */}
                <a
                    href={`tel:${phone}`}
                    className="group flex items-center gap-2.5 px-3.5 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02] active:scale-[0.98]"
                    style={{ backgroundColor: 'var(--color-primary-dark)', color: 'white' }}
                >
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" className="shrink-0">
                        <path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z" />
                    </svg>
                    <div className="min-w-0">
                        <span className="block text-sm font-bold leading-tight">Phone Call</span>
                        <span className="block text-[11px] opacity-70 font-medium">Call Admin</span>
                    </div>
                </a>

                {/* Email */}
                <a
                    href={`mailto:genuinesugarmummies@gmail.com?subject=Connection Request&body=${helpMsg}`}
                    className="group flex items-center gap-2.5 px-3.5 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02] active:scale-[0.98]"
                    style={{ backgroundColor: 'var(--color-primary)', color: 'white' }}
                >
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="shrink-0">
                        <rect width="20" height="16" x="2" y="4" rx="2" />
                        <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                    </svg>
                    <div className="min-w-0">
                        <span className="block text-sm font-bold leading-tight">Email</span>
                        <span className="block text-[11px] opacity-70 font-medium">Write to us</span>
                    </div>
                </a>

                <button
                    type="button"
                    onClick={() => setShowWhatsappNotice(true)}
                    className="col-span-2 flex min-h-12 items-center gap-2.5 rounded-xl px-3.5 py-3 text-left transition-colors hover:brightness-110"
                    style={{ backgroundColor: '#168A55', color: 'white' }}
                >
                    <MessageCircle size={21} aria-hidden="true" />
                    <span className="min-w-0 flex-1">
                        <span className="block text-sm font-bold leading-tight">WhatsApp</span>
                        <span className="block text-[11px] opacity-80 font-medium">Brief coordination</span>
                    </span>
                    <ArrowUpRight size={17} aria-hidden="true" />
                </button>
            </div>

            {showWhatsappNotice && (
                <div
                    className="fixed inset-0 z-[100] flex items-end justify-center bg-black/65 p-3 backdrop-blur-sm sm:items-center"
                    onClick={() => setShowWhatsappNotice(false)}
                >
                    <section
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="whatsapp-note-title"
                        className="w-full max-w-md rounded-2xl p-5 shadow-lg"
                        style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}
                        onClick={(event) => event.stopPropagation()}
                    >
                        <div className="flex items-start justify-between gap-4">
                            <div>
                                <p className="text-xs font-bold uppercase text-primary">Private contact options</p>
                                <h3 id="whatsapp-note-title" className="mt-1 text-xl font-bold text-text-primary">A note about WhatsApp</h3>
                            </div>
                            <button ref={closeNoticeRef} type="button" onClick={() => setShowWhatsappNotice(false)} aria-label="Close notice" className="rounded-full p-2 text-text-secondary hover:bg-surface">
                                <X size={18} />
                            </button>
                        </div>
                        <p className="mt-3 text-sm leading-relaxed text-text-secondary">
                            WhatsApp is available for brief coordination. For longer conversations, Telegram or another private channel may be more convenient. Choose the contact method that works for you.
                        </p>
                        <p className="mt-3 flex gap-2 text-sm leading-relaxed text-text-secondary">
                            <Shield size={17} className="mt-0.5 shrink-0 text-primary" />
                            Never send passwords, one-time codes, or payment PINs. Share verification images only when the desk specifically requests them through an agreed private channel.
                        </p>
                        <div className="mt-5 grid grid-cols-2 gap-2">
                            <button type="button" onClick={() => setShowWhatsappNotice(false)} className="min-h-11 rounded-xl px-3 text-sm font-bold text-text-primary" style={{ background: 'var(--color-surface)' }}>
                                Cancel
                            </button>
                            <a
                                href={`https://wa.me/${phone.replace('+', '')}?text=${connectionMsg}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                onClick={() => setShowWhatsappNotice(false)}
                                className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-3 text-sm font-bold text-white"
                                style={{ background: '#168A55' }}
                            >
                                Continue to WhatsApp <ArrowUpRight size={16} />
                            </a>
                        </div>
                    </section>
                </div>
            )}
        </div>
    );
}
