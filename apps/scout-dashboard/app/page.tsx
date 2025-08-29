'use client'
import { Grid, KpiTile, Button } from '../../scout-ui/src/components'
import { useRouter } from 'next/navigation'
import { 
  LayoutDashboard, 
  DollarSign, 
  TrendingUp, 
  FileText,
  ArrowRight 
} from 'lucide-react'

export default function HomePage() {
  const router = useRouter()
  
  const dashboards = [
    {
      title: 'Overview Dashboard',
      description: 'Main KPI overview with real-time metrics',
      icon: <LayoutDashboard className="w-6 h-6" />,
      path: '/overview',
      color: 'bg-accent/20 border-accent/30'
    },
    {
      title: 'Finebank Financial',
      description: 'Complete financial management dashboard',
      icon: <DollarSign className="w-6 h-6" />,
      path: '/finebank',
      color: 'bg-green-500/20 border-green-500/30'
    },
    {
      title: 'Analytics',
      description: 'Deep dive into performance metrics',
      icon: <TrendingUp className="w-6 h-6" />,
      path: '/analytics',
      color: 'bg-purple-500/20 border-purple-500/30'
    },
    {
      title: 'Reports',
      description: 'Generate and export custom reports',
      icon: <FileText className="w-6 h-6" />,
      path: '/reports',
      color: 'bg-orange-500/20 border-orange-500/30'
    }
  ]

  return (
    <div className="min-h-screen bg-bg p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-text mb-2">Scout Platform</h1>
          <p className="text-muted">Select a dashboard to get started</p>
        </div>

        {/* Quick Stats */}
        <Grid cols={12} className="mb-8">
          <div className="col-span-3">
            <KpiTile label="Total Revenue" value="₱ 24.6M" hint="+12.5% this month" />
          </div>
          <div className="col-span-3">
            <KpiTile label="Active Users" value="1,284" hint="+8.3% this week" />
          </div>
          <div className="col-span-3">
            <KpiTile label="Conversion Rate" value="3.24%" hint="+0.5% improvement" />
          </div>
          <div className="col-span-3">
            <KpiTile label="Avg Response Time" value="1.2s" hint="-15% faster" />
          </div>
        </Grid>

        {/* Dashboard Cards */}
        <Grid cols={12} className="gap-6">
          {dashboards.map((dashboard) => (
            <div key={dashboard.path} className="col-span-12 md:col-span-6">
              <div className={`bg-panel rounded-sk p-6 border ${dashboard.color} hover:bg-panel/80 transition-all cursor-pointer`}
                   onClick={() => router.push(dashboard.path)}>
                <div className="flex items-start justify-between mb-4">
                  <div className="p-3 bg-white/5 rounded-sk">
                    {dashboard.icon}
                  </div>
                  <ArrowRight className="w-5 h-5 text-muted" />
                </div>
                <h3 className="text-lg font-semibold text-text mb-2">{dashboard.title}</h3>
                <p className="text-sm text-muted mb-4">{dashboard.description}</p>
                <Button tone="primary" className="w-full">
                  Open Dashboard
                </Button>
              </div>
            </div>
          ))}
        </Grid>

        {/* Footer */}
        <div className="mt-12 pt-6 border-t border-white/10">
          <div className="flex items-center justify-between">
            <p className="text-sm text-muted">
              Scout UI v2.0 - Powered by Figma Code Connect
            </p>
            <div className="flex items-center gap-4">
              <button className="text-sm text-muted hover:text-text">Documentation</button>
              <button className="text-sm text-muted hover:text-text">Support</button>
              <button className="text-sm text-muted hover:text-text">Settings</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}