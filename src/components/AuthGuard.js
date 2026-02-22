'use client';

import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import Logo from '@/components/Logo';

export default function AuthGuard({ children }) {
    const { user, guest, loading } = useAuth();
    const router = useRouter();

    useEffect(() => {
        if (!loading && !user && !guest) {
            router.replace('/auth/login');
        }
    }, [user, guest, loading, router]);

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

    if (!user && !guest) return null;

    return children;
}
