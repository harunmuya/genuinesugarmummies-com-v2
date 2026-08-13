import Link from 'next/link';

export const metadata = {
    title: 'Safety Center - Genuine Sugar Mummies',
};

export default function SafetyPage() {
    return (
        <main className="min-h-dvh px-5 py-8 app-shell">
            <section className="mx-auto max-w-2xl space-y-5 rounded-2xl p-5" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <Link href="/auth/login" className="text-xs font-black text-primary">Back to login</Link>
                <h1 className="text-2xl font-black text-text-primary">Safety Center</h1>
                <div className="space-y-3 text-sm leading-relaxed text-text-secondary">
                    <p><b>Stay inside official support:</b> Use the app inbox and official admin channels for payment/package help.</p>
                    <p><b>Protect your money:</b> Do not send money to strangers claiming guaranteed meetings, jobs, gifts, or verification shortcuts.</p>
                    <p><b>Protect your identity:</b> Never share passwords, reset codes, full ID images, or private documents in chat.</p>
                    <p><b>Report danger:</b> Report scams, fake profiles, threats, harassment, underage claims, and suspicious payment requests.</p>
                </div>
            </section>
        </main>
    );
}
