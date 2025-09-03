// ============================================================================
// Trace Agent Evaluations Edge Function
// Scheduled function that collects and evaluates agent performance metrics
// Runs every 15 minutes via cron schedule
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Types
interface AgentMetric {
  agent: string;
  task: string;
  metric: string;
  score: number;
  executionTimeMs: number;
  errorCount: number;
  toolCalls: any[];
  metadata: Record<string, any>;
}

interface AgentEvaluation {
  agentName: string;
  overallScore: number;
  reliability: number;
  efficiency: number;
  accuracy: number;
  taskCompletionRate: number;
  averageExecutionTime: number;
  errorRate: number;
  recentActivity: number;
}

interface EvaluationContext {
  timeWindowMinutes: number;
  scoringWeights: {
    reliability: number;
    efficiency: number;
    accuracy: number;
    taskCompletion: number;
  };
  performanceThresholds: {
    excellent: number;
    good: number;
    fair: number;
    poor: number;
  };
}

// Configuration
const EVALUATION_CONFIG: EvaluationContext = {
  timeWindowMinutes: 60, // Evaluate last hour
  scoringWeights: {
    reliability: 0.3,
    efficiency: 0.25,
    accuracy: 0.25,
    taskCompletion: 0.2
  },
  performanceThresholds: {
    excellent: 90,
    good: 75,
    fair: 60,
    poor: 40
  }
};

// Agent-specific metric evaluators
const AGENT_EVALUATORS = {
  'CESAI': {
    keyMetrics: ['ToolErrorRate', 'FinalResultRelevance', 'CreativeScore'],
    weightFactors: { accuracy: 1.2, reliability: 1.1 }
  },
  'Claudia': {
    keyMetrics: ['FlowAdherence', 'OrchestrationEfficiency', 'TaskCompletionRate'],
    weightFactors: { taskCompletion: 1.3, reliability: 1.2 }
  },
  'Echo': {
    keyMetrics: ['ExtractionAccuracy', 'ProcessingSpeed', 'DataCompleteness'],
    weightFactors: { efficiency: 1.2, accuracy: 1.1 }
  }
};

serve(async (req: Request) => {
  try {
    console.log('🚀 Starting trace agent evaluations...');

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get evaluation time window
    const evaluationStart = new Date();
    evaluationStart.setMinutes(evaluationStart.getMinutes() - EVALUATION_CONFIG.timeWindowMinutes);

    console.log(`⏰ Evaluating agents from ${evaluationStart.toISOString()} to ${new Date().toISOString()}`);

    // Fetch recent agent metrics
    const { data: recentMetrics, error: metricsError } = await supabase
      .from('agentdash.agent_trace_metrics')
      .select('*')
      .gte('timestamp', evaluationStart.toISOString())
      .order('timestamp', { ascending: false });

    if (metricsError) {
      throw new Error(`Failed to fetch metrics: ${metricsError.message}`);
    }

    console.log(`📊 Found ${recentMetrics?.length || 0} recent metrics`);

    // Group metrics by agent
    const metricsByAgent = groupMetricsByAgent(recentMetrics || []);

    // Evaluate each agent
    const evaluations: AgentEvaluation[] = [];
    
    for (const [agentName, metrics] of Object.entries(metricsByAgent)) {
      console.log(`🤖 Evaluating agent: ${agentName}`);
      
      const evaluation = await evaluateAgent(agentName, metrics, supabase);
      evaluations.push(evaluation);

      // Store evaluation results
      await storeEvaluation(evaluation, supabase);
    }

    // Generate system-wide insights
    const systemInsights = generateSystemInsights(evaluations);
    await storeSystemInsights(systemInsights, supabase);

    // Check for alerts and anomalies
    const alerts = checkForAlerts(evaluations);
    if (alerts.length > 0) {
      await handleAlerts(alerts, supabase);
    }

    // Update performance aggregations
    await updatePerformanceAggregations(supabase);

    const response = {
      success: true,
      evaluationTime: new Date().toISOString(),
      agentsEvaluated: evaluations.length,
      totalMetrics: recentMetrics?.length || 0,
      systemInsights,
      alerts: alerts.length,
      summary: evaluations.map(e => ({
        agent: e.agentName,
        score: e.overallScore,
        status: getPerformanceStatus(e.overallScore)
      }))
    };

    console.log('✅ Agent evaluations completed successfully');
    console.log(`📈 System Performance Summary:`, response.summary);

    return new Response(JSON.stringify(response), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (error) {
    console.error('❌ Error in trace agent evaluations:', error);
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    });
  }
});

// Helper Functions
function groupMetricsByAgent(metrics: any[]): Record<string, any[]> {
  return metrics.reduce((acc, metric) => {
    if (!acc[metric.agent]) {
      acc[metric.agent] = [];
    }
    acc[metric.agent].push(metric);
    return acc;
  }, {} as Record<string, any[]>);
}

async function evaluateAgent(
  agentName: string,
  metrics: any[],
  supabase: any
): Promise<AgentEvaluation> {
  
  const evaluator = AGENT_EVALUATORS[agentName as keyof typeof AGENT_EVALUATORS];
  const weights = evaluator?.weightFactors || {};

  // Calculate base metrics
  const totalMetrics = metrics.length;
  const successfulMetrics = metrics.filter(m => m.error_count === 0);
  const failedMetrics = metrics.filter(m => m.error_count > 0);

  // Reliability: Success rate
  const reliability = totalMetrics > 0 ? (successfulMetrics.length / totalMetrics) * 100 : 0;

  // Efficiency: Average execution time (inverted score)
  const avgExecutionTime = metrics.length > 0 
    ? metrics.reduce((sum, m) => sum + (m.execution_time_ms || 0), 0) / metrics.length
    : 0;
  const efficiency = Math.max(0, 100 - (avgExecutionTime / 1000)); // Normalize to seconds

  // Accuracy: Average score
  const accuracy = metrics.length > 0
    ? metrics.reduce((sum, m) => sum + (m.score || 0), 0) / metrics.length
    : 0;

  // Task completion rate: Successful tasks vs total tasks
  const uniqueTasks = new Set(metrics.map(m => m.task)).size;
  const completedTasks = new Set(successfulMetrics.map(m => m.task)).size;
  const taskCompletionRate = uniqueTasks > 0 ? (completedTasks / uniqueTasks) * 100 : 0;

  // Apply agent-specific weights
  const weightedReliability = reliability * (weights.reliability || 1.0);
  const weightedEfficiency = efficiency * (weights.efficiency || 1.0);
  const weightedAccuracy = accuracy * (weights.accuracy || 1.0);
  const weightedTaskCompletion = taskCompletionRate * (weights.taskCompletion || 1.0);

  // Calculate overall score
  const overallScore = (
    weightedReliability * EVALUATION_CONFIG.scoringWeights.reliability +
    weightedEfficiency * EVALUATION_CONFIG.scoringWeights.efficiency +
    weightedAccuracy * EVALUATION_CONFIG.scoringWeights.accuracy +
    weightedTaskCompletion * EVALUATION_CONFIG.scoringWeights.taskCompletion
  );

  return {
    agentName,
    overallScore: Math.round(overallScore * 100) / 100,
    reliability: Math.round(weightedReliability * 100) / 100,
    efficiency: Math.round(weightedEfficiency * 100) / 100,
    accuracy: Math.round(weightedAccuracy * 100) / 100,
    taskCompletionRate: Math.round(weightedTaskCompletion * 100) / 100,
    averageExecutionTime: Math.round(avgExecutionTime),
    errorRate: Math.round((failedMetrics.length / Math.max(totalMetrics, 1)) * 100 * 100) / 100,
    recentActivity: totalMetrics
  };
}

async function storeEvaluation(evaluation: AgentEvaluation, supabase: any): Promise<void> {
  // Store in agent_trace_metrics as a summary metric
  const { error } = await supabase
    .from('agentdash.agent_trace_metrics')
    .insert({
      agent: evaluation.agentName,
      task: 'EVALUATION_SUMMARY',
      metric: 'OverallPerformance',
      score: evaluation.overallScore,
      execution_time_ms: evaluation.averageExecutionTime,
      error_count: 0,
      metadata: {
        evaluation_type: 'automated_system_evaluation',
        reliability: evaluation.reliability,
        efficiency: evaluation.efficiency,
        accuracy: evaluation.accuracy,
        task_completion_rate: evaluation.taskCompletionRate,
        error_rate: evaluation.errorRate,
        recent_activity: evaluation.recentActivity,
        evaluation_time: new Date().toISOString()
      }
    });

  if (error) {
    console.error(`❌ Failed to store evaluation for ${evaluation.agentName}:`, error);
  } else {
    console.log(`✅ Stored evaluation for ${evaluation.agentName}: ${evaluation.overallScore}`);
  }
}

function generateSystemInsights(evaluations: AgentEvaluation[]): Record<string, any> {
  const totalAgents = evaluations.length;
  const averageScore = evaluations.reduce((sum, e) => sum + e.overallScore, 0) / totalAgents;
  const highPerformingAgents = evaluations.filter(e => e.overallScore >= EVALUATION_CONFIG.performanceThresholds.good).length;
  const lowPerformingAgents = evaluations.filter(e => e.overallScore < EVALUATION_CONFIG.performanceThresholds.fair).length;

  return {
    totalAgents,
    averageSystemScore: Math.round(averageScore * 100) / 100,
    highPerformingAgents,
    lowPerformingAgents,
    systemHealth: getSystemHealth(averageScore),
    topPerformer: evaluations.reduce((top, current) => 
      current.overallScore > top.overallScore ? current : top, evaluations[0]
    ),
    needsAttention: evaluations.filter(e => 
      e.overallScore < EVALUATION_CONFIG.performanceThresholds.fair || e.errorRate > 10
    )
  };
}

async function storeSystemInsights(insights: Record<string, any>, supabase: any): Promise<void> {
  const { error } = await supabase
    .from('agentdash.agent_trace_metrics')
    .insert({
      agent: 'SYSTEM',
      task: 'SYSTEM_EVALUATION',
      metric: 'SystemHealthScore',
      score: insights.averageSystemScore,
      execution_time_ms: 0,
      error_count: 0,
      metadata: {
        ...insights,
        evaluation_type: 'system_wide_evaluation',
        evaluation_time: new Date().toISOString()
      }
    });

  if (error) {
    console.error('❌ Failed to store system insights:', error);
  } else {
    console.log(`✅ Stored system insights: ${insights.averageSystemScore}`);
  }
}

function checkForAlerts(evaluations: AgentEvaluation[]): any[] {
  const alerts = [];

  for (const evaluation of evaluations) {
    // Performance degradation alerts
    if (evaluation.overallScore < EVALUATION_CONFIG.performanceThresholds.poor) {
      alerts.push({
        type: 'PERFORMANCE_CRITICAL',
        agent: evaluation.agentName,
        message: `Agent ${evaluation.agentName} performance critically low: ${evaluation.overallScore}`,
        severity: 'critical',
        data: evaluation
      });
    } else if (evaluation.overallScore < EVALUATION_CONFIG.performanceThresholds.fair) {
      alerts.push({
        type: 'PERFORMANCE_WARNING',
        agent: evaluation.agentName,
        message: `Agent ${evaluation.agentName} performance below threshold: ${evaluation.overallScore}`,
        severity: 'warning',
        data: evaluation
      });
    }

    // High error rate alerts
    if (evaluation.errorRate > 15) {
      alerts.push({
        type: 'ERROR_RATE_HIGH',
        agent: evaluation.agentName,
        message: `Agent ${evaluation.agentName} has high error rate: ${evaluation.errorRate}%`,
        severity: 'warning',
        data: evaluation
      });
    }

    // Low activity alerts (possible failure)
    if (evaluation.recentActivity === 0) {
      alerts.push({
        type: 'NO_ACTIVITY',
        agent: evaluation.agentName,
        message: `Agent ${evaluation.agentName} has no recent activity`,
        severity: 'warning',
        data: evaluation
      });
    }
  }

  return alerts;
}

async function handleAlerts(alerts: any[], supabase: any): Promise<void> {
  console.log(`🚨 Handling ${alerts.length} alerts`);

  for (const alert of alerts) {
    // Store alert in monitoring system
    const { error } = await supabase
      .from('scout_monitoring.alert_history')
      .insert({
        rule_id: null, // System-generated alert
        severity: alert.severity,
        message: alert.message,
        details: {
          alert_type: alert.type,
          agent: alert.agent,
          data: alert.data,
          generated_by: 'trace-agent-evaluations',
          timestamp: new Date().toISOString()
        }
      });

    if (error) {
      console.error(`❌ Failed to store alert:`, error);
    } else {
      console.log(`✅ Alert stored: ${alert.type} for ${alert.agent}`);
    }

    // TODO: Send notifications (webhook, email, etc.)
    // await sendAlertNotification(alert);
  }
}

async function updatePerformanceAggregations(supabase: any): Promise<void> {
  try {
    // Call the aggregation function
    const { error } = await supabase.rpc('agentdash.aggregate_performance', {
      p_period_hours: 1
    });

    if (error) {
      console.error('❌ Failed to update performance aggregations:', error);
    } else {
      console.log('✅ Performance aggregations updated');
    }
  } catch (error) {
    console.error('❌ Error updating performance aggregations:', error);
  }
}

function getPerformanceStatus(score: number): string {
  const thresholds = EVALUATION_CONFIG.performanceThresholds;
  
  if (score >= thresholds.excellent) return 'excellent';
  if (score >= thresholds.good) return 'good';
  if (score >= thresholds.fair) return 'fair';
  return 'poor';
}

function getSystemHealth(averageScore: number): string {
  if (averageScore >= 85) return 'healthy';
  if (averageScore >= 70) return 'warning';
  return 'critical';
}