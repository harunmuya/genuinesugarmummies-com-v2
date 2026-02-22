'use client';

import { useEffect, useRef } from 'react';
import { useAuth } from '@/contexts/AuthContext';

/**
 * NotificationManager — fires OS-level push notifications (WhatsApp-style)
 * Listens for `gs-notification` custom events dispatched by AuthContext.
 * Respects user notification settings.
 */
export default function NotificationManager() {
    const { settings, user, guest } = useAuth();
    const permissionRef = useRef('default');

    // Request notification permission on mount
    useEffect(() => {
        if (typeof window === 'undefined' || !('Notification' in window)) return;

        if (Notification.permission === 'granted') {
            permissionRef.current = 'granted';
        } else if (Notification.permission !== 'denied') {
            // Wait a bit before requesting (less intrusive)
            const timer = setTimeout(() => {
                Notification.requestPermission().then((perm) => {
                    permissionRef.current = perm;
                });
            }, 8000);
            return () => clearTimeout(timer);
        }
    }, []);

    // Listen for notification events
    useEffect(() => {
        if (typeof window === 'undefined') return;

        const handleNotification = (e) => {
            // Only fire if user has notifications enabled and permission granted
            if (!settings.notifications) return;
            if (!('Notification' in window) || Notification.permission !== 'granted') return;
            // Don't notify if tab is focused (user is already looking at the app)
            if (document.visibilityState === 'visible') return;

            const { title, body, image, icon } = e.detail || {};
            if (!title) return;

            try {
                const notification = new Notification(title, {
                    body: body || '',
                    icon: icon || '/gs-logo.png',
                    badge: '/gs-logo.png',
                    image: image || undefined,
                    tag: `gs-${Date.now()}`,
                    vibrate: [200, 100, 200],
                    silent: false,
                });

                notification.onclick = () => {
                    window.focus();
                    notification.close();
                };

                // Auto-close after 8 seconds
                setTimeout(() => notification.close(), 8000);
            } catch { }
        };

        window.addEventListener('gs-notification', handleNotification);
        return () => window.removeEventListener('gs-notification', handleNotification);
    }, [settings.notifications]);

    return null; // Invisible component
}
