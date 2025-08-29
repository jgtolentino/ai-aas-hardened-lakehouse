/**
 * Rate Limiter Utility for AI Recommendations
 * Handles rate limiting with exponential backoff and request queuing
 */

interface RateLimitError extends Error {
  retryAfter?: number;
  status: number;
}

interface RateLimitConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  jitterMax: number;
}

interface QueuedRequest<T> {
  id: string;
  fn: () => Promise<T>;
  resolve: (value: T) => void;
  reject: (error: Error) => void;
  priority: number;
  timestamp: number;
}

export class RateLimiter {
  private config: RateLimitConfig;
  private requestQueue: QueuedRequest<any>[] = [];
  private isProcessing = false;
  private lastRequestTime = 0;
  private requestCount = 0;
  private windowStart = Date.now();
  private readonly windowSizeMs = 60000; // 1 minute window
  private readonly maxRequestsPerWindow = 100;

  constructor(config?: Partial<RateLimitConfig>) {
    this.config = {
      maxRetries: 3,
      baseDelayMs: 1000,
      maxDelayMs: 30000,
      jitterMax: 200,
      ...config
    };
  }

  /**
   * Execute a request with rate limiting and retry logic
   */
  async execute<T>(
    requestFn: () => Promise<T>,
    priority: number = 0,
    options?: {
      skipQueue?: boolean;
      timeout?: number;
    }
  ): Promise<T> {
    const requestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    // Check if we should queue the request
    if (!options?.skipQueue && this.shouldQueue()) {
      return this.queueRequest(requestId, requestFn, priority);
    }

    return this.executeWithRetry(requestFn, 0);
  }

  private async executeWithRetry<T>(
    requestFn: () => Promise<T>,
    attempt: number
  ): Promise<T> {
    try {
      // Check rate limits before making request
      this.checkRateLimit();
      
      // Add delay between requests to avoid overwhelming the API
      const timeSinceLastRequest = Date.now() - this.lastRequestTime;
      const minInterval = 100; // Minimum 100ms between requests
      
      if (timeSinceLastRequest < minInterval) {
        await this.delay(minInterval - timeSinceLastRequest);
      }

      this.lastRequestTime = Date.now();
      this.incrementRequestCount();

      const result = await requestFn();
      return result;

    } catch (error) {
      if (this.isRateLimitError(error)) {
        return this.handleRateLimitError(error as RateLimitError, requestFn, attempt);
      }
      
      // For non-rate-limit errors, retry with exponential backoff
      if (attempt < this.config.maxRetries && this.isRetryableError(error)) {
        const delay = this.calculateBackoffDelay(attempt);
        console.warn(`Request failed, retrying in ${delay}ms (attempt ${attempt + 1}/${this.config.maxRetries})`, error);
        
        await this.delay(delay);
        return this.executeWithRetry(requestFn, attempt + 1);
      }

      throw error;
    }
  }

  private async handleRateLimitError<T>(
    error: RateLimitError,
    requestFn: () => Promise<T>,
    attempt: number
  ): Promise<T> {
    const retryAfter = error.retryAfter || this.calculateBackoffDelay(attempt);
    
    console.warn(`Rate limit hit, retrying after ${retryAfter}ms`);
    
    if (attempt >= this.config.maxRetries) {
      throw new Error(`Rate limit exceeded after ${this.config.maxRetries} attempts. Please try again later.`);
    }

    await this.delay(retryAfter);
    return this.executeWithRetry(requestFn, attempt + 1);
  }

  private queueRequest<T>(
    id: string,
    fn: () => Promise<T>,
    priority: number
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const queuedRequest: QueuedRequest<T> = {
        id,
        fn,
        resolve,
        reject,
        priority,
        timestamp: Date.now()
      };

      // Insert request in priority order (higher priority first)
      const insertIndex = this.requestQueue.findIndex(
        req => req.priority < priority
      );
      
      if (insertIndex === -1) {
        this.requestQueue.push(queuedRequest);
      } else {
        this.requestQueue.splice(insertIndex, 0, queuedRequest);
      }

      // Start processing queue if not already processing
      if (!this.isProcessing) {
        this.processQueue();
      }
    });
  }

  private async processQueue(): Promise<void> {
    if (this.isProcessing || this.requestQueue.length === 0) {
      return;
    }

    this.isProcessing = true;

    while (this.requestQueue.length > 0) {
      const request = this.requestQueue.shift();
      if (!request) break;

      try {
        // Check if request has timed out (older than 5 minutes)
        const requestAge = Date.now() - request.timestamp;
        if (requestAge > 300000) {
          request.reject(new Error('Request timed out in queue'));
          continue;
        }

        const result = await this.executeWithRetry(request.fn, 0);
        request.resolve(result);
      } catch (error) {
        request.reject(error as Error);
      }

      // Small delay between queued requests
      await this.delay(50);
    }

    this.isProcessing = false;
  }

  private shouldQueue(): boolean {
    // Queue requests if we're approaching rate limits or have pending requests
    const currentWindow = this.getCurrentWindow();
    const requestsInWindow = this.getRequestCountInWindow(currentWindow);
    
    return (
      requestsInWindow >= this.maxRequestsPerWindow * 0.8 || // 80% of limit
      this.requestQueue.length > 0 ||
      this.isProcessing
    );
  }

  private checkRateLimit(): void {
    const currentWindow = this.getCurrentWindow();
    
    // Reset counter if we're in a new window
    if (currentWindow !== this.windowStart) {
      this.windowStart = currentWindow;
      this.requestCount = 0;
    }

    if (this.requestCount >= this.maxRequestsPerWindow) {
      throw {
        name: 'RateLimitError',
        message: 'Rate limit exceeded',
        status: 429,
        retryAfter: this.windowSizeMs - (Date.now() - this.windowStart)
      } as RateLimitError;
    }
  }

  private incrementRequestCount(): void {
    const currentWindow = this.getCurrentWindow();
    
    if (currentWindow !== this.windowStart) {
      this.windowStart = currentWindow;
      this.requestCount = 1;
    } else {
      this.requestCount++;
    }
  }

  private getCurrentWindow(): number {
    return Math.floor(Date.now() / this.windowSizeMs) * this.windowSizeMs;
  }

  private getRequestCountInWindow(window: number): number {
    return window === this.windowStart ? this.requestCount : 0;
  }

  private isRateLimitError(error: any): boolean {
    return (
      error?.status === 429 ||
      error?.name === 'RateLimitError' ||
      error?.message?.toLowerCase().includes('rate limit') ||
      error?.message?.toLowerCase().includes('too many requests')
    );
  }

  private isRetryableError(error: any): boolean {
    const retryableStatuses = [408, 429, 500, 502, 503, 504];
    return (
      retryableStatuses.includes(error?.status) ||
      error?.code === 'NETWORK_ERROR' ||
      error?.code === 'TIMEOUT'
    );
  }

  private calculateBackoffDelay(attempt: number): number {
    const exponentialDelay = Math.min(
      this.config.baseDelayMs * Math.pow(2, attempt),
      this.config.maxDelayMs
    );
    
    // Add jitter to prevent thundering herd
    const jitter = Math.random() * this.config.jitterMax;
    
    return Math.floor(exponentialDelay + jitter);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Get current rate limit status
   */
  getStatus() {
    const currentWindow = this.getCurrentWindow();
    const requestsInWindow = this.getRequestCountInWindow(currentWindow);
    const windowTimeLeft = this.windowSizeMs - (Date.now() - this.windowStart);
    
    return {
      requestsInCurrentWindow: requestsInWindow,
      maxRequestsPerWindow: this.maxRequestsPerWindow,
      windowTimeLeftMs: windowTimeLeft,
      queuedRequests: this.requestQueue.length,
      isProcessing: this.isProcessing,
      utilizationPercent: (requestsInWindow / this.maxRequestsPerWindow) * 100
    };
  }

  /**
   * Clear the request queue (useful for cleanup)
   */
  clearQueue(): void {
    this.requestQueue.forEach(req => {
      req.reject(new Error('Queue cleared'));
    });
    this.requestQueue = [];
  }
}

// Default rate limiter instance
export const rateLimiter = new RateLimiter();

export default RateLimiter;