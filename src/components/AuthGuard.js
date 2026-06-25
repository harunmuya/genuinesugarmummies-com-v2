'use client';

import { useAuth } from '@/contexts/AuthContext';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect } from 'react';
import Logo from '@/components/Logo';

function isProfileComplete(user) {
    if (!user) return false;
    const hasPhoto = Boolean(user.avatar_url || user.avatarUrl || user.photos?.[0]);
    return Boolean(hasPhoto && user.bio && user.age && user.location);
}

export default function AuthGuard({ children }) {
    const { user, loading } = useAuth();
    const router = useRouter();
    const pathname = usePathname();

    useEffect(() => {
        if (loading) return;
        if (!user) {
            router.replace('/auth/login');
            return;
        }
        if (pathname !== '/profile' && !isProfileComplete(user)) {
            router.replace('/profile?complete=1');
        }
    }, [user, loading, router, pathname]);

    if (loading) {
        return (
            <div className="min-h-dvh flex items-center justify-center" style={{ background: 'var(--gradient-primary)' }}>
                <div className="flex flex-col items-center gap-4">
                    <Logo size={48} />
                    <div className="w-8 h-8 border-3 border-white/30 border-t-white rounded-full animate-spin" />
                </div>
            </div>
        );
    }

    if (!user) return null;
    if (pathname !== '/profile' && !isProfileComplete(user)) return null;

    return children;
}