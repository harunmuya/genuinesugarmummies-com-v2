'use client';

import Link from 'next/link';
import { Bookmark, Compass } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import PageHeader from '@/components/PageHeader';
import UserAvatar from '@/components/UserAvatar';

/**
 * Profiles and posts this account has saved.
 *
 * Previously a band on the single account page whose entire content was the
 * sentence "Profiles and featured posts you save will appear here", with an
 * Open link that scrolled somewhere else. Saved items now have a screen, and
 * an empty state that says how to fill it.
 */
export default function SavedPage() {
    const { saved } = useAuth();
    const items = saved || [];

    return (
        <div className="px-4 pb-8 pt-4">
            <PageHeader
                title="Saved"
                subtitle={items.length ? `${items.length} saved` : 'Profiles and posts you keep'}
            />

            {items.length === 0 ? (
                <section className="space-y-4 py-12 text-center">
                    <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
                        <Bookmark size={28} className="text-primary" />
                    </div>
                    <div className="space-y-1.5">
                        <h2 className="font-display text-lg font-bold text-text-primary">Nothing saved yet</h2>
                        <p className="mx-auto max-w-xs text-sm text-text-muted">
                            Tap the bookmark on any profile to keep it here, so you can come back to
                            it without searching again.
                        </p>
                    </div>
                    <Link
                        href="/members"
                        className="inline-flex h-12 items-center justify-center gap-2 rounded-xl bg-primary px-6 font-bold text-bg-dark"
                    >
                        <Compass size={18} /> Browse members
                    </Link>
                </section>
            ) : (
                <section className="space-y-2.5">
                    {items.map((item) => (
                        <Link
                            key={item.wpId || item.id}
                            href={item.id ? `/members/${item.id}` : `/discover/${item.wpId}`}
                            className="flex items-center gap-3 rounded-xl p-3"
                            style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}
                        >
                            <UserAvatar name={item.name || 'Saved'} src={item.imageUrl} size={48} />
                            <div className="min-w-0 flex-1">
                                <p className="truncate font-semibold text-text-primary">{item.name || 'Saved profile'}</p>
                                {item.savedAt && (
                                    <p className="text-xs text-text-muted">
                                        Saved {new Date(item.savedAt).toLocaleDateString()}
                                    </p>
                                )}
                            </div>
                        </Link>
                    ))}
                </section>
            )}
        </div>
    );
}
