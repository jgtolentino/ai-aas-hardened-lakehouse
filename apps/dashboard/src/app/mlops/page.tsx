import { Metadata } from 'next'
import MLOpsMonitoringDashboard from '@/components/MLOpsMonitoringDashboard'

export const metadata: Metadata = {
  title: 'MLOps Monitoring | Scout Dashboard',
  description: 'Real-time monitoring for Scout Dashboard AI systems including performance tracking, cost monitoring, drift detection, and deployment management.',
  keywords: 'mlops, monitoring, ai, performance, cost tracking, drift detection, deployments',
}

export default function MLOpsPage() {
  return (
    <div className="min-h-screen bg-background">
      <MLOpsMonitoringDashboard />
    </div>
  )
}