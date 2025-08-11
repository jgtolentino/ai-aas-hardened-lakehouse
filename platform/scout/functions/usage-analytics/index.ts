import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Dataset Usage Analytics Dashboard API
 * 
 * Tracks and provides insights on dataset usage patterns across the
 * Scout Analytics platform including downloads, API calls, exports, and user engagement.
 */

interface UsageMetric {
  metric_name: string;
  metric_value: number;
  timestamp: string;
  metadata: Record<string, any>;
}

interface DatasetUsageStats {
  dataset_name: string;
  total_downloads: number;
  total_api_calls: number;
  total_exports: number;
  unique_users: number;
  average_file_size: number;
  peak_usage_hour: number;
  popular_formats: Array<{format: string, count: number}>;
  geographic_distribution: Array<{region: string, usage_count: number}>;
  usage_trend: Array<{date: string, downloads: number, api_calls: number}>;
  last_accessed: string;
}

interface UsageAnalyticsResponse {
  summary: {
    total_datasets: number;
    total_downloads_today: number;
    total_api_calls_today: number;
    active_users_today: number;
    storage_used_gb: number;
    bandwidth_used_gb: number;
  };
  top_datasets: DatasetUsageStats[];
  usage_patterns: {
    hourly_distribution: Array<{hour: number, usage: number}>;
    daily_trends: Array<{date: string, downloads: number, api_calls: number}>;
    format_preferences: Array<{format: string, percentage: number}>;
  };
  user_analytics: {
    new_users_today: number;
    returning_users: number;
    user_segments: Array<{segment: string, count: number}>;
  };
  performance_metrics: {
    average_response_time: number;
    error_rate: number;
    cache_hit_rate: number;
  };
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

// Initialize Supabase client
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

/**
 * Track a usage event
 */
async function trackUsageEvent(
  eventType: string,
  dataset: string,
  userId: string,
  metadata: Record<string, any> = {}
): Promise<void> {
  try {
    const { error } = await supabase
      .from('dataset_usage_logs')
      .insert({
        event_type: eventType,
        dataset_name: dataset,
        user_id: userId,
        metadata: metadata,
        timestamp: new Date().toISOString(),
        ip_address: metadata.ip_address,
        user_agent: metadata.user_agent,
        file_size: metadata.file_size,
        format: metadata.format,
        region: metadata.region || 'unknown',
      });

    if (error) {
      console.error('Failed to track usage event:', error);
    }
  } catch (error) {
    console.error('Error tracking usage:', error);
  }
}

/**
 * Get dataset usage statistics
 */
async function getDatasetUsageStats(datasetName?: string): Promise<DatasetUsageStats[]> {
  let query = supabase
    .from('dataset_usage_summary')
    .select('*')
    .order('total_downloads', { ascending: false });

  if (datasetName) {
    query = query.eq('dataset_name', datasetName);
  } else {
    query = query.limit(10); // Top 10 datasets
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch usage stats: ${error.message}`);
  }

  return data || [];
}

/**
 * Get usage analytics dashboard data
 */
async function getUsageAnalytics(timeRange: string = '7d'): Promise<UsageAnalyticsResponse> {
  const now = new Date();
  let startDate: Date;

  switch (timeRange) {
    case '1d':
      startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      break;
    case '7d':
      startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      break;
    case '30d':
      startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      break;
    default:
      startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  }

  // Get summary metrics
  const { data: summaryData } = await supabase.rpc('get_usage_summary', {
    start_date: startDate.toISOString(),
    end_date: now.toISOString()
  });

  // Get top datasets
  const topDatasets = await getDatasetUsageStats();

  // Get hourly usage patterns
  const { data: hourlyData } = await supabase.rpc('get_hourly_usage_pattern', {
    start_date: startDate.toISOString(),
    end_date: now.toISOString()
  });

  // Get daily trends
  const { data: dailyTrends } = await supabase.rpc('get_daily_usage_trends', {
    start_date: startDate.toISOString(),
    end_date: now.toISOString()
  });

  // Get format preferences
  const { data: formatData } = await supabase.rpc('get_format_preferences', {
    start_date: startDate.toISOString(),
    end_date: now.toISOString()
  });

  // Get user analytics
  const { data: userAnalytics } = await supabase.rpc('get_user_analytics', {
    start_date: startDate.toISOString(),
    end_date: now.toISOString()
  });

  // Get performance metrics
  const { data: performanceData } = await supabase.rpc('get_performance_metrics', {
    start_date: startDate.toISOString(),
    end_date: now.toISOString()
  });

  return {
    summary: summaryData?.[0] || {
      total_datasets: 0,
      total_downloads_today: 0,
      total_api_calls_today: 0,
      active_users_today: 0,
      storage_used_gb: 0,
      bandwidth_used_gb: 0,
    },
    top_datasets: topDatasets,
    usage_patterns: {
      hourly_distribution: hourlyData || [],
      daily_trends: dailyTrends || [],
      format_preferences: formatData || [],
    },
    user_analytics: userAnalytics?.[0] || {
      new_users_today: 0,
      returning_users: 0,
      user_segments: [],
    },
    performance_metrics: performanceData?.[0] || {
      average_response_time: 0,
      error_rate: 0,
      cache_hit_rate: 0,
    }
  };
}

/**
 * Generate usage insights and recommendations
 */
async function generateUsageInsights(): Promise<{
  insights: string[];
  recommendations: string[];
  alerts: string[];
}> {
  const analytics = await getUsageAnalytics('30d');
  const insights: string[] = [];
  const recommendations: string[] = [];
  const alerts: string[] = [];

  // Analyze top datasets
  if (analytics.top_datasets.length > 0) {
    const topDataset = analytics.top_datasets[0];
    insights.push(`Most popular dataset: ${topDataset.dataset_name} with ${topDataset.total_downloads} downloads`);
    
    if (topDataset.total_downloads > 1000) {
      recommendations.push(`Consider caching ${topDataset.dataset_name} for better performance`);
    }
  }

  // Analyze usage patterns
  const peakHour = analytics.usage_patterns.hourly_distribution
    .reduce((max, curr) => curr.usage > max.usage ? curr : max, { hour: 0, usage: 0 });
  
  if (peakHour.usage > 0) {
    insights.push(`Peak usage occurs at ${peakHour.hour}:00 UTC`);
    recommendations.push(`Scale resources during peak hours (${peakHour.hour}:00 UTC)`);
  }

  // Performance alerts
  if (analytics.performance_metrics.error_rate > 5) {
    alerts.push(`High error rate detected: ${analytics.performance_metrics.error_rate}%`);
  }

  if (analytics.performance_metrics.average_response_time > 2000) {
    alerts.push(`Slow response times: ${analytics.performance_metrics.average_response_time}ms average`);
  }

  // Storage alerts
  if (analytics.summary.storage_used_gb > 100) {
    alerts.push(`High storage usage: ${analytics.summary.storage_used_gb}GB`);
    recommendations.push('Consider implementing data archiving policies');
  }

  return { insights, recommendations, alerts };
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const { pathname, searchParams } = url;

    // Route: Track usage event
    if (pathname === '/track' && req.method === 'POST') {
      const { event_type, dataset, user_id, metadata } = await req.json();
      
      await trackUsageEvent(event_type, dataset, user_id, metadata);
      
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get usage analytics dashboard
    if (pathname === '/analytics') {
      const timeRange = searchParams.get('range') || '7d';
      const analytics = await getUsageAnalytics(timeRange);
      
      return new Response(JSON.stringify(analytics), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get dataset-specific stats
    if (pathname === '/dataset-stats') {
      const datasetName = searchParams.get('dataset');
      const stats = await getDatasetUsageStats(datasetName || undefined);
      
      return new Response(JSON.stringify(stats), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get usage insights
    if (pathname === '/insights') {
      const insights = await generateUsageInsights();
      
      return new Response(JSON.stringify(insights), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Export usage report
    if (pathname === '/export') {
      const format = searchParams.get('format') || 'json';
      const timeRange = searchParams.get('range') || '7d';
      
      const analytics = await getUsageAnalytics(timeRange);
      const insights = await generateUsageInsights();
      
      const report = {
        generated_at: new Date().toISOString(),
        time_range: timeRange,
        analytics,
        insights,
      };

      if (format === 'csv') {
        // Convert to CSV format
        const csvData = analytics.top_datasets.map(dataset => ({
          dataset: dataset.dataset_name,
          downloads: dataset.total_downloads,
          api_calls: dataset.total_api_calls,
          unique_users: dataset.unique_users,
          last_accessed: dataset.last_accessed,
        }));
        
        const csvHeaders = Object.keys(csvData[0] || {});
        const csvRows = csvData.map(row => csvHeaders.map(h => row[h]).join(','));
        const csvContent = [csvHeaders.join(','), ...csvRows].join('\n');
        
        return new Response(csvContent, {
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'text/csv',
            'Content-Disposition': `attachment; filename="usage-report-${timeRange}.csv"`
          }
        });
      }

      return new Response(JSON.stringify(report, null, 2), {
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'Content-Disposition': `attachment; filename="usage-report-${timeRange}.json"`
        }
      });
    }

    // Route: Health check
    if (pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ error: 'Route not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Usage analytics error:', error);
    
    return new Response(JSON.stringify({
      error: 'Internal server error',
      message: error.message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});