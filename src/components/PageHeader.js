'use client';

import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';

/**
 * The header on a sub-page: back arrow, title, optional action.
 *
 * Everything in the account area used to live on one scrolling page reached by
 * anchor links, so there was nothing to go back to and nowhere that announced
 * where you were. Splitting it into real pages only helps if each one says what
 * it is and offers a way out.
 *
 * back() rather than a fixed href, so arriving from a menu, a deep link or a
 * notification all return somewhere sensible. `fallback` covers the case where
 * there is no history to go back to — opening a notification in a fresh tab —
 * which would otherwise leave the arrow doing nothing.
 */
export default function PageHeader({ title, subtitle, action, fallback = '/profile' }) {
    const router = useRouter();

    const goBack = () => {
        if (typeof window !== 'undefined' && window.history.length > 1) router.back();
        else router.push(fallback);
    };

    return (
        <header
            className="sticky top-0 z-30 -mx-4 mb-4 flex items-center gap-3 px-4 py-3 backdrop-blur"
            style={{
                background: 'color-mix(in srgb, var(--color-bg-dark) 88%, transparent)',
                borderBottom: 'var(--card-border)',
            }}
        >
            <button
                type="button"
                onClick={goBack}
                aria-label="Back"
                // 44px, the minimum reliable touch target.
                className="-ml-2 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-text-primary active:bg-surface"
            >
                <ArrowLeft size={22} />
            </button>

            <div className="min-w-0 flex-1">
                <h1 className="truncate font-display text-lg font-bold text-text-primary">{title}</h1>
                {subtitle && <p className="truncate text-xs text-text-muted">{subtitle}</p>}
            </div>

            {action}
        </header>
    );
}
