import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Cross-Region Dataset Replication System
 * 
 * Manages dataset replication across multiple regions for improved availability,
 * performance, and disaster recovery. Supports automatic and on-demand replication
 * with cost optimization and monitoring.
 */

interface ReplicationRequest {
  dataset_name: string;
  source_region: string;
  target_regions: string[];
  priority?: number;
  policy?: 'immediate' | 'scheduled' | 'on_demand';
}

interface ReplicationJob {
  job_id: string;
  dataset_name: string;
  source_region: string;
  target_region: string;
  file_path: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  progress_percentage: number;
  estimated_completion: string;
  cost_estimate: number;
}

interface RegionHealth {
  region: string;
  is_active: boolean;
  latency_ms: number;
  success_rate: number;
  available_bandwidth_mbps: number;
  current_jobs: number;
  storage_used_gb: number;
}

interface ReplicationStats {
  summary: {
    total_replications_today: number;
    successful_replications: number;
    failed_replications: number;
    success_rate: number;
    total_data_replicated_gb: number;
    total_estimated_cost: number;
  };
  region_health: RegionHealth[];
  active_jobs: ReplicationJob[];
  replication_queue: {
    pending_jobs: number;
    estimated_queue_time: string;
    high_priority_jobs: number;
  };
  cost_breakdown: Array<{
    region_pair: string;
    cost: number;
    data_transferred_gb: number;
  }>;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
};

// Initialize Supabase client
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

/**
 * Create replication jobs for a dataset
 */
async function createReplicationJobs(request: ReplicationRequest): Promise<ReplicationJob[]> {
  const jobs: ReplicationJob[] = [];
  
  // Get the dataset files to replicate
  const { data: files } = await supabase.storage
    .from('scout-platinum')
    .list('', { 
      search: request.dataset_name 
    });

  if (!files || files.length === 0) {
    throw new Error(`No files found for dataset: ${request.dataset_name}`);
  }

  // Get replication rules for this dataset
  const { data: rules } = await supabase
    .from('dataset_replication_rules')
    .select('*')
    .eq('is_active', true);

  const applicableRule = rules?.find(rule => 
    new RegExp(rule.dataset_pattern).test(request.dataset_name)
  );

  for (const targetRegion of request.target_regions) {
    for (const file of files) {
      const jobId = crypto.randomUUID();
      const filePath = file.name;
      
      // Calculate cost estimate
      const { data: costData } = await supabase
        .rpc('estimate_replication_cost', {
          p_file_size_bytes: file.metadata?.size || 0,
          p_source_region: request.source_region,
          p_target_region: targetRegion
        });

      const costEstimate = costData || 0;

      // Create replication job
      const { error } = await supabase
        .from('replication_jobs')
        .insert({
          job_id: jobId,
          job_type: 'replicate_dataset',
          dataset_name: request.dataset_name,
          source_region: request.source_region,
          target_region: targetRegion,
          file_path: filePath,
          priority: request.priority || applicableRule?.priority || 5,
          status: 'pending',
          scheduled_at: new Date().toISOString(),
          metadata: {
            file_size: file.metadata?.size || 0,
            cost_estimate: costEstimate,
            policy: request.policy || 'on_demand'
          }
        });

      if (error) {
        console.error('Failed to create replication job:', error);
        continue;
      }

      jobs.push({
        job_id: jobId,
        dataset_name: request.dataset_name,
        source_region: request.source_region,
        target_region: targetRegion,
        file_path: filePath,
        status: 'pending',
        progress_percentage: 0,
        estimated_completion: new Date(Date.now() + 30 * 60 * 1000).toISOString(), // 30 min estimate
        cost_estimate: costEstimate
      });
    }
  }

  return jobs;
}

/**
 * Process replication job
 */
async function processReplicationJob(jobId: string): Promise<ReplicationJob> {
  // Get job details
  const { data: job, error: jobError } = await supabase
    .from('replication_jobs')
    .select('*')
    .eq('job_id', jobId)
    .single();

  if (jobError || !job) {
    throw new Error(`Job not found: ${jobId}`);
  }

  // Update job status to in_progress
  await supabase
    .from('replication_jobs')
    .update({ 
      status: 'in_progress',
      started_at: new Date().toISOString(),
      worker_id: `worker-${Math.random().toString(36).substr(2, 9)}`
    })
    .eq('job_id', jobId);

  try {
    // Simulate replication process
    // In a real implementation, this would:
    // 1. Download file from source region
    // 2. Upload to target region
    // 3. Verify checksum
    // 4. Update replica tracking

    const fileSize = job.metadata?.file_size || 0;
    const transferDuration = Math.max(1000, fileSize / (10 * 1024 * 1024) * 1000); // 10 MB/s simulation

    // Create replica record
    const replicaId = crypto.randomUUID();
    
    await supabase
      .from('dataset_replicas')
      .insert({
        replica_id: replicaId,
        dataset_name: job.dataset_name,
        file_path: job.file_path,
        source_region: job.source_region,
        target_region: job.target_region,
        replica_path: `${job.target_region}/${job.file_path}`,
        file_size: fileSize,
        checksum: 'simulated-checksum',
        replication_status: 'completed',
        started_at: job.started_at,
        completed_at: new Date().toISOString(),
        transfer_size_bytes: fileSize,
        transfer_duration_ms: transferDuration,
        cost_estimate: job.metadata?.cost_estimate || 0
      });

    // Update job status
    await supabase
      .from('replication_jobs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString()
      })
      .eq('job_id', jobId);

    return {
      job_id: jobId,
      dataset_name: job.dataset_name,
      source_region: job.source_region,
      target_region: job.target_region,
      file_path: job.file_path,
      status: 'completed',
      progress_percentage: 100,
      estimated_completion: new Date().toISOString(),
      cost_estimate: job.metadata?.cost_estimate || 0
    };

  } catch (error) {
    // Update job status to failed
    await supabase
      .from('replication_jobs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message,
        retry_count: (job.retry_count || 0) + 1
      })
      .eq('job_id', jobId);

    throw error;
  }
}

/**
 * Get replication statistics and monitoring data
 */
async function getReplicationStats(): Promise<ReplicationStats> {
  // Get summary statistics
  const { data: statsData } = await supabase
    .rpc('get_replication_stats', { p_days: 1 });

  const summary = statsData?.[0] || {
    total_replications: 0,
    successful_replications: 0,
    failed_replications: 0,
    success_rate: 100,
    total_data_replicated_gb: 0,
    average_transfer_speed_mbps: 0,
    total_estimated_cost: 0
  };

  // Get region health
  const { data: regionData } = await supabase
    .from('region_configs')
    .select('*')
    .eq('is_active', true);

  const regionHealth: RegionHealth[] = (regionData || []).map(region => ({
    region: region.region,
    is_active: region.is_active,
    latency_ms: region.latency_ms,
    success_rate: 95.5 + Math.random() * 4, // Simulated success rate
    available_bandwidth_mbps: 100 + Math.random() * 900,
    current_jobs: Math.floor(Math.random() * 10),
    storage_used_gb: Math.random() * 1000
  }));

  // Get active jobs
  const { data: jobsData } = await supabase
    .from('replication_jobs')
    .select('*')
    .eq('status', 'in_progress')
    .limit(10);

  const activeJobs: ReplicationJob[] = (jobsData || []).map(job => ({
    job_id: job.job_id,
    dataset_name: job.dataset_name,
    source_region: job.source_region,
    target_region: job.target_region,
    file_path: job.file_path,
    status: job.status,
    progress_percentage: Math.random() * 100,
    estimated_completion: new Date(Date.now() + Math.random() * 30 * 60 * 1000).toISOString(),
    cost_estimate: job.metadata?.cost_estimate || 0
  }));

  // Get queue status
  const { data: queueData } = await supabase
    .from('replication_jobs')
    .select('*')
    .eq('status', 'pending');

  const pendingJobs = queueData?.length || 0;
  const highPriorityJobs = queueData?.filter(job => job.priority <= 2).length || 0;

  // Get cost breakdown
  const { data: costData } = await supabase
    .from('replication_summary')
    .select('source_region, target_region, total_replicated_bytes');

  const costBreakdown = (costData || []).map(row => ({
    region_pair: `${row.source_region} → ${row.target_region}`,
    cost: (row.total_replicated_bytes / (1024**3)) * 0.05, // Estimated cost
    data_transferred_gb: row.total_replicated_bytes / (1024**3)
  }));

  return {
    summary: {
      total_replications_today: summary.total_replications || 0,
      successful_replications: summary.successful_replications || 0,
      failed_replications: summary.failed_replications || 0,
      success_rate: summary.success_rate || 100,
      total_data_replicated_gb: summary.total_data_replicated_gb || 0,
      total_estimated_cost: summary.total_estimated_cost || 0
    },
    region_health: regionHealth,
    active_jobs: activeJobs,
    replication_queue: {
      pending_jobs: pendingJobs,
      estimated_queue_time: `${Math.ceil(pendingJobs / 5)} minutes`,
      high_priority_jobs: highPriorityJobs
    },
    cost_breakdown: costBreakdown
  };
}

/**
 * Find optimal regions for dataset access
 */
async function getOptimalRegions(datasetName: string, userLocation?: string): Promise<Array<{
  region: string;
  replica_path: string;
  latency_ms: number;
  availability_score: number;
}>> {
  const { data, error } = await supabase
    .rpc('get_optimal_region', {
      p_dataset_name: datasetName,
      p_user_location: userLocation || 'us-east-1'
    });

  if (error) {
    throw new Error(`Failed to get optimal regions: ${error.message}`);
  }

  return data || [];
}

/**
 * Cleanup expired replicas
 */
async function cleanupExpiredReplicas(): Promise<{ cleaned_count: number; freed_storage_gb: number }> {
  const { data: expiredReplicas } = await supabase
    .from('dataset_replicas')
    .select('replica_id, file_size')
    .lt('completed_at', new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString()) // 90 days old
    .eq('replication_status', 'completed');

  if (!expiredReplicas || expiredReplicas.length === 0) {
    return { cleaned_count: 0, freed_storage_gb: 0 };
  }

  const totalSize = expiredReplicas.reduce((sum, replica) => sum + (replica.file_size || 0), 0);
  
  // Delete expired replicas
  await supabase
    .from('dataset_replicas')
    .delete()
    .in('replica_id', expiredReplicas.map(r => r.replica_id));

  return {
    cleaned_count: expiredReplicas.length,
    freed_storage_gb: totalSize / (1024**3)
  };
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const { pathname, searchParams } = url;

    // Route: Create replication jobs
    if (pathname === '/replicate' && req.method === 'POST') {
      const replicationRequest = await req.json();

      if (!replicationRequest.dataset_name || !replicationRequest.source_region || !replicationRequest.target_regions) {
        return new Response(JSON.stringify({
          error: 'Missing required fields: dataset_name, source_region, target_regions'
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const jobs = await createReplicationJobs(replicationRequest);

      return new Response(JSON.stringify({
        message: `Created ${jobs.length} replication jobs`,
        jobs: jobs
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Process replication job
    if (pathname.startsWith('/jobs/') && pathname.endsWith('/process') && req.method === 'POST') {
      const jobId = pathname.split('/')[2];
      const result = await processReplicationJob(jobId);

      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get replication statistics
    if (pathname === '/stats' && req.method === 'GET') {
      const stats = await getReplicationStats();

      return new Response(JSON.stringify(stats), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get optimal regions for dataset
    if (pathname === '/optimal-regions' && req.method === 'GET') {
      const datasetName = searchParams.get('dataset');
      const userLocation = searchParams.get('location');

      if (!datasetName) {
        return new Response(JSON.stringify({
          error: 'Missing required parameter: dataset'
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const regions = await getOptimalRegions(datasetName, userLocation || undefined);

      return new Response(JSON.stringify(regions), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get job status
    if (pathname.startsWith('/jobs/') && req.method === 'GET') {
      const jobId = pathname.split('/')[2];

      const { data: job, error } = await supabase
        .from('replication_jobs')
        .select('*')
        .eq('job_id', jobId)
        .single();

      if (error || !job) {
        return new Response(JSON.stringify({ error: 'Job not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      return new Response(JSON.stringify(job), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: List active replicas
    if (pathname === '/replicas' && req.method === 'GET') {
      const datasetName = searchParams.get('dataset');
      const region = searchParams.get('region');
      const limit = parseInt(searchParams.get('limit') || '50');

      let query = supabase
        .from('dataset_replicas')
        .select('*')
        .order('completed_at', { ascending: false })
        .limit(limit);

      if (datasetName) {
        query = query.eq('dataset_name', datasetName);
      }
      if (region) {
        query = query.eq('target_region', region);
      }

      const { data: replicas, error } = await query;

      if (error) {
        throw new Error(`Failed to fetch replicas: ${error.message}`);
      }

      return new Response(JSON.stringify(replicas || []), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Cleanup expired replicas
    if (pathname === '/cleanup' && req.method === 'POST') {
      const result = await cleanupExpiredReplicas();

      return new Response(JSON.stringify({
        message: 'Cleanup completed',
        ...result
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Health check
    if (pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'healthy',
        features: [
          'cross_region_replication',
          'optimal_region_selection',
          'cost_estimation',
          'replica_cleanup'
        ],
        timestamp: new Date().toISOString()
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ error: 'Route not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Cross-region replication error:', error);

    return new Response(JSON.stringify({
      error: 'Internal server error',
      message: error.message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});