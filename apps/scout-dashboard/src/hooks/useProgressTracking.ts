import { useState, useEffect, useCallback } from 'react';
import { defaultExportQueue, ExportJob, ExportType } from '@/lib/exports/batchExportQueue';
import { ProgressStep } from '@/components/ui/progress-indicator';

export interface ExportProgress {
  jobId: string;
  type: ExportType;
  fileName: string;
  overallProgress: number;
  steps: ProgressStep[];
  status: 'idle' | 'running' | 'completed' | 'failed' | 'cancelled';
  startTime?: Date;
  endTime?: Date;
  error?: string;
}

export interface ProgressTrackingConfig {
  autoStart?: boolean;
  showModal?: boolean;
  allowCancel?: boolean;
  onComplete?: (progress: ExportProgress) => void;
  onError?: (error: string, progress: ExportProgress) => void;
  onCancel?: (progress: ExportProgress) => void;
}

// Default export steps for different types
const getExportSteps = (type: ExportType): ProgressStep[] => {
  const baseSteps: ProgressStep[] = [
    { id: 'prepare', label: 'Preparing data...', status: 'pending' },
    { id: 'validate', label: 'Validating export parameters...', status: 'pending' },
  ];

  switch (type) {
    case 'csv':
      return [
        ...baseSteps,
        { id: 'format', label: 'Formatting CSV data...', status: 'pending' },
        { id: 'generate', label: 'Generating CSV file...', status: 'pending' },
        { id: 'download', label: 'Preparing download...', status: 'pending' }
      ];
    case 'png':
      return [
        ...baseSteps,
        { id: 'capture', label: 'Capturing element...', status: 'pending' },
        { id: 'render', label: 'Rendering image...', status: 'pending' },
        { id: 'compress', label: 'Optimizing image...', status: 'pending' },
        { id: 'download', label: 'Preparing download...', status: 'pending' }
      ];
    case 'pdf':
      return [
        ...baseSteps,
        { id: 'layout', label: 'Calculating layout...', status: 'pending' },
        { id: 'render', label: 'Rendering PDF...', status: 'pending' },
        { id: 'compress', label: 'Optimizing PDF...', status: 'pending' },
        { id: 'download', label: 'Preparing download...', status: 'pending' }
      ];
    default:
      return [
        ...baseSteps,
        { id: 'process', label: 'Processing export...', status: 'pending' },
        { id: 'download', label: 'Preparing download...', status: 'pending' }
      ];
  }
};

export const useProgressTracking = (config: ProgressTrackingConfig = {}) => {
  const [activeProgresses, setActiveProgresses] = useState<Map<string, ExportProgress>>(new Map());
  const [modalProgress, setModalProgress] = useState<ExportProgress | null>(null);

  // Update progress based on job events
  const updateProgress = useCallback((jobId: string, updates: Partial<ExportProgress>) => {
    setActiveProgresses(prev => {
      const newMap = new Map(prev);
      const current = newMap.get(jobId);
      if (current) {
        const updated = { ...current, ...updates };
        newMap.set(jobId, updated);
        
        // Update modal if this is the active modal progress
        if (modalProgress && modalProgress.jobId === jobId) {
          setModalProgress(updated);
        }
        
        // Handle completion callbacks
        if (updated.status === 'completed' && config.onComplete) {
          config.onComplete(updated);
        } else if (updated.status === 'failed' && config.onError) {
          config.onError(updated.error || 'Export failed', updated);
        } else if (updated.status === 'cancelled' && config.onCancel) {
          config.onCancel(updated);
        }
      }
      return newMap;
    });
  }, [modalProgress, config.onComplete, config.onError, config.onCancel]);

  // Start tracking a new export
  const startProgress = useCallback((
    jobId: string, 
    type: ExportType, 
    fileName: string = 'export'
  ): ExportProgress => {
    const steps = getExportSteps(type);
    const newProgress: ExportProgress = {
      jobId,
      type,
      fileName,
      overallProgress: 0,
      steps,
      status: 'running',
      startTime: new Date()
    };

    setActiveProgresses(prev => {
      const newMap = new Map(prev);
      newMap.set(jobId, newProgress);
      return newMap;
    });

    // Show modal if configured
    if (config.showModal) {
      setModalProgress(newProgress);
    }

    return newProgress;
  }, [config.showModal]);

  // Update step progress
  const updateStepProgress = useCallback((
    jobId: string, 
    stepId: string, 
    progress: number,
    status: ProgressStep['status'] = 'running',
    message?: string
  ) => {
    const current = activeProgresses.get(jobId);
    if (!current) return;

    const updatedSteps = current.steps.map(step => {
      if (step.id === stepId) {
        return {
          ...step,
          status,
          progress,
          message,
          startTime: step.startTime || (status === 'running' ? new Date() : undefined),
          endTime: status === 'completed' || status === 'failed' ? new Date() : undefined
        };
      }
      return step;
    });

    // Calculate overall progress
    const completedSteps = updatedSteps.filter(s => s.status === 'completed').length;
    const runningStep = updatedSteps.find(s => s.status === 'running');
    const runningProgress = runningStep?.progress || 0;
    
    const overallProgress = Math.min(100, 
      (completedSteps * 100 + runningProgress) / updatedSteps.length
    );

    updateProgress(jobId, {
      steps: updatedSteps,
      overallProgress
    });
  }, [activeProgresses, updateProgress]);

  // Complete progress tracking
  const completeProgress = useCallback((jobId: string, success: boolean = true, error?: string) => {
    const current = activeProgresses.get(jobId);
    if (!current) return;

    const updatedSteps = current.steps.map(step => ({
      ...step,
      status: success ? 'completed' as const : 'failed' as const,
      endTime: step.endTime || new Date()
    }));

    updateProgress(jobId, {
      steps: updatedSteps,
      overallProgress: 100,
      status: success ? 'completed' : 'failed',
      endTime: new Date(),
      error: success ? undefined : error
    });

    // Auto-remove after delay
    setTimeout(() => {
      setActiveProgresses(prev => {
        const newMap = new Map(prev);
        newMap.delete(jobId);
        return newMap;
      });
      
      if (modalProgress && modalProgress.jobId === jobId) {
        setModalProgress(null);
      }
    }, 3000);
  }, [activeProgresses, updateProgress, modalProgress]);

  // Cancel progress tracking
  const cancelProgress = useCallback((jobId: string) => {
    updateProgress(jobId, {
      status: 'cancelled',
      endTime: new Date()
    });

    // Cancel the actual export job
    defaultExportQueue.cancelJob(jobId);
    
    // Close modal if it's showing this job
    if (modalProgress && modalProgress.jobId === jobId) {
      setModalProgress(null);
    }
  }, [updateProgress, modalProgress]);

  // Close modal
  const closeModal = useCallback(() => {
    setModalProgress(null);
  }, []);

  // Set up event listeners for the export queue
  useEffect(() => {
    const handleJobProgress = (job: ExportJob) => {
      if (activeProgresses.has(job.id)) {
        updateProgress(job.id, {
          overallProgress: job.progress || 0
        });
      }
    };

    const handleJobCompleted = (job: ExportJob) => {
      if (activeProgresses.has(job.id)) {
        completeProgress(job.id, true);
      }
    };

    const handleJobFailed = (job: ExportJob) => {
      if (activeProgresses.has(job.id)) {
        completeProgress(job.id, false, job.error || 'Export failed');
      }
    };

    const handleJobCancelled = (job: ExportJob) => {
      if (activeProgresses.has(job.id)) {
        updateProgress(job.id, {
          status: 'cancelled',
          endTime: new Date()
        });
      }
    };

    // Register event listeners
    defaultExportQueue.on('jobProgress', handleJobProgress);
    defaultExportQueue.on('jobCompleted', handleJobCompleted);
    defaultExportQueue.on('jobFailed', handleJobFailed);
    defaultExportQueue.on('jobCancelled', handleJobCancelled);

    return () => {
      defaultExportQueue.off('jobProgress', handleJobProgress);
      defaultExportQueue.off('jobCompleted', handleJobCompleted);
      defaultExportQueue.off('jobFailed', handleJobFailed);
      defaultExportQueue.off('jobCancelled', handleJobCancelled);
    };
  }, [activeProgresses, updateProgress, completeProgress]);

  return {
    // State
    activeProgresses: Array.from(activeProgresses.values()),
    modalProgress,
    
    // Actions
    startProgress,
    updateStepProgress,
    completeProgress,
    cancelProgress,
    closeModal,
    
    // Utilities
    getProgress: (jobId: string) => activeProgresses.get(jobId),
    hasActiveProgress: activeProgresses.size > 0,
    getActiveCount: () => activeProgresses.size
  };
};

// Specialized hook for individual export operations
export const useExportWithProgress = (config: ProgressTrackingConfig = {}) => {
  const progressTracking = useProgressTracking(config);
  
  const executeExport = useCallback(async (
    type: ExportType,
    exportFunction: () => Promise<any>,
    fileName: string = `export_${Date.now()}`
  ) => {
    const jobId = `progress_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    try {
      // Start progress tracking
      const progress = progressTracking.startProgress(jobId, type, fileName);
      
      // Simulate step progression
      const steps = progress.steps;
      let currentStepIndex = 0;
      
      const progressInterval = setInterval(() => {
        if (currentStepIndex < steps.length) {
          const step = steps[currentStepIndex];
          progressTracking.updateStepProgress(jobId, step.id, 100, 'completed');
          currentStepIndex++;
          
          if (currentStepIndex < steps.length) {
            const nextStep = steps[currentStepIndex];
            progressTracking.updateStepProgress(jobId, nextStep.id, 0, 'running');
          }
        }
      }, 500);
      
      // Execute the actual export
      const result = await exportFunction();
      
      clearInterval(progressInterval);
      progressTracking.completeProgress(jobId, true);
      
      return result;
    } catch (error) {
      progressTracking.completeProgress(
        jobId, 
        false, 
        error instanceof Error ? error.message : 'Export failed'
      );
      throw error;
    }
  }, [progressTracking]);

  return {
    ...progressTracking,
    executeExport
  };
};