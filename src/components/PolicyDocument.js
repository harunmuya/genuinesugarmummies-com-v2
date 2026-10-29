import Link from 'next/link';

export default function PolicyDocument({ title, eyebrow, summary, icon = 'policy', sections = [] }) {
    return (
        <main className="min-h-dvh app-shell px-5 py-8 sm:py-12">
            <article className="mx-auto max-w-4xl">
                <Link href="/auth/login" className="inline-flex min-h-10 items-center gap-2 text-sm font-bold text-primary hover:underline">
                    <span className="material-symbols-outlined" aria-hidden="true">arrow_back</span>
                    Account access
                </Link>
                <header className="mt-8 border-b pb-8 sm:mt-10 sm:pb-10" style={{ borderColor: 'var(--color-surface-light)' }}>
                    <div className="flex items-center gap-3 text-primary">
                        <span className="material-symbols-outlined text-3xl" aria-hidden="true">{icon}</span>
                        <p className="text-xs font-extrabold uppercase tracking-wider">{eyebrow}</p>
                    </div>
                    <h1 className="mt-4 text-3xl font-extrabold leading-tight text-text-primary sm:text-4xl">{title}</h1>
                    <p className="mt-4 max-w-3xl text-base leading-7 text-text-secondary sm:text-lg sm:leading-8">{summary}</p>
                    <p className="mt-4 text-sm text-text-muted">Last updated 29 October 2026</p>
                </header>
                <div>
                    {sections.map((section, index) => (
                        <section key={section.title} className="grid gap-3 border-b py-7 sm:grid-cols-[52px_minmax(0,1fr)] sm:gap-5 sm:py-8" style={{ borderColor: 'var(--color-surface-light)' }}>
                            <span className="material-symbols-outlined flex h-11 w-11 items-center justify-center rounded-lg bg-primary/10 text-primary" aria-hidden="true">{section.icon}</span>
                            <div>
                                <p className="text-xs font-bold text-text-muted">{String(index + 1).padStart(2, '0')}</p>
                                <h2 className="mt-1 text-xl font-extrabold text-text-primary">{section.title}</h2>
                                <div className="mt-3 space-y-3 text-base leading-7 text-text-secondary sm:leading-8">
                                    {section.paragraphs.map((paragraph, paragraphIndex) => <p key={paragraphIndex}>{paragraph}</p>)}
                                </div>
                            </div>
                        </section>
                    ))}
                </div>
                <footer className="flex flex-col gap-4 py-8 sm:flex-row sm:items-center sm:justify-between">
                    <p className="max-w-2xl text-sm leading-6 text-text-muted">Questions or a concern about your account? The support page explains how to contact the desk and submit a report.</p>
                    <Link href="/contact#report" className="inline-flex min-h-11 shrink-0 items-center justify-center gap-2 rounded-lg border px-4 py-2 text-sm font-bold text-text-primary hover:border-primary" style={{ borderColor: 'var(--color-surface-light)' }}>
                        <span className="material-symbols-outlined" aria-hidden="true">support_agent</span>
                        Contact support
                    </Link>
                </footer>
            </article>
        </main>
    );
}
