/**
 * Batch Export Queue System
 * Handles multiple export operations with queuing, progress tracking, and error handling
 */

import { EventEmitter } from 'events';

export type ExportType = 'csv' | 'png' | 'pdf';

export interface ExportJob {
  id: string;
  type: ExportType;
  name: string;
  data?: any[];
  element?: HTMLElement;
  elementSelector?: string;
  options?: any;
  priority: 'low' | 'normal' | 'high';
  createdAt: Date;
  startedAt?: Date;
  completedAt?: Date;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
  progress: number; // 0-100
  result?: {
    success: boolean;
    filename?: string;
    error?: string;
    downloadUrl?: string;
    fileSize?: number;
  };
  retryCount: number;
  maxRetries: number;
}

export interface BatchExportConfig {
  maxConcurrentJobs: number;
  maxRetries: number;
  retryDelay: number;
  jobTimeout: number;
  enablePersistence: boolean;
  storageKey: string;
}

export interface QueueStats {
  total: number;
  pending: number;
  running: number;
  completed: number;
  failed: number;
  cancelled: number;
}

export interface BatchProgress {
  jobId: string;
  progress: number;
  status: string;
  currentJob?: string;
  totalJobs: number;
  completedJobs: number;
  failedJobs: number;
}

export class BatchExportQueue extends EventEmitter {
  private jobs: Map<string, ExportJob> = new Map();
  private runningJobs: Set<string> = new Set();
  private config: BatchExportConfig;
  private processingInterval?: NodeJS.Timeout;
  private isProcessing = false;

  constructor(config: Partial<BatchExportConfig> = {}) {
    super();
    
    this.config = {
      maxConcurrentJobs: config.maxConcurrentJobs || 3,
      maxRetries: config.maxRetries || 2,
      retryDelay: config.retryDelay || 1000,
      jobTimeout: config.jobTimeout || 60000, // 60 seconds
      enablePersistence: config.enablePersistence ?? true,
      storageKey: config.storageKey || 'scout_export_queue'
    };

    // Load persisted jobs if enabled
    if (this.config.enablePersistence && typeof window !== 'undefined') {
      this.loadPersistedJobs();
    }

    // Start processing queue
    this.startProcessing();
  }

  /**
   * Add a new export job to the queue
   */
  addJob(params: {
    type: ExportType;
    name: string;
    data?: any[];
    element?: HTMLElement;
    elementSelector?: string;
    options?: any;
    priority?: 'low' | 'normal' | 'high';
  }): string {
    const jobId = this.generateJobId();
    
    const job: ExportJob = {
      id: jobId,
      type: params.type,
      name: params.name,
      data: params.data,
      element: params.element,
      elementSelector: params.elementSelector,
      options: params.options || {},
      priority: params.priority || 'normal',
      createdAt: new Date(),
      status: 'pending',
      progress: 0,
      retryCount: 0,
      maxRetries: this.config.maxRetries
    };

    this.jobs.set(jobId, job);
    this.persistJobs();
    
    this.emit('jobAdded', job);
    this.emit('queueUpdated', this.getStats());
    
    return jobId;
  }

  /**
   * Add multiple jobs as a batch
   */
  addBatch(jobs: Array<{
    type: ExportType;
    name: string;
    data?: any[];
    element?: HTMLElement;
    elementSelector?: string;
    options?: any;
    priority?: 'low' | 'normal' | 'high';
  }>): string[] {
    const batchId = this.generateJobId();
    const jobIds: string[] = [];

    jobs.forEach((jobParams, index) => {
      const jobId = this.addJob({
        ...jobParams,
        name: `${jobParams.name} (${index + 1}/${jobs.length})`
      });
      jobIds.push(jobId);
    });

    this.emit('batchAdded', { batchId, jobIds, total: jobs.length });
    
    return jobIds;
  }

  /**
   * Cancel a specific job
   */
  cancelJob(jobId: string): boolean {
    const job = this.jobs.get(jobId);
    if (!job) return false;

    if (job.status === 'pending') {
      job.status = 'cancelled';
      job.completedAt = new Date();
      this.emit('jobCancelled', job);
      this.emit('queueUpdated', this.getStats());
      this.persistJobs();
      return true;
    }

    if (job.status === 'running') {
      job.status = 'cancelled';
      job.completedAt = new Date();
      this.runningJobs.delete(jobId);
      this.emit('jobCancelled', job);
      this.emit('queueUpdated', this.getStats());
      this.persistJobs();
      return true;
    }

    return false;
  }

  /**
   * Cancel all pending jobs
   */
  cancelAll(): number {
    let cancelledCount = 0;
    
    this.jobs.forEach((job) => {
      if (job.status === 'pending' || job.status === 'running') {
        job.status = 'cancelled';
        job.completedAt = new Date();
        if (job.status === 'running') {
          this.runningJobs.delete(job.id);
        }
        cancelledCount++;
      }
    });

    if (cancelledCount > 0) {
      this.emit('batchCancelled', { cancelledCount });
      this.emit('queueUpdated', this.getStats());
      this.persistJobs();
    }

    return cancelledCount;
  }

  /**
   * Clear completed and failed jobs
   */
  clearCompleted(): number {
    const completedJobs: string[] = [];
    
    this.jobs.forEach((job, id) => {
      if (job.status === 'completed' || job.status === 'failed' || job.status === 'cancelled') {
        completedJobs.push(id);
      }
    });

    completedJobs.forEach(id => {
      this.jobs.delete(id);
    });

    if (completedJobs.length > 0) {
      this.emit('queueCleared', { clearedCount: completedJobs.length });
      this.emit('queueUpdated', this.getStats());
      this.persistJobs();
    }

    return completedJobs.length;
  }

  /**
   * Get job by ID
   */
  getJob(jobId: string): ExportJob | undefined {
    return this.jobs.get(jobId);
  }

  /**
   * Get all jobs with optional filtering
   */
  getAllJobs(filter?: {
    status?: ExportJob['status'][];
    type?: ExportType[];
    priority?: ExportJob['priority'][];
  }): ExportJob[] {
    const jobs = Array.from(this.jobs.values());
    
    if (!filter) return jobs;

    return jobs.filter(job => {
      if (filter.status && !filter.status.includes(job.status)) return false;
      if (filter.type && !filter.type.includes(job.type)) return false;
      if (filter.priority && !filter.priority.includes(job.priority)) return false;
      return true;
    });
  }

  /**
   * Get queue statistics
   */
  getStats(): QueueStats {
    const jobs = Array.from(this.jobs.values());
    
    return {
      total: jobs.length,
      pending: jobs.filter(j => j.status === 'pending').length,
      running: jobs.filter(j => j.status === 'running').length,
      completed: jobs.filter(j => j.status === 'completed').length,
      failed: jobs.filter(j => j.status === 'failed').length,
      cancelled: jobs.filter(j => j.status === 'cancelled').length
    };
  }

  /**
   * Get overall batch progress
   */
  getBatchProgress(): BatchProgress {
    const jobs = Array.from(this.jobs.values());
    const runningJob = jobs.find(j => j.status === 'running');
    
    return {
      jobId: runningJob?.id || '',
      progress: jobs.length > 0 ? Math.round(jobs.reduce((sum, job) => sum + job.progress, 0) / jobs.length) : 0,
      status: this.isProcessing ? 'processing' : 'idle',
      currentJob: runningJob?.name,
      totalJobs: jobs.length,
      completedJobs: jobs.filter(j => j.status === 'completed').length,
      failedJobs: jobs.filter(j => j.status === 'failed').length
    };
  }

  /**
   * Pause queue processing
   */
  pause(): void {
    this.isProcessing = false;
    if (this.processingInterval) {
      clearInterval(this.processingInterval);
      this.processingInterval = undefined;
    }
    this.emit('queuePaused');
  }

  /**
   * Resume queue processing
   */
  resume(): void {
    if (!this.isProcessing) {
      this.startProcessing();
      this.emit('queueResumed');
    }
  }

  /**
   * Start processing the queue
   */
  private startProcessing(): void {
    if (this.processingInterval) return;
    
    this.isProcessing = true;
    this.processingInterval = setInterval(() => {
      this.processNextJobs();
    }, 100);
  }

  /**
   * Process next available jobs
   */
  private async processNextJobs(): Promise<void> {
    if (!this.isProcessing) return;

    const availableSlots = this.config.maxConcurrentJobs - this.runningJobs.size;
    if (availableSlots <= 0) return;

    const pendingJobs = this.getPendingJobsByPriority();
    const jobsToStart = pendingJobs.slice(0, availableSlots);

    for (const job of jobsToStart) {
      this.processJob(job);
    }
  }

  /**
   * Get pending jobs sorted by priority
   */
  private getPendingJobsByPriority(): ExportJob[] {
    const priorityOrder = { high: 3, normal: 2, low: 1 };
    
    return Array.from(this.jobs.values())
      .filter(job => job.status === 'pending')
      .sort((a, b) => {
        const priorityDiff = priorityOrder[b.priority] - priorityOrder[a.priority];
        if (priorityDiff !== 0) return priorityDiff;
        return a.createdAt.getTime() - b.createdAt.getTime();
      });
  }

  /**
   * Process a single job
   */
  private async processJob(job: ExportJob): Promise<void> {
    this.runningJobs.add(job.id);
    job.status = 'running';
    job.startedAt = new Date();
    job.progress = 0;
    
    this.emit('jobStarted', job);
    this.emit('queueUpdated', this.getStats());

    const timeout = setTimeout(() => {
      this.handleJobTimeout(job);
    }, this.config.jobTimeout);

    try {
      const result = await this.executeJob(job);
      clearTimeout(timeout);
      
      if (this.jobs.get(job.id)?.status === 'cancelled') return;
      
      job.status = 'completed';
      job.progress = 100;
      job.completedAt = new Date();
      job.result = result;
      
      this.emit('jobCompleted', job);
      this.emit('jobProgress', { jobId: job.id, progress: 100 });
      
    } catch (error) {
      clearTimeout(timeout);
      
      if (this.jobs.get(job.id)?.status === 'cancelled') return;
      
      await this.handleJobError(job, error);
    } finally {
      this.runningJobs.delete(job.id);
      this.emit('queueUpdated', this.getStats());
      this.persistJobs();
    }
  }

  /**
   * Execute the actual export job
   */
  private async executeJob(job: ExportJob): Promise<any> {
    // Update progress
    job.progress = 10;
    this.emit('jobProgress', { jobId: job.id, progress: 10 });

    let result: any;

    switch (job.type) {
      case 'csv':
        job.progress = 25;
        this.emit('jobProgress', { jobId: job.id, progress: 25 });
        result = await this.executeCSVExport(job);
        break;
        
      case 'png':
        job.progress = 25;
        this.emit('jobProgress', { jobId: job.id, progress: 25 });
        result = await this.executePNGExport(job);
        break;
        
      case 'pdf':
        job.progress = 25;
        this.emit('jobProgress', { jobId: job.id, progress: 25 });
        result = await this.executePDFExport(job);
        break;
        
      default:
        throw new Error(`Unsupported export type: ${job.type}`);
    }

    job.progress = 90;
    this.emit('jobProgress', { jobId: job.id, progress: 90 });

    return result;
  }

  /**
   * Execute CSV export
   */
  private async executeCSVExport(job: ExportJob): Promise<any> {
    const { csvExporter } = await import('./csvExporter');
    
    if (!job.data || job.data.length === 0) {
      throw new Error('No data available for CSV export');
    }

    job.progress = 50;
    this.emit('jobProgress', { jobId: job.id, progress: 50 });

    const result = await csvExporter.exportData(job.data, {
      filename: `${job.name.toLowerCase().replace(/\s+/g, '_')}.csv`,
      includeTimestamp: true,
      ...job.options
    });

    job.progress = 80;
    this.emit('jobProgress', { jobId: job.id, progress: 80 });

    return result;
  }

  /**
   * Execute PNG export
   */
  private async executePNGExport(job: ExportJob): Promise<any> {
    const { pngExporter } = await import('./pngExporter');
    
    let targetElement: HTMLElement | null = null;

    if (job.element) {
      targetElement = job.element;
    } else if (job.elementSelector) {
      targetElement = document.querySelector(job.elementSelector) as HTMLElement;
    }

    if (!targetElement) {
      throw new Error('No target element found for PNG export');
    }

    job.progress = 50;
    this.emit('jobProgress', { jobId: job.id, progress: 50 });

    const result = await pngExporter.exportElement(targetElement, {
      filename: `${job.name.toLowerCase().replace(/\s+/g, '_')}.png`,
      includeTimestamp: true,
      ...job.options
    });

    job.progress = 80;
    this.emit('jobProgress', { jobId: job.id, progress: 80 });

    return result;
  }

  /**
   * Execute PDF export
   */
  private async executePDFExport(job: ExportJob): Promise<any> {
    const { pdfExporter } = await import('./pdfExporter');
    
    job.progress = 40;
    this.emit('jobProgress', { jobId: job.id, progress: 40 });

    let result: any;

    if (job.data && job.data.length > 0) {
      // Generate report from data
      result = await pdfExporter.generateReport({
        title: job.name,
        subtitle: 'Generated from Scout Dashboard',
        sections: [
          {
            title: 'Data Export',
            type: 'table',
            content: job.data,
            tableOptions: {
              headers: Object.keys(job.data[0] || {}),
              maxRows: 100
            }
          }
        ],
        metadata: {
          generatedAt: new Date(),
          totalRecords: job.data.length
        },
        ...job.options
      });
    } else if (job.element || job.elementSelector) {
      // Export element to PDF
      let targetElement: HTMLElement | null = null;

      if (job.element) {
        targetElement = job.element;
      } else if (job.elementSelector) {
        targetElement = document.querySelector(job.elementSelector) as HTMLElement;
      }

      if (!targetElement) {
        throw new Error('No target element found for PDF export');
      }

      job.progress = 60;
      this.emit('jobProgress', { jobId: job.id, progress: 60 });

      result = await pdfExporter.exportElement(targetElement, {
        filename: `${job.name.toLowerCase().replace(/\s+/g, '_')}.pdf`,
        includeTimestamp: true,
        ...job.options
      });
    } else {
      throw new Error('No data or element provided for PDF export');
    }

    job.progress = 80;
    this.emit('jobProgress', { jobId: job.id, progress: 80 });

    return result;
  }

  /**
   * Handle job timeout
   */
  private handleJobTimeout(job: ExportJob): void {
    if (job.status !== 'running') return;
    
    job.status = 'failed';
    job.progress = 0;
    job.completedAt = new Date();
    job.result = {
      success: false,
      error: `Job timed out after ${this.config.jobTimeout / 1000} seconds`
    };
    
    this.runningJobs.delete(job.id);
    this.emit('jobFailed', job);
    this.emit('queueUpdated', this.getStats());
    this.persistJobs();
  }

  /**
   * Handle job error with retry logic
   */
  private async handleJobError(job: ExportJob, error: any): Promise<void> {
    job.retryCount++;
    
    if (job.retryCount <= job.maxRetries) {
      // Retry the job
      job.status = 'pending';
      job.progress = 0;
      job.startedAt = undefined;
      
      this.emit('jobRetry', { job, attempt: job.retryCount, error });
      
      // Add delay before retry
      setTimeout(() => {
        // Job will be picked up by the next processing cycle
      }, this.config.retryDelay * job.retryCount);
      
    } else {
      // Max retries reached, mark as failed
      job.status = 'failed';
      job.progress = 0;
      job.completedAt = new Date();
      job.result = {
        success: false,
        error: error instanceof Error ? error.message : String(error)
      };
      
      this.emit('jobFailed', job);
    }
  }

  /**
   * Generate unique job ID
   */
  private generateJobId(): string {
    return `export_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Persist jobs to localStorage
   */
  private persistJobs(): void {
    if (!this.config.enablePersistence || typeof window === 'undefined') return;
    
    try {
      const jobsData = Array.from(this.jobs.entries()).map(([id, job]) => ({
        id,
        ...job,
        // Remove non-serializable elements
        element: undefined,
        createdAt: job.createdAt.toISOString(),
        startedAt: job.startedAt?.toISOString(),
        completedAt: job.completedAt?.toISOString()
      }));
      
      localStorage.setItem(this.config.storageKey, JSON.stringify(jobsData));
    } catch (error) {
      console.warn('Failed to persist export jobs:', error);
    }
  }

  /**
   * Load persisted jobs from localStorage
   */
  private loadPersistedJobs(): void {
    if (typeof window === 'undefined') return;
    
    try {
      const stored = localStorage.getItem(this.config.storageKey);
      if (!stored) return;
      
      const jobsData = JSON.parse(stored);
      if (!Array.isArray(jobsData)) return;
      
      jobsData.forEach((jobData: any) => {
        // Only load pending jobs, reset running jobs to pending
        if (jobData.status === 'running') {
          jobData.status = 'pending';
          jobData.progress = 0;
          jobData.startedAt = undefined;
        }
        
        // Skip completed/failed jobs that are older than 24 hours
        if ((jobData.status === 'completed' || jobData.status === 'failed') && 
            jobData.completedAt) {
          const completedAt = new Date(jobData.completedAt);
          const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
          if (completedAt < dayAgo) return;
        }
        
        const job: ExportJob = {
          ...jobData,
          createdAt: new Date(jobData.createdAt),
          startedAt: jobData.startedAt ? new Date(jobData.startedAt) : undefined,
          completedAt: jobData.completedAt ? new Date(jobData.completedAt) : undefined
        };
        
        this.jobs.set(job.id, job);
      });
      
      console.log(`Loaded ${this.jobs.size} persisted export jobs`);
    } catch (error) {
      console.warn('Failed to load persisted export jobs:', error);
    }
  }

  /**
   * Cleanup and destroy the queue
   */
  destroy(): void {
    this.pause();
    this.cancelAll();
    this.jobs.clear();
    this.removeAllListeners();
    
    if (this.config.enablePersistence && typeof window !== 'undefined') {
      localStorage.removeItem(this.config.storageKey);
    }
  }
}

// Default instance
export const defaultExportQueue = new BatchExportQueue();

// Export utility functions
export const addExportJob = (params: {
  type: ExportType;
  name: string;
  data?: any[];
  element?: HTMLElement;
  elementSelector?: string;
  options?: any;
  priority?: 'low' | 'normal' | 'high';
}): string => {
  return defaultExportQueue.addJob(params);
};

export const addExportBatch = (jobs: Array<{
  type: ExportType;
  name: string;
  data?: any[];
  element?: HTMLElement;
  elementSelector?: string;
  options?: any;
  priority?: 'low' | 'normal' | 'high';
}>): string[] => {
  return defaultExportQueue.addBatch(jobs);
};

export const getExportQueueStats = (): QueueStats => {
  return defaultExportQueue.getStats();
};

export const getBatchExportProgress = (): BatchProgress => {
  return defaultExportQueue.getBatchProgress();
};