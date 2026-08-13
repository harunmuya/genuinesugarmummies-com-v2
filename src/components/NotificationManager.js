'use client';

import { useEffect, useMemo, useRef } from 'react';
import { useAuth } from '@/contexts/AuthContext';

function formatBadge(count) {
    if (!count) return '';
    return count > 99 ? '99+' : String(count);
}

function unreadValue(item) {
    return Math.max(0, Number(item?.unreadCount || 0)) || (item?.read ? 0 : 1);
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
    const { settings, user, guest, activity, messages, updateSettings } = useAuth();
    const permissionRef = useRef('default');
    const previousUnreadRef = useRef(0);

    const unreadCount = useMemo(() => {
        const unreadAlerts = (activity || []).filter((item) => !item.read).length;
        const unreadMessages = (messages || []).reduce((total, item) => total + unreadValue(item), 0);
        return Math.min(99, unreadAlerts + unreadMessages);
    }, [activity, messages]);

    useEffect(() => {
        if (typeof window === 'undefined') return;
        const browserPermission = 'Notification' in window ? Notification.permission : 'default';
        permissionRef.current = browserPermission;
    }, [user, guest, settings.notifications]);

    async function requestPermission() {
        if (typeof window === 'undefined') return;
        try {
            const nativeNotifications = await getNativeNotifications();
            if (nativeNotifications) {
                const nativePerm = await nativeNotifications.requestPermissions();
                permissionRef.current = nativePerm.display === 'granted' ? 'granted' : 'default';
            }
            if ('Notification' in window && Notification.permission !== 'granted') {
                permissionRef.current = await Notification.requestPermission();
            }
            updateSettings?.({ notificationPermission: permissionRef.current });
            if (permissionRef.current === 'granted') {
                await registerPushSubscription();
                window.dispatchEvent(new CustomEvent('gs-notification', {
                    detail: { title: 'Notifications enabled', body: 'GS messages and account alerts can now appear on your phone.', count: unreadCount },
                }));
            }
        } catch {}
    }

    function publicVapidKeyToUint8Array(key) {
        const padding = '='.repeat((4 - key.length % 4) % 4);
        const base64 = (key + padding).replace(/-/g, '+').replace(/_/g, '/');
        const raw = window.atob(base64);
        return Uint8Array.from([...raw].map((char) => char.charCodeAt(0)));
    }

    async function registerPushSubscription() {
        if (!user?.id || typeof navigator === 'undefined' || !('serviceWorker' in navigator) || !('PushManager' in window)) return;
        const vapidKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
        if (!vapidKey) return;
        try {
            const registration = await navigator.serviceWorker.ready;
            const existing = await registration.pushManager.getSubscription();
            const subscription = existing || await registration.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey: publicVapidKeyToUint8Array(vapidKey),
            });
            await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'push_subscription',
                    memberId: user.id,
                    email: user.email,
                    subscription: subscription.toJSON(),
                    permission: Notification.permission,
                    platform: 'web-pwa',
                    userAgent: navigator.userAgent,
                }),
            });
        } catch {}
    }

    useEffect(() => {
        if (typeof window === 'undefined') return;
        const handler = () => requestPermission();
        window.addEventListener('gs-request-notifications', handler);
        return () => window.removeEventListener('gs-request-notifications', handler);
    }, [unreadCount]);

    useEffect(() => {
        if (typeof navigator === 'undefined') return;
        const count = Math.max(0, unreadCount || 0);
        if ('setAppBadge' in navigator) {
            if (count > 0) navigator.setAppBadge(count).catch(() => {});
            else navigator.clearAppBadge?.().catch(() => {});
        }
        navigator.serviceWorker?.ready
            .then((registration) => {
                registration.active?.postMessage({ type: 'GS_BADGE_COUNT', count });
            })
            .catch(() => {});
        try { localStorage.setItem('gscom_badge_count', JSON.stringify({ count, label: formatBadge(count), at: Date.now() })); } catch {}
    }, [unreadCount]);

    useEffect(() => {
        if (typeof window === 'undefined') return;
        const previous = previousUnreadRef.current;
        previousUnreadRef.current = unreadCount;
        if (!settings.notifications || unreadCount <= previous || unreadCount <= 0) return;
        if (document.visibilityState === 'visible') return;
        window.dispatchEvent(new CustomEvent('gs-notification', {
            detail: {
                title: 'New GS activity',
                body: `You have ${formatBadge(unreadCount)} unread message${unreadCount === 1 ? '' : 's'} or alert${unreadCount === 1 ? '' : 's'}.`,
                count: unreadCount,
            },
        }));
    }, [unreadCount, settings.notifications]);

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

    return null;
}

