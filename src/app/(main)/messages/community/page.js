'use client';

import Link from 'next/link';
import { ArrowLeft, Bell, Camera, Gem, Megaphone, Rocket, ShieldCheck, Users } from 'lucide-react';

const UPDATES = [
    {
        title: '24 hour stories are live',
        body: 'Post a photo, video, or text update from your profile. Viewers and likes are shown to the story owner.',
        icon: Camera,
        href: '/profile',
        label: 'Create story',
    },
    {
        title: 'Boost puts your profile in front',
        body: 'Silver and Gold members can boost for 24 hours to appear in featured areas across the app.',
        icon: Rocket,
        href: '/profile',
        label: 'Open boost',
    },
    {
        title: 'Silver activity center',
        body: 'Silver and Gold members can see who liked, viewed, followed, and who they follow.',
        icon: Gem,
        href: '/packages',
        label: 'View packages',
    },
    {
        title: 'Follow alerts now show names',
        body: 'Notifications include display names and usernames so you know exactly who followed you.',
        icon: Bell,
        href: '/alerts',
        label: 'Open alerts',
    },
];

const GUIDES = [
    ['Complete profile', 'Upload a clear photo, add age, location, bio, phone, and your looking-for label.'],
    ['Use stories daily', 'Posting a story keeps your profile fresh and gives other members a reason to return.'],
    ['Message with care', 'Use voice notes, gifts, and calls when available. Keep all support and package requests official.'],
    ['Stay safe', 'Report fake profiles, payment claims, or suspicious behavior through support.'],
];

export default function CommunityPage() {
    return (
        <div className="px-4 py-4 pb-28 space-y-4">
            <header className="flex items-center gap-3">
                <Link href="/messages" className="h-10 w-10 rounded-full bg-primary/10 text-primary flex items-center justify-center" aria-label="Back"><ArrowLeft size={18} /></Link>
                <div>
                    <p className="text-xs font-black uppercase text-primary">Official channel</p>
                    <h1 className="text-xl font-black text-text-primary">GS App Community</h1>
                    <p className="text-xs text-text-muted">Updates, instructions, and safety notices for active members.</p>
                </div>
            </header>

            <section className="rounded-3xl p-4 text-white gradient-primary">
                <div className="mb-3 flex items-center gap-2">
                    <Megaphone size={20} />
                    <h2 className="text-lg font-black">Keep your account active</h2>
                </div>
                <p className="text-sm text-white/85">Fresh stories, complete profile details, respectful messages, and package verification help your account get more attention across the app.</p>
            </section>

            <section className="grid gap-3">
                {UPDATES.map((item) => {
                    const Icon = item.icon;
                    return (
                        <Link key={item.title} href={item.href} className="rounded-2xl p-4 flex gap-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                            <div className="h-11 w-11 rounded-2xl bg-primary/10 text-primary flex items-center justify-center shrink-0"><Icon size={19} /></div>
                            <div className="min-w-0 flex-1">
                                <p className="text-sm font-black text-text-primary">{item.title}</p>
                                <p className="mt-1 text-xs leading-relaxed text-text-muted">{item.body}</p>
                                <span className="mt-2 inline-flex rounded-full bg-secondary/10 px-2.5 py-1 text-[11px] font-black text-secondary">{item.label}</span>
                            </div>
                        </Link>
                    );
                })}
            </section>

            <section className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <h2 className="text-sm font-black text-text-primary flex items-center gap-1.5"><Users size={16} className="text-primary" /> Member Instructions</h2>
                {GUIDES.map(([title, body]) => (
                    <div key={title} className="rounded-xl p-3" style={{ background: 'var(--color-surface)' }}>
                        <p className="text-xs font-black text-text-primary flex items-center gap-1"><ShieldCheck size={13} className="text-success" /> {title}</p>
                        <p className="mt-1 text-xs text-text-muted leading-relaxed">{body}</p>
                    </div>
                ))}
            </section>
        </div>
    );
}
