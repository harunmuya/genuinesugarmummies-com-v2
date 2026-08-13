import Link from 'next/link';

export const metadata = {
    title: 'Community Guidelines - Genuine Sugar Mummies',
};

export default function CommunityGuidelinesPage() {
    return (
        <main className="min-h-dvh px-5 py-8 app-shell">
            <section className="mx-auto max-w-2xl space-y-5 rounded-2xl p-5" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <Link href="/auth/login" className="text-xs font-black text-primary">Back to login</Link>
                <h1 className="text-2xl font-black text-text-primary">Community Guidelines</h1>
                <div className="space-y-3 text-sm leading-relaxed text-text-secondary">
                    <p>Be respectful, honest, and adult. Use real photos, clear profile details, and polite communication.</p>
                    <p>No impersonation, fake documents, blackmail, spam, harassment, hate, explicit illegal content, or underage activity.</p>
                    <p>Members can be hidden, suspended, or banned when safety rules are broken. Verification badges can be revoked if documents or photos become unreliable.</p>
                </div>
            </section>
        </main>
    );
}
