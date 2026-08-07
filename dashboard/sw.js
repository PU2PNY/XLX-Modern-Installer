const CACHE_VERSION = 'xlx-modern-dashboard-pwa-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(key => key.startsWith('xlx-modern-dashboard-pwa-') && key !== CACHE_VERSION)
            .map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

/* Dynamic dashboard: always use the network for current state and API data. */
self.addEventListener('fetch', event => {
  if (event.request.method === 'GET') event.respondWith(fetch(event.request));
});
