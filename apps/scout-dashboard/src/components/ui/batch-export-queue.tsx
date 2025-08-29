import React, { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './card';
import { Button } from './button';
import { Badge } from './badge';
import { Progress } from './progress';
import { Skeleton } from './skeleton';
import { 
  Download, 
  FileSpreadsheet, 
  FileImage, 
  FileText, 
  Play, 
  Pause, 
  X, 
  Trash2, 
  AlertCircle, 
  CheckCircle, 
  Clock,
  Loader2,
  Archive
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { 
  BatchExportQueue, 
  ExportJob, 
  QueueStats, 
  BatchProgress,
  defaultExportQueue 
} from '@/lib/exports/batchExportQueue';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, DropdownMenuSeparator } from './dropdown-menu';
import { ScrollArea } from './scroll-area';

interface BatchExportQueueProps {
  className?: string;
  maxHeight?: number;
  showStats?: boolean;
  showControls?: boolean;
  autoRefresh?: boolean;
  refreshInterval?: number;
}

export const BatchExportQueueComponent: React.FC<BatchExportQueueProps> = ({
  className,
  maxHeight = 400,
  showStats = true,
  showControls = true,
  autoRefresh = true,
  refreshInterval = 1000
}) => {
  const [jobs, setJobs] = useState<ExportJob[]>([]);
  const [stats, setStats] = useState<QueueStats>({ 
    total: 0, pending: 0, running: 0, completed: 0, failed: 0, cancelled: 0 
  });
  const [batchProgress, setBatchProgress] = useState<BatchProgress>({
    jobId: '', progress: 0, status: 'idle', totalJobs: 0, completedJobs: 0, failedJobs: 0
  });
  const [isPaused, setIsPaused] = useState(false);
  const [filter, setFilter] = useState<'all' | 'active' | 'completed' | 'failed'>('all');

  // Refresh data
  const refreshData = useCallback(() => {
    const allJobs = defaultExportQueue.getAllJobs();
    setJobs(allJobs);
    setStats(defaultExportQueue.getStats());
    setBatchProgress(defaultExportQueue.getBatchProgress());
  }, []);

  // Set up event listeners and auto-refresh
  useEffect(() => {
    refreshData();

    // Event listeners
    const handleJobUpdate = () => refreshData();
    const handleQueueUpdate = () => refreshData();
    const handleProgress = () => refreshData();

    defaultExportQueue.on('jobAdded', handleJobUpdate);
    defaultExportQueue.on('jobStarted', handleJobUpdate);
    defaultExportQueue.on('jobCompleted', handleJobUpdate);
    defaultExportQueue.on('jobFailed', handleJobUpdate);
    defaultExportQueue.on('jobCancelled', handleJobUpdate);
    defaultExportQueue.on('jobProgress', handleProgress);
    defaultExportQueue.on('queueUpdated', handleQueueUpdate);
    defaultExportQueue.on('queuePaused', () => setIsPaused(true));
    defaultExportQueue.on('queueResumed', () => setIsPaused(false));

    // Auto-refresh interval
    let interval: NodeJS.Timeout | undefined;
    if (autoRefresh) {
      interval = setInterval(refreshData, refreshInterval);
    }

    return () => {
      // Cleanup event listeners
      defaultExportQueue.off('jobAdded', handleJobUpdate);
      defaultExportQueue.off('jobStarted', handleJobUpdate);
      defaultExportQueue.off('jobCompleted', handleJobUpdate);
      defaultExportQueue.off('jobFailed', handleJobUpdate);
      defaultExportQueue.off('jobCancelled', handleJobUpdate);
      defaultExportQueue.off('jobProgress', handleProgress);
      defaultExportQueue.off('queueUpdated', handleQueueUpdate);

      if (interval) {
        clearInterval(interval);
      }
    };
  }, [refreshData, autoRefresh, refreshInterval]);

  const handlePauseResume = () => {
    if (isPaused) {
      defaultExportQueue.resume();
    } else {
      defaultExportQueue.pause();
    }
  };

  const handleCancelJob = (jobId: string) => {
    defaultExportQueue.cancelJob(jobId);
  };

  const handleCancelAll = () => {
    const cancelled = defaultExportQueue.cancelAll();
    if (cancelled > 0) {
      console.log(`Cancelled ${cancelled} jobs`);
    }
  };

  const handleClearCompleted = () => {
    const cleared = defaultExportQueue.clearCompleted();
    if (cleared > 0) {
      console.log(`Cleared ${cleared} completed jobs`);
    }
  };

  const getJobIcon = (type: ExportJob['type']) => {
    switch (type) {
      case 'csv': return <FileSpreadsheet className="h-4 w-4" />;
      case 'png': return <FileImage className="h-4 w-4" />;
      case 'pdf': return <FileText className="h-4 w-4" />;
      default: return <Download className="h-4 w-4" />;
    }
  };

  const getStatusIcon = (status: ExportJob['status']) => {
    switch (status) {
      case 'running':
        return <Loader2 className="h-4 w-4 animate-spin text-blue-600" />;
      case 'completed':
        return <CheckCircle className="h-4 w-4 text-green-600" />;
      case 'failed':
        return <AlertCircle className="h-4 w-4 text-red-600" />;
      case 'cancelled':
        return <X className="h-4 w-4 text-gray-500" />;
      case 'pending':
      default:
        return <Clock className="h-4 w-4 text-yellow-600" />;
    }
  };

  const getStatusColor = (status: ExportJob['status']) => {
    switch (status) {
      case 'running': return 'bg-blue-100 text-blue-800 border-blue-200';
      case 'completed': return 'bg-green-100 text-green-800 border-green-200';
      case 'failed': return 'bg-red-100 text-red-800 border-red-200';
      case 'cancelled': return 'bg-gray-100 text-gray-800 border-gray-200';
      case 'pending':
      default: return 'bg-yellow-100 text-yellow-800 border-yellow-200';
    }
  };

  const getPriorityColor = (priority: ExportJob['priority']) => {
    switch (priority) {
      case 'high': return 'border-l-red-500';
      case 'normal': return 'border-l-blue-500';
      case 'low': return 'border-l-gray-500';
    }
  };

  const filteredJobs = jobs.filter(job => {
    switch (filter) {
      case 'active':
        return job.status === 'pending' || job.status === 'running';
      case 'completed':
        return job.status === 'completed';
      case 'failed':
        return job.status === 'failed' || job.status === 'cancelled';
      case 'all':
      default:
        return true;
    }
  });

  const formatTimeElapsed = (startTime?: Date, endTime?: Date) => {
    if (!startTime) return '';
    const end = endTime || new Date();
    const elapsed = Math.round((end.getTime() - startTime.getTime()) / 1000);
    if (elapsed < 60) return `${elapsed}s`;
    return `${Math.floor(elapsed / 60)}m ${elapsed % 60}s`;
  };

  if (stats.total === 0) {
    return (
      <Card className={className}>
        <CardContent className="flex items-center justify-center py-8">
          <div className="text-center">
            <Download className="h-8 w-8 text-gray-400 mx-auto mb-2" />
            <p className="text-gray-500">No export jobs in queue</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={className}>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Download className="h-5 w-5 text-blue-600" />
            <CardTitle className="text-lg">Export Queue</CardTitle>
            {stats.running > 0 && (
              <Badge className="bg-blue-100 text-blue-800">
                {stats.running} running
              </Badge>
            )}
          </div>
          
          {showControls && (
            <div className="flex items-center space-x-2">
              {/* Filter Dropdown */}
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" size="sm" className="gap-2">
                    {filter === 'all' && 'All Jobs'}
                    {filter === 'active' && 'Active'}
                    {filter === 'completed' && 'Completed'}
                    {filter === 'failed' && 'Failed'}
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => setFilter('all')}>
                    All Jobs ({stats.total})
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => setFilter('active')}>
                    Active ({stats.pending + stats.running})
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => setFilter('completed')}>
                    Completed ({stats.completed})
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => setFilter('failed')}>
                    Failed ({stats.failed + stats.cancelled})
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>

              {/* Queue Controls */}
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" size="sm">
                    ⋮
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem 
                    onClick={handlePauseResume}
                    className="gap-2"
                  >
                    {isPaused ? <Play className="h-4 w-4" /> : <Pause className="h-4 w-4" />}
                    {isPaused ? 'Resume Queue' : 'Pause Queue'}
                  </DropdownMenuItem>
                  <DropdownMenuItem 
                    onClick={handleCancelAll}
                    disabled={stats.pending + stats.running === 0}
                    className="gap-2"
                  >
                    <X className="h-4 w-4" />
                    Cancel All
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem 
                    onClick={handleClearCompleted}
                    disabled={stats.completed + stats.failed + stats.cancelled === 0}
                    className="gap-2"
                  >
                    <Archive className="h-4 w-4" />
                    Clear Completed
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          )}
        </div>

        {/* Overall Progress */}
        {stats.running > 0 && showStats && (
          <div className="mt-3">
            <div className="flex items-center justify-between text-sm text-gray-600 mb-2">
              <span>Overall Progress</span>
              <span>{batchProgress.completedJobs}/{batchProgress.totalJobs} completed</span>
            </div>
            <Progress value={batchProgress.progress} className="h-2" />
            {batchProgress.currentJob && (
              <p className="text-xs text-gray-500 mt-1 truncate">
                Current: {batchProgress.currentJob}
              </p>
            )}
          </div>
        )}

        {/* Stats */}
        {showStats && (
          <div className="flex items-center space-x-4 text-sm text-gray-600 mt-3">
            <div className="flex items-center space-x-1">
              <div className="w-2 h-2 rounded-full bg-yellow-500" />
              <span>{stats.pending} pending</span>
            </div>
            <div className="flex items-center space-x-1">
              <div className="w-2 h-2 rounded-full bg-blue-500" />
              <span>{stats.running} running</span>
            </div>
            <div className="flex items-center space-x-1">
              <div className="w-2 h-2 rounded-full bg-green-500" />
              <span>{stats.completed} completed</span>
            </div>
            {(stats.failed + stats.cancelled) > 0 && (
              <div className="flex items-center space-x-1">
                <div className="w-2 h-2 rounded-full bg-red-500" />
                <span>{stats.failed + stats.cancelled} failed</span>
              </div>
            )}
          </div>
        )}
      </CardHeader>

      <CardContent className="pt-0">
        <ScrollArea className="pr-4" style={{ maxHeight: `${maxHeight}px` }}>
          <div className="space-y-3">
            {filteredJobs.length === 0 ? (
              <div className="text-center py-4 text-gray-500">
                No jobs in {filter} state
              </div>
            ) : (
              filteredJobs.map((job) => (
                <div
                  key={job.id}
                  className={cn(
                    'border border-l-4 rounded-lg p-3',
                    getPriorityColor(job.priority)
                  )}
                >
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center space-x-2 flex-1 min-w-0">
                      {getJobIcon(job.type)}
                      <span className="font-medium truncate">{job.name}</span>
                      <Badge className={cn('text-xs border', getStatusColor(job.status))}>
                        {job.status}
                      </Badge>
                      {job.priority !== 'normal' && (
                        <Badge variant="outline" className="text-xs">
                          {job.priority}
                        </Badge>
                      )}
                    </div>
                    
                    <div className="flex items-center space-x-2">
                      {getStatusIcon(job.status)}
                      
                      {(job.status === 'pending' || job.status === 'running') && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleCancelJob(job.id)}
                          className="h-6 w-6 p-0 hover:bg-red-100"
                        >
                          <X className="h-3 w-3" />
                        </Button>
                      )}
                    </div>
                  </div>

                  {/* Progress Bar for Running Jobs */}
                  {job.status === 'running' && (
                    <div className="mb-2">
                      <Progress value={job.progress} className="h-1 mb-1" />
                      <div className="flex justify-between text-xs text-gray-500">
                        <span>{job.progress}% complete</span>
                        <span>{formatTimeElapsed(job.startedAt)}</span>
                      </div>
                    </div>
                  )}

                  {/* Job Details */}
                  <div className="flex justify-between text-xs text-gray-500">
                    <div className="flex items-center space-x-3">
                      <span className="uppercase">{job.type}</span>
                      {job.data && (
                        <span>{job.data.length} records</span>
                      )}
                      <span>Created {job.createdAt.toLocaleTimeString()}</span>
                    </div>
                    
                    {job.completedAt && (
                      <span>
                        Finished {formatTimeElapsed(job.startedAt, job.completedAt)}
                      </span>
                    )}
                  </div>

                  {/* Error Message */}
                  {job.status === 'failed' && job.result?.error && (
                    <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded text-xs text-red-700">
                      <AlertCircle className="h-3 w-3 inline mr-1" />
                      {job.result.error}
                      {job.retryCount > 0 && (
                        <span className="ml-2 text-red-500">
                          (Retried {job.retryCount} times)
                        </span>
                      )}
                    </div>
                  )}

                  {/* Success Message */}
                  {job.status === 'completed' && job.result?.filename && (
                    <div className="mt-2 p-2 bg-green-50 border border-green-200 rounded text-xs text-green-700">
                      <CheckCircle className="h-3 w-3 inline mr-1" />
                      Exported as {job.result.filename}
                      {job.result.fileSize && (
                        <span className="ml-2">
                          ({(job.result.fileSize / 1024).toFixed(1)} KB)
                        </span>
                      )}
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </ScrollArea>
      </CardContent>
    </Card>
  );
};

// Hook for using the export queue in components
export const useExportQueue = () => {
  const [stats, setStats] = useState<QueueStats>({ 
    total: 0, pending: 0, running: 0, completed: 0, failed: 0, cancelled: 0 
  });
  const [batchProgress, setBatchProgress] = useState<BatchProgress>({
    jobId: '', progress: 0, status: 'idle', totalJobs: 0, completedJobs: 0, failedJobs: 0
  });

  const refreshStats = useCallback(() => {
    setStats(defaultExportQueue.getStats());
    setBatchProgress(defaultExportQueue.getBatchProgress());
  }, []);

  useEffect(() => {
    refreshStats();

    const handleUpdate = () => refreshStats();
    defaultExportQueue.on('queueUpdated', handleUpdate);
    defaultExportQueue.on('jobProgress', handleUpdate);

    return () => {
      defaultExportQueue.off('queueUpdated', handleUpdate);
      defaultExportQueue.off('jobProgress', handleUpdate);
    };
  }, [refreshStats]);

  const addJob = useCallback((params: {
    type: 'csv' | 'png' | 'pdf';
    name: string;
    data?: any[];
    element?: HTMLElement;
    elementSelector?: string;
    options?: any;
    priority?: 'low' | 'normal' | 'high';
  }) => {
    return defaultExportQueue.addJob(params);
  }, []);

  const addBatch = useCallback((jobs: Array<{
    type: 'csv' | 'png' | 'pdf';
    name: string;
    data?: any[];
    element?: HTMLElement;
    elementSelector?: string;
    options?: any;
    priority?: 'low' | 'normal' | 'high';
  }>) => {
    return defaultExportQueue.addBatch(jobs);
  }, []);

  return {
    stats,
    batchProgress,
    addJob,
    addBatch,
    cancelJob: (jobId: string) => defaultExportQueue.cancelJob(jobId),
    cancelAll: () => defaultExportQueue.cancelAll(),
    clearCompleted: () => defaultExportQueue.clearCompleted(),
    pause: () => defaultExportQueue.pause(),
    resume: () => defaultExportQueue.resume(),
  };
};

export default BatchExportQueueComponent;