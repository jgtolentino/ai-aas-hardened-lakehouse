/**
 * AI Recommendations Service
 * Handles interaction with the recommendations API and business logic
 */

import { Recommendation } from '@/components/ai/RecommendationPanel';

// API Types
export interface RecommendationAPIResponse {
  success: boolean;
  data: {
    recommendations: Recommendation[];
    total_count: number;
    has_more: boolean;
    next_cursor?: string;
  };
  error?: string;
}

export interface RecommendationFilters {
  categories?: string[];
  types?: Recommendation['type'][];
  priorities?: Recommendation['priority'][];
  confidence_min?: number;
  confidence_max?: number;
  limit?: number;
  offset?: number;
  cursor?: string;
}

export interface ActionExecutionRequest {
  recommendation_id: string;
  action_id: string;
  context?: Record<string, any>;
}

export interface ActionExecutionResponse {
  success: boolean;
  action_id: string;
  result?: any;
  error?: string;
}

// Configuration
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '/api';
const RECOMMENDATIONS_ENDPOINT = `${API_BASE_URL}/ai/recommendations`;

// Error types
export class RecommendationsError extends Error {
  constructor(
    message: string, 
    public code: string,
    public status?: number
  ) {
    super(message);
    this.name = 'RecommendationsError';
  }
}

export class RateLimitError extends RecommendationsError {
  constructor(retryAfter?: number) {
    super(
      'Rate limit exceeded. Please try again later.',
      'RATE_LIMIT_EXCEEDED'
    );
    this.retryAfter = retryAfter;
  }
  
  public retryAfter?: number;
}

/**
 * Recommendations API Client
 */
export class RecommendationsAPI {
  private static instance: RecommendationsAPI;
  private baseURL: string;
  private headers: HeadersInit;

  private constructor() {
    this.baseURL = RECOMMENDATIONS_ENDPOINT;
    this.headers = {
      'Content-Type': 'application/json',
      // Add authentication headers here if needed
      // 'Authorization': `Bearer ${getAuthToken()}`
    };
  }

  static getInstance(): RecommendationsAPI {
    if (!RecommendationsAPI.instance) {
      RecommendationsAPI.instance = new RecommendationsAPI();
    }
    return RecommendationsAPI.instance;
  }

  private async handleResponse<T>(response: Response): Promise<T> {
    if (response.status === 429) {
      const retryAfter = response.headers.get('Retry-After');
      throw new RateLimitError(retryAfter ? parseInt(retryAfter, 10) : undefined);
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new RecommendationsError(
        errorData.message || `HTTP ${response.status}: ${response.statusText}`,
        errorData.code || 'API_ERROR',
        response.status
      );
    }

    return response.json();
  }

  /**
   * Fetch recommendations with filters
   */
  async getRecommendations(filters: RecommendationFilters = {}): Promise<RecommendationAPIResponse> {
    const url = new URL(this.baseURL);
    
    // Add query parameters
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        if (Array.isArray(value)) {
          value.forEach(v => url.searchParams.append(key, v.toString()));
        } else {
          url.searchParams.append(key, value.toString());
        }
      }
    });

    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: this.headers,
    });

    return this.handleResponse<RecommendationAPIResponse>(response);
  }

  /**
   * Execute a recommendation action
   */
  async executeAction(request: ActionExecutionRequest): Promise<ActionExecutionResponse> {
    const response = await fetch(`${this.baseURL}/actions`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify(request),
    });

    return this.handleResponse<ActionExecutionResponse>(response);
  }

  /**
   * Dismiss a recommendation
   */
  async dismissRecommendation(recommendationId: string): Promise<{ success: boolean }> {
    const response = await fetch(`${this.baseURL}/${recommendationId}/dismiss`, {
      method: 'POST',
      headers: this.headers,
    });

    return this.handleResponse<{ success: boolean }>(response);
  }

  /**
   * Get recommendation feedback options
   */
  async submitFeedback(
    recommendationId: string, 
    feedback: 'helpful' | 'not_helpful' | 'irrelevant',
    comment?: string
  ): Promise<{ success: boolean }> {
    const response = await fetch(`${this.baseURL}/${recommendationId}/feedback`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({ feedback, comment }),
    });

    return this.handleResponse<{ success: boolean }>(response);
  }

  /**
   * Get recommendation categories
   */
  async getCategories(): Promise<{ categories: string[] }> {
    const response = await fetch(`${this.baseURL}/categories`, {
      method: 'GET',
      headers: this.headers,
    });

    return this.handleResponse<{ categories: string[] }>(response);
  }
}

/**
 * Utility functions for recommendations
 */
export const RecommendationUtils = {
  /**
   * Sort recommendations by priority and confidence
   */
  sortByPriority: (recommendations: Recommendation[]): Recommendation[] => {
    const priorityOrder: Record<Recommendation['priority'], number> = {
      critical: 4,
      high: 3,
      medium: 2,
      low: 1
    };

    return [...recommendations].sort((a, b) => {
      const priorityDiff = priorityOrder[b.priority] - priorityOrder[a.priority];
      if (priorityDiff !== 0) return priorityDiff;
      return b.confidence - a.confidence;
    });
  },

  /**
   * Filter recommendations by confidence threshold
   */
  filterByConfidence: (
    recommendations: Recommendation[], 
    threshold: number
  ): Recommendation[] => {
    return recommendations.filter(rec => rec.confidence >= threshold);
  },

  /**
   * Group recommendations by category
   */
  groupByCategory: (recommendations: Recommendation[]): Record<string, Recommendation[]> => {
    return recommendations.reduce((acc, rec) => {
      if (!acc[rec.category]) {
        acc[rec.category] = [];
      }
      acc[rec.category].push(rec);
      return acc;
    }, {} as Record<string, Recommendation[]>);
  },

  /**
   * Calculate total estimated impact
   */
  calculateTotalImpact: (recommendations: Recommendation[], type: 'revenue' | 'efficiency'): number => {
    return recommendations
      .filter(rec => rec.impact.type === type && rec.impact.estimated_value)
      .reduce((total, rec) => total + (rec.impact.estimated_value || 0), 0);
  },

  /**
   * Check if recommendation is expired
   */
  isExpired: (recommendation: Recommendation): boolean => {
    if (!recommendation.metadata?.expires_at) return false;
    return new Date(recommendation.metadata.expires_at) < new Date();
  },

  /**
   * Format impact value for display
   */
  formatImpactValue: (impact: Recommendation['impact']): string => {
    const value = impact.estimated_value;
    if (!value) return 'N/A';

    switch (impact.type) {
      case 'revenue':
        return `₱${value.toLocaleString()}`;
      case 'efficiency':
        return `+${value}%`;
      case 'risk':
        return `${value}% risk reduction`;
      case 'customer_satisfaction':
        return `+${value} NPS points`;
      default:
        return value.toString();
    }
  },

  /**
   * Get confidence level label
   */
  getConfidenceLevel: (confidence: number): string => {
    if (confidence >= 90) return 'Very High';
    if (confidence >= 70) return 'High';
    if (confidence >= 50) return 'Medium';
    return 'Low';
  },

  /**
   * Validate recommendation data
   */
  isValidRecommendation: (rec: any): rec is Recommendation => {
    return (
      rec &&
      typeof rec.id === 'string' &&
      typeof rec.title === 'string' &&
      typeof rec.description === 'string' &&
      typeof rec.confidence === 'number' &&
      rec.confidence >= 0 &&
      rec.confidence <= 100 &&
      ['insight', 'optimization', 'alert', 'opportunity'].includes(rec.type) &&
      ['low', 'medium', 'high', 'critical'].includes(rec.priority) &&
      typeof rec.category === 'string' &&
      rec.impact &&
      ['revenue', 'efficiency', 'risk', 'customer_satisfaction'].includes(rec.impact.type)
    );
  }
};

/**
 * Rate limiting utility
 */
export class RateLimiter {
  private requests: number[] = [];
  private maxRequests: number;
  private windowMs: number;

  constructor(maxRequests: number = 100, windowMs: number = 60000) {
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
  }

  canMakeRequest(): boolean {
    const now = Date.now();
    // Remove old requests outside the window
    this.requests = this.requests.filter(time => now - time < this.windowMs);
    
    return this.requests.length < this.maxRequests;
  }

  recordRequest(): void {
    this.requests.push(Date.now());
  }

  getRetryAfterMs(): number {
    if (this.requests.length === 0) return 0;
    const oldestRequest = Math.min(...this.requests);
    return this.windowMs - (Date.now() - oldestRequest);
  }
}

// Export singleton instances
export const recommendationsAPI = RecommendationsAPI.getInstance();
export const rateLimiter = new RateLimiter();