// Scout Analytics - Data Service Layer
import { supabase } from '../lib/supabase';

export interface DashboardMetrics {
  metric: string;
  value: string;
  details: any;
}

export interface EdgeDeviceStatus {
  device_id: string;
  device_name: string;
  store_id: string;
  status: string;
  last_heartbeat: string;
  events_24h: number;
  transactions_24h: number;
}

export interface SystemHealth {
  component: string;
  status: string;
  metrics: any;
}

export interface PipelineStatus {
  metric: string;
  value: number;
  unit: string;
  status: string;
}

export interface QueueStatus {
  status: string;
  file_count: number;
  oldest_file: string;
  newest_file: string;
  avg_attempts: number;
}

// Dashboard overview data
export async function fetchDashboardMetrics(): Promise<DashboardMetrics[]> {
  const { data, error } = await supabase
    .rpc('get_ingestion_dashboard');
  
  if (error) throw error;
  return data || [];
}

// Edge device status
export async function fetchEdgeDeviceStatus(): Promise<EdgeDeviceStatus[]> {
  const { data, error } = await supabase
    .rpc('get_device_status');
  
  if (error) throw error;
  return data || [];
}

// System health overview
export async function fetchSystemHealth(): Promise<SystemHealth[]> {
  const { data, error } = await supabase
    .rpc('get_system_health');
  
  if (error) throw error;
  return data || [];
}

// Edge pipeline monitoring
export async function fetchPipelineStatus(): Promise<PipelineStatus[]> {
  const { data, error } = await supabase
    .rpc('get_edge_pipeline_status');
  
  if (error) throw error;
  return data || [];
}

// File ingestion queue status
export async function fetchQueueStatus(): Promise<QueueStatus[]> {
  const { data, error } = await supabase
    .from('v_ingestion_queue_status')
    .select('*');
  
  if (error) throw error;
  return data || [];
}

// Recent transactions
export async function fetchRecentTransactions(limit: number = 20) {
  const { data, error } = await supabase
    .from('v_edge_integrated_transactions')
    .select('*')
    .order('transaction_time', { ascending: false })
    .limit(limit);
  
  if (error) throw error;
  return data || [];
}

// Store performance comparison
export async function fetchStorePerformance() {
  const { data, error } = await supabase
    .from('v_store_performance')
    .select('*')
    .order('edge_revenue', { ascending: false });
  
  if (error) throw error;
  return data || [];
}

// Unified analytics data
export async function fetchUnifiedAnalytics(hours: number = 24) {
  const { data, error } = await supabase
    .from('v_unified_analytics')
    .select('*')
    .gte('hour', new Date(Date.now() - hours * 60 * 60 * 1000).toISOString())
    .order('hour', { ascending: false });
  
  if (error) throw error;
  return data || [];
}

// Real-time activity feed
export async function fetchRealtimeActivity() {
  const { data, error } = await supabase
    .from('v_realtime_activity')
    .select('*')
    .order('timestamp', { ascending: false })
    .limit(50);
  
  if (error) throw error;
  return data || [];
}

// Check confidence alerts
export async function fetchConfidenceAlerts() {
  const { data, error } = await supabase
    .rpc('check_confidence_alerts');
  
  if (error) throw error;
  return data || [];
}

// Scraper status (if scraping is enabled)
export async function fetchScraperStatus() {
  const { data, error } = await supabase
    .rpc('dashboard_snapshot');
  
  if (error) throw error;
  return data || [];
}

// Test API endpoints
export async function testFileIngestion(fileName: string, content: string, storeId: string) {
  const { data, error } = await supabase
    .rpc('upload_file', {
      file_name: fileName,
      file_content: content,
      store_id: storeId
    });
  
  if (error) throw error;
  return data;
}

export async function testEdgeEvent(deviceId: string, eventType: string, eventData: any, confidence: number) {
  const { data, error } = await supabase
    .rpc('ingest_edge_event', {
      p_device_id: deviceId,
      p_event_type: eventType,
      p_event_data: eventData,
      p_confidence: confidence
    });
  
  if (error) throw error;
  return data;
}