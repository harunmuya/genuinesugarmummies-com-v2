'use client';

import { useEffect, useState } from 'react';
import { ArrowDownToLine, X, Sparkles } from 'lucide-react';

/**
 * Tells members running an old Android shell that a newer one exists.
 *
 * The web layer redeploys and reaches everyone on the next reload. The native
 * shell does not: it only changes when somebody installs an APK. Nothing told
 * anybody that, so versionCode 3 has been sitting on phones with no camera or
 * microphone permission and no way to hear about the build that has them.
 *
 * The awkward case is that same versionCode 3, because it does not announce
 * itself. Only version 4 onwards appends `GSGlobal/<code>` to the User-Agent,
 * so the rule has to be:
 *
 *   running in the app, no GSGlobal token   ->  old shell, offer the update
 *   GSGlobal/N, N < current                 ->  offer the update
 *   GSGlobal/N, N >= current                ->  say nothing
 *   not in the app at all                   ->  say nothing
 *
 * That last one matters. This is a website as well as an app, and offering an
 * APK to somebody reading on a laptop is noise.
 */

const DISMISS_KEY = 'gs_update_dismissed_for';

function shellVersion() {
    if (typeof navigator === 'undefined') return null;
    const match = navigator.userAgent.match(/GSGlobal\/(\d+)/);
    return match ? Number(match[1]) : null;
}

function insideApp() {
    if (typeof window === 'undefined') return false;
    // Capacitor exposes this in the WebView it controls, and nowhere else.
    const cap = window.Capacitor;
    if (cap?.isNativePlatform?.()) return true;
    return Boolean(cap?.platform && cap.platform !== 'web');
}

export default function UpdatePrompt() {
    const [release, setRelease] = useState(null);
    const [dismissed, setDismissed] = useState(true);

    useEffect(() => {
        if (!insideApp()) return;

        let alive = true;
        (async () => {
            try {
                const res = await fetch('/api/app-version');
                if (!res.ok) return;
                const data = await res.json();
                if (!alive || !data?.versionCode) return;

                const installed = shellVersion();
                // null means a shell too old to announce itself, which is
                // precisely the one that needs updating.
                const behind = installed === null || installed < data.versionCode;
                if (!behind) return;

                // Dismissal is remembered per release, so declining today does
                // not silence the next one.
                let seen = null;
                try { seen = window.localStorage.getItem(DISMISS_KEY); } catch { /* private mode */ }
                setRelease(data);
                setDismissed(!data.mandatory && seen === String(data.versionCode));
            } catch { /* offline; try again next launch */ }
        })();

        return () => { alive = false; };
    }, []);

    if (!release || dismissed) return null;

    const close = () => {
        try { window.localStorage.setItem(DISMISS_KEY, String(release.versionCode)); } catch {}
        setDismissed(true);
    };

    return (
        <div className="fixed inset-0 z-[90] flex items-end justify-center bg-black/60 px-4 pb-24 backdrop-blur-sm sm:items-center sm:pb-4">
            <div className="w-full max-w-sm overflow-hidden rounded-[20px] bg-bg-card shadow-2xl">
                <div className="gradient-primary p-5 text-white">
                    <div className="flex items-start gap-3">
                        <div className="rounded-xl bg-white/15 p-2"><Sparkles size={20} /></div>
                        <div className="min-w-0 flex-1">
                            <p className="text-[11px] font-bold uppercase tracking-wide text-white/75">
                                Update available
                            </p>
                            <h2 className="font-display text-xl font-bold">
                                GS Global {release.versionName}
                            </h2>
                        </div>
                        {!release.mandatory && (
                            <button
                                onClick={close}
                                aria-label="Not now"
                                className="-mr-1 -mt-1 rounded-lg p-2 text-white/80 hover:bg-white/10"
                            >
                                <X size={18} />
                            </button>
                        )}
                    </div>
                </div>

                <div className="space-y-4 p-5">
                    <ul className="space-y-2">
                        {(release.notes || []).map((note) => (
                            <li key={note} className="flex gap-2 text-sm text-text-secondary">
                                <span aria-hidden className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                                {note}
                            </li>
                        ))}
                    </ul>

                    {/*
                      Said plainly, because the alternative is a member hitting
                      a Play Protect warning with no idea whether to trust it
                      and giving up on the install.
                    */}
                    <p className="rounded-xl bg-surface p-3 text-xs text-text-muted">
                        The download is from our own site, so Android will ask you to allow
                        installing it. If you see a Play Protect warning, choose
                        <span className="font-semibold text-text-secondary"> Install anyway</span>.
                        Your account and messages stay exactly as they are.
                    </p>

                    <a
                        href={release.url}
                        className="flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 font-bold text-bg-dark"
                    >
                        <ArrowDownToLine size={18} /> Download update
                    </a>

                    {!release.mandatory && (
                        <button
                            onClick={close}
                            className="h-11 w-full rounded-xl text-sm font-semibold text-text-muted"
                        >
                            Not now
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}
