const CACHE_NAME = 'gscom-cache-v3';
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

self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    // Never cache Next/Vercel build assets or API responses. Stale chunks can keep the app stuck on the splash screen.
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
