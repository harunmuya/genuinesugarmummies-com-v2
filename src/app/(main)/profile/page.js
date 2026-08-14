'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
    Bell, Bookmark, Camera, Gem, Headphones, Heart, Lock, LogOut, MessageCircle,
    Phone, ShieldCheck, SlidersHorizontal, Sparkles, Trash2, UserCog, Wallet, Eye,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';
import VerifiedBadge from '@/components/VerifiedBadge';
import { MenuGroup, MenuRow } from '@/components/MenuList';

/**
 * The account menu.
 *
 * What was here was a four-column grid of thirteen icon tiles above every
 * section of the account stacked into one page: profile fields, photos,
 * verification, stories, activity, package, settings, support and sign-out, all
 * rendered at once. Seven of the tiles were anchors — href: '#profile-info',
 * href: '#photos' — so tapping one scrolled further down the same screen rather
 * than going anywhere. There was no sense of place and nothing to go back to.
 *
 * This is a menu. Each row leads somewhere, and carries the current value where
 * there is one, so "Membership — FREE" and "Verification — Not verified" answer
 * themselves without a tap.
 *
 * The old page is not deleted: it is /profile/details, still reachable, so
 * nothing that worked has been taken away while the sections move across.
 */
export default function AccountMenuPage() {
    const router = useRouter();
    const {
        user, likes, matches, saved, messages, verificationStatus, signOut,
    } = useAuth();

    const verified = verificationStatus === 'verified' || user?.verified;
    const tier = String(user?.subscription_tier || 'free').toUpperCase();
    const unread = (messages || []).filter((message) => !message.read).length;

    /*
      Counts come from context rather than a fetch. This screen is opened
      constantly, and it used to be one more thing hitting the API on every
      visit; the numbers here are already loaded for other screens.
    */
    const stat = (value) => String(value ?? 0);

    return (
        <div className="space-y-5 px-4 pb-8 pt-4">
            {/* Who you are, and the one action most people came for. */}
            <section
                className="flex items-center gap-4 rounded-xl p-4"
                style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}
            >
                <Link href="/profile/details" className="shrink-0">
                    <UserAvatar name={user?.display_name || user?.name || 'You'} src={user?.avatarUrl || user?.avatar_url} size={64} />
                </Link>
                <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-1.5">
                        <h1 className="truncate font-display text-xl font-bold text-text-primary">
                            {user?.display_name || user?.name || 'Your account'}
                        </h1>
                        {verified && <VerifiedBadge size={16} />}
                    </div>
                    <p className="truncate text-xs text-text-muted">{user?.email}</p>
                    <span
                        className="mt-1.5 inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold"
                        style={{ background: 'rgba(20,224,200,0.12)', color: 'var(--color-primary)' }}
                    >
                        <Gem size={10} /> {tier}
                    </span>
                </div>
            </section>

            {/* The four numbers the old screen led with, kept because they are
                genuinely the summary, but as links rather than decoration. */}
            <section className="grid grid-cols-4 gap-2">
                {[
                    { label: 'Likes', value: stat(likes?.length), href: '/profile/activity' },
                    { label: 'Matches', value: stat(matches?.length), href: '/matches' },
                    { label: 'Saved', value: stat(saved?.length), href: '/profile/saved' },
                    { label: 'Messages', value: stat(messages?.length), href: '/messages' },
                ].map((item) => (
                    <Link
                        key={item.label}
                        href={item.href}
                        className="rounded-xl px-2 py-3 text-center"
                        style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}
                    >
                        <p className="font-display text-lg font-bold text-text-primary">{item.value}</p>
                        <p className="text-[11px] text-text-muted">{item.label}</p>
                    </Link>
                ))}
            </section>

            <MenuGroup title="Profile">
                <MenuRow icon={UserCog} label="Edit profile" href="/profile/details" />
                <MenuRow icon={Camera} label="Photos" href="/profile/details#photos" />
                <MenuRow
                    icon={ShieldCheck}
                    label="Verification"
                    value={verified ? 'Verified' : (verificationStatus === 'pending' ? 'In review' : 'Not verified')}
                    href="/profile/details#verification"
                />
                <MenuRow icon={SlidersHorizontal} label="Preferences" href="/profile/details" />
                <MenuRow icon={Sparkles} label="My stories" href="/profile/details#stories" />
            </MenuGroup>

            <MenuGroup title="Activity">
                <MenuRow icon={Heart} label="Likes and views" href="/profile/activity" />
                <MenuRow icon={MessageCircle} label="Messages" badge={unread} href="/messages" />
                <MenuRow icon={Bell} label="Alerts" href="/alerts" />
                <MenuRow icon={Bookmark} label="Saved" href="/profile/saved" />
            </MenuGroup>

            <MenuGroup title="Membership">
                <MenuRow icon={Gem} label="Packages" value={tier} href="/packages" />
                <MenuRow icon={Wallet} label="Wallet" href="/wallet" />
                <MenuRow icon={Phone} label="Phone reveal" href="/packages" />
            </MenuGroup>

            <MenuGroup title="Settings">
                <MenuRow icon={Lock} label="Privacy" href="/profile/details#privacy" />
                <MenuRow icon={Eye} label="Public status" href="/profile/details#status" />
                <MenuRow icon={Bell} label="Notifications" href="/profile/details#privacy" />
            </MenuGroup>

            <MenuGroup title="Help">
                <MenuRow icon={Headphones} label="Support" href="/profile/details#support" />
            </MenuGroup>

            <MenuGroup>
                <MenuRow
                    icon={LogOut}
                    label="Sign out"
                    tone="danger"
                    onClick={async () => { await signOut?.(); router.push('/auth/login'); }}
                />
                <MenuRow icon={Trash2} label="Delete account" tone="danger" href="/profile/details#danger" />
            </MenuGroup>

            <p className="pb-2 text-center text-[11px] text-text-muted">GS Global</p>
        </div>
    );
}
