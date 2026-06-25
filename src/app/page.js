'use client';

import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import Logo from '@/components/Logo';
import { motion } from 'framer-motion';

export default function HomePage() {
    const { user, loading } = useAuth();
    const router = useRouter();

    useEffect(() => {
        if (!loading) {
            if (user) {
                router.replace('/discover');
            } else {
                router.replace('/auth/login');
            }
        }
    }, [user, loading, router]);

    return (
        <div className="min-h-dvh flex items-center justify-center" style={{ background: 'var(--gradient-primary)' }}>
            <motion.div
                initial={{ scale: 0.8, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ duration: 0.5 }}
                className="flex flex-col items-center gap-5"
            >
                <div className="logo-pulse">
                    <Logo size={80} />
                </div>

                <div className="w-8 h-8 border-3 border-white/30 border-t-white rounded-full animate-spin" />
            </motion.div>
        </div>
    );
}

