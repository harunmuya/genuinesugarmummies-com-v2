import Link from 'next/link';

export const metadata = {
    title: 'Privacy Policy - Genuine Sugar Mummies',
};

export default function PrivacyPage() {
    return (
        <main className="min-h-dvh px-5 py-8 app-shell">
            <section className="mx-auto max-w-2xl space-y-5 rounded-2xl p-5" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <Link href="/auth/login" className="text-xs font-black text-primary">Back to login</Link>
                <h1 className="text-2xl font-black text-text-primary">Privacy Policy</h1>
                <div className="space-y-3 text-sm leading-relaxed text-text-secondary">
                    <p>We collect account details, profile information, photos, verification submissions, messages, package requests, support tickets, and safety reports needed to run the website.</p>
                    <p>Profile information marked public can appear in Members. Phone numbers are hidden unless package rules allow reveal. Verification documents are used for badge review.</p>
                    <p>We use account data to provide login, profile display, messaging, packages, notifications, moderation, fraud prevention, and support.</p>
                    <p>Do not upload another person's private documents or photos. Contact support if you need account correction or deletion help.</p>
                </div>
            </section>
        </main>
    );
}
