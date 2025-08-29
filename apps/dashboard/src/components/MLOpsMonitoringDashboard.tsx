'use client'

import React, { useState, useEffect, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Progress } from "@/components/ui/progress"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { LineChart, Line, AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts'
import { AlertTriangle, TrendingUp, TrendingDown, Activity, DollarSign, Clock, Zap, AlertCircle, CheckCircle, RefreshCw } from 'lucide-react'

// Types
interface ModelMetrics {
  id: string
  function_name: string
  model_version: string
  latency_ms: number
  confidence_score: number
  estimated_cost_usd: number
  error_message: string | null
  created_at: string
}

interface ExperimentResult {
  id: string
  function_name: string
  variant: string
  requests_count: number
  avg_latency: number
  success_rate: number
  conversion_rate: number | null
  created_at: string
}

interface DriftAlert {
  id: string
  function_name: string
  metric_name: string
  drift_score: number
  status: string
  detected_at: string
}

interface CostMetrics {
  function_name: string
  total_cost: number
  avg_cost_per_request: number
  total_requests: number
  cost_trend: number
}

interface DeploymentHistory {
  id: string
  function_name: string
  version: string
  deployment_type: string
  status: string
  created_at: string
  completed_at: string | null
}

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8']

export default function MLOpsMonitoringDashboard() {
  const [metrics, setMetrics] = useState<ModelMetrics[]>([])
  const [experiments, setExperiments] = useState<ExperimentResult[]>([])
  const [driftAlerts, setDriftAlerts] = useState<DriftAlert[]>([])
  const [costMetrics, setCostMetrics] = useState<CostMetrics[]>([])
  const [deployments, setDeployments] = useState<DeploymentHistory[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [lastRefresh, setLastRefresh] = useState<Date>(new Date())

  const supabase = createClient()

  // Fetch all MLOps data
  const fetchMLOpsData = async () => {
    try {
      setLoading(true)
      setError(null)

      // Fetch model performance metrics (last 24 hours)
      const { data: metricsData, error: metricsError } = await supabase
        .from('mlops.model_performance')
        .select('*')
        .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
        .order('created_at', { ascending: false })

      if (metricsError) throw metricsError
      setMetrics(metricsData || [])

      // Fetch A/B test experiments
      const { data: experimentsData, error: experimentsError } = await supabase
        .from('mlops.experiments')
        .select('*')
        .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString())
        .order('created_at', { ascending: false })

      if (experimentsError) throw experimentsError
      setExperiments(experimentsData || [])

      // Fetch drift alerts
      const { data: driftData, error: driftError } = await supabase
        .from('mlops.drift_detection')
        .select('*')
        .gte('detected_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString())
        .order('detected_at', { ascending: false })

      if (driftError) throw driftError
      setDriftAlerts(driftData || [])

      // Fetch deployment history
      const { data: deployData, error: deployError } = await supabase
        .from('mlops.deployments')
        .select('*')
        .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
        .order('created_at', { ascending: false })
        .limit(50)

      if (deployError) throw deployError
      setDeployments(deployData || [])

      setLastRefresh(new Date())
    } catch (err: any) {
      setError(err.message)
      console.error('Error fetching MLOps data:', err)
    } finally {
      setLoading(false)
    }
  }

  // Calculate cost metrics
  const calculateCostMetrics = useMemo(() => {
    const functionStats: { [key: string]: { totalCost: number; totalRequests: number } } = {}

    metrics.forEach(metric => {
      if (!functionStats[metric.function_name]) {
        functionStats[metric.function_name] = { totalCost: 0, totalRequests: 0 }
      }
      functionStats[metric.function_name].totalCost += metric.estimated_cost_usd
      functionStats[metric.function_name].totalRequests += 1
    })

    return Object.entries(functionStats).map(([functionName, stats]) => ({
      function_name: functionName,
      total_cost: stats.totalCost,
      avg_cost_per_request: stats.totalCost / stats.totalRequests,
      total_requests: stats.totalRequests,
      cost_trend: Math.random() * 20 - 10 // Placeholder trend
    }))
  }, [metrics])

  // Performance summary
  const performanceSummary = useMemo(() => {
    if (metrics.length === 0) return null

    const avgLatency = metrics.reduce((sum, m) => sum + m.latency_ms, 0) / metrics.length
    const avgConfidence = metrics.reduce((sum, m) => sum + (m.confidence_score || 0), 0) / metrics.length
    const successRate = metrics.filter(m => !m.error_message).length / metrics.length * 100
    const totalCost = metrics.reduce((sum, m) => sum + m.estimated_cost_usd, 0)

    return { avgLatency, avgConfidence, successRate, totalCost }
  }, [metrics])

  // Chart data preparation
  const latencyTrendData = useMemo(() => {
    const hourlyData: { [key: string]: { latency: number; count: number; hour: string } } = {}

    metrics.forEach(metric => {
      const hour = new Date(metric.created_at).toISOString().slice(0, 13) + ':00'
      if (!hourlyData[hour]) {
        hourlyData[hour] = { latency: 0, count: 0, hour }
      }
      hourlyData[hour].latency += metric.latency_ms
      hourlyData[hour].count += 1
    })

    return Object.values(hourlyData)
      .map(data => ({
        ...data,
        avgLatency: data.count > 0 ? Math.round(data.latency / data.count) : 0,
        time: new Date(data.hour).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }))
      .sort((a, b) => new Date(a.hour).getTime() - new Date(b.hour).getTime())
      .slice(-24) // Last 24 hours
  }, [metrics])

  const costByFunctionData = useMemo(() => {
    return calculateCostMetrics.map(metric => ({
      name: metric.function_name,
      cost: Math.round(metric.total_cost * 10000) / 10000,
      requests: metric.total_requests
    }))
  }, [calculateCostMetrics])

  useEffect(() => {
    fetchMLOpsData()
    
    // Set up real-time refresh
    const interval = setInterval(fetchMLOpsData, 30000) // Refresh every 30 seconds
    return () => clearInterval(interval)
  }, [])

  if (loading && metrics.length === 0) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex items-center space-x-2">
          <RefreshCw className="h-6 w-6 animate-spin" />
          <span>Loading MLOps monitoring data...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6 p-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">MLOps Monitoring Dashboard</h1>
          <p className="text-muted-foreground">
            Real-time monitoring for Scout Dashboard AI systems
          </p>
        </div>
        <div className="flex items-center space-x-2">
          <Badge variant="outline" className="text-xs">
            Last updated: {lastRefresh.toLocaleTimeString()}
          </Badge>
          <Button 
            onClick={fetchMLOpsData} 
            variant="outline" 
            size="sm"
            disabled={loading}
          >
            <RefreshCw className={`h-4 w-4 mr-1 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>
      </div>

      {/* Error Alert */}
      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Error</AlertTitle>
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Critical Alerts */}
      {driftAlerts.filter(alert => alert.status === 'critical').length > 0 && (
        <Alert variant="destructive">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Critical Drift Alerts</AlertTitle>
          <AlertDescription>
            {driftAlerts.filter(alert => alert.status === 'critical').length} critical drift alerts detected. 
            Immediate attention required.
          </AlertDescription>
        </Alert>
      )}

      {/* Performance Summary Cards */}
      {performanceSummary && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Avg Latency</CardTitle>
              <Clock className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {Math.round(performanceSummary.avgLatency)}ms
              </div>
              <p className="text-xs text-muted-foreground">
                Last 24 hours
              </p>
            </CardContent>
          </Card>
          
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
              <CheckCircle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {Math.round(performanceSummary.successRate)}%
              </div>
              <p className="text-xs text-muted-foreground">
                {metrics.filter(m => !m.error_message).length} / {metrics.length} requests
              </p>
            </CardContent>
          </Card>
          
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Cost</CardTitle>
              <DollarSign className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                ${performanceSummary.totalCost.toFixed(4)}
              </div>
              <p className="text-xs text-muted-foreground">
                Last 24 hours
              </p>
            </CardContent>
          </Card>
          
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Avg Confidence</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {Math.round(performanceSummary.avgConfidence)}%
              </div>
              <p className="text-xs text-muted-foreground">
                Model confidence score
              </p>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Main Tabs */}
      <Tabs defaultValue="performance" className="space-y-4">
        <TabsList>
          <TabsTrigger value="performance">Performance</TabsTrigger>
          <TabsTrigger value="experiments">A/B Testing</TabsTrigger>
          <TabsTrigger value="drift">Drift Detection</TabsTrigger>
          <TabsTrigger value="costs">Cost Monitoring</TabsTrigger>
          <TabsTrigger value="deployments">Deployments</TabsTrigger>
        </TabsList>

        {/* Performance Tab */}
        <TabsContent value="performance" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Latency Trend (24h)</CardTitle>
                <CardDescription>Average response time by hour</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={latencyTrendData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="time" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line 
                      type="monotone" 
                      dataKey="avgLatency" 
                      stroke="#8884d8" 
                      strokeWidth={2}
                      name="Avg Latency (ms)"
                    />
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Function Performance</CardTitle>
                <CardDescription>Performance breakdown by function</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {Array.from(new Set(metrics.map(m => m.function_name))).map(functionName => {
                    const functionMetrics = metrics.filter(m => m.function_name === functionName)
                    const avgLatency = functionMetrics.reduce((sum, m) => sum + m.latency_ms, 0) / functionMetrics.length
                    const successRate = functionMetrics.filter(m => !m.error_message).length / functionMetrics.length * 100

                    return (
                      <div key={functionName} className="space-y-2">
                        <div className="flex justify-between text-sm">
                          <span className="font-medium">{functionName}</span>
                          <span>{Math.round(avgLatency)}ms</span>
                        </div>
                        <Progress value={Math.min(successRate, 100)} className="h-2" />
                        <div className="flex justify-between text-xs text-muted-foreground">
                          <span>{functionMetrics.length} requests</span>
                          <span>{Math.round(successRate)}% success</span>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* A/B Testing Tab */}
        <TabsContent value="experiments" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Active Experiments</CardTitle>
              <CardDescription>A/B test results and performance comparison</CardDescription>
            </CardHeader>
            <CardContent>
              {experiments.length > 0 ? (
                <div className="space-y-4">
                  {experiments.map(exp => (
                    <div key={exp.id} className="border rounded-lg p-4">
                      <div className="flex justify-between items-start mb-2">
                        <h4 className="font-semibold">{exp.function_name}</h4>
                        <Badge variant={exp.variant === 'treatment' ? 'default' : 'secondary'}>
                          {exp.variant}
                        </Badge>
                      </div>
                      <div className="grid grid-cols-3 gap-4 text-sm">
                        <div>
                          <span className="text-muted-foreground">Requests:</span>
                          <br />
                          <span className="font-medium">{exp.requests_count}</span>
                        </div>
                        <div>
                          <span className="text-muted-foreground">Avg Latency:</span>
                          <br />
                          <span className="font-medium">{Math.round(exp.avg_latency)}ms</span>
                        </div>
                        <div>
                          <span className="text-muted-foreground">Success Rate:</span>
                          <br />
                          <span className="font-medium">{Math.round(exp.success_rate * 100)}%</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  No active experiments found
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Drift Detection Tab */}
        <TabsContent value="drift" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Data Drift Alerts</CardTitle>
              <CardDescription>Statistical drift detection for model inputs and outputs</CardDescription>
            </CardHeader>
            <CardContent>
              {driftAlerts.length > 0 ? (
                <div className="space-y-3">
                  {driftAlerts.map(alert => (
                    <div key={alert.id} className="border rounded-lg p-4">
                      <div className="flex justify-between items-center mb-2">
                        <div className="flex items-center space-x-2">
                          {alert.status === 'critical' ? (
                            <AlertTriangle className="h-5 w-5 text-red-500" />
                          ) : (
                            <AlertCircle className="h-5 w-5 text-yellow-500" />
                          )}
                          <span className="font-semibold">{alert.function_name}</span>
                        </div>
                        <Badge variant={alert.status === 'critical' ? 'destructive' : 'secondary'}>
                          {alert.status}
                        </Badge>
                      </div>
                      <div className="text-sm text-muted-foreground">
                        <span className="font-medium">{alert.metric_name}</span> drift detected
                        <br />
                        Drift score: {alert.drift_score.toFixed(3)} | {new Date(alert.detected_at).toLocaleString()}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  No drift alerts detected
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Cost Monitoring Tab */}
        <TabsContent value="costs" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Cost by Function</CardTitle>
              <CardDescription>AI model usage costs breakdown</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={costByFunctionData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip formatter={(value, name) => [`$${value}`, name]} />
                  <Legend />
                  <Bar dataKey="cost" fill="#8884d8" name="Cost ($)" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Deployments Tab */}
        <TabsContent value="deployments" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Deployment History</CardTitle>
              <CardDescription>Recent edge function deployments</CardDescription>
            </CardHeader>
            <CardContent>
              {deployments.length > 0 ? (
                <div className="space-y-3">
                  {deployments.slice(0, 10).map(deployment => (
                    <div key={deployment.id} className="border rounded-lg p-4">
                      <div className="flex justify-between items-center mb-2">
                        <span className="font-semibold">{deployment.function_name}</span>
                        <Badge variant={
                          deployment.status === 'completed' ? 'default' :
                          deployment.status === 'failed' ? 'destructive' : 'secondary'
                        }>
                          {deployment.status}
                        </Badge>
                      </div>
                      <div className="text-sm text-muted-foreground">
                        <div>Version: {deployment.version.slice(0, 8)}</div>
                        <div>Type: {deployment.deployment_type}</div>
                        <div>Started: {new Date(deployment.created_at).toLocaleString()}</div>
                        {deployment.completed_at && (
                          <div>Completed: {new Date(deployment.completed_at).toLocaleString()}</div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  No deployments found
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}