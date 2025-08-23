// Server-official telemetry mode
// Client emits only Suqi.* events, server handles aliasing

interface TelemetryEvent {
  event: string;
  properties?: Record<string, any>;
  timestamp?: Date;
}

interface PostHogClient {
  capture: (event: string, properties?: Record<string, any>) => void;
  identify: (userId: string, properties?: Record<string, any>) => void;
}

// Server-official mode: NO client-side aliasing
export function capture(event: string, props: Record<string, any> = {}) {
  const posthog = (globalThis as any).posthog as PostHogClient | undefined;
  
  if (!posthog?.capture) {
    console.warn('PostHog not initialized');
    return;
  }

  // Add common properties
  const enrichedProps = {
    ...props,
    timestamp: new Date().toISOString(),
    platform: getPlatform(),
    viewport: getViewport(),
    ...getSessionContext()
  };

  // Direct emit - no aliasing (server handles it)
  posthog.capture(event, enrichedProps);
}

export function identify(userId: string, traits: Record<string, any> = {}) {
  const posthog = (globalThis as any).posthog as PostHogClient | undefined;
  
  if (!posthog?.identify) {
    console.warn('PostHog not initialized');
    return;
  }

  posthog.identify(userId, {
    ...traits,
    platform: getPlatform()
  });
}

// Helper functions
function getPlatform(): string {
  if (typeof window === 'undefined') return 'server';
  
  const pathname = window.location.pathname;
  if (pathname.includes('/docs')) return 'docs';
  if (pathname.includes('/analytics')) return 'analytics';
  if (pathname.includes('/admin')) return 'admin';
  return 'web';
}

function getViewport() {
  if (typeof window === 'undefined') return {};
  
  return {
    width: window.innerWidth,
    height: window.innerHeight,
    devicePixelRatio: window.devicePixelRatio
  };
}

function getSessionContext() {
  if (typeof window === 'undefined') return {};
  
  return {
    referrer: document.referrer,
    url: window.location.href,
    userAgent: navigator.userAgent
  };
}

// Telemetry event builders
export const telemetry = {
  // Suqi-specific events (no Scout. prefix here)
  query: (question: string, responseTime: number) => 
    capture('Suqi.Query', { question, response_time_ms: responseTime }),
  
  cacheHit: (question: string) => 
    capture('Suqi.CacheHit', { question }),
  
  error: (error: string, context?: any) => 
    capture('Suqi.Error', { error, context }),
  
  ragRetrieval: (docCount: number, avgScore: number) => 
    capture('Suqi.RAGRetrieval', { doc_count: docCount, avg_score: avgScore }),
  
  // Feature usage
  featureUsed: (feature: string, metadata?: any) => 
    capture('Suqi.FeatureUsed', { feature, ...metadata }),
  
  // Performance metrics
  performance: (metric: string, value: number) => 
    capture('Suqi.Performance', { metric, value })
};