import BottomNav from '@/components/BottomNav';
import TopBar from '@/components/TopBar';
import AuthGuard from '@/components/AuthGuard';
import IncomingCallManager from '@/components/IncomingCallManager';
import UpdatePrompt from '@/components/UpdatePrompt';

export default function MainLayout({ children }) {
    return (
        <AuthGuard>
            <div className="min-h-dvh app-shell pb-20 min-[900px]:pb-0">
                <TopBar />
                <main className="app-main">
                    {children}
                </main>
                <footer className="mx-auto w-full max-w-5xl px-4 pb-24 pt-5 text-center text-[11px] text-text-muted min-[900px]:pb-5">
                    <nav aria-label="Legal and safety" className="mb-2 flex flex-wrap justify-center gap-x-4 gap-y-2">
                        <a href="/community-guidelines" className="hover:text-text-primary">Community guidelines</a>
                        <a href="/safety" className="hover:text-text-primary">Safety</a>
                        <a href="/privacy" className="hover:text-text-primary">Privacy</a>
                        <a href="/terms" className="hover:text-text-primary">Terms</a>
                    </nav>
                    <p>App v1.5.1 · © GS Agency Holdings LLC</p>
                </footer>
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
