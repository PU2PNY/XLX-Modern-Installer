const CACHE_VERSION = 'xlx026-pwa-v33';

self.addEventListener('install', () => {
    self.skipWaiting();
});

self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys()
            .then(keys => Promise.all(
                keys
                    .filter(key => key.startsWith('xlx026-pwa-') && key !== CACHE_VERSION)
                    .map(key => caches.delete(key))
            ))
            .then(() => self.clients.claim())
    );
});

/*
 * O painel é dinâmico e consulta a API a cada segundo.
 * Não armazenamos páginas nem respostas da API em cache.
 */
self.addEventListener('fetch', event => {
    if (event.request.method !== 'GET') {
        return;
    }

    event.respondWith(fetch(event.request));
});
