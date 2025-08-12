
// Scout Analytics Service Worker for advanced caching
const CACHE_NAME = 'scout-analytics-v1';
const STATIC_CACHE = 'scout-static-v1';
const DYNAMIC_CACHE = 'scout-dynamic-v1';

// Assets to cache immediately
const STATIC_ASSETS = [
  '/',
  '/static/css/main.css',
  '/static/js/main.js',
  '/manifest.json'
];

// Cache strategies by route pattern
const CACHE_STRATEGIES = {
  '/api/analytics/': { strategy: 'networkFirst', ttl: 300 }, // 5 minutes
  '/api/charts/': { strategy: 'staleWhileRevalidate', ttl: 600 }, // 10 minutes
  '/static/': { strategy: 'cacheFirst', ttl: 31536000 }, // 1 year
  '/images/': { strategy: 'cacheFirst', ttl: 86400 } // 1 day
};

self.addEventListener('install', event => {
  console.log('Service Worker installing...');
  
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  console.log('Service Worker activating...');
  
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          .filter(cacheName => cacheName !== CACHE_NAME && cacheName !== STATIC_CACHE)
          .map(cacheName => caches.delete(cacheName))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Skip non-GET requests
  if (request.method !== 'GET') return;
  
  // Find matching cache strategy
  let strategy = null;
  let ttl = 86400; // default 1 day
  
  for (const [pattern, config] of Object.entries(CACHE_STRATEGIES)) {
    if (url.pathname.startsWith(pattern)) {
      strategy = config.strategy;
      ttl = config.ttl;
      break;
    }
  }
  
  if (!strategy) return; // No caching for this request
  
  event.respondWith(
    handleRequest(request, strategy, ttl)
  );
});

async function handleRequest(request, strategy, ttl) {
  const cache = await caches.open(DYNAMIC_CACHE);
  
  switch (strategy) {
    case 'cacheFirst':
      return cacheFirst(request, cache, ttl);
    case 'networkFirst':
      return networkFirst(request, cache, ttl);
    case 'staleWhileRevalidate':
      return staleWhileRevalidate(request, cache, ttl);
    default:
      return fetch(request);
  }
}

async function cacheFirst(request, cache, ttl) {
  const cached = await cache.match(request);
  
  if (cached && !isExpired(cached, ttl)) {
    return cached;
  }
  
  try {
    const response = await fetch(request);
    if (response.ok) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    return cached || new Response('Offline', { status: 503 });
  }
}

async function networkFirst(request, cache, ttl) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await cache.match(request);
    return cached || new Response('Offline', { status: 503 });
  }
}

async function staleWhileRevalidate(request, cache, ttl) {
  const cached = await cache.match(request);
  
  // Always fetch in background
  const fetchPromise = fetch(request).then(response => {
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  });
  
  // Return cached if available, otherwise wait for network
  return cached || fetchPromise;
}

function isExpired(response, ttl) {
  const dateHeader = response.headers.get('date');
  if (!dateHeader) return true;
  
  const responseDate = new Date(dateHeader);
  const now = new Date();
  return (now - responseDate) > (ttl * 1000);
}
