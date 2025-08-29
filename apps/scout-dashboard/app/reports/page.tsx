'use client'
import { DataTable, Button, Grid } from '../../../scout-ui/src/components'
import { Download, FileText, Calendar, Filter } from 'lucide-react'
import { useState } from 'react'

export default function ReportsPage() {
  const [selectedReport, setSelectedReport] = useState('revenue')

  const reportData = [
    { id: 1, date: '2024-05-15', type: 'Revenue', amount: '₱ 125,000', status: 'Completed' },
    { id: 2, date: '2024-05-14', type: 'Expense', amount: '₱ 45,000', status: 'Pending' },
    { id: 3, date: '2024-05-13', type: 'Revenue', amount: '₱ 89,000', status: 'Completed' },
    { id: 4, date: '2024-05-12', type: 'Investment', amount: '₱ 250,000', status: 'Processing' },
  ]

  const columns = [
    { key: 'id' as const, label: 'ID' },
    { key: 'date' as const, label: 'Date' },
    { key: 'type' as const, label: 'Type' },
    { key: 'amount' as const, label: 'Amount' },
    { 
      key: 'status' as const, 
      label: 'Status',
      render: (value: string) => {
        const colors = {
          'Completed': 'bg-green-500/20 text-green-400',
          'Pending': 'bg-yellow-500/20 text-yellow-400',
          'Processing': 'bg-blue-500/20 text-blue-400'
        }
        return (
          <span className={`px-2 py-1 text-xs rounded-full ${colors[value as keyof typeof colors]}`}>
            {value}
          </span>
        )
      }
    }
  ]

  const reportTypes = [
    { id: 'revenue', name: 'Revenue Report', icon: <TrendingUp className="w-5 h-5" /> },
    { id: 'expense', name: 'Expense Report', icon: <CreditCard className="w-5 h-5" /> },
    { id: 'performance', name: 'Performance Report', icon: <Activity className="w-5 h-5" /> },
    { id: 'custom', name: 'Custom Report', icon: <FileText className="w-5 h-5" /> }
  ]

  return (
    <div className="min-h-screen bg-bg p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text">Reports</h1>
          <p className="text-sm text-muted">Generate and export custom reports</p>
        </div>
        <div className="flex items-center gap-3">
          <Button tone="neutral">
            <Calendar className="w-4 h-4 mr-2" />
            Schedule
          </Button>
          <Button tone="neutral">
            <Filter className="w-4 h-4 mr-2" />
            Filter
          </Button>
          <Button tone="primary">
            <Download className="w-4 h-4 mr-2" />
            Export All
          </Button>
        </div>
      </div>

      <Grid cols={12} className="gap-6">
        {/* Report Types */}
        <div className="col-span-12 lg:col-span-3">
          <div className="bg-panel rounded-sk p-4 border border-white/10">
            <h3 className="text-sm font-medium text-text mb-4">Report Types</h3>
            <div className="space-y-2">
              {reportTypes.map((report) => (
                <button
                  key={report.id}
                  onClick={() => setSelectedReport(report.id)}
                  className={`w-full flex items-center gap-3 p-3 rounded-sk transition-all ${
                    selectedReport === report.id 
                      ? 'bg-accent/20 border border-accent/30 text-text' 
                      : 'bg-bg border border-white/10 text-muted hover:text-text hover:bg-bg/50'
                  }`}
                >
                  {report.icon}
                  <span className="text-sm">{report.name}</span>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Report Data */}
        <div className="col-span-12 lg:col-span-9">
          <div className="bg-panel rounded-sk border border-white/10">
            <div className="p-4 border-b border-white/10 flex items-center justify-between">
              <h3 className="text-lg font-semibold text-text">Report Data</h3>
              <div className="flex items-center gap-2">
                <Button tone="neutral">
                  <FileText className="w-4 h-4 mr-2" />
                  PDF
                </Button>
                <Button tone="neutral">
                  <FileText className="w-4 h-4 mr-2" />
                  CSV
                </Button>
                <Button tone="neutral">
                  <FileText className="w-4 h-4 mr-2" />
                  Excel
                </Button>
              </div>
            </div>
            <div className="p-4">
              <DataTable data={reportData} columns={columns} />
            </div>
          </div>
        </div>
      </Grid>

      {/* Quick Stats */}
      <Grid cols={12} className="mt-6 gap-6">
        <div className="col-span-12 md:col-span-4">
          <div className="bg-panel rounded-sk p-4 border border-white/10">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-muted">Total Reports</span>
              <FileText className="w-4 h-4 text-muted" />
            </div>
            <p className="text-2xl font-bold text-text">247</p>
            <p className="text-xs text-muted mt-1">+12 this week</p>
          </div>
        </div>
        <div className="col-span-12 md:col-span-4">
          <div className="bg-panel rounded-sk p-4 border border-white/10">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-muted">Scheduled</span>
              <Calendar className="w-4 h-4 text-muted" />
            </div>
            <p className="text-2xl font-bold text-text">18</p>
            <p className="text-xs text-muted mt-1">Next: Tomorrow 9AM</p>
          </div>
        </div>
        <div className="col-span-12 md:col-span-4">
          <div className="bg-panel rounded-sk p-4 border border-white/10">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-muted">Exports Today</span>
              <Download className="w-4 h-4 text-muted" />
            </div>
            <p className="text-2xl font-bold text-text">34</p>
            <p className="text-xs text-muted mt-1">PDF: 20, CSV: 14</p>
          </div>
        </div>
      </Grid>
    </div>
  )
}

import { TrendingUp, CreditCard, Activity } from 'lucide-react'