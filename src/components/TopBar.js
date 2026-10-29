'use client';

import { usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';
import { Home, HeartHandshake, MessageCircle, Radio, User, Users } from 'lucide-react';
import Logo from '@/components/Logo';

const navItems = [
    { href: '/discover', label: 'Discover', icon: Home },
    { href: '/matches', label: 'Matches', icon: HeartHandshake },
    { href: '/messages', label: 'Messages', icon: MessageCircle },
    { href: '/live', label: 'Live', icon: Radio },
    { href: '/members', label: 'Members', icon: Users },
    { href: '/profile', label: 'Account', icon: User },
];

export default function TopBar() {
    const pathname = usePathname();
    const router = useRouter();

    const handleLogoClick = () => {
        if (pathname !== '/discover') router.push('/discover');
    };

    return (
        <header className="sticky top-0 z-40 w-full glass" style={{ borderBottom: 'var(--card-border)' }}>
            <div className="app-header-inner flex min-h-[64px] items-center justify-between gap-5 py-2">
                <button onClick={handleLogoClick} className="flex min-h-11 shrink-0 items-center cursor-pointer transition-opacity active:opacity-70 rounded-md" aria-label="Go to discovery">
                    <Logo size={28} />
                </button>
                <nav className="desktop-nav min-w-0 flex-1 items-center justify-end gap-1" aria-label="Main navigation">
                    {navItems.map((item) => {
                        const Icon = item.icon;
                        const active = item.href === '/discover'
                            ? pathname === item.href
                            : pathname === item.href || pathname?.startsWith(`${item.href}/`);

                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                aria-current={active ? 'page' : undefined}
                                className={`inline-flex min-h-10 items-center gap-2 rounded-lg px-3 text-sm font-semibold transition-colors ${active ? 'text-primary' : 'text-text-secondary hover:text-text-primary'}`}
                                style={active ? { background: 'var(--color-primary-soft)' } : undefined}
                            >
                                <Icon size={17} strokeWidth={active ? 2.4 : 1.8} aria-hidden="true" />
                                <span>{item.label}</span>
                            </Link>
                        );
                    })}
                </nav>
            </div>
        </header>
    );
}
