'use client';

import Link from 'next/link';
import { ChevronRight } from 'lucide-react';

/**
 * Grouped menu rows, the way every phone app presents an account area.
 *
 * The account screen was a four-column grid of thirteen icon tiles, and seven
 * of them were anchors — `href: '#profile-info'`, `href: '#photos'` — so
 * tapping one scrolled further down the same page. That is why everything was
 * stacked into one enormous screen: profile fields, photos, verification,
 * stories, activity, packages, settings, support and sign-out all at once, with
 * no way to be anywhere in particular and no way back.
 *
 * A tile also has room for one word, so thirteen of them read as "Edit Photos
 * Messages Alerts Saved Pro Verify Privacy Status Prefs Phone Support Wallet" —
 * a wall of nouns that says nothing about what is inside any of them.
 *
 * A row has room for a label, the current value, and a chevron that promises
 * somewhere to go. `value` is the point: "Membership — FREE" answers the
 * question without anybody tapping anything.
 */

export function MenuGroup({ title, children }) {
    return (
        <section className="space-y-2">
            {title && (
                <h2 className="px-1 text-[11px] font-semibold uppercase tracking-wide text-text-muted">
                    {title}
                </h2>
            )}
            <div
                className="overflow-hidden rounded-xl"
                style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}
            >
                {children}
            </div>
        </section>
    );
}

/**
 * One row. Either `href` or `onClick`, never both.
 *
 * @param {object}   props
 * @param {Function} props.icon     lucide icon component
 * @param {string}   props.label
 * @param {string}   [props.value]  current setting, shown greyed on the right
 * @param {number}   [props.badge]  unread count; hidden when zero
 * @param {string}   [props.tone]   'danger' for destructive rows
 */
export function MenuRow({ icon: Icon, label, value, badge, href, onClick, tone }) {
    const danger = tone === 'danger';

    const body = (
        <>
            <span
                aria-hidden
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
                style={{ background: danger ? 'rgba(255,77,106,0.12)' : 'rgba(20,224,200,0.10)' }}
            >
                <Icon size={18} className={danger ? 'text-danger' : 'text-primary'} />
            </span>

            <span className={`min-w-0 flex-1 truncate text-left text-[15px] font-medium ${danger ? 'text-danger' : 'text-text-primary'}`}>
                {label}
            </span>

            {Number(badge) > 0 && (
                <span className="shrink-0 rounded-full bg-danger px-2 py-0.5 text-[11px] font-bold text-white">
                    {badge > 99 ? '99+' : badge}
                </span>
            )}

            {value && (
                <span className="max-w-[42%] shrink-0 truncate text-right text-[13px] text-text-muted">
                    {value}
                </span>
            )}

            {!danger && <ChevronRight size={18} className="shrink-0 text-text-muted" />}
        </>
    );

    /*
      min-h-14 rather than a fixed height: at large text sizes a fixed row
      clips its own label, and this is the screen people go to in order to
      change things when something is hard to read.
    */
    const className = 'flex min-h-14 w-full items-center gap-3 px-4 py-3 text-left '
        + 'border-b border-[color:var(--color-surface)] last:border-b-0 active:bg-surface';

    if (href) return <Link href={href} className={className}>{body}</Link>;
    return <button type="button" onClick={onClick} className={className}>{body}</button>;
}
