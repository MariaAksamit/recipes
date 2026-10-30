// Offline režim webovej verzie (iPhone).
//
// Všetko, čo si apka stiahne (kód, písma, ikony), sa uloží do pamäte
// telefónu. Keď je internet, apka si vždy vezme najnovšiu verziu
// a pamäť aktualizuje. Keď internet nie je (alebo je veľmi pomalý),
// apka sa spustí z pamäte.
//
// Recepty a fotky sú uložené inde (IndexedDB) – tento súbor sa ich netýka.

const CACHE = 'recepty-offline-v1';
const NETWORK_TIMEOUT_MS = 4000;

// Súbory, ktoré sa uložia hneď pri prvom otvorení. Chýbajúce sa preskočia
// (napr. canvaskit/chromium sa v Safari nepoužíva).
const CORE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/apple-touch-icon.png',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/assets/recipes.json',
  'assets/shaders/ink_sparkle.frag',
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await Promise.all(CORE.map(async (path) => {
      try {
        const res = await fetch(path, { cache: 'reload' });
        if (res.ok) await cache.put(path, res);
      } catch (_) { /* bez internetu – nevadí */ }
    }));
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return;

  if (url.origin === self.location.origin) {
    event.respondWith(networkFirst(event, req));
  } else if (url.hostname.endsWith('gstatic.com') || url.hostname.endsWith('googleapis.com')) {
    // Písma (Roboto, emoji…) – adresy sa nemenia, stačí ich stiahnuť raz.
    event.respondWith(cacheFirst(req));
  }
});

async function networkFirst(event, req) {
  const cache = await caches.open(CACHE);
  const fromNetwork = fetch(req).then(async (res) => {
    if (res.status === 200) {
      try { await cache.put(req, res.clone()); } catch (_) { /* plná pamäť a pod. */ }
    }
    return res;
  });
  // Aktualizácia pamäte dobehne aj vtedy, keď odpovieme z pamäte.
  event.waitUntil(fromNetwork.catch(() => {}));

  const timeout = new Promise((resolve) => setTimeout(() => resolve(null), NETWORK_TIMEOUT_MS));
  try {
    const res = await Promise.race([fromNetwork, timeout]);
    if (res) return res;
  } catch (_) { /* bez internetu */ }

  const cached = await cache.match(req, { ignoreSearch: true }) ||
    (req.mode === 'navigate' ? await cache.match('index.html') || await cache.match('./') : undefined);
  if (cached) return cached;
  return fromNetwork; // nič v pamäti – počkáme na sieť (alebo chybu)
}

async function cacheFirst(req) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(req);
  if (cached) return cached;
  const res = await fetch(req);
  if (res.status === 200 || res.type === 'opaque') {
    try { await cache.put(req, res.clone()); } catch (_) { /* nevadí */ }
  }
  return res;
}
