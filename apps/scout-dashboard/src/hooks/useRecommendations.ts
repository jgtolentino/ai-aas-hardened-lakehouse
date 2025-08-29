import { useState, useEffect, useCallback, useMemo } from 'react';
import { Recommendation } from '@/components/ai/RecommendationPanel';
import { rateLimiter } from '@/lib/ai/rateLimiter';

interface UseRecommendationsOptions {
  autoRefresh?: boolean;
  refreshInterval?: number; // in milliseconds
  maxRecommendations?: number;
  confidenceThreshold?: number;
  categories?: string[];
  enableCaching?: boolean;
  onError?: (error: Error) => void;
}

interface RecommendationsState {
  recommendations: Recommendation[];
  isLoading: boolean;
  error: string | null;
  lastUpdated: Date | null;
  hasMore: boolean;
  rateLimitStatus?: {
    isRateLimited: boolean;
    retryAfter?: number;
    utilizationPercent: number;
    queuedRequests: number;
  };
}

interface UseRecommendationsReturn extends RecommendationsState {
  refetch: () => Promise<void>;
  dismissRecommendation: (id: string) => void;
  executeAction: (recommendationId: string, actionId: string) => Promise<boolean>;
  clearError: () => void;
  getRecommendationsByCategory: (category: string) => Recommendation[];
  getHighPriorityRecommendations: () => Recommendation[];
  getRateLimitStatus: () => ReturnType<typeof rateLimiter.getStatus>;
  clearRateLimitQueue: () => void;
}

// Mock data for development
const MOCK_RECOMMENDATIONS: Recommendation[] = [
  {
    id: 'rec-001',
    type: 'optimization',
    title: 'Optimize Manila Branch Performance',
    description: 'Based on recent data, the Manila branch shows potential for 15% revenue increase through targeted campaign adjustments.',
    confidence: 87,
    priority: 'high',
    category: 'Revenue Optimization',
    impact: {
      type: 'revenue',
      estimated_value: 2500000,
      timeframe: 'Next 3 months'
    },
    actions: [
      { id: 'act-001', label: 'View Details', type: 'primary', action: 'view_details' },
      { id: 'act-002', label: 'Apply Changes', type: 'secondary', action: 'apply_optimization' }
    ],
    metadata: {
      data_sources: ['sales_data', 'customer_analytics'],
      last_updated: new Date().toISOString(),
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
    }
  },
  {
    id: 'rec-002',
    type: 'alert',
    title: 'Customer Satisfaction Risk Detected',
    description: 'Multiple indicators suggest declining customer satisfaction in Cebu region. Immediate attention recommended.',
    confidence: 92,
    priority: 'critical',
    category: 'Customer Experience',
    impact: {
      type: 'customer_satisfaction',
      timeframe: 'Immediate'
    },
    actions: [
      { id: 'act-003', label: 'Investigate', type: 'primary', action: 'investigate_issue' },
      { id: 'act-004', label: 'Create Action Plan', type: 'secondary', action: 'create_action_plan' }
    ],
    metadata: {
      data_sources: ['feedback_data', 'nps_scores'],
      last_updated: new Date().toISOString()
    }
  },
  {
    id: 'rec-003',
    type: 'opportunity',
    title: 'New Market Expansion Opportunity',
    description: 'Market analysis reveals untapped potential in Davao with projected 30% market share opportunity.',
    confidence: 74,
    priority: 'medium',
    category: 'Market Expansion',
    impact: {
      type: 'revenue',
      estimated_value: 5000000,
      timeframe: '6-12 months'
    },
    actions: [
      { id: 'act-005', label: 'Market Analysis', type: 'primary', action: 'detailed_analysis' },
      { id: 'act-006', label: 'Feasibility Study', type: 'secondary', action: 'feasibility_study' }
    ],
    metadata: {
      data_sources: ['market_research', 'competitor_analysis'],
      last_updated: new Date().toISOString()
    }
  },
  {
    id: 'rec-004',
    type: 'insight',
    title: 'Seasonal Sales Pattern Identified',
    description: 'Historical data reveals consistent 25% sales spike during Q4. Prepare inventory and marketing strategies.',
    confidence: 95,
    priority: 'medium',
    category: 'Sales Intelligence',
    impact: {
      type: 'efficiency',
      estimated_value: 25,
      timeframe: 'Q4 2024'
    },
    actions: [
      { id: 'act-007', label: 'View Pattern Details', type: 'primary', action: 'view_pattern' },
      { id: 'act-008', label: 'Schedule Planning', type: 'secondary', action: 'schedule_planning' }
    ],
    metadata: {
      data_sources: ['historical_sales', 'seasonal_trends'],
      last_updated: new Date().toISOString()
    }
  }
];

const CACHE_KEY = 'scout_ai_recommendations';
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

export const useRecommendations = (options: UseRecommendationsOptions = {}): UseRecommendationsReturn => {
  const {
    autoRefresh = true,
    refreshInterval = 30000, // 30 seconds
    maxRecommendations = 10,
    confidenceThreshold = 50,
    categories = [],
    enableCaching = true,
    onError
  } = options;

  const [state, setState] = useState<RecommendationsState>({
    recommendations: [],
    isLoading: false,
    error: null,
    lastUpdated: null,
    hasMore: false,
    rateLimitStatus: {
      isRateLimited: false,
      utilizationPercent: 0,
      queuedRequests: 0
    }
  });

  const [dismissedIds, setDismissedIds] = useState<Set<string>>(new Set());

  // Simulated API call with rate limiting
  const fetchRecommendations = useCallback(async (): Promise<Recommendation[]> => {
    return rateLimiter.execute(async () => {
      // Check cache first
      if (enableCaching) {
        const cached = localStorage.getItem(CACHE_KEY);
        if (cached) {
          const { data, timestamp } = JSON.parse(cached);
          if (Date.now() - timestamp < CACHE_DURATION) {
            return data;
          }
        }
      }

      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 800));

      // Simulate occasional rate limit errors for testing
      if (Math.random() < 0.1) { // 10% chance
        const error = new Error('Rate limit exceeded') as any;
        error.status = 429;
        error.retryAfter = 2000;
        throw error;
      }

      // In real implementation, this would be:
      // const response = await fetch('/api/ai/recommendations');
      // if (!response.ok) {
      //   const error = new Error(`HTTP ${response.status}`) as any;
      //   error.status = response.status;
      //   if (response.status === 429) {
      //     error.retryAfter = parseInt(response.headers.get('Retry-After') || '60') * 1000;
      //   }
      //   throw error;
      // }
      // return response.json();

      let filtered = [...MOCK_RECOMMENDATIONS];

      // Apply category filter
      if (categories.length > 0) {
        filtered = filtered.filter(rec => categories.includes(rec.category));
      }

      // Apply confidence threshold
      filtered = filtered.filter(rec => rec.confidence >= confidenceThreshold);

      // Apply max recommendations limit
      filtered = filtered.slice(0, maxRecommendations);

      // Cache the results
      if (enableCaching) {
        localStorage.setItem(CACHE_KEY, JSON.stringify({
          data: filtered,
          timestamp: Date.now()
        }));
      }

      return filtered;
    }, 1); // Priority 1 for regular fetches
  }, [categories, confidenceThreshold, maxRecommendations, enableCaching]);

  const refetch = useCallback(async () => {
    setState(prev => ({ ...prev, isLoading: true, error: null }));

    try {
      const recommendations = await fetchRecommendations();
      
      // Filter out dismissed recommendations
      const activeRecommendations = recommendations.filter(rec => !dismissedIds.has(rec.id));
      
      // Update rate limit status
      const rateLimitStatus = rateLimiter.getStatus();
      
      setState(prev => ({
        ...prev,
        recommendations: activeRecommendations,
        isLoading: false,
        lastUpdated: new Date(),
        hasMore: recommendations.length > activeRecommendations.length,
        rateLimitStatus: {
          isRateLimited: rateLimitStatus.utilizationPercent >= 80,
          retryAfter: rateLimitStatus.windowTimeLeftMs,
          utilizationPercent: rateLimitStatus.utilizationPercent,
          queuedRequests: rateLimitStatus.queuedRequests
        }
      }));
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Failed to fetch recommendations';
      
      // Check if it's a rate limit error
      const isRateLimited = error instanceof Error && (
        error.message.toLowerCase().includes('rate limit') ||
        (error as any).status === 429
      );
      
      setState(prev => ({
        ...prev,
        isLoading: false,
        error: errorMessage,
        rateLimitStatus: {
          isRateLimited,
          retryAfter: isRateLimited ? (error as any).retryAfter : undefined,
          utilizationPercent: rateLimiter.getStatus().utilizationPercent,
          queuedRequests: rateLimiter.getStatus().queuedRequests
        }
      }));
      
      if (onError) {
        onError(error instanceof Error ? error : new Error(errorMessage));
      }
    }
  }, [fetchRecommendations, dismissedIds, onError]);

  const dismissRecommendation = useCallback((id: string) => {
    setDismissedIds(prev => new Set([...prev, id]));
    setState(prev => ({
      ...prev,
      recommendations: prev.recommendations.filter(rec => rec.id !== id)
    }));

    // In real implementation, persist dismissal to backend
    // fetch('/api/ai/recommendations/${id}/dismiss', { method: 'POST' });
  }, []);

  const executeAction = useCallback(async (recommendationId: string, actionId: string): Promise<boolean> => {
    return rateLimiter.execute(async () => {
      try {
        // In real implementation:
        // const response = await fetch(`/api/ai/recommendations/${recommendationId}/actions/${actionId}`, {
        //   method: 'POST'
        // });
        // return response.ok;

        // Simulate action execution
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // Mock success/failure
        const success = Math.random() > 0.1; // 90% success rate
        
        if (success) {
          // Optionally update the recommendation or remove it
          setState(prev => ({
            ...prev,
            recommendations: prev.recommendations.map(rec => {
              if (rec.id === recommendationId) {
                return {
                  ...rec,
                  metadata: {
                    ...rec.metadata,
                    last_updated: new Date().toISOString()
                  }
                };
              }
              return rec;
            })
          }));
        }
        
        return success;
      } catch (error) {
        console.error('Failed to execute action:', error);
        return false;
      }
    }, 2); // Priority 2 for action execution (higher priority than regular fetches)
  }, []);

  const clearError = useCallback(() => {
    setState(prev => ({ ...prev, error: null }));
  }, []);

  const getRateLimitStatus = useCallback(() => {
    return rateLimiter.getStatus();
  }, []);

  const clearRateLimitQueue = useCallback(() => {
    rateLimiter.clearQueue();
  }, []);

  // Computed values
  const getRecommendationsByCategory = useCallback((category: string): Recommendation[] => {
    return state.recommendations.filter(rec => rec.category === category);
  }, [state.recommendations]);

  const getHighPriorityRecommendations = useCallback((): Recommendation[] => {
    return state.recommendations.filter(rec => rec.priority === 'high' || rec.priority === 'critical');
  }, [state.recommendations]);

  // Auto-refresh effect
  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(() => {
      if (!state.isLoading) {
        refetch();
      }
    }, refreshInterval);

    return () => clearInterval(interval);
  }, [autoRefresh, refreshInterval, refetch, state.isLoading]);

  // Initial fetch
  useEffect(() => {
    refetch();
  }, [refetch]);

  return {
    ...state,
    refetch,
    dismissRecommendation,
    executeAction,
    clearError,
    getRecommendationsByCategory,
    getHighPriorityRecommendations,
    getRateLimitStatus,
    clearRateLimitQueue
  };
};

// Hook for managing recommendation feature flags with Supabase integration
export const useRecommendationFeatures = () => {
  const [features, setFeatures] = useState({
    enabled: true,
    showConfidence: true,
    allowDismiss: true,
    autoRefresh: true,
    actionExecution: true
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Feature flag keys mapping to Supabase feature flags
  const FEATURE_FLAG_KEYS = {
    enabled: 'ai.recommendations.enabled',
    showConfidence: 'ai.recommendations.show_confidence',
    allowDismiss: 'ai.recommendations.allow_dismiss',
    autoRefresh: 'ai.recommendations.auto_refresh',
    actionExecution: 'ai.recommendations.action_execution'
  };

  // Fetch feature flags from Supabase
  const fetchFeatureFlags = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);

      // In a real implementation, this would call the Supabase RPC
      // const { data } = await supabase.rpc('get_feature_flags', {
      //   flag_keys: Object.values(FEATURE_FLAG_KEYS)
      // });

      // Mock implementation for now - replace with actual Supabase call
      const mockFeatureFlags = {
        'ai.recommendations.enabled': { enabled: true, payload: {} },
        'ai.recommendations.show_confidence': { enabled: true, payload: {} },
        'ai.recommendations.allow_dismiss': { enabled: true, payload: {} },
        'ai.recommendations.auto_refresh': { enabled: true, payload: {} },
        'ai.recommendations.action_execution': { enabled: true, payload: {} }
      };

      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 300));

      // Update features state
      const updatedFeatures = Object.entries(FEATURE_FLAG_KEYS).reduce((acc, [key, flagKey]) => {
        const flag = mockFeatureFlags[flagKey];
        acc[key as keyof typeof features] = flag?.enabled ?? false;
        return acc;
      }, {} as typeof features);

      setFeatures(updatedFeatures);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch feature flags';
      setError(errorMessage);
      console.error('Error fetching feature flags:', err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Toggle feature flag in Supabase
  const toggleFeature = useCallback(async (featureName: keyof typeof features) => {
    try {
      setIsLoading(true);
      setError(null);

      const flagKey = FEATURE_FLAG_KEYS[featureName];
      const newValue = !features[featureName];

      // In a real implementation, this would call the Supabase RPC
      // const { data, error } = await supabase.rpc('toggle_feature_flag', {
      //   flag_key: flagKey,
      //   enabled: newValue
      // });

      // if (error) throw error;

      // Mock implementation - replace with actual Supabase call
      await new Promise(resolve => setTimeout(resolve, 200));

      // Optimistically update local state
      setFeatures(prev => ({
        ...prev,
        [featureName]: newValue
      }));

      // Store in localStorage as fallback
      localStorage.setItem(`feature_flag_${flagKey}`, JSON.stringify({
        enabled: newValue,
        updated_at: new Date().toISOString()
      }));

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to toggle feature flag';
      setError(errorMessage);
      console.error('Error toggling feature flag:', err);
      
      // Revert optimistic update on error
      await fetchFeatureFlags();
    } finally {
      setIsLoading(false);
    }
  }, [features, fetchFeatureFlags]);

  // Load from localStorage as fallback
  useEffect(() => {
    const loadFromLocalStorage = () => {
      const updatedFeatures = { ...features };
      let hasChanges = false;

      Object.entries(FEATURE_FLAG_KEYS).forEach(([key, flagKey]) => {
        const stored = localStorage.getItem(`feature_flag_${flagKey}`);
        if (stored) {
          try {
            const { enabled } = JSON.parse(stored);
            if (updatedFeatures[key as keyof typeof features] !== enabled) {
              updatedFeatures[key as keyof typeof features] = enabled;
              hasChanges = true;
            }
          } catch (e) {
            console.warn(`Invalid stored feature flag for ${flagKey}:`, e);
          }
        }
      });

      if (hasChanges) {
        setFeatures(updatedFeatures);
      }
    };

    loadFromLocalStorage();
    // Attempt to fetch from Supabase
    fetchFeatureFlags();
  }, [fetchFeatureFlags]);

  // Listen for feature flag updates from other tabs/windows
  useEffect(() => {
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key?.startsWith('feature_flag_ai.recommendations.')) {
        fetchFeatureFlags();
      }
    };

    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, [fetchFeatureFlags]);

  return {
    features,
    toggleFeature,
    isLoading,
    error,
    refetchFlags: fetchFeatureFlags
  };
};