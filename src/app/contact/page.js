import Link from 'next/link';

export const metadata = {
    title: 'Contact Support - Genuine Sugar Mummies',
};

export default function ContactPage() {
    return (
        <main className="min-h-dvh px-5 py-8 app-shell">
            <section className="mx-auto max-w-2xl space-y-5 rounded-2xl p-5" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <Link href="/auth/login" className="text-xs font-black text-primary">Back to login</Link>
                <h1 className="text-2xl font-black text-text-primary">Contact Support</h1>
                <div className="space-y-3 text-sm leading-relaxed text-text-secondary">
                    <p>For account, verification, package, payment, safety, or technical help, sign in and open Profile &gt; Support so your request is saved to your account.</p>
                    <p>For urgent admin connection help, use the official Admin Mary G support details shown inside the app. Always include your account email and payment reference when asking about packages.</p>
                </div>
                <Link href="/auth/login" className="inline-flex rounded-2xl px-4 py-3 text-sm font-black text-white gradient-primary">Sign in for support</Link>
            </section>
        </main>
    );
}
