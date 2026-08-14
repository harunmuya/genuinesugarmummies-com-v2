'use client';

import PageHeader from '@/components/PageHeader';
import AccountActivityPanel from '@/components/AccountActivityPanel';

/**
 * Likes, views, followers and following.
 *
 * This was one band inside the single account page, below photos and above
 * settings, so seeing who liked you meant scrolling past everything else. It is
 * its own screen now, reached from the account menu.
 */
export default function ActivityPage() {
    return (
        <div className="px-4 pb-8 pt-4">
            <PageHeader title="Activity" subtitle="Who likes, views and follows you" />
            <AccountActivityPanel />
        </div>
    );
}
