import Link from 'next/link';

export const metadata = { title: 'Contact Support - Genuine Sugarmummies' };

const SUPPORT_TOPICS = [
    ['account_circle', 'Account access', 'For sign-in, username, profile edits, visibility, or account deletion questions, sign in and open Profile, then choose Support. Include the email linked to the account, but never include its password or reset code.'],
    ['payments', 'Packages and payments', 'For a package or local introduction payment, include the transaction reference, amount, payment method, and approximate date in a signed-in support ticket. Do not send a mobile-money PIN or one-time code. Transaction references are checked against payment records by an administrator.'],
    ['verified_user', 'Profile review', 'For a publication, verification, or profile-correction question, identify the account and explain what should be reviewed. Do not send another person\'s identity documents or images unless you are authorized to provide them.'],
    ['report', 'Report a safety concern', 'Report suspected fraud, impersonation, harassment, threats, an underage account, non-consensual images, or suspicious payment instructions. Share relevant context privately through a support ticket. If there is immediate danger, contact local emergency services or someone you trust first.'],
];

export default function ContactPage() {
    return (
        <main className="min-h-dvh app-shell px-5 py-8 sm:py-12">
            <article className="mx-auto max-w-4xl">
                <Link href="/auth/login" className="inline-flex min-h-10 items-center gap-2 text-sm font-bold text-primary hover:underline">
                    <span className="material-symbols-outlined" aria-hidden="true">arrow_back</span>Account access
                </Link>
                <header className="mt-8 border-b pb-8 sm:mt-10 sm:pb-10" style={{ borderColor: 'var(--color-surface-light)' }}>
                    <div className="flex items-center gap-3 text-primary"><span className="material-symbols-outlined text-3xl" aria-hidden="true">support_agent</span><p className="text-xs font-extrabold uppercase tracking-wider">Help from the desk</p></div>
                    <h1 className="mt-4 text-3xl font-extrabold leading-tight text-text-primary sm:text-4xl">Contact support</h1>
                    <p className="mt-4 max-w-3xl text-base leading-7 text-text-secondary sm:text-lg sm:leading-8">Support requests are submitted from your account so the desk can connect the question to the right member record. Choose the topic below and include only the details needed to understand the issue.</p>
                </header>
                <div>
                    {SUPPORT_TOPICS.map(([icon, title, content], index) => (
                        <section id={title === 'Report a safety concern' ? 'report' : undefined} key={title} className="grid scroll-mt-8 gap-3 border-b py-7 sm:grid-cols-[52px_minmax(0,1fr)] sm:gap-5 sm:py-8" style={{ borderColor: 'var(--color-surface-light)' }}>
                            <span className="material-symbols-outlined flex h-11 w-11 items-center justify-center rounded-lg bg-primary/10 text-primary" aria-hidden="true">{icon}</span>
                            <div><p className="text-xs font-bold text-text-muted">{String(index + 1).padStart(2, '0')}</p><h2 className="mt-1 text-xl font-extrabold text-text-primary">{title}</h2><p className="mt-3 text-base leading-7 text-text-secondary sm:leading-8">{content}</p></div>
                        </section>
                    ))}
                </div>
                <div className="flex flex-col gap-4 py-8 sm:flex-row sm:items-center sm:justify-between">
                    <p className="max-w-2xl text-sm leading-6 text-text-muted">Once signed in, open <strong className="text-text-secondary">Profile &gt; Support</strong> and choose the relevant service. Do not use this app for emergencies.</p>
                    <Link href="/auth/login" className="inline-flex min-h-11 shrink-0 items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-bold text-white gradient-primary"><span className="material-symbols-outlined" aria-hidden="true">login</span>Sign in to contact support</Link>
                </div>
            </article>
        </main>
    );
}
