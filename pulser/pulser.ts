import { EventEmitter } from 'events';
import { agentRegistry } from './registry/agent-registry';
import { agentLoader } from './config/agent-loader';
import { router } from './routing/router';
import { validationMiddleware } from './middleware/validation-middleware';
import { pulserConfig } from './config/pulser.config';
import type { RoutingRequest, RoutingDecision } from './routing/router';

export interface PulserJob {
  id: string;
  request: RoutingRequest;
  agentId?: string;
  status: 'pending' | 'routing' | 'executing' | 'completed' | 'failed';
  result?: any;
  error?: string;
  startTime: Date;
  endTime?: Date;
  metadata?: Record<string, any>;
}

export class Pulser extends EventEmitter {
  private jobs: Map<string, PulserJob> = new Map();
  private jobQueue: PulserJob[] = [];
  private activeJobs: number = 0;
  private initialized: boolean = false;

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }

    console.log('[Pulser] Initializing...');

    try {
      // Load all agents
      const agentCount = await agentLoader.loadAllAgents();
      console.log(`[Pulser] Loaded ${agentCount} agents`);

      // Start health check interval
      if (pulserConfig.monitoring.healthCheckInterval > 0) {
        setInterval(() => this.performHealthChecks(), pulserConfig.monitoring.healthCheckInterval);
      }

      // Start job processor
      setInterval(() => this.processJobQueue(), 1000);

      this.initialized = true;
      this.emit('initialized');
      console.log('[Pulser] Initialization complete');
    } catch (error) {
      console.error('[Pulser] Initialization failed:', error);
      throw error;
    }
  }

  async execute(request: RoutingRequest): Promise<any> {
    // Validate request
    const validation = validationMiddleware.validateRequest(request);
    if (!validation.valid) {
      throw new Error(`Invalid request: ${validation.errors.join(', ')}`);
    }

    if (validation.warnings.length > 0) {
      console.warn('[Pulser] Request warnings:', validation.warnings);
    }

    // Create job
    const job: PulserJob = {
      id: this.generateJobId(),
      request: {
        ...request,
        payload: validationMiddleware.sanitizePayload(request.payload)
      },
      status: 'pending',
      startTime: new Date()
    };

    this.jobs.set(job.id, job);
    this.emit('job:created', job);

    // Add to queue
    this.jobQueue.push(job);

    // Wait for completion
    return new Promise((resolve, reject) => {
      const checkInterval = setInterval(() => {
        const currentJob = this.jobs.get(job.id);
        
        if (!currentJob) {
          clearInterval(checkInterval);
          reject(new Error('Job disappeared'));
          return;
        }

        if (currentJob.status === 'completed') {
          clearInterval(checkInterval);
          resolve(currentJob.result);
        } else if (currentJob.status === 'failed') {
          clearInterval(checkInterval);
          reject(new Error(currentJob.error || 'Job failed'));
        }

        // Check timeout
        const elapsed = Date.now() - job.startTime.getTime();
        if (elapsed > (request.context?.timeout || pulserConfig.routing.timeoutMs)) {
          clearInterval(checkInterval);
          currentJob.status = 'failed';
          currentJob.error = 'Job timed out';
          reject(new Error('Job timed out'));
        }
      }, 100);
    });
  }

  private async processJobQueue(): Promise<void> {
    if (this.activeJobs >= pulserConfig.execution.maxConcurrentJobs) {
      return;
    }

    const job = this.jobQueue.shift();
    if (!job) {
      return;
    }

    this.activeJobs++;

    try {
      // Update status
      job.status = 'routing';
      this.emit('job:routing', job);

      // Route to agent
      const decision = await router.route(job.request);
      job.agentId = decision.agentId;
      job.metadata = { routingDecision: decision };

      // Update status
      job.status = 'executing';
      this.emit('job:executing', job);

      // Execute via Bruno (or other executor)
      const result = await this.executeViaAgent(job, decision);
      
      // Update job
      job.status = 'completed';
      job.result = result;
      job.endTime = new Date();
      
      // Record metrics
      const executionTime = job.endTime.getTime() - job.startTime.getTime();
      agentRegistry.recordExecution(job.agentId, true, executionTime);
      
      this.emit('job:completed', job);
    } catch (error) {
      job.status = 'failed';
      job.error = error instanceof Error ? error.message : 'Unknown error';
      job.endTime = new Date();
      
      if (job.agentId) {
        const executionTime = job.endTime.getTime() - job.startTime.getTime();
        agentRegistry.recordExecution(job.agentId, false, executionTime);
      }
      
      this.emit('job:failed', job);
    } finally {
      this.activeJobs--;
      
      // Update agent state
      if (job.agentId) {
        agentRegistry.updateAgentState(job.agentId, 'idle');
      }
    }
  }

  private async executeViaAgent(job: PulserJob, decision: RoutingDecision): Promise<any> {
    const agent = agentRegistry.get(decision.agentId);
    if (!agent) {
      throw new Error(`Agent ${decision.agentId} not found`);
    }

    // Validate permissions
    const requiredPermissions = this.extractRequiredPermissions(job.request, agent);
    const grantedPermissions = this.getGrantedPermissions(agent);
    
    if (!validationMiddleware.validatePermissions(requiredPermissions, grantedPermissions)) {
      throw new Error('Insufficient permissions for operation');
    }

    // Execute based on runtime
    switch (agent.config.runtime) {
      case 'bruno':
        return this.executeViaBruno(job, agent);
      
      case 'node':
        return this.executeViaNode(job, agent);
      
      case 'python':
        return this.executeViaPython(job, agent);
      
      default:
        throw new Error(`Unsupported runtime: ${agent.config.runtime}`);
    }
  }

  private async executeViaBruno(job: PulserJob, agent: any): Promise<any> {
    // This would integrate with Bruno executor
    console.log(`[Pulser] Executing job ${job.id} via Bruno with agent ${agent.config.metadata.name}`);
    
    // Simulate Bruno execution
    return {
      jobId: job.id,
      agentId: agent.config.metadata.id,
      status: 'completed',
      result: `Executed ${job.request.type} successfully`,
      executedAt: new Date().toISOString()
    };
  }

  private async executeViaNode(job: PulserJob, agent: any): Promise<any> {
    // Node.js execution (sandboxed)
    throw new Error('Node.js runtime not implemented yet');
  }

  private async executeViaPython(job: PulserJob, agent: any): Promise<any> {
    // Python execution (sandboxed)
    throw new Error('Python runtime not implemented yet');
  }

  private extractRequiredPermissions(request: RoutingRequest, agent: any): string[] {
    // Extract permissions based on request and capabilities
    const permissions: string[] = [];
    
    // Find matching capability
    const capability = agent.config.capabilities.find((cap: any) => 
      request.type === cap.name || request.category === cap.name
    );
    
    if (capability?.permissions) {
      permissions.push(...capability.permissions);
    }
    
    return permissions;
  }

  private getGrantedPermissions(agent: any): string[] {
    // In production, this would check against actual permission system
    return agent.config.security.requiredPermissions || [];
  }

  private async performHealthChecks(): Promise<void> {
    const agents = agentRegistry.list();
    
    for (const agent of agents) {
      try {
        await agentRegistry.healthCheck(agent.config.metadata.id);
      } catch (error) {
        console.error(`[Pulser] Health check failed for ${agent.config.metadata.id}:`, error);
      }
    }
  }

  private generateJobId(): string {
    return `job-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  // Public API

  async reloadAgent(agentId: string): Promise<void> {
    await agentLoader.reloadAgent(agentId);
  }

  getJob(jobId: string): PulserJob | undefined {
    return this.jobs.get(jobId);
  }

  getJobs(filter?: Partial<PulserJob>): PulserJob[] {
    let jobs = Array.from(this.jobs.values());
    
    if (filter) {
      jobs = jobs.filter(job => {
        return Object.entries(filter).every(([key, value]) => {
          return job[key as keyof PulserJob] === value;
        });
      });
    }
    
    return jobs;
  }

  getAgents() {
    return agentRegistry.list();
  }

  getMetrics() {
    return {
      totalJobs: this.jobs.size,
      activeJobs: this.activeJobs,
      queuedJobs: this.jobQueue.length,
      agents: agentRegistry.list().map(agent => ({
        id: agent.config.metadata.id,
        name: agent.config.metadata.name,
        state: agent.state,
        metrics: agent.metrics
      }))
    };
  }
}

// Export singleton instance
export const pulser = new Pulser();