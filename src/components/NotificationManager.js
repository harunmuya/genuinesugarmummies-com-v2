'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { Bell } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

function formatBadge(count) {
    if (!count) return '';
    return count > 99 ? '99+' : String(count);
}

async function getNativeNotifications() {
    try {
        const [{ Capacitor }, { LocalNotifications }] = await Promise.all([
            import('@capacitor/core'),
            import('@capacitor/local-notifications'),
        ]);
        if (!Capacitor.isNativePlatform?.()) return null;
        return LocalNotifications;
    } catch {
        return null;
    }
}

export default function NotificationManager() {
    const { settings, user, guest, activity, messages } = useAuth();
    const permissionRef = useRef('default');
    const [showPrompt, setShowPrompt] = useState(false);

    const unreadCount = useMemo(() => {
        const unreadAlerts = (activity || []).filter((item) => !item.read).length;
        const unreadMessages = (messages || []).filter((item) => !item.read).length;
        return Math.min(99, unreadAlerts + unreadMessages);
    }, [activity, messages]);

    useEffect(() => {
        if (typeof window === 'undefined') return;
        const browserPermission = 'Notification' in window ? Notification.permission : 'default';
        permissionRef.current = browserPermission;
        setShowPrompt(Boolean(user && !guest && settings.notifications && browserPermission === 'default'));
    }, [user, guest, settings.notifications]);

    useEffect(() => {
        if (typeof navigator === 'undefined') return;
        const count = Math.max(0, unreadCount || 0);
        if ('setAppBadge' in navigator) {
            if (count > 0) navigator.setAppBadge(count).catch(() => {});
            else navigator.clearAppBadge?.().catch(() => {});
        }
        if (navigator.serviceWorker?.controller) {
            navigator.serviceWorker.controller.postMessage({ type: 'GS_BADGE_COUNT', count });
        }
        try { localStorage.setItem('gscom_badge_count', JSON.stringify({ count, label: formatBadge(count), at: Date.now() })); } catch {}
    }, [unreadCount]);

    async function requestPermission() {
        if (typeof window === 'undefined') return;
        try {
            const nativeNotifications = await getNativeNotifications();
            if (nativeNotifications) {
                const nativePerm = await nativeNotifications.requestPermissions();
                permissionRef.current = nativePerm.display === 'granted' ? 'granted' : 'default';
            }
            if ('Notification' in window && Notification.permission !== 'granted') {
                const perm = await Notification.requestPermission();
                permissionRef.current = perm;
            }
            setShowPrompt(false);
            if (permissionRef.current === 'granted') {
                window.dispatchEvent(new CustomEvent('gs-notification', {
                    detail: { title: 'Notifications enabled', body: 'You will see account updates, matches, and admin messages here.', count: unreadCount },
                }));
            }
        } catch {
            setShowPrompt(false);
        }
    }

    useEffect(() => {
        if (typeof window === 'undefined') return;

        const handleNotification = async (e) => {
            if (!settings.notifications) return;
            const { title, body, image, icon, count } = e.detail || {};
            if (!title) return;
            if (document.visibilityState === 'visible') return;

            const badgeCount = Math.min(99, Number(count || unreadCount || 1));
            const nativeNotifications = await getNativeNotifications();
            if (nativeNotifications) {
                const perm = await nativeNotifications.checkPermissions().catch(() => ({ display: 'prompt' }));
                if (perm.display === 'granted') {
                    await nativeNotifications.schedule({
                        notifications: [{
                            id: Math.floor(Date.now() % 2147483647),
                            title,
                            body: body || '',
                            largeIcon: icon || '/icons/icon-192.png',
                            iconColor: '#0F766E',
                            extra: { url: '/alerts', count: badgeCount, label: formatBadge(badgeCount) },
                        }],
                    }).catch(() => {});
                    return;
                }
            }

            if (!('Notification' in window) || Notification.permission !== 'granted') return;
            const options = {
                body: body || '',
                icon: icon || '/icons/icon-192.png',
                badge: '/icons/icon-192.png',
                image: image || undefined,
                tag: 'gs-account-update',
                renotify: true,
                vibrate: [160, 80, 160],
                silent: false,
                data: { url: '/alerts', count: badgeCount, label: formatBadge(badgeCount) },
            };

            try {
                const reg = await navigator.serviceWorker?.ready;
                if (reg?.showNotification) {
                    await reg.showNotification(title, options);
                    return;
                }
                const notification = new Notification(title, options);
                notification.onclick = () => {
                    window.focus();
                    notification.close();
                };
                setTimeout(() => notification.close(), 8000);
            } catch {}
        };

        window.addEventListener('gs-notification', handleNotification);
        return () => window.removeEventListener('gs-notification', handleNotification);
    }, [settings.notifications, unreadCount]);

    if (!showPrompt) return null;

    return (
        <button
            type="button"
            onClick={requestPermission}
            className="fixed right-4 bottom-24 z-[70] flex items-center gap-2 rounded-full px-4 py-3 text-xs font-black text-white shadow-xl gradient-primary"
            aria-label="Enable notifications"
        >
            <span className="relative flex h-5 w-5 items-center justify-center">
                <Bell size={18} />
                {unreadCount > 0 && <span className="absolute -right-2 -top-2 min-w-4 h-4 rounded-full bg-pink-500 px-1 text-[9px] leading-4">{formatBadge(unreadCount)}</span>}
            </span>
            Enable alerts
        </button>
    );
}

