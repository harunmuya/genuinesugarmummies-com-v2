import BottomNav from '@/components/BottomNav';
import TopBar from '@/components/TopBar';
import AuthGuard from '@/components/AuthGuard';

export default function MainLayout({ children }) {
    return (
        <AuthGuard>
            <div className="min-h-dvh bg-white pb-20">
                <TopBar />
                <main className="max-w-md mx-auto">
                    {children}
                </main>
                <BottomNav />
            </div>
        </AuthGuard>
    );
}
