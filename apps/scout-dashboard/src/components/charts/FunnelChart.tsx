'use client'

interface FunnelChartProps {}

const funnelData = [
  { stage: 'Awareness', users: 10000, percentage: 100 },
  { stage: 'Interest', users: 7500, percentage: 75 },
  { stage: 'Consideration', users: 4200, percentage: 42 },
  { stage: 'Intent', users: 1800, percentage: 18 },
  { stage: 'Purchase', users: 420, percentage: 4.2 },
]

export function FunnelChart({}: FunnelChartProps) {
  return (
    <div className="space-y-4">
      {funnelData.map((stage, index) => {
        const width = stage.percentage
        return (
          <div key={stage.stage} className="flex items-center space-x-4">
            <div className="w-20 text-right text-sm font-medium text-gray-700">
              {stage.stage}
            </div>
            <div className="flex-1">
              <div className="bg-gray-200 rounded-full h-8 relative">
                <div
                  className="bg-brand-600 h-8 rounded-full flex items-center justify-between px-3 transition-all duration-500"
                  style={{ width: `${width}%` }}
                >
                  <span className="text-white text-sm font-medium">
                    {stage.users.toLocaleString()}
                  </span>
                  <span className="text-white text-sm">
                    {stage.percentage}%
                  </span>
                </div>
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}