'use client';

import { usePathname, useRouter } from 'next/navigation';
import Logo from '@/components/Logo';

export default function TopBar() {
    const pathname = usePathname();
    const router = useRouter();

    const handleLogoClick = () => {
        if (pathname === '/discover') {
            window.location.reload();
        } else {
            router.push('/discover');
        }
    };

    return (
        <header className="sticky top-0 z-40 w-full glass" style={{ borderBottom: '1px solid rgba(124,58,237,0.12)' }}>
            <div className="flex items-center justify-between px-4 py-2.5 max-w-lg mx-auto">
                <button
                    onClick={handleLogoClick}
                    className="flex items-center gap-2 cursor-pointer transition-opacity active:opacity-70"
                    aria-label="Go to homepage"
                >
                    <Logo size={28} />
                    <h1 className="text-sm font-bold text-text-primary leading-tight">Genuine Sugar Mummies</h1>
                </button>
                <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full" style={{ background: 'rgba(124,58,237,0.08)' }}>
                    <span className="w-2 h-2 rounded-full bg-success animate-pulse" />
                    <span className="text-[10px] font-medium text-primary">Live</span>
                </div>
            </div>
        </header>
    );
}
