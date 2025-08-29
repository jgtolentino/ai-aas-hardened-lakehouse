import React, { useState, useEffect } from 'react';
import { Progress } from '@/components/ui/progress';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { 
  Loader2, 
  CheckCircle2, 
  AlertTriangle, 
  X, 
  Download,
  FileSpreadsheet,
  FileImage,
  FileText,
  Clock,
  Zap
} from 'lucide-react';
import { cn } from '@/lib/utils';

export interface ProgressStep {
  id: string;
  label: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  progress?: number;
  message?: string;
  startTime?: Date;
  endTime?: Date;
}

export interface ProgressIndicatorProps {
  title: string;
  steps: ProgressStep[];
  overallProgress: number;
  className?: string;
  showDetails?: boolean;
  allowCancel?: boolean;
  onCancel?: () => void;
  onClose?: () => void;
  variant?: 'inline' | 'modal' | 'compact';
}

const getStepIcon = (status: ProgressStep['status'], isRunning: boolean = false) => {
  switch (status) {
    case 'completed':
      return <CheckCircle2 className="h-4 w-4 text-green-600" />;
    case 'failed':
      return <AlertTriangle className="h-4 w-4 text-red-600" />;
    case 'running':
      return <Loader2 className={cn("h-4 w-4 text-blue-600", isRunning && "animate-spin")} />;
    default:
      return <Clock className="h-4 w-4 text-gray-400" />;
  }
};

const formatDuration = (start?: Date, end?: Date): string => {
  if (!start) return '';
  const duration = (end || new Date()).getTime() - start.getTime();
  return `${Math.round(duration / 1000)}s`;
};

export const ProgressIndicator: React.FC<ProgressIndicatorProps> = ({
  title,
  steps,
  overallProgress,
  className,
  showDetails = true,
  allowCancel = false,
  onCancel,
  onClose,
  variant = 'inline'
}) => {
  const [isExpanded, setIsExpanded] = useState(showDetails);
  const isRunning = steps.some(step => step.status === 'running');
  const isCompleted = steps.every(step => step.status === 'completed');
  const hasFailed = steps.some(step => step.status === 'failed');

  const completedSteps = steps.filter(step => step.status === 'completed').length;
  const totalSteps = steps.length;

  const getStatusColor = () => {
    if (hasFailed) return 'border-red-500 bg-red-50';
    if (isCompleted) return 'border-green-500 bg-green-50';
    if (isRunning) return 'border-blue-500 bg-blue-50';
    return 'border-gray-200 bg-white';
  };

  if (variant === 'compact') {
    return (
      <div className={cn('flex items-center space-x-2 px-3 py-2 rounded-md border', getStatusColor(), className)}>
        {isRunning && <Loader2 className="h-4 w-4 animate-spin text-blue-600" />}
        {isCompleted && <CheckCircle2 className="h-4 w-4 text-green-600" />}
        {hasFailed && <AlertTriangle className="h-4 w-4 text-red-600" />}
        <span className="text-sm font-medium">{title}</span>
        <div className="flex-1 min-w-0">
          <Progress value={overallProgress} className="h-2" />
        </div>
        <Badge variant="outline" className="text-xs">
          {completedSteps}/{totalSteps}
        </Badge>
      </div>
    );
  }

  if (variant === 'modal') {
    return (
      <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
        <Card className={cn('w-full max-w-md mx-4', className)}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
            <CardTitle className="text-lg font-semibold">{title}</CardTitle>
            {onClose && (
              <Button
                variant="ghost"
                size="sm"
                onClick={onClose}
                className="h-8 w-8 p-0"
              >
                <X className="h-4 w-4" />
              </Button>
            )}
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span>Overall Progress</span>
                <span>{Math.round(overallProgress)}%</span>
              </div>
              <Progress value={overallProgress} className="h-3" />
              <div className="flex justify-between text-xs text-gray-500">
                <span>{completedSteps} of {totalSteps} steps completed</span>
                {isRunning && <span className="flex items-center"><Zap className="h-3 w-3 mr-1" />Processing...</span>}
              </div>
            </div>

            {showDetails && (
              <div className="space-y-3 max-h-40 overflow-y-auto">
                {steps.map((step, index) => (
                  <div key={step.id} className="flex items-center space-x-3">
                    <div className="flex-shrink-0">
                      {getStepIcon(step.status, step.status === 'running')}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">{step.label}</p>
                      {step.message && (
                        <p className="text-xs text-gray-500 truncate">{step.message}</p>
                      )}
                      {step.status === 'running' && step.progress !== undefined && (
                        <Progress value={step.progress} className="h-1 mt-1" />
                      )}
                    </div>
                    <div className="flex-shrink-0 text-xs text-gray-500">
                      {formatDuration(step.startTime, step.endTime)}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {allowCancel && isRunning && onCancel && (
              <div className="flex justify-end pt-2 border-t">
                <Button variant="outline" size="sm" onClick={onCancel}>
                  Cancel
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    );
  }

  // Inline variant (default)
  return (
    <Card className={cn('w-full', getStatusColor(), className)}>
      <CardHeader 
        className={cn(
          'cursor-pointer flex flex-row items-center justify-between space-y-0 pb-2',
          showDetails && 'pb-4'
        )}
        onClick={() => setIsExpanded(!isExpanded)}
      >
        <div className="flex items-center space-x-3">
          <div className="flex-shrink-0">
            {isRunning && <Loader2 className="h-5 w-5 animate-spin text-blue-600" />}
            {isCompleted && <CheckCircle2 className="h-5 w-5 text-green-600" />}
            {hasFailed && <AlertTriangle className="h-5 w-5 text-red-600" />}
          </div>
          <CardTitle className="text-base font-medium">{title}</CardTitle>
        </div>
        <div className="flex items-center space-x-2">
          <Badge variant="outline" className="text-xs">
            {completedSteps}/{totalSteps}
          </Badge>
          {onClose && (
            <Button
              variant="ghost"
              size="sm"
              onClick={(e) => {
                e.stopPropagation();
                onClose();
              }}
              className="h-6 w-6 p-0"
            >
              <X className="h-3 w-3" />
            </Button>
          )}
        </div>
      </CardHeader>
      
      <CardContent className="pt-0">
        <div className="space-y-3">
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span>Progress</span>
              <span>{Math.round(overallProgress)}%</span>
            </div>
            <Progress value={overallProgress} className="h-2" />
          </div>

          {isExpanded && showDetails && (
            <div className="space-y-3 pt-2 border-t">
              {steps.map((step) => (
                <div key={step.id} className="flex items-center space-x-3">
                  <div className="flex-shrink-0">
                    {getStepIcon(step.status, step.status === 'running')}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium">{step.label}</p>
                    {step.message && (
                      <p className="text-xs text-gray-500">{step.message}</p>
                    )}
                    {step.status === 'running' && step.progress !== undefined && (
                      <Progress value={step.progress} className="h-1 mt-1" />
                    )}
                  </div>
                  <div className="flex-shrink-0 text-xs text-gray-500">
                    {formatDuration(step.startTime, step.endTime)}
                  </div>
                </div>
              ))}
            </div>
          )}

          {allowCancel && isRunning && onCancel && (
            <div className="flex justify-end pt-2 border-t">
              <Button variant="outline" size="sm" onClick={onCancel}>
                Cancel
              </Button>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

// Export Progress Overlay - specialized for export operations
interface ExportProgressOverlayProps {
  isVisible: boolean;
  exportType: 'csv' | 'png' | 'pdf';
  fileName?: string;
  progress: number;
  currentStep: string;
  onCancel?: () => void;
  onClose: () => void;
}

export const ExportProgressOverlay: React.FC<ExportProgressOverlayProps> = ({
  isVisible,
  exportType,
  fileName = 'export',
  progress,
  currentStep,
  onCancel,
  onClose
}) => {
  const getExportIcon = () => {
    switch (exportType) {
      case 'csv':
        return <FileSpreadsheet className="h-8 w-8 text-green-600" />;
      case 'png':
        return <FileImage className="h-8 w-8 text-blue-600" />;
      case 'pdf':
        return <FileText className="h-8 w-8 text-red-600" />;
    }
  };

  if (!isVisible) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <Card className="w-full max-w-sm mx-4">
        <CardContent className="pt-6">
          <div className="text-center space-y-4">
            <div className="flex justify-center">
              {getExportIcon()}
            </div>
            <div>
              <h3 className="font-semibold">Exporting {exportType.toUpperCase()}</h3>
              <p className="text-sm text-gray-500">{fileName}</p>
            </div>
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span>{currentStep}</span>
                <span>{Math.round(progress)}%</span>
              </div>
              <Progress value={progress} className="h-2" />
            </div>
            <div className="flex justify-center space-x-2">
              {onCancel && progress < 100 && (
                <Button variant="outline" size="sm" onClick={onCancel}>
                  Cancel
                </Button>
              )}
              {progress === 100 && (
                <Button size="sm" onClick={onClose}>
                  <Download className="h-4 w-4 mr-2" />
                  Close
                </Button>
              )}
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

// Hook for managing export progress
export const useExportProgress = () => {
  const [isVisible, setIsVisible] = useState(false);
  const [exportType, setExportType] = useState<'csv' | 'png' | 'pdf'>('csv');
  const [fileName, setFileName] = useState('');
  const [progress, setProgress] = useState(0);
  const [currentStep, setCurrentStep] = useState('');

  const startExport = (type: 'csv' | 'png' | 'pdf', file: string = 'export') => {
    setExportType(type);
    setFileName(file);
    setProgress(0);
    setCurrentStep('Preparing export...');
    setIsVisible(true);
  };

  const updateProgress = (newProgress: number, step: string) => {
    setProgress(newProgress);
    setCurrentStep(step);
  };

  const completeExport = () => {
    setProgress(100);
    setCurrentStep('Export completed');
  };

  const cancelExport = () => {
    setIsVisible(false);
    setProgress(0);
    setCurrentStep('');
  };

  const closeOverlay = () => {
    setIsVisible(false);
  };

  return {
    isVisible,
    exportType,
    fileName,
    progress,
    currentStep,
    startExport,
    updateProgress,
    completeExport,
    cancelExport,
    closeOverlay
  };
};

export default ProgressIndicator;