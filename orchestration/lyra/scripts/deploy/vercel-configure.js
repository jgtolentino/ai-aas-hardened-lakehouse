#!/usr/bin/env node
/**
 * W9: CDN + caching - Configure Vercel for static + Edge regions
 * Gate: WebPageTest LCP < 1.5s (cached), TTFB < 300ms
 */

import fs from 'fs';
import path from 'path';

console.log('⚡ Configuring Vercel CDN + caching...');

// Vercel configuration
const vercelConfig = {
  version: 2,
  name: "scout-analytics-dashboard",
  builds: [
    {
      src: "package.json",
      use: "@vercel/static-build",
      config: {
        distDir: "dist"
      }
    }
  ],
  routes: [
    {
      src: "/api/(.*)",
      dest: "/api/$1"
    },
    {
      src: "/(.*)",
      dest: "/$1"
    }
  ],
  headers: [
    {
      source: "/static/(.*)",
      headers: [
        {
          key: "Cache-Control",
          value: "public, max-age=31536000, immutable"
        }
      ]
    },
    {
      source: "/(.*\\.(?:js|css))",
      headers: [
        {
          key: "Cache-Control", 
          value: "public, max-age=31536000, immutable"
        }
      ]
    },
    {
      source: "/api/(.*)",
      headers: [
        {
          key: "Cache-Control",
          value: "public, s-maxage=300, stale-while-revalidate=60"
        }
      ]
    },
    {
      source: "/(.*)",
      headers: [
        {
          key: "Cache-Control",
          value: "public, s-maxage=86400, stale-while-revalidate=300"
        },
        {
          key: "X-Content-Type-Options",
          value: "nosniff"
        },
        {
          key: "X-Frame-Options", 
          value: "DENY"
        },
        {
          key: "X-XSS-Protection",
          value: "1; mode=block"
        }
      ]
    }
  ],
  regions: ["iad1", "sfo1", "lhr1", "hnd1", "fra1"],
  functions: {
    "api/**/*.js": {
      memory: 1024,
      maxDuration: 10
    }
  },
  env: {
    "SUPABASE_URL": "@supabase-url",
    "SUPABASE_ANON_KEY": "@supabase-anon-key",
    "MAPBOX_TOKEN": "@mapbox-token"
  }
};

// Next.js configuration for optimization
const nextConfig = `
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    optimizeCss: true,
  },
  compress: true,
  poweredByHeader: false,
  generateEtags: true,
  
  // Image optimization
  images: {
    domains: ['assets.scout-analytics.com', 'cdn.scout-analytics.com'],
    formats: ['image/webp', 'image/avif'],
    minimumCacheTTL: 86400,
  },
  
  // Webpack optimizations
  webpack: (config, { dev, isServer }) => {
    if (!dev && !isServer) {
      config.optimization.splitChunks = {
        chunks: 'all',
        cacheGroups: {
          vendor: {
            test: /[\\\\/]node_modules[\\\\/]/,
            name: 'vendors',
            chunks: 'all',
            priority: 10,
          },
          common: {
            minChunks: 2,
            chunks: 'all',
            name: 'common',
            priority: 5,
            reuseExistingChunk: true,
          }
        }
      };
    }
    return config;
  },
  
  // Headers for performance
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on'
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=31536000; includeSubDomains'
          },
          {
            key: 'X-Content-Type-Options', 
            value: 'nosniff'
          }
        ]
      },
      {
        source: '/static/(.*)',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable'
          }
        ]
      }
    ];
  },
  
  // Rewrites for API optimization
  async rewrites() {
    return [
      {
        source: '/api/analytics/:path*',
        destination: process.env.SUPABASE_URL + '/rest/v1/:path*'
      }
    ];
  }
};

module.exports = nextConfig;
`;

// Service Worker for advanced caching
const serviceWorkerContent = `
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
`;

// Performance optimization utilities
const performanceOptimizer = `
// Performance optimization utilities for Scout Analytics
export class PerformanceOptimizer {
  
  // Lazy load components
  static lazyLoad(componentLoader) {
    return React.lazy(componentLoader);
  }
  
  // Debounce expensive operations
  static debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }
  
  // Memoize API calls
  static memoizeAPI(apiCall, keyGenerator, ttl = 300000) {
    const cache = new Map();
    
    return async (...args) => {
      const key = keyGenerator(...args);
      const cached = cache.get(key);
      
      if (cached && Date.now() - cached.timestamp < ttl) {
        return cached.data;
      }
      
      const result = await apiCall(...args);
      cache.set(key, { data: result, timestamp: Date.now() });
      
      return result;
    };
  }
  
  // Preload critical resources
  static preloadResource(href, as = 'fetch') {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = href;
    link.as = as;
    document.head.appendChild(link);
  }
  
  // Monitor Core Web Vitals
  static setupWebVitalsMonitoring() {
    if (typeof window === 'undefined') return;
    
    import('web-vitals').then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
      getCLS(metric => this.sendMetric('CLS', metric));
      getFID(metric => this.sendMetric('FID', metric));
      getFCP(metric => this.sendMetric('FCP', metric));
      getLCP(metric => this.sendMetric('LCP', metric));
      getTTFB(metric => this.sendMetric('TTFB', metric));
    });
  }
  
  static sendMetric(name, metric) {
    // Send to analytics service
    console.log(\`Performance metric \${name}:\`, metric.value);
    
    // Send to external monitoring service
    if (window.gtag) {
      window.gtag('event', name, {
        event_category: 'Web Vitals',
        value: Math.round(metric.value),
        metric_id: metric.id,
        metric_delta: metric.delta,
      });
    }
  }
}
`;

try {
  // Write Vercel configuration
  const vercelConfigPath = './vercel.json';
  fs.writeFileSync(vercelConfigPath, JSON.stringify(vercelConfig, null, 2));
  console.log(`✅ Vercel configuration: ${vercelConfigPath}`);
  
  // Write Next.js configuration
  const nextConfigPath = './next.config.js';
  fs.writeFileSync(nextConfigPath, nextConfig);
  console.log(`✅ Next.js configuration: ${nextConfigPath}`);
  
  // Write Service Worker
  const swPath = './public/sw.js';
  fs.mkdirSync(path.dirname(swPath), { recursive: true });
  fs.writeFileSync(swPath, serviceWorkerContent);
  console.log(`✅ Service Worker: ${swPath}`);
  
  // Write performance utilities
  const perfUtilsPath = './src/utils/performance.js';
  fs.mkdirSync(path.dirname(perfUtilsPath), { recursive: true });
  fs.writeFileSync(perfUtilsPath, performanceOptimizer);
  console.log(`✅ Performance utilities: ${perfUtilsPath}`);
  
  // Create deployment script
  const deployScript = `#!/bin/bash
set -e

echo "🚀 Deploying Scout Analytics to Vercel..."

# Pre-deployment checks
echo "📋 Running pre-deployment checks..."
npm run lint
npm run type-check
npm run test:unit

# Build optimizations
echo "🏗️  Building optimized bundle..."
npm run build

# Deploy to Vercel
echo "☁️  Deploying to Vercel..."
vercel --prod

# Post-deployment validation
echo "🧪 Running post-deployment tests..."
npm run test:e2e:prod

echo "✅ Deployment complete!"
`;
  
  const deployScriptPath = './scripts/deploy.sh';
  fs.mkdirSync(path.dirname(deployScriptPath), { recursive: true });
  fs.writeFileSync(deployScriptPath, deployScript);
  fs.chmodSync(deployScriptPath, 0o755);
  console.log(`✅ Deployment script: ${deployScriptPath}`);
  
  console.log('⚡ Vercel CDN + caching configuration complete');
  process.exit(0);
  
} catch (error) {
  console.error('❌ Error configuring Vercel CDN:', error.message);
  process.exit(1);
}