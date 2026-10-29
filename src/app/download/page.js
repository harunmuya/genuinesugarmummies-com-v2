import Link from 'next/link';
import Logo from '@/components/Logo';

export const metadata = {
    title: 'Download the Android app',
    description: 'Download the Genuine Sugarmummies Android app from the official app domain. See the features, limits, and installation notes before installing.',
    robots: { index: false, follow: false },
};

const FEATURES = [
    {
        icon: 'person_search',
        title: 'Browse and discover',
        detail: 'Explore member profiles and adjust discovery preferences from your account.',
    },
    {
        icon: 'favorite',
        title: 'Matches and messages',
        detail: 'Use matching and direct messaging. Some activity has daily limits or depends on your account plan.',
    },
    {
        icon: 'manage_accounts',
        title: 'Account controls',
        detail: 'Review profile details, privacy preferences, notifications, and support options in one place.',
    },
];

export default function DownloadPage() {
    return (
        <main className="min-h-dvh app-shell px-4 py-5 sm:px-6 sm:py-8">
            <div className="mx-auto w-full max-w-5xl">
                <header className="flex min-h-14 items-center justify-between gap-4 border-b pb-4" style={{ borderColor: 'var(--color-surface-light)' }}>
                    <Link href="/auth/login" aria-label="Genuine Sugarmummies home"><Logo size={34} className="max-w-[min(60vw,250px)] object-contain object-left" /></Link>
                    <Link href="/auth/login" className="inline-flex min-h-10 shrink-0 items-center gap-2 rounded-lg border px-3 text-sm font-bold text-text-secondary hover:text-text-primary" style={{ borderColor: 'var(--color-surface-light)' }}>
                        <span className="material-symbols-outlined text-xl" aria-hidden="true">login</span>
                        Sign in
                    </Link>
                </header>

                <section className="grid gap-8 py-9 sm:py-12 lg:grid-cols-[1.1fr_0.9fr] lg:items-start">
                    <div>
                        <p className="inline-flex items-center gap-2 text-xs font-extrabold uppercase text-primary">
                            <span className="material-symbols-outlined text-lg" aria-hidden="true">android</span>
                            Android app · Version 1.5.1
                        </p>
                        <h1 className="mt-3 max-w-2xl font-display text-3xl font-bold leading-tight text-text-primary sm:text-4xl">Genuine Sugarmummies, on Android</h1>
                        <p className="mt-4 max-w-2xl text-base leading-7 text-text-secondary">
                            The app provides a mobile way to access the same adult introductions service: browse profiles, manage your preferences, and use member features from your phone. It is optional; the website remains available in your browser.
                        </p>

                        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center">
                            <a href="/downloads/genuine-sugar-mummies-1.5.1.apk" className="inline-flex min-h-12 items-center justify-center gap-2 rounded-lg bg-primary px-5 text-sm font-extrabold text-white hover:bg-primary-dark">
                                <span className="material-symbols-outlined" aria-hidden="true">download</span>
                                Download Android app
                            </a>
                            <span className="text-sm text-text-muted">APK · 1.5.1 · Android 7.0 or later</span>
                        </div>

                        <p className="mt-4 max-w-2xl text-sm leading-6 text-text-muted">
                            This is a direct Android download from our official app domain, not a Google Play or Apple App Store listing. There is no iPhone app download at this time; use the website in your mobile browser on iOS.
                        </p>
                    </div>

                    <section aria-labelledby="included-heading" className="border-t pt-2 lg:border-l lg:border-t-0 lg:pl-7 lg:pt-0" style={{ borderColor: 'var(--color-surface-light)' }}>
                        <h2 id="included-heading" className="py-3 text-lg font-bold text-text-primary">What you can use in the app</h2>
                        <ul className="divide-y" style={{ borderColor: 'var(--color-surface-light)' }}>
                            {FEATURES.map((feature) => (
                                <li key={feature.title} className="flex gap-3 py-4">
                                    <span className="material-symbols-outlined mt-0.5 text-2xl text-primary" aria-hidden="true">{feature.icon}</span>
                                    <div>
                                        <h3 className="text-sm font-bold text-text-primary">{feature.title}</h3>
                                        <p className="mt-1 text-sm leading-6 text-text-secondary">{feature.detail}</p>
                                    </div>
                                </li>
                            ))}
                        </ul>
                        <p className="mt-3 text-sm leading-6 text-text-muted">
                            Feature access and availability can vary by account, moderation status, region, and plan. A profile or match does not guarantee identity, compatibility, an introduction, a relationship, or financial support. Review current fees on the <a className="font-bold text-primary underline" href="https://genuinesugarmummies.com/pricing/">pricing page</a> before paying.
                        </p>
                    </section>
                </section>

                <section aria-labelledby="install-heading" className="border-t py-7 sm:py-8" style={{ borderColor: 'var(--color-surface-light)' }}>
                    <div className="grid gap-6 sm:grid-cols-2">
                        <div>
                            <h2 id="install-heading" className="flex items-center gap-2 text-base font-bold text-text-primary">
                                <span className="material-symbols-outlined text-xl text-primary" aria-hidden="true">verified_user</span>
                                Install with care
                            </h2>
                            <p className="mt-2 text-sm leading-6 text-text-secondary">
                                Android may ask permission for your browser to install apps. Only proceed with a file downloaded from this official hostname. If Play Protect displays a warning, cancel and contact the desk; do not disable or bypass device protections.
                            </p>
                        </div>
                        <div>
                            <h2 className="flex items-center gap-2 text-base font-bold text-text-primary">
                                <span className="material-symbols-outlined text-xl text-primary" aria-hidden="true">info</span>
                                Existing installations
                            </h2>
                            <p className="mt-2 text-sm leading-6 text-text-secondary">
                                Version 1.5.1 is signed with a new release key. Android may not install it over an earlier signed copy. Before uninstalling an older app, make sure you know your sign-in details; uninstalling can remove local app data.
                            </p>
                        </div>
                    </div>
                </section>

                <footer className="flex flex-wrap items-center justify-between gap-3 border-t py-5 text-xs text-text-muted" style={{ borderColor: 'var(--color-surface-light)' }}>
                    <span>App v1.5.1 · © GS Agency Holdings LLC</span>
                    <nav aria-label="Support and policies" className="flex flex-wrap gap-x-4 gap-y-2">
                        <Link className="hover:text-text-primary" href="/safety">Safety</Link>
                        <Link className="hover:text-text-primary" href="/privacy">Privacy</Link>
                        <a className="hover:text-text-primary" href="https://genuinesugarmummies.com/contact-us/">Contact the desk</a>
                    </nav>
                </footer>
            </div>
        </main>
    );
}
