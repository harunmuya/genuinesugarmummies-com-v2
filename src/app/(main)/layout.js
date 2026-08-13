import BottomNav from '@/components/BottomNav';
import TopBar from '@/components/TopBar';
import AuthGuard from '@/components/AuthGuard';
import IncomingCallManager from '@/components/IncomingCallManager';

export default function MainLayout({ children }) {
    return (
        <AuthGuard>
            <div className="min-h-dvh app-shell pb-20">
                <TopBar />
                <main className="app-main">
                    {children}
                </main>
                <IncomingCallManager />
                <BottomNav />
            </div>
        </AuthGuard>
    );
}
