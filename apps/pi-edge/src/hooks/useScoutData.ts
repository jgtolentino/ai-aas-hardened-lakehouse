// Scout Analytics - Custom React Hooks for Data Fetching
import { useState, useEffect, useCallback } from 'react';
import {
  fetchDashboardMetrics,
  fetchEdgeDeviceStatus,
  fetchSystemHealth,
  fetchPipelineStatus,
  fetchQueueStatus,
  fetchRecentTransactions,
  fetchStorePerformance,
  fetchUnifiedAnalytics,
  fetchRealtimeActivity,
  fetchConfidenceAlerts,
  DashboardMetrics,
  EdgeDeviceStatus,
  SystemHealth,
  PipelineStatus,
  QueueStatus
} from '../services/scoutService';

interface UseDataResult<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  refresh: () => void;
}

// Generic hook for data fetching with loading states
function useAsyncData<T>(
  fetchFn: () => Promise<T>,
  deps: any[] = [],
  autoRefresh: number = 0
): UseDataResult<T> {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await fetchFn();
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      console.error('Data fetch error:', err);
    } finally {
      setLoading(false);
    }
  }, deps);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Auto refresh if specified
  useEffect(() => {
    if (autoRefresh > 0) {
      const interval = setInterval(fetchData, autoRefresh);
      return () => clearInterval(interval);
    }
  }, [fetchData, autoRefresh]);

  return {
    data,
    loading,
    error,
    refresh: fetchData
  };
}

// Dashboard metrics hook
export function useDashboardMetrics(autoRefresh = 30000) {
  return useAsyncData<DashboardMetrics[]>(fetchDashboardMetrics, [], autoRefresh);
}

// Edge device status hook
export function useEdgeDeviceStatus(autoRefresh = 10000) {
  return useAsyncData<EdgeDeviceStatus[]>(fetchEdgeDeviceStatus, [], autoRefresh);
}

// System health hook
export function useSystemHealth(autoRefresh = 30000) {
  return useAsyncData<SystemHealth[]>(fetchSystemHealth, [], autoRefresh);
}

// Pipeline status hook
export function usePipelineStatus(autoRefresh = 5000) {
  return useAsyncData<PipelineStatus[]>(fetchPipelineStatus, [], autoRefresh);
}

// Queue status hook
export function useQueueStatus(autoRefresh = 15000) {
  return useAsyncData<QueueStatus[]>(fetchQueueStatus, [], autoRefresh);
}

// Recent transactions hook
export function useRecentTransactions(limit = 20, autoRefresh = 10000) {
  return useAsyncData(
    () => fetchRecentTransactions(limit),
    [limit],
    autoRefresh
  );
}

// Store performance hook
export function useStorePerformance(autoRefresh = 60000) {
  return useAsyncData(fetchStorePerformance, [], autoRefresh);
}

// Unified analytics hook
export function useUnifiedAnalytics(hours = 24, autoRefresh = 30000) {
  return useAsyncData(
    () => fetchUnifiedAnalytics(hours),
    [hours],
    autoRefresh
  );
}

// Real-time activity hook
export function useRealtimeActivity(autoRefresh = 5000) {
  return useAsyncData(fetchRealtimeActivity, [], autoRefresh);
}

// Confidence alerts hook
export function useConfidenceAlerts(autoRefresh = 60000) {
  return useAsyncData(fetchConfidenceAlerts, [], autoRefresh);
}

// Combined dashboard hook that fetches all essential data
export function useScoutDashboard() {
  const metrics = useDashboardMetrics();
  const devices = useEdgeDeviceStatus();
  const health = useSystemHealth();
  const pipeline = usePipelineStatus();
  const queue = useQueueStatus();

  const loading = metrics.loading || devices.loading || health.loading || pipeline.loading || queue.loading;
  const error = metrics.error || devices.error || health.error || pipeline.error || queue.error;

  const refresh = useCallback(() => {
    metrics.refresh();
    devices.refresh();
    health.refresh();
    pipeline.refresh();
    queue.refresh();
  }, [metrics, devices, health, pipeline, queue]);

  return {
    metrics: metrics.data,
    devices: devices.data,
    health: health.data,
    pipeline: pipeline.data,
    queue: queue.data,
    loading,
    error,
    refresh
  };
}