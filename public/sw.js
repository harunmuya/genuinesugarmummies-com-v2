const CACHE_NAME = 'gscom-cache-v4';
const OFFLINE_URL = '/offline.html';

const PRECACHE_URLS = [
    '/offline.html',
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS))
    );
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key))))
    );
    self.clients.claim();
});

self.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.type === 'GS_BADGE_COUNT') {
        const count = Math.max(0, Math.min(99, Number(data.count || 0)));
        if (self.navigator?.setAppBadge) {
            if (count > 0) self.navigator.setAppBadge(count).catch(() => {});
            else self.navigator.clearAppBadge?.().catch(() => {});
        }
    }
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const targetUrl = new URL(event.notification?.data?.url || '/alerts', self.location.origin).href;
    event.waitUntil((async () => {
        const list = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
        for (const client of list) {
            if ('focus' in client) {
                await client.focus();
                if ('navigate' in client) await client.navigate(targetUrl);
                return;
            }
        }
        if (self.clients.openWindow) await self.clients.openWindow(targetUrl);
    })());
});

self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    if (url.pathname.startsWith('/_next/') || url.pathname.startsWith('/api/') || url.hostname.includes('vercel')) {
        event.respondWith(fetch(event.request));
        return;
    }

    if (event.request.mode === 'navigate') {
        event.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE_URL)));
        return;
    }

    event.respondWith(
        fetch(event.request)
            .then((response) => response)
            .catch(() => caches.match(event.request).then((cached) => cached || new Response('Offline', { status: 503 })))
    );
});
