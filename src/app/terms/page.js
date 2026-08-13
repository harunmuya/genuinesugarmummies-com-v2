import Link from 'next/link';

export const metadata = {
    title: 'Terms and Conditions - Genuine Sugar Mummies',
};

export default function TermsPage() {
    return (
        <main className="min-h-dvh px-5 py-8 app-shell">
            <section className="mx-auto max-w-2xl space-y-5 rounded-2xl p-5" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <Link href="/auth/login" className="text-xs font-black text-primary">Back to login</Link>
                <h1 className="text-2xl font-black text-text-primary">Terms and Conditions</h1>
                <p className="text-sm leading-relaxed text-text-secondary">Genuine Sugar Mummies is an adults-only social dating platform. You must be 18 years or older, use your own identity, and follow all safety, privacy, and payment rules.</p>
                <div className="space-y-3 text-sm leading-relaxed text-text-secondary">
                    <p><b>Account rules:</b> Create only one real account, upload your own profile photo, and keep your information accurate. Accounts without a real photo may be hidden until completed.</p>
                    <p><b>Verification:</b> Admin only approves or rejects verification badges. A badge does not guarantee a relationship, payment, meeting, or user behavior.</p>
                    <p><b>Packages:</b> Paid packages are reviewed by admin after payment reference submission. False payment claims may lead to suspension or ban.</p>
                    <p><b>Conduct:</b> Scam attempts, harassment, impersonation, underage activity, illegal content, threats, and abusive messages are not allowed.</p>
                    <p><b>Enforcement:</b> Admin may hide, suspend, restore, or ban accounts to protect members and the website.</p>
                </div>
            </section>
        </main>
    );
}
