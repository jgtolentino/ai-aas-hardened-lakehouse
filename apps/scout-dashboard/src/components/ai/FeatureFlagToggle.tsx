import React, { useState } from 'react';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Settings, Eye, Power, RefreshCw, Zap, Info } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible';
import { cn } from '@/lib/utils';
import { useRecommendationFeatures } from '@/hooks/useRecommendations';

interface FeatureFlagToggleProps {
  className?: string;
  showAdminControls?: boolean;
  onFeatureChange?: (featureName: string, enabled: boolean) => void;
}

const FeatureFlag: React.FC<{
  name: string;
  label: string;
  description: string;
  icon: React.ReactNode;
  enabled: boolean;
  onToggle: () => void;
  disabled?: boolean;
}> = ({ name, label, description, icon, enabled, onToggle, disabled = false }) => {
  return (
    <div className="flex items-center justify-between p-3 rounded-lg border hover:bg-gray-50 transition-colors">
      <div className="flex items-start space-x-3">
        <div className={cn(
          "p-2 rounded-md",
          enabled ? "bg-blue-100 text-blue-600" : "bg-gray-100 text-gray-400"
        )}>
          {icon}
        </div>
        <div className="flex-1">
          <div className="flex items-center space-x-2">
            <Label htmlFor={`feature-${name}`} className="font-medium">
              {label}
            </Label>
            {enabled && (
              <Badge variant="outline" className="text-xs bg-green-50 text-green-700 border-green-200">
                Active
              </Badge>
            )}
          </div>
          <p className="text-sm text-gray-500 mt-1">{description}</p>
        </div>
      </div>
      <Switch
        id={`feature-${name}`}
        checked={enabled}
        onCheckedChange={onToggle}
        disabled={disabled}
      />
    </div>
  );
};

export const FeatureFlagToggle: React.FC<FeatureFlagToggleProps> = ({
  className,
  showAdminControls = false,
  onFeatureChange
}) => {
  const { features, toggleFeature, isLoading, error, refetchFlags } = useRecommendationFeatures();
  const [isExpanded, setIsExpanded] = useState(false);

  const featureDefinitions = [
    {
      key: 'enabled',
      label: 'AI Recommendations',
      description: 'Enable AI-powered recommendations panel',
      icon: <Power className="h-4 w-4" />
    },
    {
      key: 'showConfidence',
      label: 'Confidence Badges',
      description: 'Display confidence scores on recommendations',
      icon: <Eye className="h-4 w-4" />
    },
    {
      key: 'allowDismiss',
      label: 'Dismissible Cards',
      description: 'Allow users to dismiss recommendations',
      icon: <Settings className="h-4 w-4" />
    },
    {
      key: 'autoRefresh',
      label: 'Auto Refresh',
      description: 'Automatically refresh recommendations',
      icon: <RefreshCw className="h-4 w-4" />
    },
    {
      key: 'actionExecution',
      label: 'Action Buttons',
      description: 'Enable recommendation action execution',
      icon: <Zap className="h-4 w-4" />
    }
  ];

  const handleFeatureToggle = async (featureName: string) => {
    const newValue = !features[featureName as keyof typeof features];
    
    try {
      await toggleFeature(featureName as keyof typeof features);
      onFeatureChange?.(featureName, newValue);
    } catch (error) {
      console.error('Failed to toggle feature:', error);
    }
  };

  const activeFeatureCount = Object.values(features).filter(Boolean).length;

  if (!showAdminControls) {
    // Simple toggle for regular users
    return (
      <div className={cn('flex items-center space-x-2', className)}>
        <Switch
          checked={features.enabled}
          onCheckedChange={() => handleFeatureToggle('enabled')}
          disabled={isLoading}
        />
        <Label className="text-sm font-medium">AI Recommendations</Label>
        {features.enabled && (
          <Badge variant="secondary" className="text-xs">
            {activeFeatureCount} features active
          </Badge>
        )}
      </div>
    );
  }

  return (
    <Card className={cn('w-full', className)}>
      <Collapsible open={isExpanded} onOpenChange={setIsExpanded}>
        <CollapsibleTrigger asChild>
          <CardHeader className="pb-3 cursor-pointer hover:bg-gray-50 transition-colors">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Settings className="h-5 w-5 text-gray-600" />
                <CardTitle className="text-base">AI Recommendation Features</CardTitle>
                <Badge variant="secondary" className="text-xs">
                  {activeFeatureCount}/{featureDefinitions.length} active
                </Badge>
              </div>
              <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                <Settings className={cn(
                  "h-4 w-4 transition-transform",
                  isExpanded && "rotate-180"
                )} />
              </Button>
            </div>
          </CardHeader>
        </CollapsibleTrigger>
        
        <CollapsibleContent>
          <CardContent>
            {error && (
              <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
                <div className="flex items-center">
                  <Info className="h-4 w-4 text-red-600 mr-2" />
                  <span className="text-sm text-red-800">Failed to load feature flags: {error}</span>
                  <Button 
                    variant="ghost" 
                    size="sm" 
                    onClick={refetchFlags}
                    className="ml-auto h-6 px-2 text-red-600 hover:text-red-800"
                  >
                    Retry
                  </Button>
                </div>
              </div>
            )}
            
            <div className="space-y-2">
              {featureDefinitions.map((feature) => (
                <FeatureFlag
                  key={feature.key}
                  name={feature.key}
                  label={feature.label}
                  description={feature.description}
                  icon={feature.icon}
                  enabled={features[feature.key as keyof typeof features]}
                  onToggle={() => handleFeatureToggle(feature.key)}
                  disabled={isLoading}
                />
              ))}
            </div>

            {/* Global Controls */}
            <div className="flex items-center justify-between pt-4 mt-4 border-t">
              <div className="flex items-center space-x-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    featureDefinitions.forEach(feature => {
                      if (!features[feature.key as keyof typeof features]) {
                        handleFeatureToggle(feature.key);
                      }
                    });
                  }}
                  disabled={isLoading || activeFeatureCount === featureDefinitions.length}
                >
                  Enable All
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    featureDefinitions.forEach(feature => {
                      if (features[feature.key as keyof typeof features]) {
                        handleFeatureToggle(feature.key);
                      }
                    });
                  }}
                  disabled={isLoading || activeFeatureCount === 0}
                >
                  Disable All
                </Button>
              </div>
              
              <Button 
                variant="ghost" 
                size="sm" 
                onClick={refetchFlags}
                disabled={isLoading}
                className="flex items-center space-x-1"
              >
                <RefreshCw className={cn("h-3 w-3", isLoading && "animate-spin")} />
                <span>Refresh</span>
              </Button>
            </div>
            
            {/* Status Summary */}
            <div className="mt-4 p-3 bg-blue-50 rounded-lg">
              <div className="flex items-center justify-between text-sm">
                <span className="text-blue-700 font-medium">Feature Status:</span>
                <span className="text-blue-600">
                  {activeFeatureCount === 0 && "All features disabled"}
                  {activeFeatureCount === featureDefinitions.length && "All features enabled"}
                  {activeFeatureCount > 0 && activeFeatureCount < featureDefinitions.length && 
                    `${activeFeatureCount} of ${featureDefinitions.length} features active`}
                </span>
              </div>
            </div>
          </CardContent>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  );
};

export default FeatureFlagToggle;