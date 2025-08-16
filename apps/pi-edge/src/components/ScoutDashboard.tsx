// Scout Analytics Dashboard - Main Component
import React, { useEffect, useState } from 'react';
import { useScoutDashboard, usePipelineStatus, useEdgeDeviceStatus } from '../hooks/useScoutData';
import { checkSupabaseConnection } from '../lib/supabase';

interface StatusBadgeProps {
  status: string;
  children: React.ReactNode;
}

const StatusBadge: React.FC<StatusBadgeProps> = ({ status, children }) => {
  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'healthy':
      case 'online':
      case 'ok':
        return 'bg-green-100 text-green-800 border-green-200';
      case 'warning':
      case 'warn':
        return 'bg-yellow-100 text-yellow-800 border-yellow-200';
      case 'critical':
      case 'alert':
      case 'offline':
        return 'bg-red-100 text-red-800 border-red-200';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${getStatusColor(status)}`}>
      {children}
    </span>
  );
};

const ScoutDashboard: React.FC = () => {
  const [connectionStatus, setConnectionStatus] = useState<boolean | null>(null);
  const { metrics, devices, health, pipeline, loading, error, refresh } = useScoutDashboard();
  const pipelineStatus = usePipelineStatus();
  const deviceStatus = useEdgeDeviceStatus();

  // Test Supabase connection on mount
  useEffect(() => {
    checkSupabaseConnection().then(setConnectionStatus);
  }, []);

  if (loading && !metrics) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading Scout Analytics...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="bg-white p-8 rounded-lg shadow-lg max-w-md w-full">
          <div className="text-red-600 text-center mb-4">
            <svg className="w-16 h-16 mx-auto mb-4" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
            </svg>
            <h2 className="text-xl font-bold">Connection Error</h2>
            <p className="text-gray-600 mt-2">{error}</p>
          </div>
          <div className="space-y-2 text-sm">
            <p><strong>Supabase Connection:</strong> {connectionStatus ? '✅ Connected' : '❌ Failed'}</p>
            <p><strong>Project URL:</strong> https://cxzllzyxwpyptfretryc.supabase.co</p>
          </div>
          <button 
            onClick={refresh}
            className="w-full mt-4 bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700 transition-colors"
          >
            Retry Connection
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="px-6 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-3xl font-bold text-gray-900">Scout Analytics Dashboard</h1>
            <div className="flex items-center space-x-4">
              <StatusBadge status={connectionStatus ? 'healthy' : 'critical'}>
                Supabase {connectionStatus ? 'Connected' : 'Disconnected'}
              </StatusBadge>
              <button 
                onClick={refresh}
                className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
              >
                Refresh
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="px-6 py-6">
        {/* System Health Overview */}
        {health && health.length > 0 && (
          <div className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">System Health</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {health.map((component, index) => (
                <div key={index} className="bg-white p-6 rounded-lg shadow">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-lg font-medium text-gray-900">{component.component}</h3>
                    <StatusBadge status={component.status}>{component.status}</StatusBadge>
                  </div>
                  <div className="text-sm text-gray-600">
                    {Object.entries(component.metrics || {}).map(([key, value]) => (
                      <div key={key} className="flex justify-between">
                        <span>{key}:</span>
                        <span className="font-medium">{String(value)}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Edge Devices */}
        {devices && devices.length > 0 && (
          <div className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Edge Devices</h2>
            <div className="bg-white rounded-lg shadow overflow-hidden">
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Device</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Store</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Events (24h)</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Transactions (24h)</th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {devices.map((device) => (
                      <tr key={device.device_id}>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div>
                            <div className="text-sm font-medium text-gray-900">{device.device_name}</div>
                            <div className="text-sm text-gray-500">{device.device_id}</div>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{device.store_id}</td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <StatusBadge status={device.status}>{device.status}</StatusBadge>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{device.events_24h}</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{device.transactions_24h}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* Pipeline Status */}
        {pipelineStatus.data && pipelineStatus.data.length > 0 && (
          <div className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Pipeline Status</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
              {pipelineStatus.data.map((metric, index) => (
                <div key={index} className="bg-white p-6 rounded-lg shadow">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-sm font-medium text-gray-500">{metric.metric}</h3>
                    <StatusBadge status={metric.status}>{metric.status}</StatusBadge>
                  </div>
                  <div className="text-2xl font-bold text-gray-900">
                    {metric.value} {metric.unit}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Ingestion Metrics */}
        {metrics && metrics.length > 0 && (
          <div className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Ingestion Metrics</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {metrics.map((metric, index) => (
                <div key={index} className="bg-white p-6 rounded-lg shadow">
                  <h3 className="text-lg font-medium text-gray-900 mb-2">{metric.metric}</h3>
                  <div className="text-3xl font-bold text-blue-600 mb-2">{metric.value}</div>
                  {metric.details && (
                    <div className="text-sm text-gray-600">
                      {Object.entries(metric.details).map(([key, value]) => (
                        <div key={key} className="flex justify-between">
                          <span>{key}:</span>
                          <span className="font-medium">{String(value)}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Footer */}
        <div className="text-center text-gray-500 text-sm">
          <p>Scout Analytics Dashboard - Real-time store intelligence powered by edge computing</p>
          <p className="mt-1">Last updated: {new Date().toLocaleString()}</p>
        </div>
      </div>
    </div>
  );
};

export default ScoutDashboard;