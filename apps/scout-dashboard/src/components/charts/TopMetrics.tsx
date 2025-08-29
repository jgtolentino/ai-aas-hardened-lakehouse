'use client'

const campaigns = [
  { name: 'Summer Fashion 2024', impressions: '2.4M', clicks: '89K', conversions: 4.2, roi: 245, status: 'active' },
  { name: 'Back to School Promo', impressions: '1.8M', clicks: '67K', conversions: 3.8, roi: 198, status: 'active' },
  { name: 'Holiday Collection', impressions: '1.5M', clicks: '52K', conversions: 3.1, roi: 156, status: 'paused' },
  { name: 'Flash Weekend Sale', impressions: '890K', clicks: '34K', conversions: 4.1, roi: 167, status: 'active' },
  { name: 'New Year Campaign', impressions: '756K', clicks: '28K', conversions: 3.5, roi: 134, status: 'completed' },
]

export function TopMetrics() {
  return (
    <div className="p-6">
      <div className="overflow-x-auto">
        <table className="min-w-full">
          <thead>
            <tr className="border-b border-gray-200">
              <th className="pb-3 text-left text-sm font-medium text-gray-500">Campaign</th>
              <th className="pb-3 text-right text-sm font-medium text-gray-500">Impressions</th>
              <th className="pb-3 text-right text-sm font-medium text-gray-500">Clicks</th>
              <th className="pb-3 text-right text-sm font-medium text-gray-500">CVR</th>
              <th className="pb-3 text-right text-sm font-medium text-gray-500">ROI</th>
              <th className="pb-3 text-center text-sm font-medium text-gray-500">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {campaigns.map((campaign, index) => (
              <tr key={campaign.name}>
                <td className="py-3 text-sm font-medium text-gray-900">{campaign.name}</td>
                <td className="py-3 text-right text-sm text-gray-500">{campaign.impressions}</td>
                <td className="py-3 text-right text-sm text-gray-500">{campaign.clicks}</td>
                <td className="py-3 text-right text-sm text-gray-500">{campaign.conversions}%</td>
                <td className="py-3 text-right text-sm font-medium text-green-600">{campaign.roi}%</td>
                <td className="py-3 text-center">
                  <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                    campaign.status === 'active' 
                      ? 'bg-green-100 text-green-800' 
                      : campaign.status === 'paused'
                      ? 'bg-yellow-100 text-yellow-800'
                      : 'bg-gray-100 text-gray-800'
                  }`}>
                    {campaign.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}