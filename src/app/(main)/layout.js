import BottomNav from '@/components/BottomNav';
import TopBar from '@/components/TopBar';
import AuthGuard from '@/components/AuthGuard';
import IncomingCallManager from '@/components/IncomingCallManager';
import UpdatePrompt from '@/components/UpdatePrompt';

export default function MainLayout({ children }) {
    return (
        <AuthGuard>
            <div className="min-h-dvh app-shell pb-20">
                <TopBar />
                <main className="app-main">
                    {children}
                </main>
                <IncomingCallManager />
                {/*
                  Only renders inside the Android shell, and only when that
                  shell is behind the current release. On the web, and on an
                  up-to-date app, it returns null.
                */}
                <UpdatePrompt />
                <BottomNav />
            </div>
        </AuthGuard>
    );
}
