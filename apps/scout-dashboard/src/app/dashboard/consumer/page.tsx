'use client'

import { useState } from 'react'
import { DemographicsChart } from '@/components/charts/DemographicsChart'
import { BehaviorChart } from '@/components/charts/BehaviorChart'
import { SentimentChart } from '@/components/charts/SentimentChart'

export default function ConsumerPage() {
  const [selectedSegment, setSelectedSegment] = useState('all')

  return (
    <div className="space-y-8">
      <div className="sm:flex sm:items-center sm:justify-between">
        <div className="sm:flex-auto">
          <h1 className="text-2xl font-semibold leading-6 text-gray-900">Consumer Insights</h1>
          <p className="mt-2 text-sm text-gray-700">
            Understanding your audience demographics, behavior, and preferences
          </p>
        </div>
        <div className="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <select
            value={selectedSegment}
            onChange={(e) => setSelectedSegment(e.target.value)}
            className="block w-full rounded-md border-0 py-1.5 pl-3 pr-10 text-gray-900 ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-brand-600 sm:text-sm sm:leading-6"
          >
            <option value="all">All Segments</option>
            <option value="millennials">Millennials</option>
            <option value="gen-z">Gen Z</option>
            <option value="gen-x">Gen X</option>
            <option value="boomers">Baby Boomers</option>
          </select>
        </div>
      </div>

      {/* Demographics Overview */}
      <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
        <div className="lg:col-span-2 bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Demographics Breakdown</h3>
          </div>
          <div className="p-6">
            <DemographicsChart segment={selectedSegment} />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Key Metrics</h3>
          </div>
          <div className="p-6 space-y-6">
            <div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900">Average Age</span>
                <span className="text-sm text-gray-500">34.2 years</span>
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900">Income Bracket</span>
                <span className="text-sm text-gray-500">₱45-65K</span>
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900">Urban/Rural</span>
                <span className="text-sm text-gray-500">72% Urban</span>
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900">Education</span>
                <span className="text-sm text-gray-500">68% College</span>
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900">Employment</span>
                <span className="text-sm text-gray-500">81% Employed</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Behavior Analysis */}
      <div className="bg-white rounded-lg shadow">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Consumer Behavior Patterns</h3>
        </div>
        <div className="p-6">
          <BehaviorChart segment={selectedSegment} />
        </div>
      </div>

      {/* Sentiment & Preferences */}
      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Brand Sentiment</h3>
          </div>
          <div className="p-6">
            <SentimentChart />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Purchase Triggers</h3>
          </div>
          <div className="p-6">
            <div className="space-y-4">
              {[
                { trigger: 'Price Discounts', percentage: 67 },
                { trigger: 'Product Reviews', percentage: 54 },
                { trigger: 'Social Proof', percentage: 48 },
                { trigger: 'Brand Reputation', percentage: 41 },
                { trigger: 'Convenience', percentage: 38 },
                { trigger: 'Recommendations', percentage: 32 },
              ].map((item) => (
                <div key={item.trigger}>
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-sm font-medium text-gray-700">{item.trigger}</span>
                    <span className="text-sm text-gray-500">{item.percentage}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className="bg-brand-600 h-2 rounded-full transition-all duration-300"
                      style={{ width: `${item.percentage}%` }}
                    ></div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}