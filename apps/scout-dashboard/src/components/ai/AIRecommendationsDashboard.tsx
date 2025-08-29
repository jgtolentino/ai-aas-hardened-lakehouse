import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { RecommendationPanel } from './RecommendationPanel';
import { FeatureFlagToggle } from './FeatureFlagToggle';
import { useRecommendations, useRecommendationFeatures } from '@/hooks/useRecommendations';
import { Brain, Settings, BarChart3 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface AIRecommendationsDashboardProps {
  className?: string;
  showFeatureToggles?: boolean;
  adminMode?: boolean;
}

export const AIRecommendationsDashboard: React.FC<AIRecommendationsDashboardProps> = ({
  className,
  showFeatureToggles = false,
  adminMode = false
}) => {
  const {
    recommendations,
    isLoading,
    error,
    refetch,
    executeAction,
    dismissRecommendation,
    clearError
  } = useRecommendations({
    autoRefresh: true,
    refreshInterval: 30000,
    maxRecommendations: 8,
    confidenceThreshold: 50
  });

  const { features } = useRecommendationFeatures();

  const handleRecommendationClick = (recommendation: any) => {
    console.log('Recommendation clicked:', recommendation);
    // Handle recommendation click - could open modal, navigate, etc.
  };

  const handleActionClick = async (recommendation: any, actionId: string) => {
    console.log('Action clicked:', { recommendation: recommendation.id, actionId });
    
    try {
      const success = await executeAction(recommendation.id, actionId);
      if (success) {
        console.log('Action executed successfully');
        // Show success message
      } else {
        console.error('Action failed');
        // Show error message
      }
    } catch (error) {
      console.error('Error executing action:', error);
    }
  };

  const handleDismiss = (recommendationId: string) => {
    dismissRecommendation(recommendationId);
    console.log('Recommendation dismissed:', recommendationId);
  };

  const handleFeatureChange = (featureName: string, enabled: boolean) => {
    console.log(`Feature ${featureName} ${enabled ? 'enabled' : 'disabled'}`);
    // Optional: Show toast notification
  };

  return (
    <div className={cn('w-full space-y-6', className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-blue-100 rounded-lg">
            <Brain className="h-6 w-6 text-blue-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">AI Recommendations Dashboard</h1>
            <p className="text-gray-500">Intelligent insights and optimization recommendations</p>
          </div>
        </div>
        
        {adminMode && (
          <div className="flex items-center space-x-2">
            <div className="text-right text-sm text-gray-500">
              <div>Admin Mode</div>
              <div className="text-xs">
                {Object.values(features).filter(Boolean).length} features active
              </div>
            </div>
            <Settings className="h-5 w-5 text-gray-400" />
          </div>
        )}
      </div>

      {/* Feature Toggle Panel */}
      {showFeatureToggles && (
        <FeatureFlagToggle
          showAdminControls={adminMode}
          onFeatureChange={handleFeatureChange}
        />
      )}

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Recommendations</CardTitle>
            <BarChart3 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{recommendations.length}</div>
            <p className="text-xs text-muted-foreground">
              {recommendations.filter(r => r.priority === 'high' || r.priority === 'critical').length} high priority
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Average Confidence</CardTitle>
            <BarChart3 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {recommendations.length > 0 
                ? Math.round(recommendations.reduce((sum, r) => sum + r.confidence, 0) / recommendations.length)
                : 0}%
            </div>
            <p className="text-xs text-muted-foreground">
              Across all recommendations
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Feature Status</CardTitle>
            <Settings className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {features.enabled ? 'Active' : 'Disabled'}
            </div>
            <p className="text-xs text-muted-foreground">
              {Object.values(features).filter(Boolean).length} of {Object.keys(features).length} features enabled
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Recommendations Panel */}
      <RecommendationPanel
        recommendations={recommendations}
        isLoading={isLoading}
        error={error}
        maxRecommendations={8}
        showConfidenceThreshold={50}
        enableFeatureFlag={true}
        onRecommendationClick={handleRecommendationClick}
        onActionClick={handleActionClick}
        onDismiss={handleDismiss}
      />

      {/* Debug Info (Admin Mode Only) */}
      {adminMode && (
        <Card className="border-dashed">
          <CardHeader>
            <CardTitle className="text-sm">Debug Information</CardTitle>
          </CardHeader>
          <CardContent className="text-xs text-gray-500 space-y-2">
            <div>
              <strong>Feature Flags:</strong> {JSON.stringify(features, null, 2)}
            </div>
            <div>
              <strong>Total Recommendations:</strong> {recommendations.length}
            </div>
            <div>
              <strong>Loading State:</strong> {isLoading ? 'Loading...' : 'Ready'}
            </div>
            {error && (
              <div className="text-red-600">
                <strong>Error:</strong> {error}
              </div>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
};

export default AIRecommendationsDashboard;