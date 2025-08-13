
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
    console.log(`Performance metric ${name}:`, metric.value);
    
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
