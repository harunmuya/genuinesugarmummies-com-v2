'use client';

import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { Home, Bell, User, Users, Heart } from 'lucide-react';
import { motion } from 'framer-motion';
import { useAuth } from '@/contexts/AuthContext';

const navItems = [
    { href: '/discover', label: 'Home', icon: Home },
    { href: '/matches', label: 'Matches', icon: Heart },
    { href: '/alerts', label: 'Alerts', icon: Bell },
    { href: '/members', label: 'Members', icon: Users },
    { href: '/profile', label: 'Account', icon: User },
];

export default function BottomNav() {
    const pathname = usePathname();
    const { activity, messages } = useAuth();
    const unreadAlerts = (activity || []).filter((item) => !item.read).length;
    const unreadMessages = (messages || []).filter((item) => !item.read).length;
    const totalUnread = unreadAlerts + unreadMessages;

    return (
        <nav className="fixed bottom-0 left-0 right-0 z-50 glass" style={{ borderTop: '1px solid rgba(15,118,110,0.14)' }}>
            <div className="max-w-md mx-auto flex items-center justify-around py-2 px-4">
                {navItems.map((item) => {
                    const isActive = pathname?.startsWith(item.href);
                    const Icon = item.icon;
                    const showBadge = item.href === '/alerts' && totalUnread > 0;

                    return (
                        <Link key={item.href} href={item.href} className="relative flex flex-col items-center gap-0.5 py-1 px-3 rounded-xl transition-all duration-300" style={isActive ? { background: 'rgba(15,118,110,0.1)' } : {}}>
                            <div className="relative">
                                <Icon size={23} strokeWidth={isActive ? 2.5 : 1.7} className={`transition-colors duration-300 ${isActive ? 'text-primary' : 'text-text-secondary'}`} />
                                {showBadge && (
                                    <span className="absolute -top-1 -right-1.5 min-w-[16px] h-4 rounded-full flex items-center justify-center text-[9px] font-bold text-white px-1" style={{ background: '#EC4899' }}>
                                        {totalUnread > 99 ? '99+' : totalUnread}
                                    </span>
                                )}
                                {isActive && <motion.div layoutId="navIndicator" className="absolute -bottom-1.5 left-1/2 -translate-x-1/2 w-5 h-0.5 rounded-full gradient-primary" transition={{ type: 'spring', stiffness: 500, damping: 30 }} />}
                            </div>
                            <span className={`text-[10px] font-semibold transition-colors duration-300 ${isActive ? 'text-primary' : 'text-text-secondary'}`}>{item.label}</span>
                        </Link>
                    );
                })}
            </div>
            <div className="h-[env(safe-area-inset-bottom)]" />
        </nav>
    );
}