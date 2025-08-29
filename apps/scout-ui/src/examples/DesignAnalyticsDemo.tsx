import React from 'react';
import { DesignAnalyticsDashboard } from '../components';

/**
 * Design Analytics Dashboard Demo
 * 
 * Example implementation showing how to integrate the Design Analytics
 * Dashboard component into a Scout UI application.
 * 
 * Usage:
 * import { DesignAnalyticsDemo } from '@/examples/DesignAnalyticsDemo';
 * 
 * <DesignAnalyticsDemo />
 */
export const DesignAnalyticsDemo: React.FC = () => {
  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation */}
      <nav className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">
                Scout Design Analytics
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-500">
                Component Usage Intelligence
              </span>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-6">
        <div className="px-4 sm:px-6 lg:px-8">
          {/* Header */}
          <div className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900">
              Design System Analytics
            </h2>
            <p className="mt-2 text-gray-600">
              Monitor component usage, detachment rates, and design system health across your organization.
            </p>
          </div>

          {/* Analytics Dashboard */}
          <div className="bg-white rounded-lg shadow">
            <DesignAnalyticsDashboard className="p-6" />
          </div>

          {/* Footer Information */}
          <div className="mt-8 p-4 bg-blue-50 rounded-lg">
            <h3 className="text-sm font-medium text-blue-900 mb-2">
              Integration Notes:
            </h3>
            <ul className="text-sm text-blue-700 space-y-1">
              <li>• Dashboard connects to live Supabase data via design_analytics schema</li>
              <li>• Component usage is automatically tracked via Figma Bridge Plugin</li>
              <li>• AI-powered insights help optimize component adoption</li>
              <li>• Real-time updates every 30 seconds for live monitoring</li>
            </ul>
          </div>
        </div>
      </main>
    </div>
  );
};

export default DesignAnalyticsDemo;