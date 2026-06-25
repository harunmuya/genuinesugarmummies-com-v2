'use client';

import { usePathname, useRouter } from 'next/navigation';
import Logo from '@/components/Logo';

export default function TopBar() {
    const pathname = usePathname();
    const router = useRouter();

    const handleLogoClick = () => {
        if (pathname === '/discover') window.location.reload();
        else router.push('/discover');
    };

    return (
        <header className="sticky top-0 z-40 w-full glass" style={{ borderBottom: '1px solid rgba(15,118,110,0.14)' }}>
            <div className="flex items-center justify-between px-4 py-2.5 max-w-lg mx-auto">
                <button onClick={handleLogoClick} className="flex items-center cursor-pointer transition-opacity active:opacity-70 min-w-0" aria-label="Go to homepage">
                    <Logo size={34} />
                </button>

            </div>
        </header>
    );
}
